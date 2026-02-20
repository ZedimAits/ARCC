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
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Token = @import("Lexer.zig").Lexer.Token;

pub const Parser = struct {
    const NodeKind = enum { VAR, CST, ADD, SUB, LT, SET, IF, WHILE, DO, EMPTY, SEQ, EXPR, PROG };
    const NodeChilds = union(enum) {
        one_child: *ASTNode,
        two_childs: [2]*ASTNode,
        three_childs: [3]*ASTNode,
    };
    const NodeValue = union(enum) { num_value: u32, id_name: []const u8 };
    pub const ASTNode = struct { kind: NodeKind, childs: ?NodeChilds = null, value: ?NodeValue = null };
    const ParserError = error{ SyntaxError, LexerError };

    allocator: Allocator,
    tokens: []Token = undefined,
    pos: usize = 0,

    pub fn parse(self: *Parser, tokens: []Token) ParserError!*ASTNode {
        self.tokens = tokens;
        const prog = self.getNode(.PROG);
        prog.childs = .{ .one_child = try self.statement() };

        if (self.next() != null) return ParserError.SyntaxError;

        return prog;
    }

    fn statement(self: *Parser) ParserError!*ASTNode {
        var node: *ASTNode = undefined;
        var token = self.next() orelse return ParserError.SyntaxError;

        if (token.token_type == .IF_SYM) // "if" <paren_expr> <statement>

        {
            node = self.getNode(.IF);

            const cond = try self.paren_expr();
            const then = try self.statement();

            node.childs = .{ .two_childs = .{ cond, then } };

            if (self.peek()) |t| {
                if (t.token_type == .ELSE_SYM) {
                    _ = self.next() orelse return ParserError.SyntaxError; // else konsumieren
                    const else_block = try self.statement();
                    node.childs = .{ .three_childs = .{ cond, then, else_block } };
                }
            }
        } else if (token.token_type == .WHILE_SYM) //"while" <paren_expr> <statement>
        {
            node = self.getNode(.WHILE);

            const cond = try self.paren_expr();
            const while_block = try self.statement();

            node.childs = .{ .two_childs = .{ cond, while_block } };
        } else if (token.token_type == .DO_SYM) //"do" <statement> "while" <paren_expr> ";"
        {
            node = self.getNode(.DO);
            const do_block = try self.statement();

            const semi = self.next() orelse return ParserError.SyntaxError;
            if (semi.token_type != .WHILE_SYM) return ParserError.SyntaxError;

            const cond = try self.paren_expr();

            token = self.next() orelse return ParserError.SyntaxError;
            if (token.token_type != .SEMI) return ParserError.SyntaxError;

            node.childs = .{ .two_childs = .{ do_block, cond } };
        } else if (token.token_type == .SEMI) //";"
        {
            node = self.getNode(.EMPTY);
        } else if (token.token_type == .LBRA) //"{" { <statement> } "}"
        {
            var node_opt: ?*ASTNode = null;
            while ((self.peek() orelse return ParserError.SyntaxError).token_type != .RBRA) {
                const stmt = try self.statement();

                if (node_opt) |prev| {
                    const seq = self.getNode(.SEQ);
                    seq.childs = .{ .two_childs = .{ prev, stmt } };
                    node_opt = seq;
                } else {
                    node_opt = stmt; // erstes Statement, kein SEQ/EMPTY davor
                }
            }
            node = node_opt orelse self.getNode(.EMPTY);

            _ = self.next() orelse return ParserError.SyntaxError;
        } else { // <expr> ";"
            node = self.getNode(.EXPR);

            // Starttoken ist bereits cur() (das token von oben)
            node.childs = .{ .one_child = try self.expr() };

            const semi = self.next() orelse return ParserError.SyntaxError;
            if (semi.token_type != .SEMI) return ParserError.SyntaxError;
        }

        return node;
    }

    fn paren_expr(self: *Parser) ParserError!*ASTNode { //<paren_expr> ::= "(" <expr> ")" */
        const lpar = self.next() orelse return ParserError.SyntaxError;
        if (lpar.token_type != .LPAR) return ParserError.SyntaxError;

        // expr startet jetzt bei cur() (erstes Token IN der Klammer)
        _ = self.next() orelse return ParserError.SyntaxError;
        const node = try self.expr();

        const rpar = self.next() orelse return ParserError.SyntaxError;
        if (rpar.token_type != .RPAR) return ParserError.SyntaxError;

        return node;
    }

    fn expr(self: *Parser) ParserError!*ASTNode { //  <expr> ::= <test> | <id> "=" <expr>
        var node = try self.test_node();

        // assignment: nur wenn node VAR und nächstes token '=' ist
        if (node.kind == .VAR) {
            if (self.peek()) |t| {
                if (t.token_type == .EQUAL) {
                    _ = self.next() orelse return ParserError.SyntaxError; // '=' konsumieren

                    // start rhs token konsumieren
                    _ = self.next() orelse return ParserError.SyntaxError;
                    const right = try self.expr();

                    const set = self.getNode(.SET);
                    set.childs = .{ .two_childs = .{ node, right } };
                    return set;
                }
            }
        }
        return node;
    }

    fn test_node(self: *Parser) ParserError!*ASTNode { //<test> ::= <sum> | <sum> "<" <sum>
        const node = try self.sum();

        if (self.peek()) |t| {
            if (t.token_type == .LESS) {
                _ = self.next() orelse return ParserError.SyntaxError; // '<'

                _ = self.next() orelse return ParserError.SyntaxError; // start rhs
                const right = try self.sum();

                const lt = self.getNode(.LT);
                lt.childs = .{ .two_childs = .{ node, right } };
                return lt;
            }
        }
        return node;
    }

    fn sum(self: *Parser) ParserError!*ASTNode { //<sum> ::= <term> | <sum> "+" <term> | <sum> "-" <term>
        var node = try self.term();

        while (true) {
            const t = self.peek() orelse break;
            if (t.token_type != .PLUS and t.token_type != .MINUS) break;

            const op = self.next() orelse return ParserError.SyntaxError; // '+' / '-'

            _ = self.next() orelse return ParserError.SyntaxError; // start rhs
            const right = try self.term();

            const left = node;
            node = self.getNode(if (op.token_type == .PLUS) .ADD else .SUB);
            node.childs = .{ .two_childs = .{ left, right } };
        }

        return node;
    }

    fn term(self: *Parser) ParserError!*ASTNode { // <term> ::= <id> | <int> | <paren_expr>
        //next token already consumed
        var node: *ASTNode = undefined;
        const token: Token = self.cur() orelse return ParserError.SyntaxError;

        if (token.token_type == .ID) {
            node = self.getNode(.VAR);

            if (token.value) |t| {
                switch (t) {
                    .id_name => |name| node.value = .{ .id_name = name },
                    else => {
                        std.debug.print("token_type ID but id_name is not set ('{any}')", .{token});
                        return error.LexerError;
                    },
                }
            } else {
                std.debug.print("token_type ID but value is null ('{any}')", .{token});
                return error.LexerError;
            }
        } else if (token.token_type == .INT) {
            node = self.getNode(.CST);

            if (token.value) |t| {
                switch (t) {
                    .num_value => |num| node.value = .{ .num_value = num },
                    else => {
                        std.debug.print("token_type INT but num_value is not set ('{any}')", .{token});
                        return error.LexerError;
                    },
                }
            } else {
                std.debug.print("token_type INT but value is null ('{any}')", .{token});
                return error.LexerError;
            }
        } else {
            node = try self.paren_expr();
        }
        return node;
    }

    fn next(self: *Parser) ?Token {
        if (self.pos >= self.tokens.len) return null;

        const next_token: Token = self.tokens[self.pos];
        //std.debug.print("\nProcessed: {any}\n", .{next_token.token_type});

        self.pos += 1;

        return next_token;
    }

    fn cur(self: *Parser) ?Token {
        if (self.pos == 0) return null;
        if (self.pos > self.tokens.len) return null;
        return self.tokens[self.pos - 1];
    }

    fn peek(self: *Parser) ?Token {
        if (self.pos >= self.tokens.len) return null;
        return self.tokens[self.pos];
    }

    fn getNode(self: *Parser, kind: NodeKind) *ASTNode {
        const node = self.allocator.create(ASTNode) catch unreachable;
        node.* = .{
            .kind = kind,
            .childs = null,
            .value = null,
        };
        return node;
    }

    pub fn printAST(ast_node: *ASTNode) void {
        const F = struct {
            fn printASTWithIndent(node: *ASTNode, depth: usize) void {
                var i: usize = 0;
                while (i < depth) : (i += 1) {
                    std.debug.print("| ", .{});
                }

                std.debug.print("{s}", .{@tagName(node.kind)});

                if (node.value) |value| {
                    switch (value) {
                        .num_value => |num| std.debug.print("({d})", .{num}),
                        .id_name => |name| std.debug.print("({s})", .{name}),
                    }
                }

                std.debug.print("\n", .{});

                if (node.childs) |childs| {
                    switch (childs) {
                        .one_child => |child| printASTWithIndent(child, depth + 1),
                        .two_childs => |pair| {
                            printASTWithIndent(pair[0], depth + 1);
                            printASTWithIndent(pair[1], depth + 1);
                        },
                        .three_childs => |triple| {
                            printASTWithIndent(triple[0], depth + 1);
                            printASTWithIndent(triple[1], depth + 1);
                            printASTWithIndent(triple[2], depth + 1);
                        },
                    }
                }
            }
        };
        F.printASTWithIndent(ast_node, 0);
    }
};
