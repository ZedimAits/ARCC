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

pub const HLNodeID = struct { value: u32 };

pub const SymbolID = struct { value: u32 };
pub const TypeId = struct { value: u32 };
pub const RegionId = struct { value: u32 };

pub fn HLTree(comptime HLNode: type) type {
    return struct {
        const Self = @This();

        pub const HLNodeMeta = struct {
            type_: TypeId, // set after typecheck
            region: RegionId, // RegionId

            data: HLNode,

            flags: Flags,
            effects: Effects,
            span: Span,

            pub const Flags = packed struct(u16) {
                produces_place: bool = false,
                is_const: bool = false,
                is_move: bool = false,
                _pad: u13 = 0,
            };

            pub const Effects = packed struct(u8) {
                reads_mem: bool = false,
                writes_mem: bool = false,
                has_io: bool = false,
                _pad: u5 = 0,
            };
        };

        gpa: std.mem.Allocator,
        nodes: std.ArrayListUnmanaged(HLNode) = .{},

        pub fn init(gpa: std.mem.Allocator) Self {
            return .{ .gpa = gpa };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit(self.gpa);
        }

        pub fn add(self: *Self, span: Span, node: HLNode) !HLNodeID {
            const raw_id: u32 = @intCast(self.nodes.items.len);
            const id = HLNodeID{ .value = raw_id };

            try self.nodes.append(self.gpa, .{
                .type_ = .{ .value = 0 }, // unknown
                    .region = .{ .value = 0 }, // global/static
                    .flags = .{},
                    .effects = .{},
                    .span = span,
                .data = node,
            });

            return id;
        }

        pub fn get(self: *Self, id: HLNodeID) *HLNode {
            return &self.nodes.items[id.value];
        }
    };
}
