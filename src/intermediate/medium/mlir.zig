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
    region: nodes.Region,
    block: nodes.Block,
    arg: nodes.Arg,

    const_: nodes.Const,
    load: nodes.Load,
    store: nodes.Store,
    addr_of: nodes.AddrOf,
    index_addr: nodes.IndexAddr,
    cast: nodes.Cast,
    unary: nodes.Unary,
    binary: nodes.Binary,
    cmp: nodes.Cmp,
    select: nodes.Select,
    call: nodes.Call,
    ret: nodes.Ret,
    br: nodes.Br,
    cond_br: nodes.CondBr,
    switch_: nodes.Switch,
    phi: nodes.Phi,
    alloc_stack: nodes.AllocStack,
    alloc_heap: nodes.AllocHeap,
    free: nodes.Free,
    loop_: nodes.Loop,
    aggregate_make: nodes.AggregateMake,
    extract: nodes.Extract,
    insert: nodes.Insert,
    global: nodes.Global,
    func: nodes.Func,
    extern_func: nodes.ExternFunc,
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
