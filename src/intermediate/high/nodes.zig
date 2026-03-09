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

//const core = @import("../front.zig");

const hlir = @import("hlir.zig");
const HLNodeID = hlir.HLNodeID;
const SymbolID = hlir.SymbolID;
const LiteralID = @import("../../frontend/front.zig").LiteralID;

// Example: let x = 1;
pub const Let = struct {
    // Example: int a = 5;
    symbol: SymbolID,
    init: HLNodeID,
};

// Example: x = y + 1;
pub const Assign = struct {
    // Example: a = 5;
    target: HLNodeID,
    value: HLNodeID,
};

// Example: { a = 1; b = 2; }
pub const Block = struct {
    // Example: { stmt1; stmt2; }
    start: HLNodeID,
    count: usize,
};

// Example: -x
pub const Unary = struct {
    // Example: -x
    expr: HLNodeID,
};

// Example: a + b
pub const Binary = struct {
    // Example: a + b
    left: HLNodeID,
    right: HLNodeID,
};

// Example: if (a < b) x = 1; else x = 2;
pub const If = struct {
    // Example: if (cond) then_stmt else else_stmt
    cond: HLNodeID,
    then: HLNodeID,
    else_: ?HLNodeID,
};

// Example: while (i < 10) i = i + 1;
pub const While = struct {
    // Example: while (cond) body
    cond: HLNodeID,
    body: HLNodeID,
};

// Example: do i = i + 1; while (i < 10);
pub const DoWhile = struct {
    // Example: do body while (cond);
    body: HLNodeID,
    cond: HLNodeID,
};

// Example: foo + 1;
pub const ExprStmt = struct {
    // Example: foo();
    expr: HLNodeID,
};

// Example: variable x in expression x + 1
pub const Identifier = struct {
    // Example: a
    symbol: SymbolID,
};

// Example: 42
pub const Literal = struct {
    // Example: 42
    literal: LiteralID,
};
