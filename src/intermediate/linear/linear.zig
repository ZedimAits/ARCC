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
const llir = @import("../low/llir.zig");

// Optional straight-line debug/interpreter view over LLIR.
// This is not a required pipeline stage for native codegen.
pub const DebugItem = union(enum) {
    label: llir.LLBlockID,
    inst: llir.LLInstID,
};

pub const DebugFunction = struct {
    name: []const u8,
    items: std.ArrayListUnmanaged(DebugItem) = .{},

    pub fn deinit(self: *DebugFunction, gpa: std.mem.Allocator) void {
        self.items.deinit(gpa);
    }
};

pub const LLDebugView = struct {
    gpa: std.mem.Allocator,
    funcs: std.ArrayListUnmanaged(DebugFunction) = .{},

    pub fn init(gpa: std.mem.Allocator) LLDebugView {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *LLDebugView) void {
        for (self.funcs.items) |*func| {
            func.deinit(self.gpa);
        }
        self.funcs.deinit(self.gpa);
    }

    pub fn writeTo(self: *const LLDebugView, ll_module: *const llir.LLModule, writer: *std.Io.Writer) !void {
        var total_items: usize = 0;
        for (self.funcs.items) |func| total_items += func.items.items.len;
        try writer.print("LL-DEBUG-VIEW (funcs={d}, items={d})\n", .{ self.funcs.items.len, total_items });

        for (self.funcs.items, 0..) |func, i| {
            try writer.print("func[{d}] {s}\n", .{ i, func.name });
            for (func.items.items) |item| {
                switch (item) {
                    .label => |block_id| try writer.print("  label b{d}\n", .{block_id.value}),
                    .inst => |inst_id| {
                        const inst = ll_module.insts.items[inst_id.value];
                        if (inst.meta.result_ty != null) {
                            try writer.print("  v{d} = ", .{inst.meta.result_value.?.value});
                        } else {
                            try writer.print("  ", .{});
                        }
                        try writer.print("{s}", .{@tagName(inst.data)});
                        try ll_module.writeInstOperands(writer, inst);
                        try writer.print("\n", .{});
                    },
                }
            }
        }
    }
};

pub fn debugViewFromLL(ll_module: *const llir.LLModule) !LLDebugView {
    var view = LLDebugView.init(ll_module.gpa);
    errdefer view.deinit();

    for (ll_module.funcs.items) |func| {
        var debug_func = DebugFunction{ .name = func.name };
        errdefer debug_func.deinit(view.gpa);
        for (func.blocks.items) |block_id| {
            try debug_func.items.append(view.gpa, .{ .label = block_id });

            const block = ll_module.blocks.items[block_id.value];
            for (block.insts.items) |inst_id| {
                try debug_func.items.append(view.gpa, .{ .inst = inst_id });
            }
        }

        try view.funcs.append(view.gpa, debug_func);
    }

    return view;
}
