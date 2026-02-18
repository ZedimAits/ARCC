
// ─────────────────────────────────────────────────────────────────────
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Cedric Beck
// Copyright 2026 Felix Koppe <fkoppe@web.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// ─────────────────────────────────────────────────────────────────────

const std = @import("std");

const core = @import("../core.zig");

pub const NodeID = u32;

pub fn ASTTree(comptime Node: type) type {
    return struct {
        const Self = @This();

        gpa: std.mem.Allocator,
        nodes: std.ArrayListUnmanaged(Node) = .{},

        pub const NodeId = u32;

        pub fn add(self: *Self, n: Node) !NodeId {
            const id: NodeId = @intCast(self.nodes.items.len);
            try self.nodes.append(self.gpa, n);
            return id;
        }

        pub fn get(self: *const Self, id: NodeId) *const Node {
            const idx: usize = @intCast(id);
            std.debug.assert(idx < self.nodes.items.len);
            return &self.nodes.items[idx];
        }
    };
}
