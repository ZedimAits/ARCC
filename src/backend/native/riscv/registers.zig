const llir = @import("../../../intermediate/low/llir.zig");
const tc = @import("../target_constraints.zig");

pub const RVReg = enum(u16) {
    zero,
    ra,
    sp,
    gp,
    tp,
    t0,
    t1,
    t2,
    s0,
    s1,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    s2,
    s3,
    s4,
    s5,
    s6,
    s7,
    s8,
    s9,
    s10,
    s11,
    t3,
    t4,
    t5,
    t6,

    pub fn id(self: RVReg) llir.PhysRegID {
        return .{ .value = @intFromEnum(self) };
    }

    pub fn text(self: RVReg) []const u8 {
        return @tagName(self);
    }
};

pub const regs = [_]tc.PhysRegDesc{
    .{ .id = RVReg.zero.id(), .class = .gp, .reserved = true },
    .{ .id = RVReg.ra.id(), .class = .gp, .reserved = true },
    .{ .id = RVReg.sp.id(), .class = .gp, .reserved = true },
    .{ .id = RVReg.gp.id(), .class = .gp, .reserved = true },
    .{ .id = RVReg.tp.id(), .class = .gp, .reserved = true },
    .{ .id = RVReg.t0.id(), .class = .gp },
    .{ .id = RVReg.t1.id(), .class = .gp },
    .{ .id = RVReg.t2.id(), .class = .gp },
    .{ .id = RVReg.s0.id(), .class = .gp },
    .{ .id = RVReg.s1.id(), .class = .gp },
    .{ .id = RVReg.a0.id(), .class = .gp },
    .{ .id = RVReg.a1.id(), .class = .gp },
    .{ .id = RVReg.a2.id(), .class = .gp },
    .{ .id = RVReg.a3.id(), .class = .gp },
    .{ .id = RVReg.a4.id(), .class = .gp },
    .{ .id = RVReg.a5.id(), .class = .gp },
    .{ .id = RVReg.a6.id(), .class = .gp },
    .{ .id = RVReg.a7.id(), .class = .gp },
    .{ .id = RVReg.s2.id(), .class = .gp },
    .{ .id = RVReg.s3.id(), .class = .gp },
    .{ .id = RVReg.s4.id(), .class = .gp },
    .{ .id = RVReg.s5.id(), .class = .gp },
    .{ .id = RVReg.s6.id(), .class = .gp },
    .{ .id = RVReg.s7.id(), .class = .gp },
    .{ .id = RVReg.s8.id(), .class = .gp },
    .{ .id = RVReg.s9.id(), .class = .gp },
    .{ .id = RVReg.s10.id(), .class = .gp },
    .{ .id = RVReg.s11.id(), .class = .gp },
    .{ .id = RVReg.t3.id(), .class = .gp },
    .{ .id = RVReg.t4.id(), .class = .gp },
    .{ .id = RVReg.t5.id(), .class = .gp },
    .{ .id = RVReg.t6.id(), .class = .gp },
};

pub const riscv64 = tc.TargetConstraints{
    .kind = .riscv64,
    .regs = &regs,
    .caller_saved = &.{
        RVReg.t0.id(), RVReg.t1.id(), RVReg.t2.id(),
        RVReg.a0.id(), RVReg.a1.id(), RVReg.a2.id(),
        RVReg.a3.id(), RVReg.a4.id(), RVReg.a5.id(),
        RVReg.a6.id(), RVReg.a7.id(), RVReg.t3.id(),
        RVReg.t4.id(), RVReg.t5.id(), RVReg.t6.id(),
    },
    .callee_saved = &.{
        RVReg.s0.id(),  RVReg.s1.id(),  RVReg.s2.id(), RVReg.s3.id(), RVReg.s4.id(),
        RVReg.s5.id(),  RVReg.s6.id(),  RVReg.s7.id(), RVReg.s8.id(), RVReg.s9.id(),
        RVReg.s10.id(), RVReg.s11.id(),
    },
    .arg_regs_gp = &.{
        RVReg.a0.id(), RVReg.a1.id(), RVReg.a2.id(), RVReg.a3.id(),
        RVReg.a4.id(), RVReg.a5.id(), RVReg.a6.id(), RVReg.a7.id(),
    },
    .ret_regs_gp = &.{RVReg.a0.id()},
    .special = .{
        .stack_ptr = RVReg.sp.id(),
        .link = RVReg.ra.id(),
        .zero = RVReg.zero.id(),
        .div_rem_lo = RVReg.a0.id(),
        .div_rem_hi = RVReg.a1.id(),
    },
    .stack_align = 16,
};
