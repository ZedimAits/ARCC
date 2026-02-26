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
const nodes = core.nodes;

const ASTNodeKind = enum {
    empty,
    unary,
    binary,
    block,
    if_,
    while_,
    do_while,
    expr_stmt,
    assign,
    ident,
    literal,
};

pub const ASTNode = union(ASTNodeKind) {
    empty,
    unary: nodes.UnaryNode(UnaryOp),
    binary: nodes.BinaryNode(BinaryOp),
    block: nodes.Block,
    if_: nodes.If,
    while_: nodes.While,
    do_while: nodes.DoWhile,
    expr_stmt: nodes.ExprStmt,
    assign: nodes.Assign,
    ident: nodes.Identifier,
    literal: nodes.Literal,

    pub fn writeTo(self: @This(), tree: anytype, writer: *std.Io.Writer, indent: usize) anyerror!void {
        return self.writeToResolved(tree, writer, indent, .{});
    }

    pub fn writeToResolved(self: @This(), tree: anytype, writer: *std.Io.Writer, indent: usize, resolver: anytype) anyerror!void {
        const NodeID = core.NodeID;

        switch (self) {
            .empty => {
                try writeIndent(writer, indent);
                try writer.print("empty\n", .{});
            },
            .unary => |n| {
                try writeIndent(writer, indent);
                try writer.print("unary(op={s})\n", .{@tagName(n.op)});
                try tree.writeNodeRecursiveWith(writer, n.expr, indent + 1, resolver);
            },
            .binary => |n| {
                try writeIndent(writer, indent);
                try writer.print("binary(op={s})\n", .{@tagName(n.op)});
                try tree.writeNodeRecursiveWith(writer, n.left, indent + 1, resolver);
                try tree.writeNodeRecursiveWith(writer, n.right, indent + 1, resolver);
            },
            .block => |n| {
                try writeIndent(writer, indent);
                try writer.print("block(count={d})\n", .{n.count});
                for (0..n.count) |i| {
                    const child_id: u32 = n.start.value + @as(u32, @intCast(i));
                    try tree.writeNodeRecursiveWith(writer, NodeID{ .value = child_id }, indent + 1, resolver);
                }
            },
            .if_ => |n| {
                try writeIndent(writer, indent);
                try writer.print("if\n", .{});
                try writeIndent(writer, indent + 1);
                try writer.print("cond:\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.cond, indent + 2, resolver);
                try writeIndent(writer, indent + 1);
                try writer.print("then:\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.then, indent + 2, resolver);
                if (n.else_) |e| {
                    try writeIndent(writer, indent + 1);
                    try writer.print("else:\n", .{});
                    try tree.writeNodeRecursiveWith(writer, e, indent + 2, resolver);
                }
            },
            .while_ => |n| {
                try writeIndent(writer, indent);
                try writer.print("while\n", .{});
                try writeIndent(writer, indent + 1);
                try writer.print("cond:\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.cond, indent + 2, resolver);
                try writeIndent(writer, indent + 1);
                try writer.print("body:\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.body, indent + 2, resolver);
            },
            .do_while => |n| {
                try writeIndent(writer, indent);
                try writer.print("do_while\n", .{});
                try writeIndent(writer, indent + 1);
                try writer.print("body:\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.body, indent + 2, resolver);
                try writeIndent(writer, indent + 1);
                try writer.print("cond:\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.cond, indent + 2, resolver);
            },
            .expr_stmt => |n| {
                try writeIndent(writer, indent);
                try writer.print("expr_stmt\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.expr, indent + 1, resolver);
            },
            .assign => |n| {
                try writeIndent(writer, indent);
                try writer.print("assign\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.left, indent + 1, resolver);
                try tree.writeNodeRecursiveWith(writer, n.right, indent + 1, resolver);
            },
            .ident => |n| {
                try writeIndent(writer, indent);
                if (lookupIdentifier(resolver, n.id)) |name| {
                    try writer.print("ident(id={d}, name=\"{s}\")\n", .{ n.id.value, name });
                } else {
                    try writer.print("ident(id={d})\n", .{n.id.value});
                }
            },
            .literal => |n| {
                try writeIndent(writer, indent);
                if (lookupLiteral(resolver, n.id)) |lit| {
                    try writer.print("literal(id={d}, value=", .{n.id.value});
                    try writeLiteralValue(writer, lit);
                    try writer.print(")\n", .{});
                } else {
                    try writer.print("literal(id={d})\n", .{n.id.value});
                }
            },
        }
    }

    fn writeIndent(writer: *std.Io.Writer, indent: usize) anyerror!void {
        for (0..indent) |_| {
            try writer.print("  ", .{});
        }
    }

    fn lookupIdentifier(resolver: anytype, id: core.IdentifierID) ?[]const u8 {
        if (!@hasDecl(@TypeOf(resolver), "lookupIdentifier")) return null;
        return resolver.lookupIdentifier(id);
    }

    fn lookupLiteral(resolver: anytype, id: core.LiteralID) ?core.Literal {
        if (!@hasDecl(@TypeOf(resolver), "lookupLiteral")) return null;
        return resolver.lookupLiteral(id);
    }

    fn writeLiteralValue(writer: *std.Io.Writer, lit: core.Literal) anyerror!void {
        switch (lit) {
            .int => |v| try writer.print("int({d})", .{v.value}),
            .float => |v| try writer.print("float({d})", .{v.value}),
            .bool => |v| try writer.print("bool({any})", .{v}),
            .string => |v| try writer.print("string(\"{s}\")", .{v}),
            .char => |v| try writer.print("char({d})", .{v}),
            .null => try writer.print("null", .{}),
        }
    }
};

pub const BinaryOp = enum {
    add,
    sub,
    mul,
    div,
    eq,
    ne,
    lt,
    le,
    gt,
    ge,
    //and_and, or_or,
    //bit_and, bit_or, bit_xor,
    //shl, shr,
};

pub const UnaryOp = enum {
    neg, // -x
    not, // !x
    //bit_not,  // ~x
    //addr,     // &x
    //deref,    // *x
};

pub const SpannedASTNode = core.Spanned(ASTNode);
pub const ASTTree: type = core.ASTTree(SpannedASTNode);