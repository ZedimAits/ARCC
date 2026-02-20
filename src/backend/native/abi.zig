const X86Reg = @import("./x86_64/abi.zig").X86Reg;
const A64Reg = @import("./aarch64/abi.zig").A64Reg;
const RVReg = @import("./riscv/abi.zig").RVReg;

pub const PhysReg = union(enum) {
    x86: X86Reg,
    aarch64: A64Reg,
    riscv: RVReg,
};

pub const Abi = struct {
    arg_regs: []const PhysReg,
    ret_regs: []const PhysReg,
    callee_saved: []const PhysReg,
    stack_align: u8,
    shadow_space: u8 = 0, // win64 only
};
 
//pub fn selectAbi() Abi {
//    return switch (builtin.target.cpu.arch) {
//        .x86_64 => switch (builtin.target.os.tag) {
//            .windows => Win64_x86_64,
//            else => SysV_x86_64,
//        },
//        .aarch64 => AAPCS64,
//        .riscv64 => RISCV64,
//        else => @panic("unsupported target"),
//    };
//}

//fn lowerCall(call: Call, abi: Abi) void {
//    for (call.args, 0..) |arg, i| {
//        if (i < abi.arg_regs.len) {
//            const reg = abi.arg_regs[i];
//            emitMove(reg, arg);
//        } else {
//            spillToStack(arg);
//        }
//    }
//
//    emitCall(call.callee);
//
//    if (call.ret) |dst| {
//        emitMove(dst, abi.ret_regs[0]);
//    }
//}

//fn emitMove(dst: PhysReg, src: PhysReg) void {
//    switch (dst) {
//        .x86 => |r| emitX86Move(r, src),
//        .aarch64 => |r| emitA64Move(r, src),
//        .riscv => |r| emitRVMove(r, src),
//    }
//}
