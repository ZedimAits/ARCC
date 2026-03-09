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

const core = @import("../front.zig");

pub fn TokenStream(comptime Lexer: type) type {
    const SpannedToken = Lexer.SpannedToken;
    const Token = @TypeOf((@as(SpannedToken, undefined)).value);

    return struct {
        const Self = @This();

        lexer: *Lexer,
        alloc: std.mem.Allocator,
        buf: std.ArrayList(SpannedToken),
        pos: usize = 0,

        pub fn init(alloc: std.mem.Allocator, lexer: *Lexer) Self {
            return .{
                .lexer = lexer,
                .alloc = alloc,
                .buf = std.ArrayList(SpannedToken).empty,
            };
        }

        pub fn deinit(self: *Self) void {
            self.buf.deinit(self.alloc);
        }

        fn fill(self: *Self, n: usize) void {
            while (self.buf.items.len <= n) {
                const next_token = self.lexer.next() catch {
                    const err_span: @TypeOf((@as(SpannedToken, undefined)).span) = if (self.lexer.last_error) |diag| diag.span else .{
                        .source_id = 0,
                        .start = 0,
                        .end = 0,
                        .line_start = 1,
                        .col_start = 1,
                        .line_end = 1,
                        .col_end = 1,
                    };
                    self.buf.append(self.alloc, .{
                        .span = err_span,
                        .value = .eof,
                    }) catch return;
                    return;
                };
                const t = next_token orelse SpannedToken{
                    .span = .{
                        .source_id = 0,
                        .start = 0,
                        .end = 0,
                        .line_start = 1,
                        .col_start = 1,
                        .line_end = 1,
                        .col_end = 1,
                    },
                    .value = .eof,
                };
                self.buf.append(self.alloc, t) catch unreachable;

                if (t.value == .eof) break;
            }
        }

        pub fn peek(self: *Self) SpannedToken {
            return self.peekN(0);
        }

        pub fn peekN(self: *Self, n: usize) SpannedToken {
            self.fill(self.pos + n);
            return self.buf.items[self.pos + n];
        }

        pub fn advance(self: *Self) SpannedToken {
            const t = self.peek();
            self.pos += 1;
            return t;
        }

        pub fn checkpoint(self: *const Self) usize {
            return self.pos;
        }

        pub fn restore(self: *Self, p: usize) void {
            self.pos = p;
        }

        pub fn speculate(self: *Self, f: fn (*Self) bool) bool {
            const cp = self.checkpoint();
            if (f(self)) return true;
            self.restore(cp);
            return false;
        }

        pub fn match(self: *Self, k: Token) bool {
            if (self.peek().value == k) {
                _ = self.advance();
                return true;
            }
            return false;
        }

        pub fn checkSymbol(self: *Self, s: anytype) bool {
            const t = self.peek().value;
            return switch (t) {
                .symbol => |x| x == s,
                else => false,
            };
        }

        pub fn matchSymbol(self: *Self, s: anytype) bool {
            if (self.checkSymbol(s)) {
                _ = self.advance();
                return true;
            }
            return false;
        }

        pub fn checkKeyword(self: *Self, k: anytype) bool {
            const t = self.peek().value;
            return switch (t) {
                .keyword => |x| x == k,
                else => false,
            };
        }

        pub fn matchKeyword(self: *Self, k: anytype) bool {
            if (self.checkKeyword(k)) {
                _ = self.advance();
                return true;
            }
            return false;
        }

        pub fn checkIdent(self: *Self) bool {
            const t = self.peek().value;
            return t == .identifier;
        }

        pub fn matchIdent(self: *Self) ?core.IdentifierID {
            const t = self.peek().value;
            return switch (t) {
                .identifier => |id| {
                    _ = self.advance();
                    return id;
                },
                else => null,
            };
        }

        pub fn checkLiteral(self: *Self) bool {
            const t = self.peek().value;
            return t == .literal;
        }

        pub fn matchLiteral(self: *Self) ?core.LiteralID {
            const t = self.peek().value;
            return switch (t) {
                .literal => |id| {
                    _ = self.advance();
                    return id;
                },
                else => null,
            };
        }
    };
}
