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

pub const Span = struct {
    source_id: u32,
    start: usize,
    end: usize,
};

pub fn Spanned(comptime T: type) type {
    return struct {
        span: Span,
        value: T,

        const Self = @This();

        pub fn init(start: usize, end: usize, value: T) Self {
            return .{
                .span = .{ .source_id = 0, .start = start, .end = end },
                .value = value,
            };
        }
    };
}
