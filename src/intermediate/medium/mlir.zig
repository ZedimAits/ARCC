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
const Span = front.Span;
const nodes = @import("nodes.zig");

pub const MLNodeID = nodes.MLNodeID;
pub const MLValueID = nodes.MLValueID;
pub const MLBlockID = nodes.MLBlockID;
pub const MLRegionID = nodes.MLRegionID;
pub const MLTypeID = nodes.MLTypeID;
pub const MLSymbolID = nodes.MLSymbolID;
pub const AttrSetID = struct { value: u32 };

pub const EffectFlags = packed struct(u8) {
    reads_mem: bool = false,
    writes_mem: bool = false,
    has_io: bool = false,
    is_volatile: bool = false,
    _pad: u4 = 0,
};

pub const MLNodeMeta = struct {
    span: Span,
    effects: EffectFlags = .{},
    attrs: AttrSetID = .{ .value = 0 },
    region: MLRegionID = .{ .value = 0 },
    scope: u32 = 0,
    result_start: u32 = 0,
    result_count: u16 = 0,
};

pub const UnaryOp = nodes.UnaryOp;
pub const BinaryOp = nodes.BinaryOp;
pub const CmpOp = nodes.CmpOp;

pub const MLNodeData = union(enum) {
    region: nodes.Region, // Container for blocks
    block: nodes.Block, // Sequence of ML nodes
    arg: nodes.Arg, // Block or function argument

    const_: nodes.Const, // Constant value
    load: nodes.Load, // Read value from memory
    store: nodes.Store, // Write value to memory
    addr_of: nodes.AddrOf, // Address of a symbol/object
    index_addr: nodes.IndexAddr, // Address with index offset
    cast: nodes.Cast, // Type conversion
    unary: nodes.Unary, // Unary operation
    binary: nodes.Binary, // Binary operation
    cmp: nodes.Cmp, // Comparison operation
    select: nodes.Select, // Conditional select (ternary op)
    call: nodes.Call, // Function call
    ret: nodes.Ret, // Function return
    br: nodes.Br, // Unconditional branch
    cond_br: nodes.CondBr, // Conditional branch
    switch_: nodes.Switch, // Multi-way branch
    phi: nodes.Phi, // SSA phi merge
    alloc_stack: nodes.AllocStack, // Stack allocation
    alloc_heap: nodes.AllocHeap, // Heap allocation
    free: nodes.Free, // Free heap memory
    loop_: nodes.Loop, // Loop node
    aggregate_make: nodes.AggregateMake, // Build aggregate value
    extract: nodes.Extract, // Read field/element from aggregate
    insert: nodes.Insert, // Write field/element into aggregate
    global: nodes.Global, // Global definition
    func: nodes.Func, // Function definition
    extern_func: nodes.ExternFunc, // External function declaration
};

pub const MLNode = struct {
    id: MLNodeID,
    kind: std.meta.Tag(MLNodeData),
    meta: MLNodeMeta,
    data: MLNodeData,
};

pub const MLTree = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(MLNode) = .{},

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *Self) void {
        self.nodes.deinit(self.gpa);
    }

    pub fn add(self: *Self, span: Span, data: MLNodeData) !MLNodeID {
        const raw_id: u32 = @intCast(self.nodes.items.len);
        const id = MLNodeID{ .value = raw_id };
        const kind = std.meta.activeTag(data);

        try self.nodes.append(self.gpa, .{
            .id = id,
            .kind = kind,
            .meta = .{
                .span = span,
            },
            .data = data,
        });

        return id;
    }

    pub fn get(self: *Self, id: MLNodeID) *MLNode {
        return &self.nodes.items[id.value];
    }
};
