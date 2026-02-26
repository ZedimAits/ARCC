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

pub const LLTypeID = struct { value: u32 };
pub const LLValueID = struct { value: u32 };
pub const LLInstID = struct { value: u32 };
pub const LLBlockID = struct { value: u32 };
pub const LLFuncID = struct { value: u32 };
pub const LLGlobalID = struct { value: u32 };

pub const CallingConv = enum {
    c,
    fast,
    cold,
};

pub const IntSign = enum {
    unsigned,
    signed,
};

pub const LLTypeKind = enum {
    void,
    int,
    float,
    ptr,
    array,
    vector,
    function,
};

pub const LLType = union(LLTypeKind) {
    void,
    int: struct {
        bits: u16,
        sign: IntSign = .unsigned,
    },
    float: struct {
        bits: u16, // usually 8/16/32/64/128
    },
    ptr,
    array: struct {
        elem: LLTypeID,
        len: u32,
    },
    vector: struct {
        elem: LLTypeID,
        len: u16,
    },
    function: struct {
        ret: LLTypeID,
        param_start: u32,
        param_count: u16,
        variadic: bool = false,
        cc: CallingConv = .c,
    },
};

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
    select: struct { cond: LLValueID, then_v: LLValueID, else_v: LLValueID }, // ternary value select
    phi: struct { incoming_start: u32, incoming_count: u16 }, // SSA merge from predecessors
    call: struct { callee: LLValueID, arg_start: u32, arg_count: u16 }, // direct/indirect call
    br: struct { target: LLBlockID }, // unconditional jump
    cond_br: struct { cond: LLValueID, then_blk: LLBlockID, else_blk: LLBlockID }, // conditional jump
    switch_: struct { value: LLValueID, default_blk: LLBlockID, case_start: u32, case_count: u16 }, // multi-way jump
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

pub const LLModule = struct {
    const Self = @This();

    gpa: std.mem.Allocator,

    types: std.ArrayListUnmanaged(LLType) = .{},
    values: std.ArrayListUnmanaged(LLValue) = .{},
    phi_incoming: std.ArrayListUnmanaged(LLPhiIncoming) = .{},
    switch_cases: std.ArrayListUnmanaged(LLSwitchCase) = .{},
    call_args: std.ArrayListUnmanaged(LLValueID) = .{},

    globals: std.ArrayListUnmanaged(LLGlobal) = .{},
    funcs: std.ArrayListUnmanaged(LLFunction) = .{},
    blocks: std.ArrayListUnmanaged(LLBlock) = .{},
    insts: std.ArrayListUnmanaged(LLInst) = .{},

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *Self) void {
        self.types.deinit(self.gpa);
        self.values.deinit(self.gpa);
        self.phi_incoming.deinit(self.gpa);
        self.switch_cases.deinit(self.gpa);
        self.call_args.deinit(self.gpa);
        self.globals.deinit(self.gpa);
        self.funcs.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        self.insts.deinit(self.gpa);
    }

    pub fn addType(self: *Self, data: LLType) !LLTypeID {
        const id = LLTypeID{ .value = @intCast(self.types.items.len) };
        try self.types.append(self.gpa, .{ .id = id, .data = data });
        return id;
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
            self.types.items.len,
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
        }
    }
};
