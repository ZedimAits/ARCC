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

const nodes = @import("../../intermediate/high/nodes.zig");

const ast = @import("ast.zig");
const ASTTree = ast.ASTTree;
const SpannedASTNode = ast.SpannedASTNode;

const MLGraph = @import("../../intermediate/medium/mlir.zig").MLGraph;
const MLNode = @import("../../intermediate/medium/mlir.zig").MLNode;
const MLNodeID = @import("../../intermediate/medium/mlir.zig").MLNodeID;
const MLNodeData = @import("../../intermediate/medium/mlir.zig").MLNodeData;
const MLValueID = @import("../../intermediate/medium/mlir.zig").MLValueID;
const MLValue = @import("../../intermediate/medium/mlir.zig").MLValue;
const MLNodes = @import("../../intermediate/medium/nodes.zig");

const HLNodeKind = enum {
    empty,
    let,
    assign,
    unary,
    binary,
    block,
    if_,
    while_,
    do_while,
    expr_stmt,
    ident,
    literal,
};

pub const HLNode = union(HLNodeKind) {
    empty,
    let: nodes.Let,
    assign: nodes.Assign,
    unary: nodes.Unary,
    binary: nodes.Binary,
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
            .unary => |n| {
                try writeIndent(writer, indent);
                try writer.print("unary\n", .{});
                try tree.writeNodeRecursiveWith(writer, n.expr, indent + 1, resolver);
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
    return switch (node.value) {
        .empty => try tree.add(node.span, .{ .empty = {} }),
        .unary => |unary| blk: {
            const expr = try lowerASTNode(ast_tree, ast_tree.get(unary.expr), tree);
            break :blk try tree.add(node.span, .{ .unary = .{ .expr = expr } });
        },
        .binary => |binary| blk: {
            const left = try lowerASTNode(ast_tree, ast_tree.get(binary.left), tree);
            const right = try lowerASTNode(ast_tree, ast_tree.get(binary.right), tree);
            break :blk try tree.add(node.span, .{ .binary = .{ .left = left, .right = right } });
        },
        .block => |block| blk: {
            if (block.count == 0) {
                break :blk try tree.add(node.span, .{ .empty = {} });
            }

            var first: ?HLNodeID = null;
            for (0..block.count) |i| {
                const child_ast_id = front.NodeID{
                    .value = block.start.value + @as(u32, @intCast(i)),
                };
                const child = try lowerASTNode(ast_tree, ast_tree.get(child_ast_id), tree);
                if (first == null) first = child;
            }

            break :blk try tree.add(node.span, .{ .block = .{
                .start = first.?,
                .count = block.count,
            } });
        },
        .if_ => |if_node| blk: {
            const cond = try lowerASTNode(ast_tree, ast_tree.get(if_node.cond), tree);
            const then = try lowerASTNode(ast_tree, ast_tree.get(if_node.then), tree);
            const else_ = if (if_node.else_) |else_id|
                try lowerASTNode(ast_tree, ast_tree.get(else_id), tree)
            else
                null;
            break :blk try tree.add(node.span, .{ .if_ = .{
                .cond = cond,
                .then = then,
                .else_ = else_,
            } });
        },
        .while_ => |while_node| blk: {
            const cond = try lowerASTNode(ast_tree, ast_tree.get(while_node.cond), tree);
            const body = try lowerASTNode(ast_tree, ast_tree.get(while_node.body), tree);
            break :blk try tree.add(node.span, .{ .while_ = .{ .cond = cond, .body = body } });
        },
        .do_while => |do_while_node| blk: {
            const body = try lowerASTNode(ast_tree, ast_tree.get(do_while_node.body), tree);
            const cond = try lowerASTNode(ast_tree, ast_tree.get(do_while_node.cond), tree);
            break :blk try tree.add(node.span, .{ .do_while = .{ .body = body, .cond = cond } });
        },
        .expr_stmt => |expr_stmt| blk: {
            const expr = try lowerASTNode(ast_tree, ast_tree.get(expr_stmt.expr), tree);
            break :blk try tree.add(node.span, .{ .expr_stmt = .{ .expr = expr } });
        },
        .assign => |assign| blk: {
            const target = try lowerASTNode(ast_tree, ast_tree.get(assign.left), tree);
            const value = try lowerASTNode(ast_tree, ast_tree.get(assign.right), tree);
            break :blk try tree.add(node.span, .{ .assign = .{ .target = target, .value = value } });
        },
        .ident => |ident| try tree.add(node.span, .{ .ident = .{
            .symbol = .{ .value = ident.id.value },
        } }),
        .literal => |literal| try tree.add(node.span, .{ .literal = .{
            .literal = literal.id,
        } }),
    };
}

pub fn lowerHLtoML(hl_tree: *const HLTree) !MLGraph {
    var graph = MLGraph.init(hl_tree.gpa);

    const items = hl_tree.roots.items;
    for (items) |root_id| {
        const node = hl_tree.get(root_id);
        const hl_root = try lowerHLNode(hl_tree, node, &graph);
        _ = hl_root;
    }

    return graph;
}

//TODO:
//- SymbolIDs -> ValueID in ml_graph einfügen
pub fn lowerHLNode(hl_tree: *const HLTree, node: *const HLNodeMeta, ml_graph: *MLGraph) !MLNodeID {
    switch (node.data) {
        // .let => |_| {
        // const let: nodes.Let = let_switch;
        // const symbol = let.symbol;
        // const init = hl_tree.get(let.init);

        // gleich wie bei assign??? TODO
        // },
        .assign => |assign_switch| {
            const assign: nodes.Assign = assign_switch;
            const left = hl_tree.get(assign.target);
            const right = hl_tree.get(assign.value);

            const left_symbol = switch (left.data) {
                .ident => |ident| ident.symbol,
                else => return error.InvalidAssignmentTarget,
            };
            const left_value = ml_graph.lookup_symbol(left_symbol) orelse error.SymbolNotFound;

            const right_node = try lowerHLNode(hl_tree, right, ml_graph);
            const right_value = ml_graph.get(right_node).value;

            const assign_node = try ml_graph.add(node.span, .{ .store = .{ .addr = left_value, .value = right_value } });

            ml_graph.connect(right_node, assign_node);

            return assign_node;
        },
        .unary => |unary_switch| {
            const unary: nodes.Unary = unary_switch;
            const expr_hl = hl_tree.get(unary.expr);

            const expr_node = try lowerHLNode(hl_tree, expr_hl, ml_graph);

            const unary_op: MLNodes.UnaryOp = .ineg;

            const unary_data: MLNodeData = .{ .unary = .{ .op = unary_op, .value = ml_graph.get(expr_node).value } };

            const unary_node = try ml_graph.add(node.span, unary_data);

            ml_graph.connect(expr_node, unary_node);

            return unary_node;
        },
        .binary => |binary_switch| {
            const binary: nodes.Binary = binary_switch;

            //TODO: Add binaryOP to HLIR

            const right = try lowerHLNode(hl_tree, hl_tree.get(binary.right), ml_graph);
            //TODO: connect right and left
            const left = try lowerHLNode(hl_tree, hl_tree.get(binary.left), ml_graph);

            const binary_data: MLNodeData = .{ .binary = .{ .op = .iadd, .left = ml_graph.get(left).value, .right = ml_graph.get(right).value } };
            const binary_node = try ml_graph.add(node.span, binary_data);
            ml_graph.connect(left, binary_node);

            return binary_node;
        },
        //block: nodes.Block, //TODO
        .if_ => |if_switch| {
            const if_: nodes.If = if_switch;
            const cond_hl = hl_tree.get(if_.cond);

            const cond_node = try lowerHLNode(hl_tree, cond_hl, ml_graph);
        },
        //while_: nodes.While,
        //do_while: nodes.DoWhile,
        //expr_stmt: nodes.ExprStmt,
        //ident: nodes.Identifier,
        //literal: nodes.Literal,
        //empty,
        else => return error.UnimplementedHLNode,
    }
}
