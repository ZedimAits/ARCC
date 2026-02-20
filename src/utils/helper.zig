const std = @import("std");

pub fn initStaticStringMap(comptime V: type, comptime table: anytype) std.StaticStringMap(V) {
    var kvs: [table.len]struct { []const u8, V } = undefined;
    for (table, 0..) |entry, i| {
        kvs[i] = .{ entry.text, entry.tag };
    }
    return std.StaticStringMap(V).initComptime(kvs[0..]);
}

pub fn isDigitBase(c: u8, base: u8) bool {
    return switch (base) {
        2 => c == '0' or c == '1',
        8 => c >= '0' and c <= '7',
        10 => std.ascii.isDigit(c),
        16 => std.ascii.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'),
        else => false,
    };
}
