const llir = @import("../../intermediate/low/llir.zig");

pub const TargetKind = enum {
    x86_64,
    aarch64,
    riscv64,
};

pub const SpecialRegRole = enum {
    stack_ptr,
    frame_ptr,
    link,
    zero,
    shift_count,
    div_rem_lo,
    div_rem_hi,
};

pub const PhysRegDesc = struct {
    id: llir.PhysRegID,
    class: llir.RegClass,
    reserved: bool = false,
};

pub const SpecialRegs = struct {
    stack_ptr: ?llir.PhysRegID = null,
    frame_ptr: ?llir.PhysRegID = null,
    link: ?llir.PhysRegID = null,
    zero: ?llir.PhysRegID = null,
    shift_count: ?llir.PhysRegID = null,
    div_rem_lo: ?llir.PhysRegID = null,
    div_rem_hi: ?llir.PhysRegID = null,
};

pub const TargetConstraints = struct {
    kind: TargetKind,
    regs: []const PhysRegDesc,
    caller_saved: []const llir.PhysRegID,
    callee_saved: []const llir.PhysRegID,
    arg_regs_gp: []const llir.PhysRegID,
    ret_regs_gp: []const llir.PhysRegID,
    special: SpecialRegs = .{},
    stack_align: u8,

    pub fn regIndex(self: TargetConstraints, reg: llir.PhysRegID) ?usize {
        for (self.regs, 0..) |desc, idx| {
            if (desc.id.value == reg.value) return idx;
        }
        return null;
    }

    pub fn regDesc(self: TargetConstraints, reg: llir.PhysRegID) ?PhysRegDesc {
        const idx = self.regIndex(reg) orelse return null;
        return self.regs[idx];
    }

    pub fn regClass(self: TargetConstraints, reg: llir.PhysRegID) ?llir.RegClass {
        const desc = self.regDesc(reg) orelse return null;
        return desc.class;
    }

    pub fn isAllocatable(self: TargetConstraints, reg: llir.PhysRegID) bool {
        const desc = self.regDesc(reg) orelse return false;
        return !desc.reserved;
    }

    pub fn specialReg(self: TargetConstraints, role: SpecialRegRole) ?llir.PhysRegID {
        return switch (role) {
            .stack_ptr => self.special.stack_ptr,
            .frame_ptr => self.special.frame_ptr,
            .link => self.special.link,
            .zero => self.special.zero,
            .shift_count => self.special.shift_count,
            .div_rem_lo => self.special.div_rem_lo,
            .div_rem_hi => self.special.div_rem_hi,
        };
    }
};

pub const x86_64 = @import("./x86_64/registers.zig");
pub const aarch64 = @import("./aarch64/registers.zig");
pub const riscv = @import("./riscv/registers.zig");
