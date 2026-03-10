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
const types = @import("../type.zig");
const type_interner = @import("../type_interner.zig");

pub const LLTypeID = types.TypeID;
pub const LLValueID = struct { value: u32 };
pub const LLInstID = struct { value: u32 };
pub const LLBlockID = struct { value: u32 };
pub const LLFuncID = struct { value: u32 };
pub const LLGlobalID = struct { value: u32 };

pub const CallingConv = types.CallingConv;

pub const IntSign = types.IntSign;

pub const LLTypeKind = types.TypeKind;

pub const LLType = types.Type;

pub const LLConst = union(enum) {
    int: u128,
    float_bits: u64,
    bool: bool,
    null,
};

pub const LLBinaryOp = enum {
    add,
    sub,
    mul,
    udiv,
    sdiv,
    urem,
    srem,
    shl,
    lshr,
    ashr,
    and_,
    or_,
    xor_,
};

pub const LLCmpOp = enum {
    eq,
    ne,
    ult,
    ule,
    ugt,
    uge,
    slt,
    sle,
    sgt,
    sge,
};

pub const LLCastOp = enum {
    zext,
    sext,
    trunc,
    bitcast,
    int_to_ptr,
    ptr_to_int,
};

pub const LLEffectFlags = packed struct(u8) {
    reads_mem: bool = false,
    writes_mem: bool = false,
    has_io: bool = false,
    may_trap: bool = false,
    _pad: u4 = 0,
};

pub const LLBlock = struct {
    label: ?[]const u8 = null,
    inst_start: u32,
    inst_count: u32,
};

pub const LLFunction = struct {
    name: []const u8,
    ty: LLTypeID, // function type
    entry: LLBlockID,
    block_start: u32,
    block_count: u32,
    arg_start: u32,
    arg_count: u16,
};

pub const LLGlobal = struct {
    name: []const u8,
    ty: LLTypeID,
    init: ?LLValueID = null,
    is_const: bool = false,
};

pub const LLValue = union(enum) {
    none, // instruction has no SSA result
    const_: struct { // inline constant value
        ty: LLTypeID,
        value: LLConst,
    },
    arg: struct { // function argument
        index: u16,
    },
    inst: struct { // result of another instruction
        id: LLInstID,
    },
    global: struct { // reference to global symbol
        id: LLGlobalID,
    },
};

pub const LLInstMeta = struct {
    result_ty: ?LLTypeID = null,
    effects: LLEffectFlags = .{},
    name_hint: ?[]const u8 = null,
};

pub const LLInstData = union(enum) {
    nop, // explicit no-op
    alloca: struct { ty: LLTypeID }, // reserve stack slot
    load: struct { ptr: LLValueID }, // read from memory
    store: struct { ptr: LLValueID, value: LLValueID }, // write to memory
    gep: struct { base_ptr: LLValueID, index: LLValueID }, // pointer + scaled index
    binary: struct { op: LLBinaryOp, lhs: LLValueID, rhs: LLValueID }, // integer arithmetic/bitwise op
    icmp: struct { op: LLCmpOp, lhs: LLValueID, rhs: LLValueID }, // integer comparison
    cast: struct { op: LLCastOp, value: LLValueID, to_ty: LLTypeID }, // explicit type conversion
    call: struct { callee: LLValueID, arg_start: u32, arg_count: u16 }, // direct/indirect call
    br: struct { target: LLBlockID }, // unconditional jump
    cond_br: struct { cond: LLValueID, then_blk: LLBlockID, else_blk: LLBlockID }, // conditional jump
    ret: struct { value: ?LLValueID = null }, // function return
    unreachable_: void, // proven impossible path
};

pub const LLPhiIncoming = struct {
    block: LLBlockID,
    value: LLValueID,
};

pub const LLSwitchCase = struct {
    key: LLConst,
    target: LLBlockID,
};

pub const LLInst = struct {
    id: LLInstID,
    meta: LLInstMeta = .{},
    data: LLInstData,
};

// LLIR is the last structured backend IR: module -> functions -> blocks -> instructions.
// High-level CFG/value ops such as select/switch/phi belong in MLIR and must be removed before LL lowering.
// Final straight-line emission belongs to a later linearization stage.
pub const LLModule = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    type_interner: *const type_interner.TypeInterner,
    values: std.ArrayListUnmanaged(LLValue) = .{},
    phi_incoming: std.ArrayListUnmanaged(LLPhiIncoming) = .{},
    switch_cases: std.ArrayListUnmanaged(LLSwitchCase) = .{},
    call_args: std.ArrayListUnmanaged(LLValueID) = .{},

    globals: std.ArrayListUnmanaged(LLGlobal) = .{},
    funcs: std.ArrayListUnmanaged(LLFunction) = .{},
    blocks: std.ArrayListUnmanaged(LLBlock) = .{},
    insts: std.ArrayListUnmanaged(LLInst) = .{},

    pub fn init(gpa: std.mem.Allocator, interner: *const type_interner.TypeInterner) Self {
        return .{
            .gpa = gpa,
            .type_interner = interner,
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit(self.gpa);
        self.phi_incoming.deinit(self.gpa);
        self.switch_cases.deinit(self.gpa);
        self.call_args.deinit(self.gpa);
        self.globals.deinit(self.gpa);
        self.funcs.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.insts.deinit(self.gpa);
    }

    pub fn addValue(self: *Self, value: LLValue) !LLValueID {
        const id = LLValueID{ .value = @intCast(self.values.items.len) };
        try self.values.append(self.gpa, value);
        return id;
    }

    pub fn addBlock(self: *Self, block: LLBlock) !LLBlockID {
        const id = LLBlockID{ .value = @intCast(self.blocks.items.len) };
        try self.blocks.append(self.gpa, block);
        return id;
    }

    pub fn addInst(self: *Self, data: LLInstData, meta: LLInstMeta) !LLInstID {
        const id = LLInstID{ .value = @intCast(self.insts.items.len) };
        try self.insts.append(self.gpa, .{
            .id = id,
            .meta = meta,
            .data = data,
        });
        return id;
    }

    pub fn addGlobal(self: *Self, global: LLGlobal) !LLGlobalID {
        const id = LLGlobalID{ .value = @intCast(self.globals.items.len) };
        try self.globals.append(self.gpa, global);
        return id;
    }

    pub fn addFunction(self: *Self, func: LLFunction) !LLFuncID {
        const id = LLFuncID{ .value = @intCast(self.funcs.items.len) };
        try self.funcs.append(self.gpa, func);
        return id;
    }

    pub fn writeTo(self: *const Self, writer: *std.Io.Writer) anyerror!void {
        try writer.print("LL-MODULE (types={d}, values={d}, globals={d}, funcs={d}, blocks={d}, insts={d})\n", .{
            self.type_interner.count(),
            self.values.items.len,
            self.globals.items.len,
            self.funcs.items.len,
            self.blocks.items.len,
            self.insts.items.len,
        });

        for (self.funcs.items, 0..) |f, i| {
            try writer.print("func[{d}] {s} (entry=b{d}, blocks={d})\n", .{
                i,
                f.name,
                f.entry.value,
                f.block_count,
            });

            const block_end = f.block_start + f.block_count;
            var block_index = f.block_start;
            while (block_index < block_end) : (block_index += 1) {
                try self.writeBlock(writer, .{ .value = @intCast(block_index) });
            }
        }
    }

    fn writeBlock(self: *const Self, writer: *std.Io.Writer, block_id: LLBlockID) anyerror!void {
        const block = self.blocks.items[block_id.value];
        try writer.print("  block[{d}]\n", .{block_id.value});

        var inst_index = block.inst_start;
        const inst_end = block.inst_start + block.inst_count;
        while (inst_index < inst_end) : (inst_index += 1) {
            const inst = self.insts.items[inst_index];
            try writer.print("    i{d}", .{inst.id.value});
            if (inst.meta.result_ty != null) {
                try writer.print(" -> v{d}", .{inst.id.value});
            }
            try writer.print(" = {s}", .{@tagName(inst.data)});
            try self.writeInstOperands(writer, inst);
            try writer.print("\n", .{});
        }
    }

    pub fn writeInstOperands(self: *const Self, writer: *std.Io.Writer, inst: LLInst) anyerror!void {
        switch (inst.data) {
            .nop => try writer.print("()", .{}),
            .alloca => |n| try writer.print("(ty=t{d})", .{n.ty.value}),
            .load => |n| try writer.print("(ptr=v{d})", .{n.ptr.value}),
            .store => |n| try writer.print("(ptr=v{d}, value=v{d})", .{ n.ptr.value, n.value.value }),
            .gep => |n| try writer.print("(base=v{d}, index=v{d})", .{ n.base_ptr.value, n.index.value }),
            .binary => |n| try writer.print("(op={s}, lhs=v{d}, rhs=v{d})", .{ @tagName(n.op), n.lhs.value, n.rhs.value }),
            .icmp => |n| try writer.print("(op={s}, lhs=v{d}, rhs=v{d})", .{ @tagName(n.op), n.lhs.value, n.rhs.value }),
            .cast => |n| try writer.print("(op={s}, value=v{d}, to=t{d})", .{ @tagName(n.op), n.value.value, n.to_ty.value }),
            .call => |n| {
                try writer.print("(callee=v{d}", .{n.callee.value});
                const args = self.call_args.items[n.arg_start .. n.arg_start + n.arg_count];
                for (args, 0..) |arg, idx| {
                    try writer.print(", arg{d}=v{d}", .{ idx, arg.value });
                }
                try writer.print(")", .{});
            },
            .br => |n| try writer.print("(target=b{d})", .{n.target.value}),
            .cond_br => |n| try writer.print("(cond=v{d}, true=b{d}, false=b{d})", .{ n.cond.value, n.then_blk.value, n.else_blk.value }),
            .ret => |n| if (n.value) |value| try writer.print("(value=v{d})", .{value.value}) else try writer.print("()", .{}),
            .unreachable_ => try writer.print("()", .{}),
        }
    }
};
