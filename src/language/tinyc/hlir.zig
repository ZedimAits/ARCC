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

const front = @import("../../frontend/front.zig");

const hlir = @import("../../intermediate/high/hlir.zig");
const HLNodeID = hlir.HLNodeID;

const nodes = @import("../../intermediate/high/nodes.zig");

const ast = @import("ast.zig");
const ASTTree = ast.ASTTree;
const SpannedASTNode = ast.SpannedASTNode;

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
};

pub const HLTree = hlir.HLTree(HLNode);

pub fn lowerASTtoHL(ast_tree: *const ASTTree) !HLTree {
    var tree = HLTree.init(ast_tree.gpa);
    errdefer tree.deinit();

    for (0..ast_tree.rootCount()) |i| {
        const root_id = ast_tree.getRoot(i);
        _ = try lowerNode(ast_tree, ast_tree.get(root_id), &tree);
    }

    return tree;
}

pub fn lowerNode(ast_tree: *const ASTTree, node: *const SpannedASTNode, tree: *HLTree) !HLNodeID {
    return switch (node.value) {
        .empty => try tree.add(node.span, .{ .empty = {} }),
        .unary => |unary| blk: {
            const expr = try lowerNode(ast_tree, ast_tree.get(unary.expr), tree);
            break :blk try tree.add(node.span, .{ .unary = .{ .expr = expr } });
        },
        .binary => |binary| blk: {
            const left = try lowerNode(ast_tree, ast_tree.get(binary.left), tree);
            const right = try lowerNode(ast_tree, ast_tree.get(binary.right), tree);
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
                const child = try lowerNode(ast_tree, ast_tree.get(child_ast_id), tree);
                if (first == null) first = child;
            }

            break :blk try tree.add(node.span, .{ .block = .{
                .start = first.?,
                .count = block.count,
            } });
        },
        .if_ => |if_node| blk: {
            const cond = try lowerNode(ast_tree, ast_tree.get(if_node.cond), tree);
            const then = try lowerNode(ast_tree, ast_tree.get(if_node.then), tree);
            const else_ = if (if_node.else_) |else_id|
                try lowerNode(ast_tree, ast_tree.get(else_id), tree)
            else
                null;
            break :blk try tree.add(node.span, .{ .if_ = .{
                .cond = cond,
                .then = then,
                .else_ = else_,
            } });
        },
        .while_ => |while_node| blk: {
            const cond = try lowerNode(ast_tree, ast_tree.get(while_node.cond), tree);
            const body = try lowerNode(ast_tree, ast_tree.get(while_node.body), tree);
            break :blk try tree.add(node.span, .{ .while_ = .{ .cond = cond, .body = body } });
        },
        .do_while => |do_while_node| blk: {
            const body = try lowerNode(ast_tree, ast_tree.get(do_while_node.body), tree);
            const cond = try lowerNode(ast_tree, ast_tree.get(do_while_node.cond), tree);
            break :blk try tree.add(node.span, .{ .do_while = .{ .body = body, .cond = cond } });
        },
        .expr_stmt => |expr_stmt| blk: {
            const expr = try lowerNode(ast_tree, ast_tree.get(expr_stmt.expr), tree);
            break :blk try tree.add(node.span, .{ .expr_stmt = .{ .expr = expr } });
        },
        .assign => |assign| blk: {
            const target = try lowerNode(ast_tree, ast_tree.get(assign.left), tree);
            const value = try lowerNode(ast_tree, ast_tree.get(assign.right), tree);
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
