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

const front = @import("../../frontend/front.zig");
const types = @import("../type.zig");

pub const MLNodeID = struct { value: u32 };
pub const MLValueID = struct { value: u32 };
pub const MLBlockID = struct { value: u32 };
pub const MLRegionID = struct { value: u32 };
pub const MLTypeID = types.TypeID;
pub const MLSymbolID = struct { value: u32 };

pub const UnaryOp = enum {
    ineg,
    fneg,
    bnot,
};

pub const BinaryOp = enum {
    iadd,
    isub,
    imul,
    idiv,
    imod,
    fadd,
    fsub,
    fmul,
    fdiv,
    band,
    bor,
    bxor,
    shl,
    lshr,
    ashr,
};

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

pub const Region = struct {
    entry: MLBlockID,
};

pub const Block = struct {
    first: ?MLNodeID,
    count: u32,
};

pub const Arg = struct {
    block: MLBlockID,
    index: u16,
    type_: MLTypeID,
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
    callee: MLSymbolID,
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
};

pub const Func = struct {
    sym: MLSymbolID,
    region: MLRegionID,
    param_start: u32,
    param_count: u16,
};

pub const ExternFunc = struct {
    sym: MLSymbolID,
    param_start: u32,
    param_count: u16,
};
