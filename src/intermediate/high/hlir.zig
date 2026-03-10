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
pub const SymbolID = @import("../symbol.zig").SymbolID;
pub const lower_to_ml = @import("lower_to_ml.zig");
const types = @import("../type.zig");

pub const HLNodeID = struct { value: u32 };
pub const TypeId = types.TypeID;
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
        nodes: std.ArrayListUnmanaged(HLNodeMeta) = .{},
        roots: std.ArrayListUnmanaged(HLNodeID) = .{},

        pub fn init(gpa: std.mem.Allocator) Self {
            return .{ .gpa = gpa };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit(self.gpa);
            self.roots.deinit(self.gpa);
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

        pub fn addRoot(self: *Self, id: HLNodeID) !void {
            const idx: usize = @intCast(id.value);
            std.debug.assert(idx < self.nodes.items.len);
            try self.roots.append(self.gpa, id);
        }

        pub fn get(self: *const Self, id: HLNodeID) *const HLNodeMeta {
            return &self.nodes.items[id.value];
        }

        pub fn getMut(self: *Self, id: HLNodeID) *HLNodeMeta {
            return &self.nodes.items[id.value];
        }

        pub fn getRoot(self: *const Self, i: usize) HLNodeID {
            std.debug.assert(i < self.roots.items.len);
            return self.roots.items[i];
        }

        pub fn count(self: *const Self) usize {
            return self.nodes.items.len;
        }

        pub fn rootCount(self: *const Self) usize {
            return self.roots.items.len;
        }

        pub fn writeTo(self: *const Self, writer: *std.Io.Writer) anyerror!void {
            return self.writeToWith(writer, .{});
        }

        pub fn writeToWith(self: *const Self, writer: *std.Io.Writer, resolver: anytype) anyerror!void {
            try writer.print("HL-TREE (roots={d}, nodes={d}):\n", .{
                self.rootCount(),
                self.count(),
            });
            for (self.roots.items, 0..) |root, i| {
                try writer.print("root[{d}]:\n", .{i});
                try self.writeNodeRecursiveWith(writer, root, 1, resolver);
            }
        }

        pub fn writeNodeRecursive(self: *const Self, writer: *std.Io.Writer, id: HLNodeID, indent: usize) anyerror!void {
            return self.writeNodeRecursiveWith(writer, id, indent, .{});
        }

        pub fn writeNodeRecursiveWith(self: *const Self, writer: *std.Io.Writer, id: HLNodeID, indent: usize, resolver: anytype) anyerror!void {
            if (id.value >= self.nodes.items.len) {
                try writeIndent(writer, indent);
                try writer.print("<invalid node id={d}>\n", .{id.value});
                return;
            }

            const node = self.get(id).data;
            if (@hasDecl(HLNode, "writeToResolved")) {
                try node.writeToResolved(self, writer, indent, resolver);
            } else if (@hasDecl(HLNode, "writeTo")) {
                try node.writeTo(self, writer, indent);
            } else {
                try writeIndent(writer, indent);
                try writer.print("[{d}] {any}\n", .{ id.value, node });
            }
        }

        fn writeIndent(writer: *std.Io.Writer, indent: usize) anyerror!void {
            for (0..indent) |_| {
                try writer.print("  ", .{});
            }
        }

        pub fn toString(self: *const Self, alloc: std.mem.Allocator) ![]u8 {
            return self.toStringWith(alloc, .{});
        }

        pub fn toStringWith(self: *const Self, alloc: std.mem.Allocator, resolver: anytype) ![]u8 {
            var out = std.ArrayList(u8).empty;
            defer out.deinit(alloc);

            var writer = out.writer(alloc);
            try self.writeToWith(&writer, resolver);

            return out.toOwnedSlice(alloc);
        }
    };
}
