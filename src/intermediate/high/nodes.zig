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

pub const Let = struct {
    symbol: SymbolID,
    init: HLNodeID,
};

pub const Assign = struct {
    target: HLNodeID,
    value: HLNodeID,
};

pub const Block = struct {
    start: HLNodeID,
    count: usize,
};

pub const Unary = struct {
    expr: HLNodeID,
};

pub const Binary = struct {
    left: HLNodeID,
    right: HLNodeID,
};

pub const If = struct {
    cond: HLNodeID,
    then: HLNodeID,
    else_: ?HLNodeID,
};

pub const While = struct {
    cond: HLNodeID,
    body: HLNodeID,
};

pub const DoWhile = struct {
    body: HLNodeID,
    cond: HLNodeID,
};

pub const ExprStmt = struct {
    expr: HLNodeID,
};

pub const Identifier = struct {
    symbol: SymbolID,
};

pub const Literal = struct {
    literal: LiteralID,
};
