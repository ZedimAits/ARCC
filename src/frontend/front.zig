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

pub const LiteralID = struct { value: u32 };
pub const IdentifierID = struct { value: u32 };

const literal = @import("literal.zig");
pub const Literal = literal.Literal;
pub const LiteralTag = literal.LiteralTag;

const ast = @import("./ast/ast.zig");
pub const ASTTree = ast.ASTTree;
pub const ASTPrintResolver = ast.ASTPrintResolver;
pub const NodeID = ast.ASTNodeID;

pub const nodes = @import("./ast/nodes.zig");

pub const IdentInterner = @import("./intern/ident_interner.zig").IdentInterner;
pub const LiteralInterner = @import("./intern/literal_interner.zig").LiteralInterner;

pub const Lexer = @import("./lexer/lexer.zig").Lexer;
const lexicon = @import("./lexer/lexicon.zig");
pub const CommentSpec = lexicon.CommentSpec;
pub const LiteralRule = lexicon.LiteralRule;
pub const LiteralStart = lexicon.LiteralStart;
pub const LiteralBody = lexicon.LiteralBody;
pub const NumberSpec = lexicon.NumberSpec;
pub const DelimitedSpec = lexicon.DelimitedSpec;
pub const DelimitedEnd = lexicon.DelimitedEnd;
pub const EscapeMode = lexicon.EscapeMode;

pub const TokenStream = @import("./parser/tokenstream.zig").TokenStream;
pub const ParseError = @import("./parser/parse.zig").ParseError;

pub const Span = @import("span.zig").Span;
pub const Spanned = @import("span.zig").Spanned;
