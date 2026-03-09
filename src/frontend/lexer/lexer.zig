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

const spec = @import("spec.zig");
const span = @import("../span.zig");

const helper = @import("../../utils/helper.zig");

const IdentInterner = @import("../intern/ident_interner.zig").IdentInterner;
const LiteralInterner = @import("../intern/literal_interner.zig").LiteralInterner;

pub const LexerError = error{
    InvalidCharacter,
    UnterminatedLiteral,
} || std.mem.Allocator.Error;

pub fn Lexer(comptime Lexicon: type) type {
    comptime {
        spec.validate(Lexicon);
    }

    const keyword_map = helper.initStaticStringMap(Lexicon.Keyword, Lexicon.keywords);

    return struct {
        const Self = @This();

        pub const SpannedToken = span.Spanned(Lexicon.Token);

        allocator: std.mem.Allocator,
        input: []const u8,
        source_id: u32 = 0,
        identInterner: *IdentInterner,
        literalInterner: *LiteralInterner,

        pos: usize = 0,
        last_error: ?struct { span: span.Span, message: []const u8 } = null,

        pub fn init(allocator: std.mem.Allocator, input: []const u8, identInterner: *IdentInterner, literalInterner: *LiteralInterner) Self {
            return .{
                .allocator = allocator,
                .input = input,
                .identInterner = identInterner,
                .literalInterner = literalInterner,
            };
        }

        pub fn initWithSourceId(allocator: std.mem.Allocator, input: []const u8, source_id: u32, identInterner: *IdentInterner, literalInterner: *LiteralInterner) Self {
            var self = init(allocator, input, identInterner, literalInterner);
            self.source_id = source_id;
            return self;
        }

        pub fn printLastError(self: *const Self) void {
            const diag = self.last_error orelse return;
            const line_text = lineTextAt(self.input, diag.span.start);

            std.debug.print("Lexer error [src={d}] at {d}:{d}..{d}:{d} (bytes {d}..{d}): {s}\n", .{
                diag.span.source_id,
                diag.span.line_start,
                diag.span.col_start,
                diag.span.line_end,
                diag.span.col_end,
                diag.span.start,
                diag.span.end,
                diag.message,
            });
            std.debug.print("{s}\n", .{line_text});
            for (1..diag.span.col_start) |_| {
                std.debug.print(" ", .{});
            }
            const width = caretWidth(diag.span);
            for (0..width) |_| {
                std.debug.print("^", .{});
            }
            std.debug.print("\n", .{});
        }

        pub fn next(self: *Self) !?SpannedToken {
            self.skipWhitespaceAndComments();

            if (self.reached_eof()) return null;

            const start = self.pos;

            if (try self.matchSymbol(start)) |tok| return tok;
            if (try self.matchIdentifierOrKeyword(start)) |tok| return tok;
            if (try self.matchLiteral(start)) |tok| return tok;

            self.last_error = .{
                .span = self.makeSpan(start, self.pos + 1),
                .message = "invalid character",
            };
            return LexerError.InvalidCharacter;
        }

        fn advance(self: *Self, n: usize) void {
            self.pos += n;
        }

        fn reached_eof(self: *Self) bool {
            return self.pos >= self.input.len;
        }

        fn skipWhitespaceAndComments(self: *Self) void {
            while (true) {
                if (self.reached_eof()) break;
                const c = self.input[self.pos];
                if (Lexicon.isWhitespace(c)) {
                    self.pos += 1;
                    continue;
                }

                if (@hasDecl(Lexicon, "comment")) {
                    if (Lexicon.comment.line) |line_prefix| {
                        if (self.startsWith(line_prefix)) {
                            self.advance(line_prefix.len);
                            while (!self.reached_eof()) : (self.pos += 1) {
                                const cc = self.input[self.pos];
                                if (cc == '\n' or cc == '\r') break;
                            }
                            continue;
                        }
                    }
                }

                break;
            }
        }

        fn matchSymbol(self: *Self, start_pos: usize) !?SpannedToken {
            if (self.reached_eof()) return null;

            const remaining = self.input.len - self.pos;
            var best_len: usize = 0;
            var best_sym: ?Lexicon.Symbol = null;

            for (Lexicon.symbols) |entry| {
                const text = entry.text;
                if (text.len == 0) continue;
                if (text.len > remaining) continue;
                if (text.len < best_len) continue;
                if (self.startsWith(text)) {
                    best_len = text.len;
                    best_sym = entry.tag;
                }
            }

            if (best_sym) |sym| {
                self.advance(best_len);
                return self.makeToken(start_pos, self.pos, Lexicon.Token{ .symbol = sym });
            }
            return null;
        }

        fn matchIdentifierOrKeyword(self: *Self, start_pos: usize) !?SpannedToken {
            if (self.reached_eof()) return null;
            const c = self.input[self.pos];
            if (!Lexicon.isIdentStart(c)) return null;

            const start = self.pos;
            self.pos += 1;
            while (!self.reached_eof()) {
                const cc = self.input[self.pos];
                if (!Lexicon.isIdentContinue(cc)) break;
                self.pos += 1;
            }
            const word = self.input[start..self.pos];

            if (keyword_map.get(word)) |kw| {
                return self.makeToken(start_pos, self.pos, Lexicon.Token{ .keyword = kw });
            }
            const id = try self.identInterner.intern(word);
            return self.makeToken(start_pos, self.pos, Lexicon.Token{ .identifier = id });
        }

        fn matchLiteral(self: *Self, start_pos: usize) !?SpannedToken {
            var best_rule_index: ?usize = null;
            var best_prefix_len: usize = 0;

            for (Lexicon.literals, 0..) |lit, i| {
                const starts = switch (lit.start) {
                    .any_of => |s| s,
                };
                for (starts) |pref| {
                    if (pref.len == 0) continue;
                    if (pref.len < best_prefix_len) continue;
                    if (self.startsWith(pref)) {
                        best_prefix_len = pref.len;
                        best_rule_index = i;
                    }
                }
            }

            // Handle empty-prefix number rules last so they don't shadow everything.
            if (best_rule_index == null) {
                for (Lexicon.literals, 0..) |lit, i| {
                    const starts = switch (lit.start) {
                        .any_of => |s| s,
                    };
                    for (starts) |pref| {
                        if (pref.len != 0) continue;
                        best_rule_index = i;
                        best_prefix_len = 0;
                        break;
                    }
                    if (best_rule_index != null) break;
                }
            }

            const rule_index = best_rule_index orelse return null;
            const rule = Lexicon.literals[rule_index];

            const lit = switch (rule.body) {
                .number => |num| (try self.parseNumberLiteral(start_pos, best_prefix_len, num)) orelse return null,
                .exact => try self.parseExactLiteral(start_pos, best_prefix_len, rule.kind),
                .delimited => |delim| (try self.parseDelimitedLiteral(start_pos, best_prefix_len, delim, rule.kind)) orelse return null,
            };

            const literal_id = try self.literalInterner.intern(lit);
            return self.makeToken(start_pos, self.pos, Lexicon.Token{ .literal = literal_id });
        }

        fn parseNumberLiteral(self: *Self, start_pos: usize, prefix_len: usize, num: core.NumberSpec) !?core.Literal {
            if (prefix_len == 0) {
                if (self.reached_eof() or !helper.isDigitBase(self.input[self.pos], num.base)) {
                    self.pos = start_pos;
                    return null;
                }
            }

            self.advance(prefix_len);
            var seen_digit = false;
            while (!self.reached_eof()) {
                const c = self.input[self.pos];
                if (num.digit_sep) |sep| {
                    if (c == sep) {
                        self.pos += 1;
                        continue;
                    }
                }
                if (helper.isDigitBase(c, num.base)) {
                    seen_digit = true;
                    self.pos += 1;
                    continue;
                }
                break;
            }
            if (!seen_digit) {
                self.pos = start_pos;
                return null;
            }

            const lexeme = self.input[start_pos..self.pos];
            return switch (try self.literalFromLexeme(core.LiteralTag.int, lexeme)) {
                .int => |v| .{ .int = v },
                else => return LexerError.InvalidCharacter,
            };
        }

        fn parseExactLiteral(self: *Self, start_pos: usize, prefix_len: usize, kind: core.LiteralTag) !core.Literal {
            const lexeme = self.input[start_pos .. start_pos + prefix_len];
            self.pos = start_pos + prefix_len;
            return self.literalFromLexeme(kind, lexeme);
        }

        fn parseDelimitedLiteral(self: *Self, start_pos: usize, prefix_len: usize, delim: core.DelimitedSpec, kind: core.LiteralTag) !?core.Literal {
            if (prefix_len == 0) return null;

            self.advance(prefix_len);
            const end_seq = switch (delim.end) {
                .same_as_start => self.input[start_pos .. start_pos + prefix_len],
                .fixed => |f| f,
            };

            while (!self.reached_eof()) {
                const c = self.input[self.pos];

                if (delim.escape == .backslash and c == '\\') {
                    self.pos += 1;
                    if (!self.reached_eof()) self.pos += 1;
                    continue;
                }

                if (delim.escape == .doubled_end and end_seq.len == 1 and c == end_seq[0]) {
                    if (self.pos + 1 < self.input.len and self.input[self.pos + 1] == end_seq[0]) {
                        self.pos += 2;
                        continue;
                    }
                }

                if (self.startsWith(end_seq)) {
                    self.pos += end_seq.len;
                    const lexeme = self.input[start_pos..self.pos];
                    return try self.literalFromLexeme(kind, lexeme);
                }

                self.pos += 1;
            }

            self.last_error = .{
                .span = self.makeSpan(start_pos, self.pos),
                .message = "unterminated literal",
            };
            return LexerError.UnterminatedLiteral;
        }

        fn makeToken(self: *Self, start: usize, end: usize, value: Lexicon.Token) SpannedToken {
            return SpannedToken.initWithSpan(self.makeSpan(start, end), value);
        }

        fn makeSpan(self: *Self, start: usize, end: usize) span.Span {
            const start_loc = self.lineColAt(start);
            const end_loc = self.lineColAt(end);
            return .{
                .source_id = self.source_id,
                .start = start,
                .end = end,
                .line_start = start_loc.line,
                .col_start = start_loc.col,
                .line_end = end_loc.line,
                .col_end = end_loc.col,
            };
        }

        fn lineColAt(self: *Self, pos: usize) struct { line: usize, col: usize } {
            const p = @min(pos, self.input.len);
            var line: usize = 1;
            var col: usize = 1;
            var i: usize = 0;
            while (i < p) : (i += 1) {
                if (self.input[i] == '\n') {
                    line += 1;
                    col = 1;
                } else {
                    col += 1;
                }
            }
            return .{ .line = line, .col = col };
        }

        fn literalFromLexeme(self: *Self, kind: core.LiteralTag, lexeme: []const u8) !core.Literal {
            _ = self;
            return switch (kind) {
                .int => {
                    const value = try parseIntLexeme(lexeme);
                    return .{ .int = .{
                        .signed = false,
                        .bits = 64,
                        .value = value,
                    } };
                },
                .bool => .{ .bool = std.mem.eql(u8, lexeme, "true") },
                .string => {
                    if (lexeme.len < 2) return LexerError.InvalidCharacter;
                    return .{ .string = lexeme[1 .. lexeme.len - 1] };
                },
                .char => {
                    const c = try parseCharLexeme(lexeme);
                    return .{ .char = c };
                },
                .null => .null,
                .float => return LexerError.InvalidCharacter,
            };
        }

        fn parseIntLexeme(lexeme: []const u8) !u128 {
            var base: u8 = 10;
            var digits = lexeme;
            if (std.mem.startsWith(u8, lexeme, "0x") or std.mem.startsWith(u8, lexeme, "0X")) {
                base = 16;
                digits = lexeme[2..];
            } else if (std.mem.startsWith(u8, lexeme, "0b") or std.mem.startsWith(u8, lexeme, "0B")) {
                base = 2;
                digits = lexeme[2..];
            }
            return std.fmt.parseInt(u128, digits, base) catch LexerError.InvalidCharacter;
        }

        fn parseCharLexeme(lexeme: []const u8) !u32 {
            if (lexeme.len < 3) return LexerError.InvalidCharacter;
            if (lexeme[1] == '\\') {
                if (lexeme.len < 4) return LexerError.InvalidCharacter;
                return switch (lexeme[2]) {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    '\\' => '\\',
                    '\'' => '\'',
                    '"' => '"',
                    else => lexeme[2],
                };
            }
            return lexeme[1];
        }

        fn startsWith(self: *Self, needle: []const u8) bool {
            if (needle.len == 0) return true;
            if (self.pos + needle.len > self.input.len) return false;
            return std.mem.eql(u8, self.input[self.pos .. self.pos + needle.len], needle);
        }

        fn lineTextAt(input: []const u8, pos: usize) []const u8 {
            const p = @min(pos, input.len);
            var line_start: usize = 0;
            var i: usize = 0;
            while (i < p) : (i += 1) {
                if (input[i] == '\n') {
                    line_start = i + 1;
                }
            }

            var line_end = line_start;
            while (line_end < input.len and input[line_end] != '\n' and input[line_end] != '\r') : (line_end += 1) {}
            return input[line_start..line_end];
        }

        fn caretWidth(err_span: span.Span) usize {
            if (err_span.line_start != err_span.line_end) return 1;
            if (err_span.col_end <= err_span.col_start) return 1;
            return err_span.col_end - err_span.col_start;
        }
    };
}
