const std = @import("std");

pub fn Block(comptime ChildID: type) type {
    return struct {
        children: std.ArrayList(ChildID),

        const Self = @This();

        pub fn init() Self {
            return .{ .children = std.ArrayList(ChildID).empty };
        }

        pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
            self.children.deinit(alloc);
        }

        pub fn append(self: *Self, alloc: std.mem.Allocator, child: ChildID) !void {
            try self.children.append(alloc, child);
        }

        pub fn len(self: *const Self) usize {
            return self.children.items.len;
        }

        pub fn items(self: *const Self) []const ChildID {
            return self.children.items;
        }
    };
}
