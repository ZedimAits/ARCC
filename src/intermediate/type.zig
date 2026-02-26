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

pub const TypeID = struct { value: u32 };

pub const CallingConv = enum {
    c,
    fast,
    cold,
};

pub const IntSign = enum {
    unsigned,
    signed,
};

pub const TypeKind = enum {
    void,
    int,
    float,
    ptr,
    array,
    vector,
    function,
};

pub const Type = union(TypeKind) {
    void,
    int: struct {
        bits: u16,
        sign: IntSign = .unsigned,
    },
    float: struct {
        bits: u16,
    },
    ptr,
    array: struct {
        elem: TypeID,
        len: u32,
    },
    vector: struct {
        elem: TypeID,
        len: u16,
    },
    function: struct {
        ret: TypeID,
        param_start: u32,
        param_count: u16,
        variadic: bool = false,
        cc: CallingConv = .c,
    },
};
