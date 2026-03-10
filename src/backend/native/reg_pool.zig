const std = @import("std");
const llir = @import("../../intermediate/low/llir.zig");
const tc = @import("target_constraints.zig");

pub const RegPoolError = error{
    UnknownRegister,
};

pub const RegPool = struct {
    gpa: std.mem.Allocator,
    target: tc.TargetConstraints,
    free: std.DynamicBitSetUnmanaged = .{},
    pinned: std.DynamicBitSetUnmanaged = .{},

    pub fn init(gpa: std.mem.Allocator, target: tc.TargetConstraints) !RegPool {
        var pool = RegPool{
            .gpa = gpa,
            .target = target,
        };
        errdefer pool.deinit();

        try pool.free.resize(gpa, target.regs.len, false);
        try pool.pinned.resize(gpa, target.regs.len, false);

        for (target.regs, 0..) |desc, idx| {
            if (!desc.reserved) pool.free.set(idx);
        }

        return pool;
    }

    pub fn deinit(self: *RegPool) void {
        self.free.deinit(self.gpa);
        self.pinned.deinit(self.gpa);
    }

    pub fn isFree(self: *const RegPool, reg: llir.PhysRegID) bool {
        const idx = self.target.regIndex(reg) orelse return false;
        return self.free.isSet(idx) and !self.pinned.isSet(idx);
    }

    pub fn isPinned(self: *const RegPool, reg: llir.PhysRegID) bool {
        const idx = self.target.regIndex(reg) orelse return false;
        return self.pinned.isSet(idx);
    }

    pub fn acquireAny(self: *RegPool, class: llir.RegClass) ?llir.PhysRegID {
        for (self.target.regs, 0..) |desc, idx| {
            if (desc.class != class) continue;
            if (!self.free.isSet(idx) or self.pinned.isSet(idx)) continue;
            self.free.unset(idx);
            return desc.id;
        }
        return null;
    }

    pub fn acquireFixed(self: *RegPool, reg: llir.PhysRegID) bool {
        const idx = self.target.regIndex(reg) orelse return false;
        if (!self.free.isSet(idx) or self.pinned.isSet(idx)) return false;
        self.free.unset(idx);
        return true;
    }

    pub fn acquireRoleOrAny(self: *RegPool, role: tc.SpecialRegRole, class: llir.RegClass) ?llir.PhysRegID {
        if (self.target.specialReg(role)) |reg| {
            if (self.target.isAllocatable(reg) and self.acquireFixed(reg)) {
                return reg;
            }
        }
        return self.acquireAny(class);
    }

    pub fn release(self: *RegPool, reg: llir.PhysRegID) RegPoolError!void {
        const idx = self.target.regIndex(reg) orelse return error.UnknownRegister;
        if (self.pinned.isSet(idx)) return;
        if (self.target.isAllocatable(reg)) self.free.set(idx);
    }

    pub fn pin(self: *RegPool, reg: llir.PhysRegID) RegPoolError!void {
        const idx = self.target.regIndex(reg) orelse return error.UnknownRegister;
        self.free.unset(idx);
        self.pinned.set(idx);
    }

    pub fn unpin(self: *RegPool, reg: llir.PhysRegID) RegPoolError!void {
        const idx = self.target.regIndex(reg) orelse return error.UnknownRegister;
        self.pinned.unset(idx);
        if (self.target.isAllocatable(reg)) self.free.set(idx);
    }
};

test "acquire role or any prefers special allocatable register" {
    const alloc = std.testing.allocator;
    var pool = try RegPool.init(alloc, tc.x86_64.sysv);
    defer pool.deinit();

    const reg = pool.acquireRoleOrAny(.shift_count, .gp) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(tc.x86_64.X86Reg.rcx.id().value, reg.value);
}

test "acquire role or any falls back for missing role" {
    const alloc = std.testing.allocator;
    var pool = try RegPool.init(alloc, tc.aarch64.aapcs64);
    defer pool.deinit();

    const reg = pool.acquireRoleOrAny(.shift_count, .gp) orelse return error.TestExpectedEqual;
    try std.testing.expect(tc.aarch64.aapcs64.regClass(reg) == .gp);
    try std.testing.expect(tc.aarch64.aapcs64.specialReg(.shift_count) == null);
}

test "pinned registers are not reused" {
    const alloc = std.testing.allocator;
    var pool = try RegPool.init(alloc, tc.x86_64.sysv);
    defer pool.deinit();

    try pool.pin(tc.x86_64.X86Reg.r10.id());
    const reg = pool.acquireAny(.gp) orelse return error.TestExpectedEqual;
    try std.testing.expect(reg.value != tc.x86_64.X86Reg.r10.id().value);
}
