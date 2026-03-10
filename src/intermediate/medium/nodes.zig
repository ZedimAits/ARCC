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
const types = @import("../type.zig");
const symbol = @import("../symbol.zig");

pub const MLInstID = struct { value: u32 };
pub const MLValueID = struct { value: u32 };
pub const MLUseID = struct { value: u32 };
pub const MLBlockID = struct { value: u32 };
pub const MLRegionID = struct { value: u32 };
pub const MLFuncID = struct { value: u32 };
pub const SymbolID = symbol.SymbolID;

pub const MLValueKind = enum {
    inst_result,
    block_param,
    constant,
    symbol,
};

pub const MLValueData = union(MLValueKind) {
    inst_result: struct {
        def_inst: MLInstID,
    },
    block_param: struct {
        owner_block: MLBlockID,
    },
    constant: struct {
        literal: front.LiteralID,
    },
    symbol: struct {
        symbol: SymbolID,
    },
};

pub const MLValue = struct {
    type_: types.TypeID,
    use_head: ?MLUseID = null,
    data: MLValueData,

    pub fn kind(self: *const MLValue) MLValueKind {
        return std.meta.activeTag(self.data);
    }

    pub fn instResult(type_: types.TypeID, def_inst: MLInstID) MLValue {
        return .{
            .type_ = type_,
            .data = .{ .inst_result = .{ .def_inst = def_inst } },
        };
    }

    pub fn blockParam(type_: types.TypeID, owner_block: MLBlockID) MLValue {
        return .{
            .type_ = type_,
            .data = .{ .block_param = .{ .owner_block = owner_block } },
        };
    }

    pub fn constant(type_: types.TypeID, literal: front.LiteralID) MLValue {
        return .{
            .type_ = type_,
            .data = .{ .constant = .{ .literal = literal } },
        };
    }

    pub fn symbol(type_: types.TypeID, symbol_id: SymbolID) MLValue {
        return .{
            .type_ = type_,
            .data = .{ .symbol = .{ .symbol = symbol_id } },
        };
    }
};

pub const MLUse = struct {
    user: MLInstID,
    operand_index: u16,
    next: ?MLUseID = null,
};

pub const EffectFlags = packed struct(u8) {
    reads_mem: bool = false,
    writes_mem: bool = false,
    has_io: bool = false,
    is_volatile: bool = false,
    _pad: u4 = 0,
};

pub const MLInstMeta = struct {
    span: front.Span,
    effects: EffectFlags = .{},
    scope: u32 = 0,
};

pub const UnaryOp = enum {
    ineg,
    fneg,
    bnot,
};

pub const BinaryOp = enum { iadd, isub, imul, idiv, imod, fadd, fsub, fmul, fdiv, band, bor, bxor, shl, lshr, ashr };

pub const CmpOp = enum {
    ieq,
    ine,
    ilt,
    ile,
    igt,
    ige,
    feq,
    fne,
    flt,
    fle,
    fgt,
    fge,
};

pub const Const = struct {
    lit: front.LiteralID,
    type_: types.TypeID,
};

pub const Load = struct {
    addr: MLValueID,
};

pub const Store = struct {
    addr: MLValueID,
    value: MLValueID,
};

pub const AddrOf = struct {
    sym: SymbolID,
};

pub const IndexAddr = struct {
    base: MLValueID,
    index: MLValueID,
};

pub const Cast = struct {
    value: MLValueID,
    to_type: types.TypeID,
};

pub const Unary = struct {
    op: UnaryOp,
    value: MLValueID,
};

pub const Binary = struct {
    op: BinaryOp,
    left: MLValueID,
    right: MLValueID,
};

pub const Cmp = struct {
    op: CmpOp,
    left: MLValueID,
    right: MLValueID,
};

pub const Select = struct {
    cond: MLValueID,
    then_value: MLValueID,
    else_value: MLValueID,
};

pub const Call = struct {
    callee: MLValueID,
    args: std.ArrayListUnmanaged(MLValueID) = .{},
};

pub const Ret = struct {
    value: ?MLValueID,
};

pub const Br = struct {
    target: MLBlockID,
    args: std.ArrayListUnmanaged(MLValueID) = .{},
};

pub const CondBr = struct {
    cond: MLValueID,
    then_target: MLBlockID,
    else_target: MLBlockID,
};

pub const Switch = struct {
    scrutinee: MLValueID,
    default_target: MLBlockID,
    cases: std.ArrayListUnmanaged(MLSwitchCase) = .{},
};

pub const Phi = struct {
    incoming: std.ArrayListUnmanaged(MLPhiIncoming) = .{},
};

pub const AllocStack = struct {
    type_: types.TypeID,
};

pub const AllocHeap = struct {
    type_: types.TypeID,
    count: MLValueID,
};

pub const Free = struct {
    ptr: MLValueID,
};

pub const Loop = struct {
    header: MLBlockID,
    body: MLRegionID,
};

pub const AggregateMake = struct {
    elems: std.ArrayListUnmanaged(MLValueID) = .{},
    type_: types.TypeID,
};

pub const Extract = struct {
    aggregate: MLValueID,
    index: u32,
};

pub const Insert = struct {
    aggregate: MLValueID,
    index: u32,
    value: MLValueID,
};

pub const Global = struct {
    sym: SymbolID,
    type_: types.TypeID,
    init: ?MLValueID,
    is_const: bool = false,
};

pub const ExternFunc = struct {
    sym: SymbolID,
    type_: types.TypeID,
};

pub const MLInstData = union(enum) {
    const_: Const,
    load: Load,
    store: Store,
    addr_of: AddrOf,
    index_addr: IndexAddr,
    cast: Cast,
    unary: Unary,
    binary: Binary,
    cmp: Cmp,
    select: Select,
    call: Call,
    ret: Ret,
    br: Br,
    cond_br: CondBr,
    switch_: Switch,
    phi: Phi,
    alloc_stack: AllocStack,
    alloc_heap: AllocHeap,
    free: Free,
    loop_: Loop,
    aggregate_make: AggregateMake,
    extract: Extract,
    insert: Insert,
    global: Global,
    extern_func: ExternFunc,
};

pub const MLInst = struct {
    id: MLInstID,
    kind: std.meta.Tag(MLInstData),
    parent_block: MLBlockID,
    prev: ?MLInstID = null,
    next: ?MLInstID = null,
    meta: MLInstMeta,
    data: MLInstData,
    results: std.ArrayListUnmanaged(MLValueID) = .{},

    pub fn deinit(self: *MLInst, gpa: std.mem.Allocator) void {
        self.results.deinit(gpa);
        switch (self.data) {
            .call => |n| {
                var args = n.args;
                args.deinit(gpa);
            },
            .br => |n| {
                var args = n.args;
                args.deinit(gpa);
            },
            .switch_ => |n| {
                var cases = n.cases;
                cases.deinit(gpa);
            },
            .phi => |n| {
                var incoming = n.incoming;
                incoming.deinit(gpa);
            },
            .aggregate_make => |n| {
                var elems = n.elems;
                elems.deinit(gpa);
            },
            else => {},
        }
    }
};

pub const MLBlock = struct {
    parent_region: MLRegionID,
    first_inst: ?MLInstID = null,
    last_inst: ?MLInstID = null,
    params: std.ArrayListUnmanaged(MLValueID) = .{},

    pub fn deinit(self: *MLBlock, gpa: std.mem.Allocator) void {
        self.params.deinit(gpa);
    }
};

pub const MLRegion = struct {
    entry: MLBlockID,
    blocks: std.ArrayListUnmanaged(MLBlockID) = .{},

    pub fn deinit(self: *MLRegion, gpa: std.mem.Allocator) void {
        self.blocks.deinit(gpa);
    }
};

pub const MLFunction = struct {
    name: []const u8,
    region: MLRegionID,
    ret_type: types.TypeID,
};

pub const MLPhiIncoming = struct {
    block: MLBlockID,
    value: MLValueID,
};

pub const MLSwitchCase = struct {
    value: u64,
    target: MLBlockID,
};
