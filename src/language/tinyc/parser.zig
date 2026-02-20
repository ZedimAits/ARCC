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

const core = @import("../../frontend/front.zig");
const tinyc = @import("tinyc.zig");

const ParserError = core.ParseError;

const ASTNode = tinyc.ASTNode;
const BinaryOp = @import("ast.zig").BinaryOp;
const ASTTree = core.ASTTree(ASTNode);
const SpannedToken = tinyc.Lexer.SpannedToken;
const Token = tinyc.Token;
const TokenStream = tinyc.TokenStream;
const Symbol = @import("lexicon.zig").Lexicon.Symbol;
const Keyword = @import("lexicon.zig").Lexicon.Keyword;

pub const Parser = struct {
    token_stream: *TokenStream,
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator, token_stream: *TokenStream) Parser {
        return .{
            .token_stream = token_stream,
            .gpa = gpa,
        };
    }

    pub fn parse(self: *const Parser) ParserError!ASTTree {
        var tree = ASTTree.init(self.gpa);
        errdefer tree.deinit();

        while (!self.isEof()) {
            const root = try self.statement(&tree);
            try tree.addRoot(root);
        }

        return tree;
    }

    fn statement(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const tok = self.peek();

        switch (tok.value) {
            .symbol => |s| switch (s) {
                .semicolon => {
                    _ = self.advance();
                    return tree.add(.{ .empty = {} }) catch return ParserError.SyntaxError;
                },
                .l_brace => return self.block(tree),
                else => {},
            },
            .keyword => |k| switch (k) {
                .if_ => return self.ifStmt(tree),
                .while_ => return self.whileStmt(tree),
                .do_ => return self.doWhileStmt(tree),
                else => {},
            },
            else => {},
        }

        const expr_id = try self.expression(tree);
        try self.expectSymbol(.semicolon);
        return tree.add(.{ .expr_stmt = .{ .expr = expr_id } }) catch return ParserError.SyntaxError;
    }

    fn block(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        try self.expectSymbol(.l_brace);

        var start: ?core.NodeID = null;
        var count: usize = 0;

        while (!self.checkSymbol(.r_brace)) {
            if (self.isEof()) return ParserError.SyntaxError;

            const stmt_id = try self.statement(tree);
            if (start == null) start = stmt_id;
            count += 1;
        }

        try self.expectSymbol(.r_brace);

        if (start == null) {
            const empty_id = tree.add(.{ .empty = {} }) catch return ParserError.SyntaxError;
            return tree.add(.{ .block = .{ .start = empty_id, .count = 1 } }) catch return ParserError.SyntaxError;
        }

        return tree.add(.{ .block = .{ .start = start.?, .count = count } }) catch return ParserError.SyntaxError;
    }

    fn ifStmt(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        try self.expectKeyword(.if_);
        const cond = try self.parenExpr(tree);
        const then_body = try self.statement(tree);

        var else_body: ?core.NodeID = null;
        if (self.matchKeyword(.else_)) {
            else_body = try self.statement(tree);
        }

        return tree.add(.{ .if_ = .{
            .cond = cond,
            .then = then_body,
            .else_ = else_body,
        } }) catch return ParserError.SyntaxError;
    }

    fn whileStmt(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        try self.expectKeyword(.while_);
        const cond = try self.parenExpr(tree);
        const body = try self.statement(tree);

        return tree.add(.{ .while_ = .{
            .cond = cond,
            .body = body,
        } }) catch return ParserError.SyntaxError;
    }

    fn doWhileStmt(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        try self.expectKeyword(.do_);
        const body = try self.statement(tree);
        try self.expectKeyword(.while_);
        const cond = try self.parenExpr(tree);
        try self.expectSymbol(.semicolon);

        return tree.add(.{ .do_while = .{
            .body = body,
            .cond = cond,
        } }) catch return ParserError.SyntaxError;
    }

    fn parenExpr(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        try self.expectSymbol(.l_paren);
        const expr = try self.expression(tree);
        try self.expectSymbol(.r_paren);
        return expr;
    }

    // <expr> ::= <test> | <id> "=" <expr>
    fn expression(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const left = try self.testExpr(tree);

        if (self.matchSymbol(.equal)) {
            switch (tree.get(left).*) {
                .ident => {},
                else => return ParserError.SyntaxError,
            }

            const right = try self.expression(tree);
            return tree.add(.{ .assign = .{ .left = left, .right = right } }) catch return ParserError.SyntaxError;
        }

        return left;
    }

    // <test> ::= <sum> | <sum> "<" <sum>
    fn testExpr(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        var left = try self.sum(tree);

        if (self.matchSymbol(.less_than)) {
            const right = try self.sum(tree);
            left = tree.add(.{ .binary = .{ .op = .lt, .left = left, .right = right } }) catch return ParserError.SyntaxError;
        }

        return left;
    }

    // <sum> ::= <term> | <sum> "+" <term> | <sum> "-" <term>
    fn sum(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        var left = try self.term(tree);

        while (true) {
            const op = switch (self.peek().value) {
                .symbol => |s| switch (s) {
                    .plus => BinaryOp.add,
                    .minus => BinaryOp.sub,
                    else => break,
                },
                else => break,
            };

            _ = self.advance();
            const right = try self.term(tree);

            left = tree.add(.{ .binary = .{ .op = op, .left = left, .right = right } }) catch return ParserError.SyntaxError;
        }

        return left;
    }

    // <term> ::= <identifierID> | <LiteralID> | <paren_expr>
    fn term(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const tok = self.peek();

        return switch (tok.value) {
            .identifier => |id| blk: {
                _ = self.advance();
                break :blk tree.add(.{ .ident = .{ .id = id } }) catch return ParserError.SyntaxError;
            },
            .literal => |id| blk: {
                _ = self.advance();
                break :blk tree.add(.{ .literal = .{ .id = id } }) catch return ParserError.SyntaxError;
            },
            .symbol => |s| switch (s) {
                .l_paren => self.parenExpr(tree),
                .minus => blk: {
                    _ = self.advance();
                    const expr = try self.term(tree);
                    break :blk tree.add(.{ .unary = .{ .op = .neg, .expr = expr } }) catch return ParserError.SyntaxError;
                },
                else => ParserError.SyntaxError,
            },
            else => ParserError.SyntaxError,
        };
    }

    fn checkSymbol(self: *const Parser, s: Symbol) bool {
        return switch (self.peek().value) {
            .symbol => |got| got == s,
            else => false,
        };
    }

    fn matchSymbol(self: *const Parser, s: Symbol) bool {
        if (!self.checkSymbol(s)) return false;
        _ = self.advance();
        return true;
    }

    fn checkKeyword(self: *const Parser, k: Keyword) bool {
        return switch (self.peek().value) {
            .keyword => |got| got == k,
            else => false,
        };
    }

    fn matchKeyword(self: *const Parser, k: Keyword) bool {
        if (!self.checkKeyword(k)) return false;
        _ = self.advance();
        return true;
    }

    fn expectSymbol(self: *const Parser, s: Symbol) ParserError!void {
        if (!self.matchSymbol(s)) return ParserError.SyntaxError;
    }

    fn expectKeyword(self: *const Parser, k: Keyword) ParserError!void {
        if (!self.matchKeyword(k)) return ParserError.SyntaxError;
    }

    fn peek(self: *const Parser) SpannedToken {
        return self.token_stream.peek();
    }

    fn advance(self: *const Parser) SpannedToken {
        return self.token_stream.advance();
    }

    fn isEof(self: *const Parser) bool {
        return self.peek().value == .eof;
    }
};
