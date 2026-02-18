// ─────────────────────────────────────────────────────────────────────
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Cedric Beck
// Copyright 2026 Felix Koppe <fkoppe@web.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// ─────────────────────────────────────────────────────────────────────

pub const LiteralID = struct { value: u32 };
pub const IdentifierID = struct { value: u32 };

const literal = @import("literal.zig");
pub const Literal = literal.Literal;
pub const LiteralTag = literal.LiteralTag;

const ast = @import("./ast/ast.zig");
pub const ASTTree = ast.ASTTree;
pub const NodeID = ast.NodeID;

pub const nodes = @import("./ast/nodes.zig");