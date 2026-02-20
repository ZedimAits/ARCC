const Abi = @import("../abi.zig").Abi;

pub const RVReg = enum {
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    t0,
    t1,
    t2,
};

pub const RISCV64 = Abi{
    .arg_regs = &.{
        .a0, .a1, .a2, .a3,
        .a4, .a5, .a6, .a7,
    },
    .ret_regs = &.{.a0},
    .callee_saved = &.{}, // s0–s11 if needed
    .stack_align = 16,
};
