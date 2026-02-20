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

const core = @import("../../frontend/front.zig");

const Lexicon = @import("lexicon.zig").Lexicon;
pub const Token = Lexicon.Token;

pub const ASTPrintResolver = core.ASTPrintResolver;

pub const ASTNode = @import("ast.zig").ASTNode;
const ASTTree = core.ASTTree(ASTNode);
pub const Lexer = core.Lexer(Lexicon);

pub const TokenStream = core.TokenStream(Lexer);
pub const Parser = @import("parser.zig").Parser;
