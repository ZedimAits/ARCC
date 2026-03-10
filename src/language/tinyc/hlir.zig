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

const hlir = @import("../../intermediate/high/hlir.zig");
const HLNodeID = hlir.HLNodeID;
const lower_to_ml = hlir.lower_to_ml;
const type_interner = @import("../../intermediate/type_interner.zig");

const nodes = @import("../../intermediate/high/nodes.zig");

const ast = @import("ast.zig");
const ASTTree = ast.ASTTree;
const SpannedASTNode = ast.SpannedASTNode;

const mlir = @import("../../intermediate/medium/mlir.zig");
const MLGraph = mlir.MLGraph;
const MLNodeID = mlir.MLNodeID;
const MLValueID = mlir.MLValueID;
const MLNodes = @import("../../intermediate/medium/nodes.zig");

const HLNodeKind = enum {
    empty,
    let,
    assign,
    binary,
    block,
    if_,
    while_,
    do_while,
    expr_stmt,
    ident,
    literal,
};

const BinaryOp = enum {
    add,
    mul,
    lt,
};

fn convert_ASTBinaryOp_HLBinaryOp(ast_op: ast.BinaryOp) BinaryOp {
    return switch (ast_op) {
        .add => BinaryOp.add,
        .mul => BinaryOp.mul,
        .lt => BinaryOp.lt,
        else => unreachable,
    };
}

fn convert_HLBinaryOp_MLBinaryOp(hl_op: BinaryOp) MLNodes.BinaryOp {
    return switch (hl_op) {
        .add => MLNodes.BinaryOp.iadd,
        .mul => MLNodes.BinaryOp.imul,
        else => unreachable,
    };
}

fn convert_HLBinaryOp_MLCmpOp(hl_op: BinaryOp) MLNodes.CmpOp {
    return switch (hl_op) {
        .lt => MLNodes.CmpOp.ilt,
        else => unreachable,
    };
}

fn isComparisonOp(op: BinaryOp) bool {
    return switch (op) {
        .lt => true,
        else => false,
    };
}

pub const HLNode = union(HLNodeKind) {
    empty,
    let: nodes.Let,
    assign: nodes.Assign,
    binary: nodes.BinaryNode(BinaryOp),
    block: nodes.Block,
    if_: nodes.If,
    while_: nodes.While,
    do_while: nodes.DoWhile,
    expr_stmt: nodes.ExprStmt,
    ident: nodes.Identifier,
    literal: nodes.Literal,

    pub fn writeTo(self: @This(), tree: anytype, writer: *std.Io.Writer, indent: usize) anyerror!void {
        return self.writeToResolved(tree, writer, indent, .{});
    }

    pub fn writeToResolved(self: @This(), tree: anytype, writer: *std.Io.Writer, indent: usize, resolver: anytype) anyerror!void {
        switch (self) {
            .empty => {
                try writeIndent(writer, indent);
                try writer.print("empty\n", .{});
            },
            .let => |n| {
                try writeIndent(writer, indent);
                if (lookupSymbol(resolver, n.symbol)) |name| {
                    try writer.print("let(symbol={d}, name=\"{s}\")\n", .{ n.symbol.value, name });
                } else {
                    try writer.print("let(symbol={d})\n", .{n.symbol.value});
                }
                try tree.writeNodeRecursiveWith(writer, n.init, indent + 1, resolver);
            },
            .assign => |n| {
                try writeIndent(writer, indent);
                try writer.print("assign\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.target, indent + 1, resolver);
                try tree.writeNodeRecursiveWith(writer, n.value, indent + 1, resolver);
            },
            .binary => |n| {
                try writeIndent(writer, indent);
                try writer.print("binary\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.left, indent + 1, resolver);
                try tree.writeNodeRecursiveWith(writer, n.right, indent + 1, resolver);
            },
            .block => |n| {
                try writeIndent(writer, indent);
                try writer.print("block(count={d})\n", .{n.count});
                for (0..n.count) |i| {
                    const child_id = HLNodeID{
                        .value = n.start.value + @as(u32, @intCast(i)),
                    };
                    try tree.writeNodeRecursiveWith(writer, child_id, indent + 1, resolver);
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
            .ident => |n| {
                try writeIndent(writer, indent);
                if (lookupSymbol(resolver, n.symbol)) |name| {
                    try writer.print("ident(symbol={d}, name=\"{s}\")\n", .{ n.symbol.value, name });
                } else {
                    try writer.print("ident(symbol={d})\n", .{n.symbol.value});
                }
            },
            .literal => |n| {
                try writeIndent(writer, indent);
                if (lookupLiteral(resolver, n.literal)) |lit| {
                    try writer.print("literal(id={d}, value=", .{n.literal.value});
                    try writeLiteralValue(writer, lit);
                    try writer.print(")\n", .{});
                } else {
                    try writer.print("literal(id={d})\n", .{n.literal.value});
                }
            },
        }
    }

    fn writeIndent(writer: *std.Io.Writer, indent: usize) anyerror!void {
        for (0..indent) |_| {
            try writer.print("  ", .{});
        }
    }

    fn lookupSymbol(resolver: anytype, id: hlir.SymbolID) ?[]const u8 {
        if (!@hasDecl(@TypeOf(resolver), "lookupSymbol")) return null;
        return resolver.lookupSymbol(id);
    }

    fn lookupLiteral(resolver: anytype, id: front.LiteralID) ?front.Literal {
        if (!@hasDecl(@TypeOf(resolver), "lookupLiteral")) return null;
        return resolver.lookupLiteral(id);
    }

    fn writeLiteralValue(writer: *std.Io.Writer, lit: front.Literal) anyerror!void {
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

pub const HLTree = hlir.HLTree(HLNode);
const HLNodeMeta = HLTree.HLNodeMeta;

pub const HLPrintResolver = struct {
    ident_interner: *const front.IdentInterner,
    literal_interner: *const front.LiteralInterner,

    pub fn lookupSymbol(self: @This(), id: hlir.SymbolID) ?[]const u8 {
        return self.ident_interner.get(.{ .value = id.value });
    }

    pub fn lookupLiteral(self: @This(), id: front.LiteralID) ?front.Literal {
        return self.literal_interner.get(id);
    }
};

pub fn lowerASTtoHL(ast_tree: *const ASTTree) !HLTree {
    var tree = HLTree.init(ast_tree.gpa);
    errdefer tree.deinit();

    for (0..ast_tree.rootCount()) |i| {
        const root_id = ast_tree.getRoot(i);
        const hl_root = try lowerASTNode(ast_tree, ast_tree.get(root_id), &tree);
        try tree.addRoot(hl_root);
    }

    return tree;
}

pub fn lowerASTNode(ast_tree: *const ASTTree, node: *const SpannedASTNode, tree: *HLTree) !HLNodeID {
    switch (node.value) {
        .empty => return try tree.add(node.span, .{ .empty = {} }),
        .unary => return error.UnsupportedUnaryOperator,
        .binary => |binary| {
            const left = try lowerASTNode(ast_tree, ast_tree.get(binary.left), tree);
            const right = try lowerASTNode(ast_tree, ast_tree.get(binary.right), tree);
            return try tree.add(node.span, .{ .binary = .{
                .op = convert_ASTBinaryOp_HLBinaryOp(binary.op),
                .left = left,
                .right = right,
            } });
        },
        .block => |block| {
            if (block.count == 0) {
                return try tree.add(node.span, .{ .empty = {} });
            }

            var first: ?HLNodeID = null;
            for (0..block.count) |i| {
                const child_ast_id = front.NodeID{
                    .value = block.start.value + @as(u32, @intCast(i)),
                };
                const child = try lowerASTNode(ast_tree, ast_tree.get(child_ast_id), tree);
                if (first == null) first = child;
            }

            return try tree.add(node.span, .{ .block = .{
                .start = first.?,
                .count = block.count,
            } });
        },
        .if_ => |if_node| {
            const cond = try lowerASTNode(ast_tree, ast_tree.get(if_node.cond), tree);
            const then = try lowerASTNode(ast_tree, ast_tree.get(if_node.then), tree);
            const else_ = if (if_node.else_) |else_id|
                try lowerASTNode(ast_tree, ast_tree.get(else_id), tree)
            else
                null;
            return try tree.add(node.span, .{ .if_ = .{
                .cond = cond,
                .then = then,
                .else_ = else_,
            } });
        },
        .while_ => |while_node| {
            const cond = try lowerASTNode(ast_tree, ast_tree.get(while_node.cond), tree);
            const body = try lowerASTNode(ast_tree, ast_tree.get(while_node.body), tree);
            return try tree.add(node.span, .{ .while_ = .{ .cond = cond, .body = body } });
        },
        .do_while => |do_while_node| {
            const body = try lowerASTNode(ast_tree, ast_tree.get(do_while_node.body), tree);
            const cond = try lowerASTNode(ast_tree, ast_tree.get(do_while_node.cond), tree);
            return try tree.add(node.span, .{ .do_while = .{ .body = body, .cond = cond } });
        },
        .expr_stmt => |expr_stmt| {
            const expr = try lowerASTNode(ast_tree, ast_tree.get(expr_stmt.expr), tree);
            return try tree.add(node.span, .{ .expr_stmt = .{ .expr = expr } });
        },
        .assign => |assign| {
            const target = try lowerASTNode(ast_tree, ast_tree.get(assign.left), tree);
            const value = try lowerASTNode(ast_tree, ast_tree.get(assign.right), tree);
            return try tree.add(node.span, .{ .assign = .{ .target = target, .value = value } });
        },
        .ident => |ident| return try tree.add(node.span, .{ .ident = .{
            .symbol = .{ .value = ident.id.value },
        } }),
        .literal => |literal| return try tree.add(node.span, .{ .literal = .{
            .literal = literal.id,
        } }),
    }
}

pub fn lowerHLtoML(hl_tree: *const HLTree, builtins: type_interner.BuiltinTypes) !MLGraph {
    return lower_to_ml.lowerTreeToML(hl_tree, builtins, TinyCLowering{});
}

pub fn lowerHLNode(hl_tree: *const HLTree, node: *const HLNodeMeta, ml_graph: *MLGraph, builtins: type_interner.BuiltinTypes) !MLNodeID {
    return lower_to_ml.lowerNodeToML(hl_tree, node, ml_graph, builtins, TinyCLowering{});
}

const TinyCLowering = struct {
    pub fn lowerExpr(ctx: anytype, node: *const HLNodeMeta) anyerror!MLValueID {
        switch (node.data) {
            .literal => |lit| {
                const inst = try ctx.ml_graph.appendInst(ctx.current_block, node.span, .{
                    .const_ = .{ .lit = lit.literal, .type_ = ctx.ty_i64 },
                }, ctx.ty_i64);
                return try ctx.ml_graph.resultOf(inst);
            },
            .ident => |ident| {
                const addr = try ensureSymbolAddress(ctx, ident.symbol);
                const inst = try ctx.ml_graph.appendInst(ctx.current_block, node.span, .{
                    .load = .{ .addr = addr },
                }, ctx.ty_i64);
                return try ctx.ml_graph.resultOf(inst);
            },
            .binary => |binary| {
                const left = try lowerExpr(ctx, ctx.hl_tree.get(binary.left));
                const right = try lowerExpr(ctx, ctx.hl_tree.get(binary.right));
                const inst = if (isComparisonOp(binary.op))
                    try ctx.ml_graph.appendInst(ctx.current_block, node.span, .{
                        .cmp = .{ .op = convert_HLBinaryOp_MLCmpOp(binary.op), .left = left, .right = right },
                    }, ctx.ty_i1)
                else
                    try ctx.ml_graph.appendInst(ctx.current_block, node.span, .{
                        .binary = .{ .op = convert_HLBinaryOp_MLBinaryOp(binary.op), .left = left, .right = right },
                    }, ctx.ty_i64);
                return try ctx.ml_graph.resultOf(inst);
            },
            .assign => |assign| {
                const target = ctx.hl_tree.get(assign.target);
                const symbol = switch (target.data) {
                    .ident => |ident| ident.symbol,
                    else => return error.InvalidAssignmentTarget,
                };
                const addr = try ensureSymbolAddress(ctx, symbol);
                const stored = try lowerExpr(ctx, ctx.hl_tree.get(assign.value));
                _ = try ctx.ml_graph.appendInst(ctx.current_block, node.span, .{
                    .store = .{ .addr = addr, .value = stored },
                }, null);
                const load = try ctx.ml_graph.appendInst(ctx.current_block, node.span, .{
                    .load = .{ .addr = addr },
                }, ctx.ty_i64);
                return try ctx.ml_graph.resultOf(load);
            },
            else => return error.ExpectedExpression,
        }
    }

    pub fn ensureSymbolAddress(ctx: anytype, symbol: hlir.SymbolID) !MLValueID {
        return ctx.ml_graph.lookup_symbol(symbol) orelse try ctx.ml_graph.addSymbolValue(symbol, ctx.ty_ptr);
    }
};
