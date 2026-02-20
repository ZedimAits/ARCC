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

const core = @import("../front.zig");

pub const ASTNodeID = struct { value: u32 };

pub fn ASTTree(comptime Node: type) type {
    return struct {
        const Self = @This();

        gpa: std.mem.Allocator,
        nodes: std.ArrayListUnmanaged(Node) = .{},
        roots: std.ArrayListUnmanaged(ASTNodeID) = .{},

        pub fn init(gpa: std.mem.Allocator) Self {
            return .{ .gpa = gpa };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit(self.gpa);
            self.roots.deinit(self.gpa);
        }

        pub fn add(self: *Self, n: Node) !ASTNodeID {
            const id: u32 = @intCast(self.nodes.items.len);
            if (id == std.math.maxInt(u32))
                return error.TooManyNodes;

            try self.nodes.append(self.gpa, n);
            return ASTNodeID{ .value = id };
        }

        pub fn addRoot(self: *Self, id: ASTNodeID) !void {
            const idx: usize = @intCast(id.value);
            std.debug.assert(idx < self.nodes.items.len);
            try self.roots.append(self.gpa, id);
        }

        pub fn get(self: *const Self, id: ASTNodeID) *const Node {
            const idx: usize = @intCast(id.value);
            std.debug.assert(idx < self.nodes.items.len);
            return &self.nodes.items[idx];
        }

        pub fn getRoot(self: *const Self, i: usize) ASTNodeID {
            std.debug.assert(i < self.roots.items.len);
            return self.roots.items[i];
        }

        pub fn count(self: *const Self) usize {
            return self.nodes.items.len;
        }

        pub fn rootCount(self: *const Self) usize {
            return self.roots.items.len;
        }

        pub fn reserve(self: *Self, n_nodes: usize, n_roots: usize) !void {
            try self.nodes.ensureTotalCapacity(self.gpa, n_nodes);
            try self.roots.ensureTotalCapacity(self.gpa, n_roots);
        }

        pub fn reserveNodes(self: *Self, n: usize) !void {
            try self.nodes.ensureTotalCapacity(self.gpa, n);
        }

        pub fn reserveRoots(self: *Self, n: usize) !void {
            try self.roots.ensureTotalCapacity(self.gpa, n);
        }

        pub fn writeTo(self: *const Self, writer: *std.Io.Writer) anyerror!void {
            return self.writeToWith(writer, .{});
        }

        pub fn writeToWith(self: *const Self, writer: *std.Io.Writer, resolver: anytype) anyerror!void {
            try writer.print("ASTTree(roots={d}, nodes={d})\n", .{
                self.rootCount(),
                self.count(),
            });
            for (self.roots.items, 0..) |root, i| {
                try writer.print("root[{d}]:\n", .{i});
                try self.writeNodeRecursiveWith(writer, root, 1, resolver);
            }
        }

        pub fn writeNodeRecursive(self: *const Self, writer: *std.Io.Writer, id: ASTNodeID, indent: usize) anyerror!void {
            return self.writeNodeRecursiveWith(writer, id, indent, .{});
        }

        pub fn writeNodeRecursiveWith(self: *const Self, writer: *std.Io.Writer, id: ASTNodeID, indent: usize, resolver: anytype) anyerror!void {
            if (id.value >= self.nodes.items.len) {
                try writeIndent(writer, indent);
                try writer.print("<invalid node id={d}>\n", .{id.value});
                return;
            }

            const node = self.get(id).*;
            if (@hasDecl(Node, "writeToResolved")) {
                try node.writeToResolved(self, writer, indent, resolver);
            } else if (@hasDecl(Node, "writeTo")) {
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

pub const ASTPrintResolver = struct {
    ident_interner: *const core.IdentInterner,
    literal_interner: *const core.LiteralInterner,

    pub fn lookupIdentifier(self: @This(), id: core.IdentifierID) ?[]const u8 {
        return self.ident_interner.get(id);
    }

    pub fn lookupLiteral(self: @This(), id: core.LiteralID) ?core.Literal {
        return self.literal_interner.get(id);
    }
};
