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
pub const prep_for_ll = @import("prep_for_ll.zig");

const front = @import("../../frontend/front.zig");
const Span = front.Span;
const nodes = @import("nodes.zig");
const types = @import("../type.zig");

pub const MLTypeID = types.TypeID;
pub const MLInstID = nodes.MLInstID;
pub const MLValueID = nodes.MLValueID;
pub const MLUseID = nodes.MLUseID;
pub const MLValue = nodes.MLValue;
pub const MLUse = nodes.MLUse;
pub const MLBlockID = nodes.MLBlockID;
pub const MLRegionID = nodes.MLRegionID;
pub const MLFuncID = nodes.MLFuncID;
pub const SymbolID = nodes.SymbolID;
pub const MLInstMeta = nodes.MLInstMeta;
pub const EffectFlags = nodes.EffectFlags;
pub const UnaryOp = nodes.UnaryOp;
pub const BinaryOp = nodes.BinaryOp;
pub const CmpOp = nodes.CmpOp;
pub const MLInstData = nodes.MLInstData;
pub const MLInst = nodes.MLInst;
pub const MLBlock = nodes.MLBlock;
pub const MLRegion = nodes.MLRegion;
pub const MLFunction = nodes.MLFunction;
pub const MLPhiIncoming = nodes.MLPhiIncoming;
pub const MLSwitchCase = nodes.MLSwitchCase;

pub const MLGraph = struct {
    const Self = @This();

    pub const FunctionFrame = struct {
        func: MLFuncID,
        region: MLRegionID,
        entry_block: MLBlockID,
    };

    gpa: std.mem.Allocator,
    values: std.ArrayListUnmanaged(MLValue) = .{},
    uses: std.ArrayListUnmanaged(MLUse) = .{},
    insts: std.ArrayListUnmanaged(MLInst) = .{},
    blocks: std.ArrayListUnmanaged(MLBlock) = .{},
    regions: std.ArrayListUnmanaged(MLRegion) = .{},
    funcs: std.ArrayListUnmanaged(MLFunction) = .{},
    symbol_map: std.AutoHashMap(SymbolID, MLValueID) = undefined,

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{
            .gpa = gpa,
            .symbol_map = std.AutoHashMap(SymbolID, MLValueID).init(gpa),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.insts.items) |*inst| {
            inst.deinit(self.gpa);
        }
        for (self.blocks.items) |*block| {
            block.deinit(self.gpa);
        }
        for (self.regions.items) |*region| {
            region.deinit(self.gpa);
        }
        self.values.deinit(self.gpa);
        self.uses.deinit(self.gpa);
        self.insts.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.regions.deinit(self.gpa);
        self.funcs.deinit(self.gpa);
        self.symbol_map.deinit();
    }

    pub fn prepareForLL(self: *Self) prep_for_ll.PrepForLLError!void {
        return prep_for_ll.validateReadyForLL(self);
    }

    pub fn addSymbol(self: *Self, symbol: SymbolID, value: MLValue) !MLValueID {
        if (self.symbol_map.get(symbol)) |id| return id;

        const id = try self.appendRawValue(value);
        try self.symbol_map.put(symbol, id);
        return id;
    }

    pub fn addSymbolValue(self: *Self, symbol: SymbolID, type_: MLTypeID) !MLValueID {
        return self.addSymbol(symbol, MLValue.symbol(type_, symbol));
    }

    pub fn lookupSymbol(self: *const Self, symbol: SymbolID) ?MLValueID {
        return self.symbol_map.get(symbol);
    }

    pub fn addConstant(self: *Self, literal: front.LiteralID, type_: MLTypeID) !MLValueID {
        return self.appendRawValue(MLValue.constant(type_, literal));
    }

    pub fn addRegion(self: *Self) !MLRegionID {
        const id = MLRegionID{ .value = @intCast(self.regions.items.len) };
        try self.regions.append(self.gpa, .{
            .entry = undefined,
        });
        const block = try self.addBlock(id);
        self.regions.items[id.value].entry = block;
        return id;
    }

    pub fn addBlock(self: *Self, region: MLRegionID) !MLBlockID {
        const id = MLBlockID{ .value = @intCast(self.blocks.items.len) };
        try self.blocks.append(self.gpa, .{
            .parent_region = region,
        });

        if (region.value < self.regions.items.len) {
            try self.regions.items[region.value].blocks.append(self.gpa, id);
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

    pub fn addFunctionWithEntry(self: *Self, name: []const u8, ret_type: MLTypeID) !FunctionFrame {
        const region = try self.addRegion();
        const func = try self.addFunction(name, region, ret_type);
        return .{
            .func = func,
            .region = region,
            .entry_block = self.regions.items[region.value].entry,
        };
    }

    pub fn addBlockParam(self: *Self, block: MLBlockID, type_: MLTypeID) !MLValueID {
        const id = try self.appendRawValue(MLValue.blockParam(type_, block));
        try self.blocks.items[block.value].params.append(self.gpa, id);
        return id;
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
        var result_ids = std.ArrayListUnmanaged(MLValueID){};
        errdefer result_ids.deinit(self.gpa);

        for (result_types) |ty| {
            const value_id = try self.appendRawValue(MLValue.instResult(ty, id));
            try result_ids.append(self.gpa, value_id);
        }

        const inst = MLInst{
            .id = id,
            .kind = std.meta.activeTag(data),
            .parent_block = block,
            .meta = .{ .span = span },
            .data = data,
            .results = result_ids,
        };

        try self.insts.append(self.gpa, inst);
        try self.linkIntoBlock(block, id);
        try self.recordUsesForInst(id);
        return id;
    }

    pub fn getInst(self: *Self, id: MLInstID) *MLInst {
        return &self.insts.items[id.value];
    }

    pub fn getValue(self: *Self, id: MLValueID) *MLValue {
        return &self.values.items[id.value];
    }

    pub fn resultOf(self: *Self, inst: MLInstID) !MLValueID {
        const node = self.getInst(inst);
        if (node.results.items.len == 0) return error.NoResult;
        return node.results.items[0];
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
            for (region.blocks.items) |block_id| {
                try self.writeBlock(writer, block_id);
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
                for (n.args.items, 1..) |arg, idx| {
                    try self.addUse(arg, inst_id, @intCast(idx));
                }
            },
            .ret => |n| {
                if (n.value) |value| {
                    try self.addUse(value, inst_id, 0);
                }
            },
            .br => |n| {
                for (n.args.items, 0..) |arg, idx| {
                    try self.addUse(arg, inst_id, @intCast(idx));
                }
            },
            .cond_br => |n| try self.addUse(n.cond, inst_id, 0),
            .switch_ => |n| try self.addUse(n.scrutinee, inst_id, 0),
            .phi => |n| {
                for (n.incoming.items, 0..) |item, idx| {
                    try self.addUse(item.value, inst_id, @intCast(idx));
                }
            },
            .alloc_heap => |n| try self.addUse(n.count, inst_id, 0),
            .free => |n| try self.addUse(n.ptr, inst_id, 0),
            .loop_ => {},
            .aggregate_make => |n| {
                for (n.elems.items, 0..) |elem, idx| {
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
                    n.args.items[operand_index - 1] = value;
                }
            },
            .ret => |n| n.value = value,
            .br => |n| n.args.items[operand_index] = value,
            .cond_br => |n| n.cond = value,
            .switch_ => |n| n.scrutinee = value,
            .phi => |n| n.incoming.items[operand_index].value = value,
            .alloc_heap => |n| n.count = value,
            .free => |n| n.ptr = value,
            .aggregate_make => |n| n.elems.items[operand_index] = value,
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
            block.params.items.len,
        });

        var inst_opt = block.first_inst;
        while (inst_opt) |inst_id| {
            const inst = self.insts.items[inst_id.value];
            if (inst.results.items.len > 0) {
                try writer.print("    ", .{});
                for (inst.results.items, 0..) |result_id, result_index| {
                    if (result_index > 0) try writer.print(", ", .{});
                    try writer.print("v{d}", .{result_id.value});
                }
                try writer.print(" = ", .{});
            } else {
                try writer.print("    ", .{});
            }
            try writer.print("{s}", .{@tagName(inst.kind)});
            try self.writeInstOperands(writer, inst);
            try writer.print("\n", .{});
            inst_opt = inst.next;
        }
    }

    fn writeValueRef(self: *const Self, writer: *std.Io.Writer, value_id: MLValueID) anyerror!void {
        const value = self.values.items[value_id.value];
        switch (value.data) {
            .inst_result => try writer.print("v{d}", .{value_id.value}),
            .block_param => |param| try writer.print("v{d}:param(b{d})", .{ value_id.value, param.owner_block.value }),
            .constant => |constant| try writer.print("v{d}:const(lit={d})", .{ value_id.value, constant.literal.value }),
            .symbol => |sym| try writer.print("v{d}:sym({d})", .{ value_id.value, sym.symbol.value }),
        }
    }

    fn writeInstOperands(self: *const Self, writer: *std.Io.Writer, inst: MLInst) anyerror!void {
        switch (inst.data) {
            .const_ => |n| try writer.print("(lit={d}, ty=t{d})", .{ n.lit.value, n.type_.value }),
            .load => |n| {
                try writer.print("(addr=", .{});
                try self.writeValueRef(writer, n.addr);
                try writer.print(")", .{});
            },
            .store => |n| {
                try writer.print("(addr=", .{});
                try self.writeValueRef(writer, n.addr);
                try writer.print(", value=", .{});
                try self.writeValueRef(writer, n.value);
                try writer.print(")", .{});
            },
            .addr_of => |n| try writer.print("(sym={d})", .{n.sym.value}),
            .index_addr => |n| {
                try writer.print("(base=", .{});
                try self.writeValueRef(writer, n.base);
                try writer.print(", index=", .{});
                try self.writeValueRef(writer, n.index);
                try writer.print(")", .{});
            },
            .cast => |n| {
                try writer.print("(value=", .{});
                try self.writeValueRef(writer, n.value);
                try writer.print(", to=t{d})", .{n.to_type.value});
            },
            .unary => |n| {
                try writer.print("(op={s}, value=", .{@tagName(n.op)});
                try self.writeValueRef(writer, n.value);
                try writer.print(")", .{});
            },
            .binary => |n| {
                try writer.print("(op={s}, left=", .{@tagName(n.op)});
                try self.writeValueRef(writer, n.left);
                try writer.print(", right=", .{});
                try self.writeValueRef(writer, n.right);
                try writer.print(")", .{});
            },
            .cmp => |n| {
                try writer.print("(op={s}, left=", .{@tagName(n.op)});
                try self.writeValueRef(writer, n.left);
                try writer.print(", right=", .{});
                try self.writeValueRef(writer, n.right);
                try writer.print(")", .{});
            },
            .select => |n| {
                try writer.print("(cond=", .{});
                try self.writeValueRef(writer, n.cond);
                try writer.print(", then=", .{});
                try self.writeValueRef(writer, n.then_value);
                try writer.print(", else=", .{});
                try self.writeValueRef(writer, n.else_value);
                try writer.print(")", .{});
            },
            .call => |n| {
                try writer.print("(callee=", .{});
                try self.writeValueRef(writer, n.callee);
                try writer.print(", argc={d})", .{n.args.items.len});
            },
            .ret => |n| if (n.value) |value| {
                try writer.print("(value=", .{});
                try self.writeValueRef(writer, value);
                try writer.print(")", .{});
            } else try writer.print("()", .{}),
            .br => |n| try writer.print("(target=b{d}, argc={d})", .{ n.target.value, n.args.items.len }),
            .cond_br => |n| {
                try writer.print("(cond=", .{});
                try self.writeValueRef(writer, n.cond);
                try writer.print(", true=b{d}, false=b{d})", .{ n.then_target.value, n.else_target.value });
            },
            .switch_ => |n| {
                try writer.print("(scrutinee=", .{});
                try self.writeValueRef(writer, n.scrutinee);
                try writer.print(", default=b{d}, cases={d})", .{ n.default_target.value, n.cases.items.len });
            },
            .phi => |n| try writer.print("(incoming={d})", .{n.incoming.items.len}),
            .alloc_stack => |n| try writer.print("(ty=t{d})", .{n.type_.value}),
            .alloc_heap => |n| {
                try writer.print("(ty=t{d}, count=", .{n.type_.value});
                try self.writeValueRef(writer, n.count);
                try writer.print(")", .{});
            },
            .free => |n| {
                try writer.print("(ptr=", .{});
                try self.writeValueRef(writer, n.ptr);
                try writer.print(")", .{});
            },
            .loop_ => |n| try writer.print("(header=b{d}, body=r{d})", .{ n.header.value, n.body.value }),
            .aggregate_make => |n| try writer.print("(elems={d}, ty=t{d})", .{ n.elems.items.len, n.type_.value }),
            .extract => |n| {
                try writer.print("(aggregate=", .{});
                try self.writeValueRef(writer, n.aggregate);
                try writer.print(", index={d})", .{n.index});
            },
            .insert => |n| {
                try writer.print("(aggregate=", .{});
                try self.writeValueRef(writer, n.aggregate);
                try writer.print(", index={d}, value=", .{n.index});
                try self.writeValueRef(writer, n.value);
                try writer.print(")", .{});
            },
            .global => |n| try writer.print("(sym={d}, ty=t{d})", .{ n.sym.value, n.type_.value }),
            .extern_func => |n| try writer.print("(sym={d}, ty=t{d})", .{ n.sym.value, n.type_.value }),
        }
    }
};
