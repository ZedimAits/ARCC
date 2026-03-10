// ─────────────────────────────────────────────────────────────────────
// SPDX-License-Identifier: Apache-2.0
//
// ARCC - Advanced Retargetable Compiler Collection - Version 0.1.0
//
// Copyright (C) 2026 Cedric Beck
// Copyright (C) 2026 Felix Koppe <fkoppe@web.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// ─────────────────────────────────────────────────────────────────────

const std = @import("std");
const types = @import("../type.zig");
const type_interner = @import("../type_interner.zig");
const symbol = @import("../symbol.zig");

pub const LLTypeID = types.TypeID;
pub const LLValueID = struct { value: u32 };
pub const LLInstID = struct { value: u32 };
pub const LLBlockID = struct { value: u32 };
pub const LLFuncID = struct { value: u32 };
pub const LLGlobalID = struct { value: u32 };
pub const PhysRegID = struct { value: u16 };

pub const CallingConv = types.CallingConv;

pub const IntSign = types.IntSign;

pub const LLTypeKind = types.TypeKind;

pub const LLType = types.Type;

pub const LLConst = union(enum) {
    int: u128,
    float_bits: u64,
    bool: bool,
    null,
};

pub const LLBinaryOp = enum {
    add,
    sub,
    mul,
    udiv,
    sdiv,
    urem,
    srem,
    shl,
    lshr,
    ashr,
    and_,
    or_,
    xor_,
};

pub const LLCmpOp = enum {
    eq,
    ne,
    ult,
    ule,
    ugt,
    uge,
    slt,
    sle,
    sgt,
    sge,
};

pub const LLCastOp = enum {
    zext,
    sext,
    trunc,
    bitcast,
    int_to_ptr,
    ptr_to_int,
};

pub const LLEffectFlags = packed struct(u8) {
    reads_mem: bool = false,
    writes_mem: bool = false,
    has_io: bool = false,
    may_trap: bool = false,
    _pad: u4 = 0,
};

pub const RegClass = enum(u8) {
    gp,
    fp,
    vec,
};

pub const OperandConstraint = union(enum) {
    any,
    reg_class: RegClass,
    fixed_reg: PhysRegID,
    same_as_operand: u8,
};

pub const InstConstraints = struct {
    operands: std.ArrayListUnmanaged(OperandConstraint) = .{},
    result: OperandConstraint = .any,
    clobbers: std.ArrayListUnmanaged(PhysRegID) = .{},

    pub fn deinit(self: *InstConstraints, gpa: std.mem.Allocator) void {
        self.operands.deinit(gpa);
        self.clobbers.deinit(gpa);
    }
};

pub const LLBlock = struct {
    label: ?[]const u8 = null,
    insts: std.ArrayListUnmanaged(LLInstID) = .{},

    pub fn deinit(self: *LLBlock, gpa: std.mem.Allocator) void {
        self.insts.deinit(gpa);
    }
};

pub const LLFunction = struct {
    name: []const u8,
    ty: LLTypeID, // function type
    entry: LLBlockID,
    blocks: std.ArrayListUnmanaged(LLBlockID) = .{},
    args: std.ArrayListUnmanaged(LLValueID) = .{},

    pub fn deinit(self: *LLFunction, gpa: std.mem.Allocator) void {
        self.blocks.deinit(gpa);
        self.args.deinit(gpa);
    }
};

pub const LLGlobal = struct {
    symbol: symbol.SymbolID,
    name_cache: ?[]const u8 = null,
    ty: LLTypeID,
    init: ?LLValueID = null,
    is_const: bool = false,
};

pub const LLValueOperandView = struct {
    items: [4]LLValueID = undefined,
    len: u8 = 0,

    pub fn slice(self: *const LLValueOperandView) []const LLValueID {
        return self.items[0..self.len];
    }
};

pub const LLBlockSuccessorView = struct {
    items: [2]LLBlockID = undefined,
    len: u8 = 0,

    pub fn slice(self: *const LLBlockSuccessorView) []const LLBlockID {
        return self.items[0..self.len];
    }
};

pub const LLValue = union(enum) {
    vreg: struct { // virtual backend register/result slot
        def_inst: ?LLInstID = null,
    },
    const_: struct { // inline constant value
        ty: LLTypeID,
        value: LLConst,
    },
    arg: struct { // function argument
        index: u16,
    },
    global: struct { // reference to global symbol
        id: LLGlobalID,
    },
};

pub const LLInstMeta = struct {
    result_ty: ?LLTypeID = null,
    result_value: ?LLValueID = null,
    effects: LLEffectFlags = .{},
    name_hint: ?[]const u8 = null,
    constraints: ?InstConstraints = null,
};

pub const LLInstData = union(enum) {
    nop, // explicit no-op
    alloca: struct { ty: LLTypeID }, // reserve stack slot
    load: struct { ptr: LLValueID }, // read from memory
    store: struct { ptr: LLValueID, value: LLValueID }, // write to memory
    gep: struct { base_ptr: LLValueID, index: LLValueID }, // pointer + scaled index
    binary: struct { op: LLBinaryOp, lhs: LLValueID, rhs: LLValueID }, // integer arithmetic/bitwise op
    icmp: struct { op: LLCmpOp, lhs: LLValueID, rhs: LLValueID }, // integer comparison
    cast: struct { op: LLCastOp, value: LLValueID, to_ty: LLTypeID }, // explicit type conversion
    call: struct { callee: LLValueID, args: std.ArrayListUnmanaged(LLValueID) = .{} }, // direct/indirect call
    br: struct { target: LLBlockID }, // unconditional jump
    cond_br: struct { cond: LLValueID, then_blk: LLBlockID, else_blk: LLBlockID }, // conditional jump
    ret: struct { value: ?LLValueID = null }, // function return
    unreachable_: void, // proven impossible path
};

pub const LLInst = struct {
    id: LLInstID,
    meta: LLInstMeta = .{},
    data: LLInstData,

    pub fn deinit(self: *LLInst, gpa: std.mem.Allocator) void {
        switch (self.data) {
            .call => |*call| call.args.deinit(gpa),
            else => {},
        }
        if (self.meta.constraints) |*constraints| {
            constraints.deinit(gpa);
        }
    }
};

// LLIR is the last structured backend IR: module -> functions -> blocks -> instructions.
// High-level CFG/value ops such as select/switch/phi belong in MLIR and must be removed before LL lowering.
// Native codegen should work from LLIR directly; optional straight-line views can be derived for debugging/interpreting.
pub const LLModule = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    type_interner: *const type_interner.TypeInterner,
    values: std.ArrayListUnmanaged(LLValue) = .{},
    globals: std.ArrayListUnmanaged(LLGlobal) = .{},
    funcs: std.ArrayListUnmanaged(LLFunction) = .{},
    blocks: std.ArrayListUnmanaged(LLBlock) = .{},
    insts: std.ArrayListUnmanaged(LLInst) = .{},

    pub fn init(gpa: std.mem.Allocator, interner: *const type_interner.TypeInterner) Self {
        return .{
            .gpa = gpa,
            .type_interner = interner,
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit(self.gpa);
        self.globals.deinit(self.gpa);
        for (self.funcs.items) |*func| func.deinit(self.gpa);
        self.funcs.deinit(self.gpa);
        for (self.blocks.items) |*block| block.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
        for (self.insts.items) |*inst| inst.deinit(self.gpa);
        self.insts.deinit(self.gpa);
    }

    pub fn addValue(self: *Self, value: LLValue) !LLValueID {
        const id = LLValueID{ .value = @intCast(self.values.items.len) };
        try self.values.append(self.gpa, value);
        return id;
    }

    pub fn addVirtualValue(self: *Self) !LLValueID {
        return self.addValue(.{ .vreg = .{} });
    }

    pub fn addBlock(self: *Self, block: LLBlock) !LLBlockID {
        const id = LLBlockID{ .value = @intCast(self.blocks.items.len) };
        try self.blocks.append(self.gpa, block);
        return id;
    }

    pub fn addInst(self: *Self, data: LLInstData, meta: LLInstMeta) !LLInstID {
        const id = LLInstID{ .value = @intCast(self.insts.items.len) };
        try self.insts.append(self.gpa, .{
            .id = id,
            .meta = meta,
            .data = data,
        });
        return id;
    }

    pub fn addGlobal(self: *Self, global: LLGlobal) !LLGlobalID {
        const id = LLGlobalID{ .value = @intCast(self.globals.items.len) };
        try self.globals.append(self.gpa, global);
        return id;
    }

    pub fn addFunction(self: *Self, func: LLFunction) !LLFuncID {
        const id = LLFuncID{ .value = @intCast(self.funcs.items.len) };
        try self.funcs.append(self.gpa, func);
        return id;
    }

    pub fn writeTo(self: *const Self, writer: *std.Io.Writer) anyerror!void {
        try writer.print("LL-MODULE (types={d}, values={d}, globals={d}, funcs={d}, blocks={d}, insts={d})\n", .{
            self.type_interner.count(),
            self.values.items.len,
            self.globals.items.len,
            self.funcs.items.len,
            self.blocks.items.len,
            self.insts.items.len,
        });

        for (self.funcs.items, 0..) |f, i| {
            try writer.print("func[{d}] {s} (entry=b{d}, blocks={d})\n", .{
                i,
                f.name,
                f.entry.value,
                f.blocks.items.len,
            });

            for (f.blocks.items) |block_id| {
                try self.writeBlock(writer, block_id);
            }
        }
    }

    fn writeBlock(self: *const Self, writer: *std.Io.Writer, block_id: LLBlockID) anyerror!void {
        const block = self.blocks.items[block_id.value];
        try writer.print("  block[{d}]\n", .{block_id.value});

        for (block.insts.items) |inst_id| {
            const inst = self.insts.items[inst_id.value];
            if (inst.meta.result_ty != null) {
                try writer.print("    v{d} = ", .{inst.meta.result_value.?.value});
            } else {
                try writer.print("    ", .{});
            }
            try writer.print("{s}", .{@tagName(inst.data)});
            try self.writeInstOperands(writer, inst);
            try writer.print("\n", .{});
        }
    }

    pub fn writeValueRef(self: *const Self, writer: *std.Io.Writer, value_id: LLValueID) anyerror!void {
        const value = self.values.items[value_id.value];
        switch (value) {
            .vreg => try writer.print("v{d}", .{value_id.value}),
            .arg => |arg| try writer.print("v{d}:arg({d})", .{ value_id.value, arg.index }),
            .global => |global| {
                const g = self.globals.items[global.id.value];
                if (g.name_cache) |name| {
                    try writer.print("v{d}:sym({s})", .{ value_id.value, name });
                } else {
                    try writer.print("v{d}:sym({d})", .{ value_id.value, g.symbol.value });
                }
            },
            .const_ => |constant| {
                try writer.print("v{d}:const(", .{value_id.value});
                switch (constant.value) {
                    .int => |v| try writer.print("{d}", .{v}),
                    .bool => |v| try writer.print("{any}", .{v}),
                    .null => try writer.print("null", .{}),
                    .float_bits => |v| try writer.print("bits:{d}", .{v}),
                }
                try writer.print(")", .{});
            },
        }
    }

    pub fn writeInstOperands(self: *const Self, writer: *std.Io.Writer, inst: LLInst) anyerror!void {
        switch (inst.data) {
            .nop => try writer.print("()", .{}),
            .alloca => |n| try writer.print("(ty=t{d})", .{n.ty.value}),
            .load => |n| {
                try writer.print("(ptr=", .{});
                try self.writeValueRef(writer, n.ptr);
                try writer.print(")", .{});
            },
            .store => |n| {
                try writer.print("(ptr=", .{});
                try self.writeValueRef(writer, n.ptr);
                try writer.print(", value=", .{});
                try self.writeValueRef(writer, n.value);
                try writer.print(")", .{});
            },
            .gep => |n| {
                try writer.print("(base=", .{});
                try self.writeValueRef(writer, n.base_ptr);
                try writer.print(", index=", .{});
                try self.writeValueRef(writer, n.index);
                try writer.print(")", .{});
            },
            .binary => |n| {
                try writer.print("(op={s}, lhs=", .{@tagName(n.op)});
                try self.writeValueRef(writer, n.lhs);
                try writer.print(", rhs=", .{});
                try self.writeValueRef(writer, n.rhs);
                try writer.print(")", .{});
            },
            .icmp => |n| {
                try writer.print("(op={s}, lhs=", .{@tagName(n.op)});
                try self.writeValueRef(writer, n.lhs);
                try writer.print(", rhs=", .{});
                try self.writeValueRef(writer, n.rhs);
                try writer.print(")", .{});
            },
            .cast => |n| {
                try writer.print("(op={s}, value=", .{@tagName(n.op)});
                try self.writeValueRef(writer, n.value);
                try writer.print(", to=t{d})", .{n.to_ty.value});
            },
            .call => |n| {
                try writer.print("(callee=", .{});
                try self.writeValueRef(writer, n.callee);
                for (n.args.items, 0..) |arg, idx| {
                    try writer.print(", arg{d}=", .{idx});
                    try self.writeValueRef(writer, arg);
                }
                try writer.print(")", .{});
            },
            .br => |n| try writer.print("(target=b{d})", .{n.target.value}),
            .cond_br => |n| {
                try writer.print("(cond=", .{});
                try self.writeValueRef(writer, n.cond);
                try writer.print(", true=b{d}, false=b{d})", .{ n.then_blk.value, n.else_blk.value });
            },
            .ret => |n| if (n.value) |value| {
                try writer.print("(value=", .{});
                try self.writeValueRef(writer, value);
                try writer.print(")", .{});
            } else try writer.print("()", .{}),
            .unreachable_ => try writer.print("()", .{}),
        }
    }

    pub fn instResult(self: *const Self, inst_id: LLInstID) ?LLValueID {
        return self.insts.items[inst_id.value].meta.result_value;
    }

    pub fn instOperands(_: *const Self, inst: LLInst) LLValueOperandView {
        var view = LLValueOperandView{};
        switch (inst.data) {
            .nop, .br, .unreachable_ => {},
            .alloca => {},
            .load => |n| {
                view.items[0] = n.ptr;
                view.len = 1;
            },
            .store => |n| {
                view.items[0] = n.ptr;
                view.items[1] = n.value;
                view.len = 2;
            },
            .gep => |n| {
                view.items[0] = n.base_ptr;
                view.items[1] = n.index;
                view.len = 2;
            },
            .binary => |n| {
                view.items[0] = n.lhs;
                view.items[1] = n.rhs;
                view.len = 2;
            },
            .icmp => |n| {
                view.items[0] = n.lhs;
                view.items[1] = n.rhs;
                view.len = 2;
            },
            .cast => |n| {
                view.items[0] = n.value;
                view.len = 1;
            },
            .call => |n| {
                view.items[0] = n.callee;
                view.len = 1;
            },
            .cond_br => |n| {
                view.items[0] = n.cond;
                view.len = 1;
            },
            .ret => |n| if (n.value) |value| {
                view.items[0] = value;
                view.len = 1;
            },
        }
        return view;
    }

    pub fn blockSuccessors(self: *const Self, block_id: LLBlockID) LLBlockSuccessorView {
        const block = self.blocks.items[block_id.value];
        var view = LLBlockSuccessorView{};
        if (block.insts.items.len == 0) return view;

        const term = self.insts.items[block.insts.items[block.insts.items.len - 1].value];
        switch (term.data) {
            .br => |n| {
                view.items[0] = n.target;
                view.len = 1;
            },
            .cond_br => |n| {
                view.items[0] = n.then_blk;
                view.items[1] = n.else_blk;
                view.len = 2;
            },
            else => {},
        }
        return view;
    }
};
