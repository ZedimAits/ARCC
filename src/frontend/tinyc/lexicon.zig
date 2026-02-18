const std = @import("std");
const core = @import("../core/core.zig");
const Interner = @import("../core/interner.zig").Interner;

pub const Lexicon = struct {

    // ############################## TOKEN ##############################

    pub const Token = union(enum) {
        symbol: Symbol,
        keyword: Keyword,
        literal: core.LiteralID,
        identifier: core.IdentifierID,
        eof,
    };

    // ############################## KEYWORD ##############################

    pub const Keyword = enum {
        do_,
        while_,
        if_,
        else_,

        fn text(self: Keyword) []const u8 {
            for (keywords) |k| {
                if (k.tag == self) return k.text;
            }
            unreachable;
        }
    };

    pub const keywords = [_]struct {
        text: []const u8,
        tag: Keyword,
    }{
        .{ .text = "do", .tag = .do_ },
        .{ .text = "while", .tag = .while_ },
        .{ .text = "if", .tag = .if_ },
        .{ .text = "else", .tag = .else_ },
    };

    // ############################## SYMBOL ##############################
    pub const Symbol = enum {
        l_brace,
        r_brace,
        l_paren,
        r_paren,
        plus,
        minus,
        less_than,
        semicolon,
        equal,

        fn text(self: Symbol) []const u8 {
            for (symbols) |s| {
                if (s.tag == self) return s.text;
            }
            unreachable;
        }
    };

    pub const symbols = [_]struct {
        text: []const u8,
        tag: Symbol,
    }{
        .{ .text = "{", .tag = .l_brace },
        .{ .text = "}", .tag = .r_brace },
        .{ .text = "(", .tag = .l_paren },
        .{ .text = ")", .tag = .r_paren },
        .{ .text = "+", .tag = .plus },
        .{ .text = "-", .tag = .minus },
        .{ .text = "<", .tag = .less_than },
        .{ .text = ";", .tag = .semicolon },
        .{ .text = "=", .tag = .equal },
    };

    pub fn isIdentStart(c: u8) bool {
        return std.ascii.isAlphabetic(c) or c == '_';
    }

    pub fn isIdentContinue(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_';
    }

    pub fn isWhitespace(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\n', '\r' => true,
            else => false,
        };
    }

    // ############################## COMMENT ##############################
    pub const comment = core.CommentSpec{
        .line = "//",
    };

    // ############################## LITERAL ##############################
    pub const LiteralForm = enum {
        dec_int,
        hex_int,
        bin_int,
        float,
        string,
        raw_string,
        char,
        bool,
        null,
    };

    pub const literals = [_]core.L(core.Literal){
        .{
            .text = "bool",
            .kind = .bool,
            .start = .{ .any_of = &.{ "true", "false" } },
            .body = .{ .exact = {} },
        },

        .{
            .text = "decimal integer",
            .kind = .int,
            .body = .{
                .number = .{ .base = 10 },
            },
        },

        .{
            .text = "hex integer",
            .kind = .int,
            .start = .{ .any_of = &.{ "0x", "0X" } },
            .body = .{
                .number = .{ .base = 16 },
            },
        },

        .{
            .text = "binary integer",
            .kind = .int,
            .start = .{ .any_of = &.{ "0b", "0B" } },
            .body = .{
                .number = .{ .base = 2 },
            },
        },

        .{
            .text = "string",
            .kind = .string,
            .start = .{ .any_of = &.{"\""} },
            .body = .{
                .delimited = .{
                    .end = .same_as_start,
                    .escape = .backslash,
                },
            },
        },

        .{
            .text = "char",
            .kind = .char,
            .start = .{ .any_of = &.{"'"} },
            .body = .{
                .delimited = .{
                    .end = .same_as_start,
                    .escape = .backslash,
                },
            },
        },
    };
};
