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

pub const LinearItem = union(enum) {
    label: llir.LLBlockID,
    inst: llir.LLInstID,
};

pub const LinearFunction = struct {
    name: []const u8,
    item_start: u32,
    item_count: u32,
};

pub const LinearProgram = struct {
    gpa: std.mem.Allocator,
    funcs: std.ArrayListUnmanaged(LinearFunction) = .{},
    items: std.ArrayListUnmanaged(LinearItem) = .{},

    pub fn init(gpa: std.mem.Allocator) LinearProgram {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *LinearProgram) void {
        self.funcs.deinit(self.gpa);
        self.items.deinit(self.gpa);
    }

    pub fn writeTo(self: *const LinearProgram, ll_module: *const llir.LLModule, writer: *std.Io.Writer) !void {
        try writer.print("LINEAR-PROGRAM (funcs={d}, items={d})\n", .{
            self.funcs.items.len,
            self.items.items.len,
        });

        for (self.funcs.items, 0..) |func, i| {
            try writer.print("func[{d}] {s}\n", .{ i, func.name });
            const item_end = func.item_start + func.item_count;
            var item_index = func.item_start;
            while (item_index < item_end) : (item_index += 1) {
                switch (self.items.items[item_index]) {
                    .label => |block_id| try writer.print("  label b{d}\n", .{block_id.value}),
                    .inst => |inst_id| {
                        const inst = ll_module.insts.items[inst_id.value];
                        try writer.print("  i{d}", .{inst_id.value});
                        if (inst.meta.result_ty != null) {
                            try writer.print(" -> v{d}", .{inst_id.value});
                        }
                        try writer.print(" = {s}", .{@tagName(inst.data)});
                        try ll_module.writeInstOperands(writer, inst);
                        try writer.print("\n", .{});
                    },
                }
            }
        }
    }
};

pub fn linearize(ll_module: *const llir.LLModule) !LinearProgram {
    var program = LinearProgram.init(ll_module.gpa);
    errdefer program.deinit();

    for (ll_module.funcs.items) |func| {
        const item_start: u32 = @intCast(program.items.items.len);
        const block_end = func.block_start + func.block_count;
        var block_index = func.block_start;
        while (block_index < block_end) : (block_index += 1) {
            const block_id: llir.LLBlockID = .{ .value = @intCast(block_index) };
            try program.items.append(program.gpa, .{ .label = block_id });

            const block = ll_module.blocks.items[block_id.value];
            const inst_end = block.inst_start + block.inst_count;
            var inst_index = block.inst_start;
            while (inst_index < inst_end) : (inst_index += 1) {
                try program.items.append(program.gpa, .{ .inst = .{ .value = @intCast(inst_index) } });
            }
        }

        try program.funcs.append(program.gpa, .{
            .name = func.name,
            .item_start = item_start,
            .item_count = @intCast(program.items.items.len - item_start),
        });
    }

    return program;
}
