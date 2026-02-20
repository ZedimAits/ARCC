const Abi = @import("../abi.zig").Abi;

pub const X86Reg = enum {
    rax,
    rbx,
    rcx,
    rdx,
    rsi,
    rdi,
    r8,
    r9,
    r10,
    r11,
    r12,
    r13,
    r14,
    r15,
};

pub const SysV_x86_64 = Abi{
    .arg_regs = &.{
        .{ .x86 = .rdi },
        .{ .x86 = .rsi },
        .{ .x86 = .rdx },
        .{ .x86 = .rcx },
        .{ .x86 = .r8 },
        .{ .x86 = .r9 },
    },
    .ret_regs = &.{.{ .x86 = .rax }},
};

pub const Win64_x86_64 = Abi{
    .arg_regs = &.{
        .rcx, .rdx, .r8, .r9,
    },
    .ret_regs = &.{.rax},
    .callee_saved = &.{
        .rbx, .rdi, .rsi, .r12, .r13, .r14, .r15,
    },
    .stack_align = 16,
    .shadow_space = 32,
};
