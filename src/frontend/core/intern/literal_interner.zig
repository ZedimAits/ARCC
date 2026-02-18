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
const core = @import("../core.zig");

/// Interns canonical semantic literal values and returns stable LiteralId handles.
/// Owns storage for string payloads.
pub const LiteralInterner = struct {
    gpa: std.mem.Allocator,

    const Context = struct {
        pub fn hash(_: @This(), k: core.Literal) u64 {
            var h = std.hash.Wyhash.init(0);

            switch (k) {
                .int => |v| {
                    const s: u8 = @intFromBool(v.signed);
                    h.update(&.{s});
                    h.update(std.mem.asBytes(&v.bits));
                    h.update(std.mem.asBytes(&v.value));
                },
                .float => |v| {
                    h.update(std.mem.asBytes(&v.bits));
                    const bits: u64 = @bitCast(v.value);
                    h.update(std.mem.asBytes(&bits));
                },
                .bool => |v| {
                    const b: u8 = @intFromBool(v);
                    h.update(&.{b});
                },
                .char => |c| h.update(std.mem.asBytes(&c)),
                .string => |s| h.update(s),
                .null => {},
            }

            return h.final();
        }

        pub fn eql(_: @This(), a: core.Literal, b: core.Literal) bool {
            if (@intFromEnum(a) != @intFromEnum(b)) return false;

            return switch (a) {
                .int => |v| {
                    const w = b.int;
                    return v.signed == w.signed
                        and v.bits == w.bits
                        and v.value == w.value;
                },
                .float => |v| {
                    const w = b.float;
                    if (v.bits != w.bits) return false;
                    const ab: u64 = @bitCast(v.value);
                    const bb: u64 = @bitCast(w.value);
                    return ab == bb;
                },
                .bool => |v| v == b.bool,
                .char => |c| c == b.char,
                .string => |s| std.mem.eql(u8, s, b.string),
                .null => true,
            };
        }
    };

    map: std.HashMapUnmanaged(core.Literal, core.LiteralId, Context, 80) = .{},
    values: std.ArrayListUnmanaged(core.Literal) = .{},

    pub fn init(gpa: std.mem.Allocator) LiteralInterner {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *LiteralInterner) void {
        for (self.values.items) |lit| {
            switch (lit) {
                .string => |s| self.gpa.free(s),
                else => {},
            }
        }
        self.values.deinit(self.gpa);
        self.map.deinit(self.gpa);
    }

    pub fn count(self: *const LiteralInterner) usize {
        return self.values.items.len;
    }

    pub fn reserve(self: *LiteralInterner, n: usize) !void {
        try self.values.ensureTotalCapacity(self.gpa, n);
        try self.map.ensureTotalCapacity(self.gpa, n);
    }

    /// Interns a semantic literal value and returns a stable ID.
    /// Takes ownership of string payloads by duplicating them.
    pub fn intern(self: *LiteralInterner, lit: core.Literal) !core.LiteralID {
        // Probe without allocating for string
        if (self.map.get(lit)) |id| return id;

        var stored = lit;

        switch (lit) {
            .string => |s| {
                const owned = try self.gpa.dupe(u8, s);
                errdefer self.gpa.free(owned);
                stored = .{ .string = owned };
            },
            else => {},
        }

        const id: core.LiteralID = @intCast(self.values.items.len);
        if (id == std.math.maxInt(core.LiteralID))
            return error.TooManyLiterals;

        try self.values.append(self.gpa, stored);
        errdefer _ = self.values.pop();

        try self.map.put(self.gpa, stored, id);
        return id;
    }

    pub fn get(self: *const LiteralInterner, id: core.LiteralID) ?core.Literal {
        if (id >= self.values.items.len) return null;
        return self.values.items[@intCast(id)];
    }
};
