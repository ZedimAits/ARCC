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

pub const SymbolID = struct { value: u32 };

/// Interns symbol names and returns stable SymbolID handles.
pub const SymbolInterner = struct {
    gpa: std.mem.Allocator,

    map: std.StringHashMapUnmanaged(SymbolID) = .{},
    symbols: std.ArrayListUnmanaged([]const u8) = .{},

    pub fn init(gpa: std.mem.Allocator) SymbolInterner {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *SymbolInterner) void {
        for (self.symbols.items) |s| self.gpa.free(s);
        self.symbols.deinit(self.gpa);
        self.map.deinit(self.gpa);
    }

    pub fn count(self: *const SymbolInterner) usize {
        return self.symbols.items.len;
    }

    pub fn reserve(self: *SymbolInterner, n: usize) !void {
        try self.symbols.ensureTotalCapacity(self.gpa, n);
        try self.map.ensureTotalCapacity(self.gpa, n);
    }

    pub fn intern(self: *SymbolInterner, name: []const u8) !SymbolID {
        if (self.map.get(name)) |id| return id;

        const owned = try self.gpa.dupe(u8, name);
        errdefer self.gpa.free(owned);

        const id: SymbolID = .{ .value = @intCast(self.symbols.items.len) };
        if (id.value == std.math.maxInt(u32))
            return error.TooManySymbols;

        try self.symbols.append(self.gpa, owned);
        errdefer _ = self.symbols.pop();

        try self.map.put(self.gpa, owned, id);
        return id;
    }

    pub fn lookup(self: *const SymbolInterner, name: []const u8) ?SymbolID {
        return self.map.get(name);
    }

    pub fn get(self: *const SymbolInterner, id: SymbolID) ?[]const u8 {
        if (id.value >= self.symbols.items.len) return null;
        return self.symbols.items[@intCast(id.value)];
    }
};
