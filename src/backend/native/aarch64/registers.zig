const llir = @import("../../../intermediate/low/llir.zig");
const tc = @import("../target_constraints.zig");

pub const A64Reg = enum(u16) {
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
    x16,
    x17,
    x18,
    x19,
    x20,
    x21,
    x22,
    x23,
    x24,
    x25,
    x26,
    x27,
    x28,
    fp,
    lr,
    sp,

    pub fn id(self: A64Reg) llir.PhysRegID {
        return .{ .value = @intFromEnum(self) };
    }

    pub fn text(self: A64Reg) []const u8 {
        return @tagName(self);
    }
};

pub const regs = [_]tc.PhysRegDesc{
    .{ .id = A64Reg.x0.id(), .class = .gp },
    .{ .id = A64Reg.x1.id(), .class = .gp },
    .{ .id = A64Reg.x2.id(), .class = .gp },
    .{ .id = A64Reg.x3.id(), .class = .gp },
    .{ .id = A64Reg.x4.id(), .class = .gp },
    .{ .id = A64Reg.x5.id(), .class = .gp },
    .{ .id = A64Reg.x6.id(), .class = .gp },
    .{ .id = A64Reg.x7.id(), .class = .gp },
    .{ .id = A64Reg.x8.id(), .class = .gp },
    .{ .id = A64Reg.x9.id(), .class = .gp },
    .{ .id = A64Reg.x10.id(), .class = .gp },
    .{ .id = A64Reg.x11.id(), .class = .gp },
    .{ .id = A64Reg.x12.id(), .class = .gp },
    .{ .id = A64Reg.x13.id(), .class = .gp },
    .{ .id = A64Reg.x14.id(), .class = .gp },
    .{ .id = A64Reg.x15.id(), .class = .gp },
    .{ .id = A64Reg.x16.id(), .class = .gp },
    .{ .id = A64Reg.x17.id(), .class = .gp },
    .{ .id = A64Reg.x18.id(), .class = .gp, .reserved = true },
    .{ .id = A64Reg.x19.id(), .class = .gp },
    .{ .id = A64Reg.x20.id(), .class = .gp },
    .{ .id = A64Reg.x21.id(), .class = .gp },
    .{ .id = A64Reg.x22.id(), .class = .gp },
    .{ .id = A64Reg.x23.id(), .class = .gp },
    .{ .id = A64Reg.x24.id(), .class = .gp },
    .{ .id = A64Reg.x25.id(), .class = .gp },
    .{ .id = A64Reg.x26.id(), .class = .gp },
    .{ .id = A64Reg.x27.id(), .class = .gp },
    .{ .id = A64Reg.x28.id(), .class = .gp },
    .{ .id = A64Reg.fp.id(), .class = .gp, .reserved = true },
    .{ .id = A64Reg.lr.id(), .class = .gp, .reserved = true },
    .{ .id = A64Reg.sp.id(), .class = .gp, .reserved = true },
};

pub const aapcs64 = tc.TargetConstraints{
    .kind = .aarch64,
    .regs = &regs,
    .caller_saved = &.{
        A64Reg.x0.id(), A64Reg.x1.id(), A64Reg.x2.id(), A64Reg.x3.id(),
        A64Reg.x4.id(), A64Reg.x5.id(), A64Reg.x6.id(), A64Reg.x7.id(),
        A64Reg.x8.id(), A64Reg.x9.id(), A64Reg.x10.id(), A64Reg.x11.id(),
        A64Reg.x12.id(), A64Reg.x13.id(), A64Reg.x14.id(), A64Reg.x15.id(),
        A64Reg.x16.id(), A64Reg.x17.id(),
    },
    .callee_saved = &.{
        A64Reg.x19.id(), A64Reg.x20.id(), A64Reg.x21.id(), A64Reg.x22.id(), A64Reg.x23.id(),
        A64Reg.x24.id(), A64Reg.x25.id(), A64Reg.x26.id(), A64Reg.x27.id(), A64Reg.x28.id(),
    },
    .arg_regs_gp = &.{
        A64Reg.x0.id(), A64Reg.x1.id(), A64Reg.x2.id(), A64Reg.x3.id(),
        A64Reg.x4.id(), A64Reg.x5.id(), A64Reg.x6.id(), A64Reg.x7.id(),
    },
    .ret_regs_gp = &.{A64Reg.x0.id()},
    .special = .{
        .stack_ptr = A64Reg.sp.id(),
        .frame_ptr = A64Reg.fp.id(),
        .link = A64Reg.lr.id(),
        .div_rem_lo = A64Reg.x0.id(),
    },
    .stack_align = 16,
};
