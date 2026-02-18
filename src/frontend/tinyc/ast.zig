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

const core = @import("../core/core.zig");
const nodes = core.nodes;

const Lexicon = @import("lexicon.zig").Lexicon;

const NodeKind = enum {
    empty,
    unary,
    binary,
    block,
    if_,
    while_,
    do_while,
    expr_stmt,
    assign,
};

pub const ASTNode = union(NodeKind) {
    empty,
    unary: nodes.UnaryNode(UnaryOp),
    binary: nodes.BinaryNode(BinaryOp),
    block: nodes.Block,
    if_: nodes.If,
    while_: nodes.While,
    do_while: nodes.DoWhile,
    expr_stmt: nodes.ExprStmt,
    assign: nodes.Assign,
    //less_than: nodes.BinaryNode(, comptime Id: type),
    //sub: Sub,
    //ident: Ident,
    //integer: Number,
};

pub const BinaryOp = enum {
    add,
    sub,
    mul,
    div,
    eq,
    ne,
    lt,
    le,
    gt,
    ge,
    //and_and, or_or,
    //bit_and, bit_or, bit_xor,
    //shl, shr,
};

pub const UnaryOp = enum {
    neg, // -x
    not, // !x
    //bit_not,  // ~x
    //addr,     // &x
    //deref,    // *x
};
