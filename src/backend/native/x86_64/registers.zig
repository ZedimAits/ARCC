const llir = @import("../../../intermediate/low/llir.zig");
const tc = @import("../target_constraints.zig");

pub const X86Reg = enum(u16) {
    rax,
    rbx,
    rcx,
    rdx,
    rsi,
    rdi,
    rsp,
    rbp,
    r8,
    r9,
    r10,
    r11,
    r12,
    r13,
    r14,
    r15,

    pub fn id(self: X86Reg) llir.PhysRegID {
        return .{ .value = @intFromEnum(self) };
    }

    pub fn text(self: X86Reg) []const u8 {
        return @tagName(self);
    }
};

pub const regs = [_]tc.PhysRegDesc{
    .{ .id = X86Reg.rax.id(), .class = .gp },
    .{ .id = X86Reg.rbx.id(), .class = .gp },
    .{ .id = X86Reg.rcx.id(), .class = .gp },
    .{ .id = X86Reg.rdx.id(), .class = .gp },
    .{ .id = X86Reg.rsi.id(), .class = .gp },
    .{ .id = X86Reg.rdi.id(), .class = .gp },
    .{ .id = X86Reg.rsp.id(), .class = .gp, .reserved = true },
    .{ .id = X86Reg.rbp.id(), .class = .gp, .reserved = true },
    .{ .id = X86Reg.r8.id(), .class = .gp },
    .{ .id = X86Reg.r9.id(), .class = .gp },
    .{ .id = X86Reg.r10.id(), .class = .gp },
    .{ .id = X86Reg.r11.id(), .class = .gp },
    .{ .id = X86Reg.r12.id(), .class = .gp },
    .{ .id = X86Reg.r13.id(), .class = .gp },
    .{ .id = X86Reg.r14.id(), .class = .gp },
    .{ .id = X86Reg.r15.id(), .class = .gp },
};

pub const sysv = tc.TargetConstraints{
    .kind = .x86_64,
    .regs = &regs,
    .caller_saved = &.{
        X86Reg.rax.id(), X86Reg.rcx.id(), X86Reg.rdx.id(), X86Reg.rsi.id(), X86Reg.rdi.id(),
        X86Reg.r8.id(), X86Reg.r9.id(), X86Reg.r10.id(), X86Reg.r11.id(),
    },
    .callee_saved = &.{
        X86Reg.rbx.id(), X86Reg.r12.id(), X86Reg.r13.id(), X86Reg.r14.id(), X86Reg.r15.id(),
    },
    .arg_regs_gp = &.{
        X86Reg.rdi.id(), X86Reg.rsi.id(), X86Reg.rdx.id(), X86Reg.rcx.id(), X86Reg.r8.id(), X86Reg.r9.id(),
    },
    .ret_regs_gp = &.{X86Reg.rax.id()},
    .special = .{
        .stack_ptr = X86Reg.rsp.id(),
        .frame_ptr = X86Reg.rbp.id(),
        .shift_count = X86Reg.rcx.id(),
        .div_rem_lo = X86Reg.rax.id(),
        .div_rem_hi = X86Reg.rdx.id(),
    },
    .stack_align = 16,
};
