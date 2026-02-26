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
const SpannedASTNode = tinyc.SpannedASTNode;
const BinaryOp = @import("ast.zig").BinaryOp;
const ASTTree = core.ASTTree(SpannedASTNode);
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
                    const semi = self.advance();
                    return self.addNode(tree, semi.span, .{ .empty = {} });
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
        const semi = try self.expectSymbol(.semicolon);
        const expr_span = self.spanOfNode(tree, expr_id);
        return self.addNode(tree, self.mergeSpans(expr_span, semi.span), .{ .expr_stmt = .{ .expr = expr_id } });
    }

    fn block(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const l_brace = try self.expectSymbol(.l_brace);

        var start: ?core.NodeID = null;
        var count: usize = 0;

        while (!self.checkSymbol(.r_brace)) {
            if (self.isEof()) return ParserError.SyntaxError;

            const stmt_id = try self.statement(tree);
            if (start == null) start = stmt_id;
            count += 1;
        }

        const r_brace = try self.expectSymbol(.r_brace);
        const block_span = self.mergeSpans(l_brace.span, r_brace.span);

        if (start == null) {
            const empty_id = try self.addNode(tree, block_span, .{ .empty = {} });
            return self.addNode(tree, block_span, .{ .block = .{ .start = empty_id, .count = 1 } });
        }

        return self.addNode(tree, block_span, .{ .block = .{ .start = start.?, .count = count } });
    }

    fn ifStmt(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const if_tok = try self.expectKeyword(.if_);
        const cond = try self.parenExpr(tree);
        const then_body = try self.statement(tree);

        var else_body: ?core.NodeID = null;
        var end_span = self.spanOfNode(tree, then_body);
        if (self.matchKeyword(.else_)) {
            else_body = try self.statement(tree);
            end_span = self.spanOfNode(tree, else_body.?);
        }

        return self.addNode(tree, self.mergeSpans(if_tok.span, end_span), .{ .if_ = .{
            .cond = cond,
            .then = then_body,
            .else_ = else_body,
        } });
    }

    fn whileStmt(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const while_tok = try self.expectKeyword(.while_);
        const cond = try self.parenExpr(tree);
        const body = try self.statement(tree);

        const body_span = self.spanOfNode(tree, body);
        return self.addNode(tree, self.mergeSpans(while_tok.span, body_span), .{ .while_ = .{
            .cond = cond,
            .body = body,
        } });
    }

    fn doWhileStmt(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const do_tok = try self.expectKeyword(.do_);
        const body = try self.statement(tree);
        _ = try self.expectKeyword(.while_);
        const cond = try self.parenExpr(tree);
        const semi = try self.expectSymbol(.semicolon);

        return self.addNode(tree, self.mergeSpans(do_tok.span, semi.span), .{ .do_while = .{
            .body = body,
            .cond = cond,
        } });
    }

    fn parenExpr(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        _ = try self.expectSymbol(.l_paren);
        const expr = try self.expression(tree);
        _ = try self.expectSymbol(.r_paren);
        return expr;
    }

    // <expr> ::= <test> | <id> "=" <expr>
    fn expression(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const left = try self.testExpr(tree);

        if (self.matchSymbol(.equal)) {
            switch (tree.get(left).value) {
                .ident => {},
                else => return ParserError.SyntaxError,
            }

            const right = try self.expression(tree);
            const left_span = self.spanOfNode(tree, left);
            const right_span = self.spanOfNode(tree, right);
            return self.addNode(tree, self.mergeSpans(left_span, right_span), .{ .assign = .{ .left = left, .right = right } });
        }

        return left;
    }

    // <test> ::= <sum> | <sum> "<" <sum>
    fn testExpr(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        var left = try self.sum(tree);

        if (self.matchSymbol(.less_than)) {
            const right = try self.sum(tree);
            const left_span = self.spanOfNode(tree, left);
            const right_span = self.spanOfNode(tree, right);
            left = try self.addNode(tree, self.mergeSpans(left_span, right_span), .{ .binary = .{ .op = .lt, .left = left, .right = right } });
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

            const left_span = self.spanOfNode(tree, left);
            const right_span = self.spanOfNode(tree, right);
            left = try self.addNode(tree, self.mergeSpans(left_span, right_span), .{ .binary = .{ .op = op, .left = left, .right = right } });
        }

        return left;
    }

    // <term> ::= <identifierID> | <LiteralID> | <paren_expr>
    fn term(self: *const Parser, tree: *ASTTree) ParserError!core.NodeID {
        const tok = self.peek();

        return switch (tok.value) {
            .identifier => |id| blk: {
                _ = self.advance();
                break :blk self.addNode(tree, tok.span, .{ .ident = .{ .id = id } });
            },
            .literal => |id| blk: {
                _ = self.advance();
                break :blk self.addNode(tree, tok.span, .{ .literal = .{ .id = id } });
            },
            .symbol => |s| switch (s) {
                .l_paren => self.parenExpr(tree),
                .minus => blk: {
                    const minus = self.advance();
                    const expr = try self.term(tree);
                    const expr_span = self.spanOfNode(tree, expr);
                    break :blk self.addNode(tree, self.mergeSpans(minus.span, expr_span), .{ .unary = .{ .op = .neg, .expr = expr } });
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

    fn expectSymbol(self: *const Parser, s: Symbol) ParserError!SpannedToken {
        const tok = self.peek();
        switch (tok.value) {
            .symbol => |got| {
                if (got == s) {
                    _ = self.advance();
                    return tok;
                }
            },
            else => {},
        }
        return ParserError.SyntaxError;
    }

    fn expectKeyword(self: *const Parser, k: Keyword) ParserError!SpannedToken {
        const tok = self.peek();
        switch (tok.value) {
            .keyword => |got| {
                if (got == k) {
                    _ = self.advance();
                    return tok;
                }
            },
            else => {},
        }
        return ParserError.SyntaxError;
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

    fn addNode(self: *const Parser, tree: *ASTTree, span: core.Span, value: ASTNode) ParserError!core.NodeID {
        _ = self;
        return tree.add(SpannedASTNode.initWithSpan(span, value)) catch return ParserError.SyntaxError;
    }

    fn spanOfNode(self: *const Parser, tree: *const ASTTree, id: core.NodeID) core.Span {
        _ = self;
        return tree.get(id).span;
    }

    fn mergeSpans(self: *const Parser, start: core.Span, end: core.Span) core.Span {
        _ = self;
        return .{
            .source_id = start.source_id,
            .start = start.start,
            .end = end.end,
            .line_start = start.line_start,
            .col_start = start.col_start,
            .line_end = end.line_end,
            .col_end = end.col_end,
        };
    }
};
