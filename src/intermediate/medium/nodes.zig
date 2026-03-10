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

pub const MLTypeID = types.TypeID;

pub const MLInstID = struct { value: u32 };
pub const MLNodeID = MLInstID;
pub const MLValueID = struct { value: u32 };
pub const MLUseID = struct { value: u32 };
pub const MLBlockID = struct { value: u32 };
pub const MLRegionID = struct { value: u32 };
pub const MLFuncID = struct { value: u32 };
pub const MLSymbolID = struct { value: u32 };

pub const MLValueKind = enum {
    inst_result,
    block_param,
    constant,
    symbol,
};

pub const MLValue = struct {
    kind: MLValueKind,
    type_: MLTypeID,
    def_inst: ?MLInstID = null,
    owner_block: ?MLBlockID = null,
    literal: ?front.LiteralID = null,
    symbol: ?MLSymbolID = null,
    use_head: ?MLUseID = null,
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
    type_: MLTypeID,
};

pub const Load = struct {
    addr: MLValueID,
};

pub const Store = struct {
    addr: MLValueID,
    value: MLValueID,
};

pub const AddrOf = struct {
    sym: MLSymbolID,
};

pub const IndexAddr = struct {
    base: MLValueID,
    index: MLValueID,
};

pub const Cast = struct {
    value: MLValueID,
    to_type: MLTypeID,
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
    arg_start: u32,
    arg_count: u16,
};

pub const Ret = struct {
    value: ?MLValueID,
};

pub const Br = struct {
    target: MLBlockID,
    arg_start: u32,
    arg_count: u16,
};

pub const CondBr = struct {
    cond: MLValueID,
    then_target: MLBlockID,
    else_target: MLBlockID,
};

pub const Switch = struct {
    scrutinee: MLValueID,
    default_target: MLBlockID,
    case_start: u32,
    case_count: u16,
};

pub const Phi = struct {
    incoming_start: u32,
    incoming_count: u16,
};

pub const AllocStack = struct {
    type_: MLTypeID,
};

pub const AllocHeap = struct {
    type_: MLTypeID,
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
    elem_start: u32,
    elem_count: u16,
    type_: MLTypeID,
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
    sym: MLSymbolID,
    type_: MLTypeID,
    init: ?MLValueID,
    is_const: bool = false,
};

pub const ExternFunc = struct {
    sym: MLSymbolID,
    type_: MLTypeID,
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
    result_start: u32 = 0,
    result_count: u8 = 0,
};

pub const MLBlock = struct {
    parent_region: MLRegionID,
    first_inst: ?MLInstID = null,
    last_inst: ?MLInstID = null,
    param_start: u32 = 0,
    param_count: u16 = 0,
};

pub const MLRegion = struct {
    entry: MLBlockID,
    block_start: u32,
    block_count: u32,
};

pub const MLFunction = struct {
    name: []const u8,
    region: MLRegionID,
    ret_type: MLTypeID,
};

pub const MLPhiIncoming = struct {
    block: MLBlockID,
    value: MLValueID,
};

pub const MLSwitchCase = struct {
    value: u64,
    target: MLBlockID,
};
