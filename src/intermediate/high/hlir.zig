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

pub const HLNodeID = struct { value: u32 };

pub const UniqueID = u32;
pub const TypeId = u32;
pub const RegionId = u32;


pub fn HLTree(comptime HLNode: type) type {
    return struct {
        const Self = @This();

        gpa: std.mem.Allocator,
        nodes: std.ArrayListUnmanaged(HLNode),

        pub fn add(
            self: *Self,
            span: Span,
            kind: HLNode,
        ) !HLNodeID {
            //TODO

            return id;
        }

        pub fn get(self: *Self, id: HLNodeID) *HLNode {
            return &self.nodes.items[id];
        }
    };
}
