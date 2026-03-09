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
const Span = front.Span;
const nodes = @import("nodes.zig");

pub const MLTypeID = nodes.MLTypeID;
pub const MLInstID = nodes.MLInstID;
pub const MLNodeID = nodes.MLNodeID;
pub const MLValueID = nodes.MLValueID;
pub const MLUseID = nodes.MLUseID;
pub const MLValue = nodes.MLValue;
pub const MLUse = nodes.MLUse;
pub const MLBlockID = nodes.MLBlockID;
pub const MLRegionID = nodes.MLRegionID;
pub const MLFuncID = nodes.MLFuncID;
pub const MLSymbolID = nodes.MLSymbolID;
pub const MLInstMeta = nodes.MLInstMeta;
pub const MLNodeMeta = MLInstMeta;
pub const EffectFlags = nodes.EffectFlags;
pub const UnaryOp = nodes.UnaryOp;
pub const BinaryOp = nodes.BinaryOp;
pub const CmpOp = nodes.CmpOp;
pub const MLInstData = nodes.MLInstData;
pub const MLNodeData = MLInstData;
pub const MLInst = nodes.MLInst;
pub const MLNode = MLInst;
pub const MLBlock = nodes.MLBlock;
pub const MLRegion = nodes.MLRegion;
pub const MLFunction = nodes.MLFunction;
pub const MLPhiIncoming = nodes.MLPhiIncoming;
pub const MLSwitchCase = nodes.MLSwitchCase;

const SymbolID = @import("../../intermediate/symbol.zig").SymbolID;

pub const MLGraph = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    values: std.ArrayListUnmanaged(MLValue) = .{},
    uses: std.ArrayListUnmanaged(MLUse) = .{},
    insts: std.ArrayListUnmanaged(MLInst) = .{},
    blocks: std.ArrayListUnmanaged(MLBlock) = .{},
    regions: std.ArrayListUnmanaged(MLRegion) = .{},
    funcs: std.ArrayListUnmanaged(MLFunction) = .{},
    block_params: std.ArrayListUnmanaged(MLValueID) = .{},
    call_args: std.ArrayListUnmanaged(MLValueID) = .{},
    branch_args: std.ArrayListUnmanaged(MLValueID) = .{},
    switch_cases: std.ArrayListUnmanaged(MLSwitchCase) = .{},
    phi_incoming: std.ArrayListUnmanaged(MLPhiIncoming) = .{},
    aggregate_elems: std.ArrayListUnmanaged(MLValueID) = .{},
    symbol_map: std.AutoHashMap(SymbolID, MLValueID) = undefined,

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{
            .gpa = gpa,
            .symbol_map = std.AutoHashMap(SymbolID, MLValueID).init(gpa),
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit(self.gpa);
        self.uses.deinit(self.gpa);
        self.insts.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.regions.deinit(self.gpa);
        self.funcs.deinit(self.gpa);
        self.block_params.deinit(self.gpa);
        self.call_args.deinit(self.gpa);
        self.branch_args.deinit(self.gpa);
        self.switch_cases.deinit(self.gpa);
        self.phi_incoming.deinit(self.gpa);
        self.aggregate_elems.deinit(self.gpa);
        self.symbol_map.deinit();
    }

    pub fn add_symbol(self: *Self, symbol: SymbolID, value: MLValue) !MLValueID {
        if (self.symbol_map.get(symbol)) |id| return id;

        const id = try self.appendRawValue(value);
        try self.symbol_map.put(symbol, id);
        return id;
    }

    pub fn addSymbolValue(self: *Self, symbol: SymbolID, type_: MLTypeID) !MLValueID {
        return self.add_symbol(symbol, .{
            .kind = .symbol,
            .type_ = type_,
            .symbol = .{ .value = symbol.value },
        });
    }

    pub fn lookup_symbol(self: *const Self, symbol: SymbolID) ?MLValueID {
        return self.symbol_map.get(symbol);
    }

    pub fn addConstant(self: *Self, literal: front.LiteralID, type_: MLTypeID) !MLValueID {
        return self.appendRawValue(.{
            .kind = .constant,
            .type_ = type_,
            .literal = literal,
        });
    }

    pub fn addRegion(self: *Self) !MLRegionID {
        const block = try self.addBlock(.{ .value = 0 });
        const id = MLRegionID{ .value = @intCast(self.regions.items.len) };
        self.blocks.items[block.value].parent_region = id;
        try self.regions.append(self.gpa, .{
            .entry = block,
            .block_start = block.value,
            .block_count = 1,
        });
        return id;
    }

    pub fn addBlock(self: *Self, region: MLRegionID) !MLBlockID {
        const id = MLBlockID{ .value = @intCast(self.blocks.items.len) };
        try self.blocks.append(self.gpa, .{
            .parent_region = region,
        });

        if (region.value < self.regions.items.len) {
            self.regions.items[region.value].block_count += 1;
        }

        return id;
    }

    pub fn addFunction(self: *Self, name: []const u8, region: MLRegionID, ret_type: MLTypeID) !MLFuncID {
        const id = MLFuncID{ .value = @intCast(self.funcs.items.len) };
        try self.funcs.append(self.gpa, .{
            .name = name,
            .region = region,
            .ret_type = ret_type,
        });
        return id;
    }

    pub fn addBlockParam(self: *Self, block: MLBlockID, type_: MLTypeID) !MLValueID {
        const id = try self.appendRawValue(.{
            .kind = .block_param,
            .type_ = type_,
            .owner_block = block,
        });
        var blk = &self.blocks.items[block.value];
        if (blk.param_count == 0) {
            blk.param_start = @intCast(self.block_params.items.len);
        }
        try self.block_params.append(self.gpa, id);
        blk.param_count += 1;
        return id;
    }

    pub fn appendCallArgs(self: *Self, args: []const MLValueID) !struct { start: u32, count: u16 } {
        const start: u32 = @intCast(self.call_args.items.len);
        try self.call_args.appendSlice(self.gpa, args);
        return .{ .start = start, .count = @intCast(args.len) };
    }

    pub fn appendBranchArgs(self: *Self, args: []const MLValueID) !struct { start: u32, count: u16 } {
        const start: u32 = @intCast(self.branch_args.items.len);
        try self.branch_args.appendSlice(self.gpa, args);
        return .{ .start = start, .count = @intCast(args.len) };
    }

    pub fn appendInst(
        self: *Self,
        block: MLBlockID,
        span: Span,
        data: MLInstData,
        result_type: ?MLTypeID,
    ) !MLInstID {
        var result_buf: [1]MLTypeID = undefined;
        var result_types: []const MLTypeID = &.{};
        if (result_type) |ty| {
            result_buf[0] = ty;
            result_types = result_buf[0..1];
        }
        return self.appendInstWithResults(block, span, data, result_types);
    }

    pub fn appendInstWithResults(
        self: *Self,
        block: MLBlockID,
        span: Span,
        data: MLInstData,
        result_types: []const MLTypeID,
    ) !MLInstID {
        const id = MLInstID{ .value = @intCast(self.insts.items.len) };
        const result_start: u32 = @intCast(self.values.items.len);

        for (result_types) |ty| {
            _ = try self.appendRawValue(.{
                .kind = .inst_result,
                .type_ = ty,
                .def_inst = id,
            });
        }

        const inst = MLInst{
            .id = id,
            .kind = std.meta.activeTag(data),
            .parent_block = block,
            .meta = .{ .span = span },
            .data = data,
            .result_start = result_start,
            .result_count = @intCast(result_types.len),
        };

        try self.insts.append(self.gpa, inst);
        try self.linkIntoBlock(block, id);
        try self.recordUsesForInst(id);
        return id;
    }

    pub fn getInst(self: *Self, id: MLInstID) *MLInst {
        return &self.insts.items[id.value];
    }

    pub fn getNode(self: *Self, id: MLNodeID) *MLNode {
        return self.getInst(id);
    }

    pub fn getValue(self: *Self, id: MLValueID) *MLValue {
        return &self.values.items[id.value];
    }

    pub fn resultOf(self: *Self, inst: MLInstID) !MLValueID {
        const node = self.getInst(inst);
        if (node.result_count == 0) return error.NoResult;
        return .{ .value = node.result_start };
    }

    pub fn writeTo(self: *const Self, writer: *std.Io.Writer) anyerror!void {
        try writer.print("ML-GRAPH (funcs={d}, regions={d}, blocks={d}, values={d}, insts={d})\n", .{
            self.funcs.items.len,
            self.regions.items.len,
            self.blocks.items.len,
            self.values.items.len,
            self.insts.items.len,
        });

        for (self.funcs.items, 0..) |func, func_idx| {
            try writer.print("func[{d}] {s} region={d} ret_ty=t{d}\n", .{
                func_idx,
                func.name,
                func.region.value,
                func.ret_type.value,
            });

            const region = self.regions.items[func.region.value];
            const region_end = region.block_start + region.block_count;
            var block_index = region.block_start;
            while (block_index < region_end) : (block_index += 1) {
                try self.writeBlock(writer, .{ .value = @intCast(block_index) });
            }
        }
    }

    pub fn replaceAllUsesWith(self: *Self, old_value: MLValueID, new_value: MLValueID) void {
        var use_opt = self.values.items[old_value.value].use_head;
        while (use_opt) |use_id| {
            const use = self.uses.items[use_id.value];
            self.setOperand(use.user, use.operand_index, new_value);
            use_opt = use.next;
        }
        self.values.items[old_value.value].use_head = null;
    }

    fn appendRawValue(self: *Self, value: MLValue) !MLValueID {
        const id = MLValueID{ .value = @intCast(self.values.items.len) };
        try self.values.append(self.gpa, value);
        return id;
    }

    fn linkIntoBlock(self: *Self, block_id: MLBlockID, inst_id: MLInstID) !void {
        var block = &self.blocks.items[block_id.value];
        if (block.last_inst) |last_id| {
            self.insts.items[last_id.value].next = inst_id;
            self.insts.items[inst_id.value].prev = last_id;
        } else {
            block.first_inst = inst_id;
        }
        block.last_inst = inst_id;
    }

    fn addUse(self: *Self, value_id: MLValueID, user: MLInstID, operand_index: u16) !void {
        const use_id = MLUseID{ .value = @intCast(self.uses.items.len) };
        const head = self.values.items[value_id.value].use_head;
        try self.uses.append(self.gpa, .{
            .user = user,
            .operand_index = operand_index,
            .next = head,
        });
        self.values.items[value_id.value].use_head = use_id;
    }

    fn recordUsesForInst(self: *Self, inst_id: MLInstID) !void {
        const inst = self.insts.items[inst_id.value];
        switch (inst.data) {
            .const_, .addr_of, .alloc_stack, .global, .extern_func => {},
            .load => |n| try self.addUse(n.addr, inst_id, 0),
            .store => |n| {
                try self.addUse(n.addr, inst_id, 0);
                try self.addUse(n.value, inst_id, 1);
            },
            .index_addr => |n| {
                try self.addUse(n.base, inst_id, 0);
                try self.addUse(n.index, inst_id, 1);
            },
            .cast => |n| try self.addUse(n.value, inst_id, 0),
            .unary => |n| try self.addUse(n.value, inst_id, 0),
            .binary => |n| {
                try self.addUse(n.left, inst_id, 0);
                try self.addUse(n.right, inst_id, 1);
            },
            .cmp => |n| {
                try self.addUse(n.left, inst_id, 0);
                try self.addUse(n.right, inst_id, 1);
            },
            .select => |n| {
                try self.addUse(n.cond, inst_id, 0);
                try self.addUse(n.then_value, inst_id, 1);
                try self.addUse(n.else_value, inst_id, 2);
            },
            .call => |n| {
                try self.addUse(n.callee, inst_id, 0);
                const args = self.call_args.items[n.arg_start .. n.arg_start + n.arg_count];
                for (args, 1..) |arg, idx| {
                    try self.addUse(arg, inst_id, @intCast(idx));
                }
            },
            .ret => |n| {
                if (n.value) |value| {
                    try self.addUse(value, inst_id, 0);
                }
            },
            .br => |n| {
                const args = self.branch_args.items[n.arg_start .. n.arg_start + n.arg_count];
                for (args, 0..) |arg, idx| {
                    try self.addUse(arg, inst_id, @intCast(idx));
                }
            },
            .cond_br => |n| try self.addUse(n.cond, inst_id, 0),
            .switch_ => |n| try self.addUse(n.scrutinee, inst_id, 0),
            .phi => |n| {
                const incoming = self.phi_incoming.items[n.incoming_start .. n.incoming_start + n.incoming_count];
                for (incoming, 0..) |item, idx| {
                    try self.addUse(item.value, inst_id, @intCast(idx));
                }
            },
            .alloc_heap => |n| try self.addUse(n.count, inst_id, 0),
            .free => |n| try self.addUse(n.ptr, inst_id, 0),
            .loop_ => {},
            .aggregate_make => |n| {
                const elems = self.aggregate_elems.items[n.elem_start .. n.elem_start + n.elem_count];
                for (elems, 0..) |elem, idx| {
                    try self.addUse(elem, inst_id, @intCast(idx));
                }
            },
            .extract => |n| try self.addUse(n.aggregate, inst_id, 0),
            .insert => |n| {
                try self.addUse(n.aggregate, inst_id, 0);
                try self.addUse(n.value, inst_id, 1);
            },
        }
    }

    fn setOperand(self: *Self, inst_id: MLInstID, operand_index: u16, value: MLValueID) void {
        var inst = &self.insts.items[inst_id.value];
        switch (&inst.data) {
            .load => |n| n.addr = value,
            .store => |n| {
                if (operand_index == 0) {
                    n.addr = value;
                } else {
                    n.value = value;
                }
            },
            .index_addr => |n| {
                if (operand_index == 0) {
                    n.base = value;
                } else {
                    n.index = value;
                }
            },
            .cast => |n| n.value = value,
            .unary => |n| n.value = value,
            .binary => |n| {
                if (operand_index == 0) {
                    n.left = value;
                } else {
                    n.right = value;
                }
            },
            .cmp => |n| {
                if (operand_index == 0) {
                    n.left = value;
                } else {
                    n.right = value;
                }
            },
            .select => |n| switch (operand_index) {
                0 => n.cond = value,
                1 => n.then_value = value,
                else => n.else_value = value,
            },
            .call => |n| {
                if (operand_index == 0) {
                    n.callee = value;
                } else {
                    self.call_args.items[n.arg_start + operand_index - 1] = value;
                }
            },
            .ret => |n| n.value = value,
            .br => |n| self.branch_args.items[n.arg_start + operand_index] = value,
            .cond_br => |n| n.cond = value,
            .switch_ => |n| n.scrutinee = value,
            .phi => |n| self.phi_incoming.items[n.incoming_start + operand_index].value = value,
            .alloc_heap => |n| n.count = value,
            .free => |n| n.ptr = value,
            .aggregate_make => |n| self.aggregate_elems.items[n.elem_start + operand_index] = value,
            .extract => |n| n.aggregate = value,
            .insert => |n| {
                if (operand_index == 0) {
                    n.aggregate = value;
                } else {
                    n.value = value;
                }
            },
            .const_, .addr_of, .alloc_stack, .loop_, .global, .extern_func => {},
        }
    }

    fn writeBlock(self: *const Self, writer: *std.Io.Writer, block_id: MLBlockID) anyerror!void {
        const block = self.blocks.items[block_id.value];
        try writer.print("  block[{d}] params={d}\n", .{
            block_id.value,
            block.param_count,
        });

        var inst_opt = block.first_inst;
        while (inst_opt) |inst_id| {
            const inst = self.insts.items[inst_id.value];
            try writer.print("    i{d}", .{inst_id.value});
            if (inst.result_count > 0) {
                try writer.print(" ->", .{});
                var result_index: u32 = 0;
                while (result_index < inst.result_count) : (result_index += 1) {
                    try writer.print(" v{d}", .{inst.result_start + result_index});
                }
            }
            try writer.print(" = {s}", .{@tagName(inst.kind)});
            try self.writeInstOperands(writer, inst);
            try writer.print("\n", .{});
            inst_opt = inst.next;
        }
    }

    fn writeInstOperands(_: *const Self, writer: *std.Io.Writer, inst: MLInst) anyerror!void {
        switch (inst.data) {
            .const_ => |n| try writer.print("(lit={d}, ty=t{d})", .{ n.lit.value, n.type_.value }),
            .load => |n| try writer.print("(addr=v{d})", .{n.addr.value}),
            .store => |n| try writer.print("(addr=v{d}, value=v{d})", .{ n.addr.value, n.value.value }),
            .addr_of => |n| try writer.print("(sym={d})", .{n.sym.value}),
            .index_addr => |n| try writer.print("(base=v{d}, index=v{d})", .{ n.base.value, n.index.value }),
            .cast => |n| try writer.print("(value=v{d}, to=t{d})", .{ n.value.value, n.to_type.value }),
            .unary => |n| try writer.print("(op={s}, value=v{d})", .{ @tagName(n.op), n.value.value }),
            .binary => |n| try writer.print("(op={s}, left=v{d}, right=v{d})", .{ @tagName(n.op), n.left.value, n.right.value }),
            .cmp => |n| try writer.print("(op={s}, left=v{d}, right=v{d})", .{ @tagName(n.op), n.left.value, n.right.value }),
            .select => |n| try writer.print("(cond=v{d}, then=v{d}, else=v{d})", .{ n.cond.value, n.then_value.value, n.else_value.value }),
            .call => |n| try writer.print("(callee=v{d}, argc={d})", .{ n.callee.value, n.arg_count }),
            .ret => |n| if (n.value) |value| try writer.print("(value=v{d})", .{value.value}) else try writer.print("()", .{}),
            .br => |n| try writer.print("(target=b{d}, argc={d})", .{ n.target.value, n.arg_count }),
            .cond_br => |n| try writer.print("(cond=v{d}, then=b{d}, else=b{d})", .{ n.cond.value, n.then_target.value, n.else_target.value }),
            .switch_ => |n| try writer.print("(scrutinee=v{d}, default=b{d}, cases={d})", .{ n.scrutinee.value, n.default_target.value, n.case_count }),
            .phi => |n| try writer.print("(incoming={d})", .{n.incoming_count}),
            .alloc_stack => |n| try writer.print("(ty=t{d})", .{n.type_.value}),
            .alloc_heap => |n| try writer.print("(ty=t{d}, count=v{d})", .{ n.type_.value, n.count.value }),
            .free => |n| try writer.print("(ptr=v{d})", .{n.ptr.value}),
            .loop_ => |n| try writer.print("(header=b{d}, body=r{d})", .{ n.header.value, n.body.value }),
            .aggregate_make => |n| try writer.print("(elems={d}, ty=t{d})", .{ n.elem_count, n.type_.value }),
            .extract => |n| try writer.print("(aggregate=v{d}, index={d})", .{ n.aggregate.value, n.index }),
            .insert => |n| try writer.print("(aggregate=v{d}, index={d}, value=v{d})", .{ n.aggregate.value, n.index, n.value.value }),
            .global => |n| try writer.print("(sym={d}, ty=t{d})", .{ n.sym.value, n.type_.value }),
            .extern_func => |n| try writer.print("(sym={d}, ty=t{d})", .{ n.sym.value, n.type_.value }),
        }
    }
};
