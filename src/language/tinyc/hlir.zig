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

const hlir = @import("../../intermediate/high/hlir.zig");
const HLNodeID = hlir.HLNodeID;
const HLNodeMeta = hlir.HLNodeMeta;

const nodes = @import("../../intermediate/high/nodes.zig");

const HLNodeKind = enum {
    empty,
    let,
    assign,
    unary,
    binary,
    block,
    if_,
    while_,
    do_while,
    expr_stmt,
    ident,
    literal,
};

pub const HLNodeData = union(HLNodeKind) {
    empty,
    let: nodes.Let,
    assign: nodes.Assign,
    unary: nodes.Unary,
    binary: nodes.Binary,
    block: nodes.Block,
    if_: nodes.If,
    while_: nodes.While,
    do_while: nodes.DoWhile,
    expr_stmt: nodes.ExprStmt,
    ident: nodes.Identifier,
    literal: nodes.Literal,
};

pub const HLNode = struct {
    id: HLNodeID,
    meta: HLNodeMeta,
    data: HLNodeData,
};
