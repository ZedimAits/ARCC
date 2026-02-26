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

const mlir = @import("../medium/mlir.zig");
const llir = @import("llir.zig");

pub const LowerError = error{
    MissingResultSlot,
};

const LowerCtx = struct {
    mod: llir.LLModule,

    // ML id -> LL id maps
    value_slots: std.AutoHashMap(u32, llir.LLValueID),
    type_map: std.AutoHashMap(u32, llir.LLTypeID),
    block_map: std.AutoHashMap(u32, llir.LLBlockID),
    global_map: std.AutoHashMap(u32, llir.LLGlobalID),

    // Common builtin LL types
    ty_void: llir.LLTypeID,
    ty_i1: llir.LLTypeID,
    ty_i64: llir.LLTypeID,
    ty_ptr: llir.LLTypeID,

    entry_block: llir.LLBlockID,

    fn init(gpa: std.mem.Allocator) !LowerCtx {
        var m = llir.LLModule.init(gpa);

        const ty_void = try m.addType(.{ .void = {} });
        const ty_i1 = try m.addType(.{ .int = .{ .bits = 1, .sign = .unsigned } });
        const ty_i64 = try m.addType(.{ .int = .{ .bits = 64, .sign = .signed } });
        const ty_ptr = try m.addType(.{ .ptr = {} });

        const entry = try m.addBlock(.{
            .label = "entry",
            .inst_start = 0,
            .inst_count = 0,
        });

        _ = try m.addFunction(.{
            .name = "mlir_lowered",
            .ty = ty_void,
            .entry = entry,
            .block_start = entry.value,
            .block_count = 1,
            .arg_start = 0,
            .arg_count = 0,
        });

        return .{
            .mod = m,
            .value_slots = std.AutoHashMap(u32, llir.LLValueID).init(gpa),
            .type_map = std.AutoHashMap(u32, llir.LLTypeID).init(gpa),
            .block_map = std.AutoHashMap(u32, llir.LLBlockID).init(gpa),
            .global_map = std.AutoHashMap(u32, llir.LLGlobalID).init(gpa),
            .ty_void = ty_void,
            .ty_i1 = ty_i1,
            .ty_i64 = ty_i64,
            .ty_ptr = ty_ptr,
            .entry_block = entry,
        };
    }

    fn deinit(self: *LowerCtx) void {
        self.value_slots.deinit();
        self.type_map.deinit();
        self.block_map.deinit();
        self.global_map.deinit();
    }

    fn predeclareNodeResults(self: *LowerCtx, node: mlir.MLNode) !void {
        if (node.meta.result_count == 0) return;

        var i: u32 = 0;
        while (i < @as(u32, node.meta.result_count)) : (i += 1) {
            const ml_value = node.meta.result_start + i;
            if (self.value_slots.get(ml_value) != null) continue;
            const slot = try self.mod.addValue(.none);
            try self.value_slots.put(ml_value, slot);
        }
    }

    fn assignPrimaryResult(self: *LowerCtx, node: mlir.MLNode, value: llir.LLValue) !void {
        if (node.meta.result_count == 0) return;
        const ml_value = node.meta.result_start;
        const slot = self.value_slots.get(ml_value) orelse return LowerError.MissingResultSlot;
        self.mod.values.items[slot.value] = value;
    }

    fn getValue(self: *LowerCtx, value: mlir.MLValueID) !llir.LLValueID {
        if (self.value_slots.get(value.value)) |id| return id;
        const slot = try self.mod.addValue(.none);
        try self.value_slots.put(value.value, slot);
        return slot;
    }

    fn getType(self: *LowerCtx, ty: mlir.MLTypeID) !llir.LLTypeID {
        if (self.type_map.get(ty.value)) |mapped| return mapped;
        // MLIR currently has no shared type table in MLGraph; use i64 default.
        try self.type_map.put(ty.value, self.ty_i64);
        return self.ty_i64;
    }

    fn getBlock(self: *LowerCtx, b: mlir.MLBlockID) !llir.LLBlockID {
        if (self.block_map.get(b.value)) |mapped| return mapped;
        const fresh = try self.mod.addBlock(.{
            .label = null,
            .inst_start = 0,
            .inst_count = 0,
        });
        try self.block_map.put(b.value, fresh);
        return fresh;
    }

    fn getGlobal(self: *LowerCtx, sym: mlir.MLSymbolID) !llir.LLGlobalID {
        if (self.global_map.get(sym.value)) |mapped| return mapped;
        const gid = try self.mod.addGlobal(.{
            .name = "",
            .ty = self.ty_ptr,
            .init = null,
            .is_const = false,
        });
        try self.global_map.put(sym.value, gid);
        return gid;
    }

    fn appendInst(self: *LowerCtx, data: llir.LLInstData, meta: llir.LLInstMeta) !llir.LLInstID {
        const id = try self.mod.addInst(data, meta);
        self.mod.blocks.items[self.entry_block.value].inst_count += 1;
        return id;
    }
};

pub fn lowerMLtoLL(ml_graph: *const mlir.MLGraph) !llir.LLModule {
    var ctx = try LowerCtx.init(ml_graph.gpa);
    errdefer ctx.mod.deinit();
    defer ctx.deinit();

    // Pass 1: reserve LL value slots for every ML node result.
    for (ml_graph.nodes.items) |node| {
        try ctx.predeclareNodeResults(node);
    }

    // Pass 2: lower node payloads.
    for (ml_graph.nodes.items) |node| {
        switch (node.data) {
            .arg => |a| {
                try ctx.assignPrimaryResult(node, .{ .arg = .{ .index = a.index } });
            },
            .const_ => |c| {
                const ty = try ctx.getType(c.type_);
                // MLGraph currently stores literal IDs only; keep id as integer payload for now.
                try ctx.assignPrimaryResult(node, .{
                    .const_ = .{
                        .ty = ty,
                        .value = .{ .int = c.lit.value },
                    },
                });
            },
            .load => |n| {
                const ptr = try ctx.getValue(n.addr);
                const inst = try ctx.appendInst(.{ .load = .{ .ptr = ptr } }, .{
                    .result_ty = ctx.ty_i64,
                    .effects = .{ .reads_mem = true },
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .store => |n| {
                const ptr = try ctx.getValue(n.addr);
                const val = try ctx.getValue(n.value);
                _ = try ctx.appendInst(.{ .store = .{ .ptr = ptr, .value = val } }, .{
                    .result_ty = null,
                    .effects = .{ .writes_mem = true },
                });
            },
            .addr_of => |n| {
                const gid = try ctx.getGlobal(n.sym);
                try ctx.assignPrimaryResult(node, .{ .global = .{ .id = gid } });
            },
            .index_addr => |n| {
                const base = try ctx.getValue(n.base);
                const idx = try ctx.getValue(n.index);
                const inst = try ctx.appendInst(.{ .gep = .{
                    .base_ptr = base,
                    .index = idx,
                } }, .{
                    .result_ty = ctx.ty_ptr,
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .cast => |n| {
                const in_v = try ctx.getValue(n.value);
                const to_ty = try ctx.getType(n.to_type);
                const inst = try ctx.appendInst(.{ .cast = .{
                    .op = .bitcast,
                    .value = in_v,
                    .to_ty = to_ty,
                } }, .{
                    .result_ty = to_ty,
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .binary => |n| {
                const lhs = try ctx.getValue(n.left);
                const rhs = try ctx.getValue(n.right);
                const inst = try ctx.appendInst(.{ .binary = .{
                    .op = mapBinaryOp(n.op),
                    .lhs = lhs,
                    .rhs = rhs,
                } }, .{
                    .result_ty = ctx.ty_i64,
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .cmp => |n| {
                const lhs = try ctx.getValue(n.left);
                const rhs = try ctx.getValue(n.right);
                const inst = try ctx.appendInst(.{ .icmp = .{
                    .op = mapCmpOp(n.op),
                    .lhs = lhs,
                    .rhs = rhs,
                } }, .{
                    .result_ty = ctx.ty_i1,
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .select => |n| {
                const cond = try ctx.getValue(n.cond);
                const tv = try ctx.getValue(n.then_value);
                const ev = try ctx.getValue(n.else_value);
                const inst = try ctx.appendInst(.{ .select = .{
                    .cond = cond,
                    .then_v = tv,
                    .else_v = ev,
                } }, .{
                    .result_ty = ctx.ty_i64,
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .call => |n| {
                const gid = try ctx.getGlobal(.{ .value = n.callee.value });
                const callee = try ctx.mod.addValue(.{ .global = .{ .id = gid } });
                // TODO: MLGraph needs explicit argument storage to keep arg list here.
                const inst = try ctx.appendInst(.{ .call = .{
                    .callee = callee,
                    .arg_start = 0,
                    .arg_count = 0,
                } }, .{
                    .result_ty = if (node.meta.result_count > 0) ctx.ty_i64 else null,
                    .effects = .{ .reads_mem = true, .writes_mem = true, .has_io = true },
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
            .ret => |n| {
                const rv = if (n.value) |v| try ctx.getValue(v) else null;
                _ = try ctx.appendInst(.{ .ret = .{ .value = rv } }, .{ .result_ty = null });
            },
            .br => |n| {
                const target = try ctx.getBlock(n.target);
                _ = try ctx.appendInst(.{ .br = .{ .target = target } }, .{ .result_ty = null });
            },
            .cond_br => |n| {
                const cond = try ctx.getValue(n.cond);
                const then_blk = try ctx.getBlock(n.then_target);
                const else_blk = try ctx.getBlock(n.else_target);
                _ = try ctx.appendInst(.{ .cond_br = .{
                    .cond = cond,
                    .then_blk = then_blk,
                    .else_blk = else_blk,
                } }, .{ .result_ty = null });
            },
            .alloc_stack => |n| {
                const ty = try ctx.getType(n.type_);
                const inst = try ctx.appendInst(.{ .alloca = .{ .ty = ty } }, .{
                    .result_ty = ctx.ty_ptr,
                    .effects = .{ .writes_mem = true },
                });
                try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },

            .region, .block, .func, .extern_func, .switch_, .phi, .unary, .alloc_heap, .free, .loop_, .aggregate_make, .extract, .insert, .global => {
                @panic("unimplemented");

                //const inst = try ctx.appendInst(.{ .nop = {} }, .{
                //    .result_ty = if (node.meta.result_count > 0) ctx.ty_i64 else null,
                //});
                //try ctx.assignPrimaryResult(node, .{ .inst = .{ .id = inst } });
            },
        }
    }

    return ctx.mod;
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

        // Float ops currently lowered to integer fallback ops.
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
