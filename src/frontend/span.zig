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
    line_start: usize,
    col_start: usize,
    line_end: usize,
    col_end: usize,
};

pub fn Spanned(comptime T: type) type {
    return struct {
        span: Span,
        value: T,

        const Self = @This();

        pub fn init(start: usize, end: usize, value: T) Self {
            const col_start = start + 1;
            const col_end = end + 1;
            return .{
                .span = .{
                    .source_id = 0,
                    .start = start,
                    .end = end,
                    .line_start = 1,
                    .col_start = col_start,
                    .line_end = 1,
                    .col_end = col_end,
                },
                .value = value,
            };
        }

        pub fn initWithSpan(span_value: Span, value: T) Self {
            return .{
                .span = span_value,
                .value = value,
            };
        }
    };
}
