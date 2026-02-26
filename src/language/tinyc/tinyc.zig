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

const Lexicon = @import("lexicon.zig").Lexicon;
pub const Token = Lexicon.Token;
pub const Lexer = front.Lexer(Lexicon);

pub const TokenStream = front.TokenStream(Lexer);

const ast = @import("ast.zig");
pub const Parser = @import("parser.zig").Parser;
pub const ASTTree = ast.ASTTree;
pub const SpannedASTNode = ast.SpannedASTNode;
pub const ASTNode = ast.ASTNode;

pub const ASTPrintResolver = front.ASTPrintResolver;

const hlir = @import("hlir.zig");
pub const lowerASTtoHL = hlir.lowerASTtoHL;
pub const HLPrintResolver = hlir.HLPrintResolver;
