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

pub const LiteralTag = enum {
    int,
    float,
    bool,
    string,
    char,
    null,
};

pub const Literal = union(LiteralTag) {
    int: Int,
    float: Float,
    bool: bool,
    string: []const u8,
    char: u32,
    null: void,
};

pub const Int = struct {
    signed: bool,
    bits: u16,
    value: u128,
};

pub const Float = struct {
    bits: u16,
    value: f64,
};
