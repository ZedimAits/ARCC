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

const core = @import("../front.zig");

const NodeID = @import("ast.zig").ASTNodeID;

pub fn BinaryNode(comptime Op: type) type {
    return struct {
        op: Op,
        left: NodeID,
        right: NodeID,
    };
}

pub fn UnaryNode(comptime Op: type) type {
    return struct {
        op: Op,
        expr: NodeID,
    };
}

pub const If = struct {
    cond: NodeID,
    then: NodeID,
    else_: ?NodeID,
};

pub const While = struct {
    cond: NodeID,
    body: NodeID,
};

pub const DoWhile = struct {
    body: NodeID,
    cond: NodeID,
};

pub const For = struct {
    init: ?NodeID,
    cond: ?NodeID,
    step: ?NodeID,
    body: NodeID,
};

pub const Block = struct {
    start: NodeID,
    count: usize,
};

pub const Call = struct {
    callee: NodeID,
    start: NodeID,
    count: usize,
};

pub const Assign = struct {
    left: NodeID,
    right: NodeID,
};

pub const Return = struct {
    value: ?NodeID,
};

pub const Member = struct {
    object: NodeID,
    field: core.IdentifierID,
};

pub const Index = struct {
    object: NodeID,
    index: NodeID,
};

pub const VarDecl = struct {
    name: core.IdentifierID,
    type_name: core.IdentifierID,
    value: ?NodeID,
};

pub const ExprStmt = struct {
    expr: NodeID,
};

pub const Cast = struct {
    type_name: core.IdentifierID,
    expr: NodeID,
};

pub const Literal = struct {
    id: core.LiteralID,
};

pub const Identifier = struct {
    id: core.IdentifierID,
};
