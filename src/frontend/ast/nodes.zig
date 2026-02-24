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

const ASTNodeID = @import("ast.zig").ASTNodeID;

pub fn BinaryNode(comptime Op: type) type {
    return struct {
        op: Op,
        left: ASTNodeID,
        right: ASTNodeID,
    };
}

pub fn UnaryNode(comptime Op: type) type {
    return struct {
        op: Op,
        expr: ASTNodeID,
    };
}

pub const If = struct {
    cond: ASTNodeID,
    then: ASTNodeID,
    else_: ?ASTNodeID,
};

pub const While = struct {
    cond: ASTNodeID,
    body: ASTNodeID,
};

pub const DoWhile = struct {
    body: ASTNodeID,
    cond: ASTNodeID,
};

pub const For = struct {
    init: ?ASTNodeID,
    cond: ?ASTNodeID,
    step: ?ASTNodeID,
    body: ASTNodeID,
};

pub const Block = struct {
    start: ASTNodeID,
    count: usize,
};

pub const Call = struct {
    callee: ASTNodeID,
    start: ASTNodeID,
    count: usize,
};

pub const Assign = struct {
    left: ASTNodeID,
    right: ASTNodeID,
};

pub const Return = struct {
    value: ?ASTNodeID,
};

pub const Member = struct {
    object: ASTNodeID,
    field: core.IdentifierID,
};

pub const Index = struct {
    object: ASTNodeID,
    index: ASTNodeID,
};

pub const VarDecl = struct {
    name: core.IdentifierID,
    type_name: core.IdentifierID,
    value: ?ASTNodeID,
};

pub const ExprStmt = struct {
    expr: ASTNodeID,
};

pub const Cast = struct {
    type_name: core.IdentifierID,
    expr: ASTNodeID,
};

pub const Literal = struct {
    id: core.LiteralID,
};

pub const Identifier = struct {
    id: core.IdentifierID,
};
