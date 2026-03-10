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
const typ = @import("type.zig");

/// Interns canonical shared Type descriptors and returns stable TypeID handles.
pub const TypeInterner = struct {
    const Context = struct {
        pub fn hash(_: @This(), t: typ.Type) u64 {
            var h = std.hash.Wyhash.init(0);
            const tag: u8 = @intCast(@intFromEnum(t));
            h.update(&.{tag});

            switch (t) {
                .void => {},
                .int => |v| {
                    h.update(std.mem.asBytes(&v.bits));
                    const sign: u8 = @intCast(@intFromEnum(v.sign));
                    h.update(&.{sign});
                },
                .float => |v| h.update(std.mem.asBytes(&v.bits)),
                .ptr => {},
                .array => |v| {
                    h.update(std.mem.asBytes(&v.elem.value));
                    h.update(std.mem.asBytes(&v.len));
                },
                .vector => |v| {
                    h.update(std.mem.asBytes(&v.elem.value));
                    h.update(std.mem.asBytes(&v.len));
                },
                .function => |v| {
                    h.update(std.mem.asBytes(&v.ret.value));
                    const param_count: u32 = @intCast(v.params.items.len);
                    h.update(std.mem.asBytes(&param_count));
                    for (v.params.items) |param| {
                        h.update(std.mem.asBytes(&param.value));
                    }
                    const variadic: u8 = @intFromBool(v.variadic);
                    h.update(&.{variadic});
                    const cc: u8 = @intCast(@intFromEnum(v.cc));
                    h.update(&.{cc});
                },
            }

            return h.final();
        }

        pub fn eql(_: @This(), a: typ.Type, b: typ.Type) bool {
            if (@intFromEnum(a) != @intFromEnum(b)) return false;

            return switch (a) {
                .void => true,
                .int => |v| {
                    const w = b.int;
                    return v.bits == w.bits and v.sign == w.sign;
                },
                .float => |v| v.bits == b.float.bits,
                .ptr => true,
                .array => |v| {
                    const w = b.array;
                    return v.elem.value == w.elem.value and v.len == w.len;
                },
                .vector => |v| {
                    const w = b.vector;
                    return v.elem.value == w.elem.value and v.len == w.len;
                },
                .function => |v| {
                    const w = b.function;
                    if (v.params.items.len != w.params.items.len) return false;
                    for (v.params.items, w.params.items) |lhs, rhs| {
                        if (lhs.value != rhs.value) return false;
                    }
                    return v.ret.value == w.ret.value and
                        v.variadic == w.variadic and
                        v.cc == w.cc;
                },
            };
        }
    };

    gpa: std.mem.Allocator,

    map: std.HashMapUnmanaged(typ.Type, typ.TypeID, Context, 80) = .{},
    types: std.ArrayListUnmanaged(typ.Type) = .{},

    pub fn init(gpa: std.mem.Allocator) TypeInterner {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *TypeInterner) void {
        for (self.types.items) |*t| {
            switch (t.*) {
                .function => |*f| f.deinit(self.gpa),
                else => {},
            }
        }
        self.types.deinit(self.gpa);
        self.map.deinit(self.gpa);
    }

    pub fn count(self: *const TypeInterner) usize {
        return self.types.items.len;
    }

    pub fn reserve(self: *TypeInterner, n: usize) !void {
        try self.types.ensureTotalCapacity(self.gpa, n);
        try self.map.ensureTotalCapacity(self.gpa, n);
    }

    pub fn intern(self: *TypeInterner, t: typ.Type) !typ.TypeID {
        if (self.map.get(t)) |id| {
            switch (t) {
                .function => |v| v.deinit(self.gpa),
                else => {},
            }
            return id;
        }

        const id: typ.TypeID = .{ .value = @intCast(self.types.items.len) };
        if (id.value == std.math.maxInt(u32))
            return error.TooManyTypes;

        try self.types.append(self.gpa, t);
        errdefer _ = self.types.pop();

        try self.map.put(self.gpa, t, id);
        return id;
    }

    pub fn lookup(self: *const TypeInterner, t: typ.Type) ?typ.TypeID {
        return self.map.get(t);
    }

    pub fn get(self: *const TypeInterner, id: typ.TypeID) ?typ.Type {
        if (id.value >= self.types.items.len) return null;
        return self.types.items[@intCast(id.value)];
    }
};

pub const BuiltinTypes = struct {
    void: typ.TypeID,
    i1: typ.TypeID,
    i64: typ.TypeID,
    ptr: typ.TypeID,

    pub fn intern(interner: *TypeInterner) !BuiltinTypes {
        return .{
            .void = try interner.intern(.{ .void = {} }),
            .i1 = try interner.intern(.{ .int = .{ .bits = 1, .sign = .unsigned } }),
            .i64 = try interner.intern(.{ .int = .{ .bits = 64, .sign = .signed } }),
            .ptr = try interner.intern(.{ .ptr = {} }),
        };
    }
};
