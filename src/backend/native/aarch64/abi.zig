const Abi = @import("../abi.zig").Abi;

pub const A64Reg = enum {
    x0,
    x1,
    x2,
    x3,
    x4,
    x5,
    x6,
    x7,
    x8,
    x9,
    x10,
    x11,
    x12,
    x13,
    x14,
    x15,
};

pub const AAPCS64 = Abi{
    .arg_regs = &.{
        .{ .aarch64 = .x0 },
        .{ .aarch64 = .x1 },
        .{ .aarch64 = .x2 },
        .{ .aarch64 = .x3 },
    },
    .ret_regs = &.{.{ .aarch64 = .x0 }},
};
