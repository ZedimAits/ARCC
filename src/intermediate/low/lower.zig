// ─────────────────────────────────────────────────────────────────────
// SPDX-License-Identifier: Apache-2.0
//
// ARCC - Advanced Retargetable Compiler Collection - Version 0.1.0
//
// Copyright (C) 2026 Cedric Beck
// Copyright (C) 2026 Felix Koppe <fkoppe@web.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// ─────────────────────────────────────────────────────────────────────

const std = @import("std");

const front = @import("../../frontend/front.zig");
const mlir = @import("../medium/mlir.zig");
const llir = @import("llir.zig");
const symbol = @import("../symbol.zig");
const type_interner = @import("../type_interner.zig");

pub const LowerError = error{
    MissingResultSlot,
    UnsupportedValueKind,
};

const LowerCtx = struct {
    ml_graph: *const mlir.MLGraph,
    mod: llir.LLModule,
    value_slots: std.AutoHashMap(u32, llir.LLValueID),
    block_map: std.AutoHashMap(u32, llir.LLBlockID),
    global_map: std.AutoHashMap(u32, llir.LLGlobalID),
    builtins: type_interner.BuiltinTypes,
    literal_interner: *const front.LiteralInterner,
    symbol_interner: *const symbol.SymbolInterner,

    fn init(
        ml_graph: *const mlir.MLGraph,
        interner: *const type_interner.TypeInterner,
        builtins: type_interner.BuiltinTypes,
        literal_interner: *const front.LiteralInterner,
        symbol_interner: *const symbol.SymbolInterner,
    ) !LowerCtx {
        const m = llir.LLModule.init(ml_graph.gpa, interner);
        return .{
            .ml_graph = ml_graph,
            .mod = m,
            .value_slots = std.AutoHashMap(u32, llir.LLValueID).init(ml_graph.gpa),
            .block_map = std.AutoHashMap(u32, llir.LLBlockID).init(ml_graph.gpa),
            .global_map = std.AutoHashMap(u32, llir.LLGlobalID).init(ml_graph.gpa),
            .builtins = builtins,
            .literal_interner = literal_interner,
            .symbol_interner = symbol_interner,
        };
    }

    fn deinit(self: *LowerCtx) void {
        self.value_slots.deinit();
        self.block_map.deinit();
        self.global_map.deinit();
    }

    fn predeclareResults(self: *LowerCtx, inst: mlir.MLInst) !void {
        for (inst.results.items) |result_id| {
            const value_id = result_id.value;
            if (self.value_slots.get(value_id) != null) continue;
            const slot = try self.mod.addVirtualValue();
            try self.value_slots.put(value_id, slot);
        }
    }

    fn assignPrimaryResult(self: *LowerCtx, inst: mlir.MLInst, value: llir.LLValue) !void {
        if (inst.results.items.len == 0) return;
        const slot = self.value_slots.get(inst.results.items[0].value) orelse return LowerError.MissingResultSlot;
        self.mod.values.items[slot.value] = value;
        if (value == .vreg) {
            if (value.vreg.def_inst) |def_inst| {
                self.mod.insts.items[def_inst.value].meta.result_value = slot;
            }
        }
    }

    fn getValue(self: *LowerCtx, value_id: mlir.MLValueID) !llir.LLValueID {
        if (self.value_slots.get(value_id.value)) |id| return id;

        const value = self.ml_graph.values.items[value_id.value];
        switch (value.data) {
            .constant => |constant| {
                const ty = try self.getType(value.type_);
                const lit = self.literal_interner.get(constant.literal) orelse return error.UnknownLiteral;
                const slot = try self.mod.addValue(.{
                    .const_ = .{
                        .ty = ty,
                        .value = switch (lit) {
                            .int => |v| .{ .int = v.value },
                            .bool => |v| .{ .bool = v },
                            .null => .null,
                            else => return error.UnsupportedLiteralKind,
                        },
                    },
                });
                try self.value_slots.put(value_id.value, slot);
                return slot;
            },
            .symbol => |sym| {
                const gid = try self.getGlobal(sym.symbol);
                const slot = try self.mod.addValue(.{ .global = .{ .id = gid } });
                try self.value_slots.put(value_id.value, slot);
                return slot;
            },
            .block_param => {
                const slot = try self.mod.addValue(.{ .arg = .{ .index = 0 } });
                try self.value_slots.put(value_id.value, slot);
                return slot;
            },
            .inst_result => return LowerError.MissingResultSlot,
        }
    }

    fn getType(self: *LowerCtx, ty: mlir.MLTypeID) !llir.LLTypeID {
        if (self.mod.type_interner.get(ty) == null) return error.UnknownType;
        return ty;
    }

    fn getBlock(self: *LowerCtx, b: mlir.MLBlockID) !llir.LLBlockID {
        return self.block_map.get(b.value) orelse {
            const fresh = try self.mod.addBlock(.{
                .label = null,
            });
            try self.block_map.put(b.value, fresh);
            return fresh;
        };
    }

    fn getGlobal(self: *LowerCtx, sym: mlir.SymbolID) !llir.LLGlobalID {
        if (self.global_map.get(sym.value)) |mapped| return mapped;
        const gid = try self.mod.addGlobal(.{
            .symbol = sym,
            .name_cache = self.symbol_interner.get(sym),
            .ty = self.builtins.ptr,
            .init = null,
            .is_const = false,
        });
        try self.global_map.put(sym.value, gid);
        return gid;
    }

    fn appendInst(self: *LowerCtx, block: llir.LLBlockID, data: llir.LLInstData, meta: llir.LLInstMeta) !llir.LLInstID {
        var ll_block = &self.mod.blocks.items[block.value];
        const id = try self.mod.addInst(data, meta);
        try ll_block.insts.append(self.mod.gpa, id);
        return id;
    }

    fn predeclareFunctionsAndBlocks(self: *LowerCtx) !void {
        for (self.ml_graph.funcs.items) |ml_func| {
            const region = self.ml_graph.regions.items[ml_func.region.value];
            const ret_ty = try self.getType(ml_func.ret_type);
            const func_id = try self.mod.addFunction(.{
                .name = ml_func.name,
                .ty = ret_ty,
                .entry = undefined,
            });
            var ll_func = &self.mod.funcs.items[func_id.value];

            for (region.blocks.items) |ml_block| {
                const ll_block = try self.mod.addBlock(.{
                    .label = null,
                });
                try self.block_map.put(ml_block.value, ll_block);
                try ll_func.blocks.append(self.mod.gpa, ll_block);
            }

            ll_func.entry = try self.getBlock(region.entry);
        }
    }
};

pub fn lowerMLtoLL(
    ml_graph: *const mlir.MLGraph,
    interner: *const type_interner.TypeInterner,
    literal_interner: *const front.LiteralInterner,
    symbol_interner: *const symbol.SymbolInterner,
    builtins: type_interner.BuiltinTypes,
) !llir.LLModule {
    var ctx = try LowerCtx.init(ml_graph, interner, builtins, literal_interner, symbol_interner);
    errdefer ctx.mod.deinit();
    defer ctx.deinit();

    try ctx.predeclareFunctionsAndBlocks();

    for (ml_graph.insts.items) |inst| {
        try ctx.predeclareResults(inst);
    }

    for (ml_graph.funcs.items) |ml_func| {
        const region = ml_graph.regions.items[ml_func.region.value];
        for (region.blocks.items) |ml_block_id| {
            const ll_block_id = try ctx.getBlock(ml_block_id);
            const ml_block = ml_graph.blocks.items[ml_block_id.value];

            var inst_opt = ml_block.first_inst;
            while (inst_opt) |inst_id| {
                const inst = ml_graph.insts.items[inst_id.value];
                try lowerInst(&ctx, ll_block_id, inst);
                inst_opt = inst.next;
            }
        }
    }

    return ctx.mod;
}

fn lowerInst(ctx: *LowerCtx, ll_block_id: llir.LLBlockID, inst: mlir.MLInst) !void {
    switch (inst.data) {
        .const_ => |c| {
            const ty = try ctx.getType(c.type_);
            try ctx.assignPrimaryResult(inst, .{
                .const_ = .{
                    .ty = ty,
                    .value = .{ .int = c.lit.value },
                },
            });
        },
        .load => |n| {
            const ptr = try ctx.getValue(n.addr);
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .load = .{ .ptr = ptr } }, .{
                .result_ty = ctx.builtins.i64,
                .effects = .{ .reads_mem = true },
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .store => |n| {
            const ptr = try ctx.getValue(n.addr);
            const val = try ctx.getValue(n.value);
            _ = try ctx.appendInst(ll_block_id, .{ .store = .{ .ptr = ptr, .value = val } }, .{
                .result_ty = null,
                .effects = .{ .writes_mem = true },
            });
        },
        .addr_of => |n| {
            const gid = try ctx.getGlobal(n.sym);
            try ctx.assignPrimaryResult(inst, .{ .global = .{ .id = gid } });
        },
        .index_addr => |n| {
            const base = try ctx.getValue(n.base);
            const idx = try ctx.getValue(n.index);
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .gep = .{
                .base_ptr = base,
                .index = idx,
            } }, .{
                .result_ty = ctx.builtins.ptr,
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .cast => |n| {
            const in_v = try ctx.getValue(n.value);
            const to_ty = try ctx.getType(n.to_type);
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .cast = .{
                .op = .bitcast,
                .value = in_v,
                .to_ty = to_ty,
            } }, .{
                .result_ty = to_ty,
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .unary => |n| {
            const zero = try ctx.mod.addValue(.{
                .const_ = .{
                    .ty = ctx.builtins.i64,
                    .value = .{ .int = 0 },
                },
            });
            const operand = try ctx.getValue(n.value);
            const ll_inst = switch (n.op) {
                .ineg => try ctx.appendInst(ll_block_id, .{ .binary = .{
                    .op = .sub,
                    .lhs = zero,
                    .rhs = operand,
                } }, .{ .result_ty = ctx.builtins.i64 }),
                .bnot => try ctx.appendInst(ll_block_id, .{ .binary = .{
                    .op = .xor_,
                    .lhs = operand,
                    .rhs = try ctx.mod.addValue(.{
                        .const_ = .{
                            .ty = ctx.builtins.i64,
                            .value = .{ .int = std.math.maxInt(u64) },
                        },
                    }),
                } }, .{ .result_ty = ctx.builtins.i64 }),
                .fneg => try ctx.appendInst(ll_block_id, .{ .binary = .{
                    .op = .sub,
                    .lhs = zero,
                    .rhs = operand,
                } }, .{ .result_ty = ctx.builtins.i64 }),
            };
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .binary => |n| {
            const lhs = try ctx.getValue(n.left);
            const rhs = try ctx.getValue(n.right);
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .binary = .{
                .op = mapBinaryOp(n.op),
                .lhs = lhs,
                .rhs = rhs,
            } }, .{
                .result_ty = ctx.builtins.i64,
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .cmp => |n| {
            const lhs = try ctx.getValue(n.left);
            const rhs = try ctx.getValue(n.right);
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .icmp = .{
                .op = mapCmpOp(n.op),
                .lhs = lhs,
                .rhs = rhs,
            } }, .{
                .result_ty = ctx.builtins.i1,
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .call => |n| {
            const callee = try ctx.getValue(n.callee);
            var ll_call_args = std.ArrayListUnmanaged(llir.LLValueID){};
            errdefer ll_call_args.deinit(ctx.mod.gpa);
            for (n.args.items) |arg| {
                try ll_call_args.append(ctx.mod.gpa, try ctx.getValue(arg));
            }
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .call = .{
                .callee = callee,
                .args = ll_call_args,
            } }, .{
                .result_ty = if (inst.results.items.len > 0) ctx.builtins.i64 else null,
                .effects = .{ .reads_mem = true, .writes_mem = true, .has_io = true },
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .ret => |n| {
            const rv = if (n.value) |value| try ctx.getValue(value) else null;
            _ = try ctx.appendInst(ll_block_id, .{ .ret = .{ .value = rv } }, .{ .result_ty = null });
        },
        .br => |n| {
            const target = try ctx.getBlock(n.target);
            _ = try ctx.appendInst(ll_block_id, .{ .br = .{ .target = target } }, .{ .result_ty = null });
        },
        .cond_br => |n| {
            const cond = try ctx.getValue(n.cond);
            const then_blk = try ctx.getBlock(n.then_target);
            const else_blk = try ctx.getBlock(n.else_target);
            _ = try ctx.appendInst(ll_block_id, .{ .cond_br = .{
                .cond = cond,
                .then_blk = then_blk,
                .else_blk = else_blk,
            } }, .{ .result_ty = null });
        },
        .alloc_stack => |n| {
            const ty = try ctx.getType(n.type_);
            const ll_inst = try ctx.appendInst(ll_block_id, .{ .alloca = .{ .ty = ty } }, .{
                .result_ty = ctx.builtins.ptr,
                .effects = .{ .writes_mem = true },
            });
            try ctx.assignPrimaryResult(inst, .{ .vreg = .{ .def_inst = ll_inst } });
        },
        .select,
        .alloc_heap,
        .free,
        .loop_,
        .aggregate_make,
        .extract,
        .insert,
        .global,
        .extern_func,
        .switch_,
        .phi,
        => {
            @panic("unimplemented");
        },
    }
}

fn mapBinaryOp(op: mlir.BinaryOp) llir.LLBinaryOp {
    return switch (op) {
        .iadd => .add,
        .isub => .sub,
        .imul => .mul,
        .idiv => .sdiv,
        .imod => .srem,
        .band => .and_,
        .bor => .or_,
        .bxor => .xor_,
        .shl => .shl,
        .lshr => .lshr,
        .ashr => .ashr,
        .fadd => .add,
        .fsub => .sub,
        .fmul => .mul,
        .fdiv => .sdiv,
    };
}

fn mapCmpOp(op: mlir.CmpOp) llir.LLCmpOp {
    return switch (op) {
        .ieq, .feq => .eq,
        .ine, .fne => .ne,
        .ilt, .flt => .slt,
        .ile, .fle => .sle,
        .igt, .fgt => .sgt,
        .ige, .fge => .sge,
    };
}
