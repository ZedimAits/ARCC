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
const hlir = @import("hlir.zig");
const mlir = @import("../medium/mlir.zig");
const type_interner = @import("../type_interner.zig");

const Span = front.Span;
const HLNodeID = hlir.HLNodeID;
const SymbolID = hlir.SymbolID;
const MLGraph = mlir.MLGraph;
const MLNodeID = mlir.MLNodeID;
const MLValueID = mlir.MLValueID;
const MLTypeID = mlir.MLTypeID;
const MLBlockID = mlir.MLBlockID;
const MLRegionID = mlir.MLRegionID;

pub fn lowerTreeToML(hl_tree: anytype, builtins: type_interner.BuiltinTypes, adapter: anytype) !MLGraph {
    var graph = MLGraph.init(hl_tree.gpa);
    errdefer graph.deinit();

    var ctx = LowerCtx(@TypeOf(hl_tree.*), @TypeOf(adapter)).init(hl_tree, &graph, builtins, adapter);
    try ctx.initEntry();

    for (hl_tree.roots.items) |root_id| {
        try ctx.lowerStmt(hl_tree.get(root_id));
    }

    _ = try graph.appendInst(ctx.current_block, syntheticSpan(), .{ .ret = .{ .value = null } }, null);
    return graph;
}

pub fn lowerNodeToML(hl_tree: anytype, node: anytype, ml_graph: *MLGraph, builtins: type_interner.BuiltinTypes, adapter: anytype) !MLNodeID {
    var ctx = LowerCtx(@TypeOf(hl_tree.*), @TypeOf(adapter)).init(hl_tree, ml_graph, builtins, adapter);
    try ctx.initEntry();

    const value = try adapter.lowerExpr(&ctx, node);
    return ml_graph.appendInst(ctx.current_block, node.span, .{
        .cast = .{ .value = value, .to_type = ctx.ty_i64 },
    }, ctx.ty_i64);
}

pub fn LowerCtx(comptime HLTreeType: type, comptime AdapterType: type) type {
    return struct {
        const Self = @This();

        hl_tree: *const HLTreeType,
        ml_graph: *MLGraph,
        builtins: type_interner.BuiltinTypes,
        adapter: AdapterType,
        current_region: MLRegionID = .{ .value = 0 },
        current_block: MLBlockID = .{ .value = 0 },
        ty_void: MLTypeID,
        ty_i1: MLTypeID,
        ty_i64: MLTypeID,
        ty_ptr: MLTypeID,

        pub fn init(hl_tree: *const HLTreeType, ml_graph: *MLGraph, builtins: type_interner.BuiltinTypes, adapter: AdapterType) Self {
            return .{
                .hl_tree = hl_tree,
                .ml_graph = ml_graph,
                .builtins = builtins,
                .adapter = adapter,
                .ty_void = builtins.void,
                .ty_i1 = builtins.i1,
                .ty_i64 = builtins.i64,
                .ty_ptr = builtins.ptr,
            };
        }

        pub fn initEntry(self: *Self) !void {
            const entry = try self.ml_graph.addFunctionWithEntry(self.syntheticEntryName(), self.entryReturnType());
            self.current_region = entry.region;
            self.current_block = entry.entry_block;
        }

        pub fn lowerStmt(self: *Self, node: *const HLTreeType.HLNodeMeta) anyerror!void {
            switch (node.data) {
                .empty => {},
                .expr_stmt => |expr| {
                    _ = try AdapterType.lowerExpr(self, self.hl_tree.get(expr.expr));
                },
                .let => |let_node| {
                    const init_value = try AdapterType.lowerExpr(self, self.hl_tree.get(let_node.init));
                    const addr = try AdapterType.ensureSymbolAddress(self, let_node.symbol);
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .store = .{ .addr = addr, .value = init_value },
                    }, null);
                },
                .assign => |assign| {
                    const addr = try AdapterType.ensureSymbolAddress(self, try self.assignTargetSymbol(assign.target));
                    const value = try AdapterType.lowerExpr(self, self.hl_tree.get(assign.value));
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .store = .{ .addr = addr, .value = value },
                    }, null);
                },
                .block => |block| {
                    for (0..block.count) |i| {
                        const child_id = HLNodeID{ .value = block.start.value + @as(u32, @intCast(i)) };
                        try self.lowerStmt(self.hl_tree.get(child_id));
                    }
                },
                .if_ => |if_node| {
                    const then_block = try self.ml_graph.addBlock(self.current_region);
                    const cont_block = try self.ml_graph.addBlock(self.current_region);
                    const else_block = if (if_node.else_ != null)
                        try self.ml_graph.addBlock(self.current_region)
                    else
                        cont_block;
                    const cond = try self.lowerCond(self.hl_tree.get(if_node.cond));

                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .cond_br = .{
                            .cond = cond,
                            .then_target = then_block,
                            .else_target = else_block,
                        },
                    }, null);

                    self.current_block = then_block;
                    try self.lowerStmt(self.hl_tree.get(if_node.then));
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .br = .{ .target = cont_block, .arg_start = 0, .arg_count = 0 },
                    }, null);

                    if (if_node.else_) |else_id| {
                        self.current_block = else_block;
                        try self.lowerStmt(self.hl_tree.get(else_id));
                        _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                            .br = .{ .target = cont_block, .arg_start = 0, .arg_count = 0 },
                        }, null);
                    }

                    self.current_block = cont_block;
                },
                .while_ => |while_node| {
                    const header_block = try self.ml_graph.addBlock(self.current_region);
                    const body_block = try self.ml_graph.addBlock(self.current_region);
                    const exit_block = try self.ml_graph.addBlock(self.current_region);

                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .br = .{ .target = header_block, .arg_start = 0, .arg_count = 0 },
                    }, null);

                    self.current_block = header_block;
                    const cond = try self.lowerCond(self.hl_tree.get(while_node.cond));
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .cond_br = .{
                            .cond = cond,
                            .then_target = body_block,
                            .else_target = exit_block,
                        },
                    }, null);

                    self.current_block = body_block;
                    try self.lowerStmt(self.hl_tree.get(while_node.body));
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .br = .{ .target = header_block, .arg_start = 0, .arg_count = 0 },
                    }, null);

                    self.current_block = exit_block;
                },
                .do_while => |do_while_node| {
                    const body_block = try self.ml_graph.addBlock(self.current_region);
                    const latch_block = try self.ml_graph.addBlock(self.current_region);
                    const exit_block = try self.ml_graph.addBlock(self.current_region);

                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .br = .{ .target = body_block, .arg_start = 0, .arg_count = 0 },
                    }, null);

                    self.current_block = body_block;
                    try self.lowerStmt(self.hl_tree.get(do_while_node.body));
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .br = .{ .target = latch_block, .arg_start = 0, .arg_count = 0 },
                    }, null);

                    self.current_block = latch_block;
                    const cond = try self.lowerCond(self.hl_tree.get(do_while_node.cond));
                    _ = try self.ml_graph.appendInst(self.current_block, node.span, .{
                        .cond_br = .{
                            .cond = cond,
                            .then_target = body_block,
                            .else_target = exit_block,
                        },
                    }, null);

                    self.current_block = exit_block;
                },
                else => {
                    _ = try AdapterType.lowerExpr(self, node);
                },
            }
        }

        fn assignTargetSymbol(self: *Self, target_id: HLNodeID) !SymbolID {
            const target = self.hl_tree.get(target_id);
            return switch (target.data) {
                .ident => |ident| ident.symbol,
                else => error.InvalidAssignmentTarget,
            };
        }

        fn lowerCond(self: *Self, node: *const HLTreeType.HLNodeMeta) !MLValueID {
            if (@hasDecl(AdapterType, "lowerCondition")) {
                return AdapterType.lowerCondition(self, node);
            }
            return AdapterType.lowerExpr(self, node);
        }

        fn syntheticEntryName(_: *const Self) []const u8 {
            if (@hasDecl(AdapterType, "syntheticEntryName")) {
                return AdapterType.syntheticEntryName();
            }
            return "__synthetic_entry";
        }

        fn entryReturnType(self: *const Self) MLTypeID {
            if (@hasDecl(AdapterType, "entryReturnType")) {
                return AdapterType.entryReturnType(self);
            }
            return self.ty_void;
        }
    };
}

fn syntheticSpan() Span {
    return .{
        .source_id = 0,
        .start = 0,
        .end = 0,
        .line_start = 0,
        .col_start = 0,
        .line_end = 0,
        .col_end = 0,
    };
}
