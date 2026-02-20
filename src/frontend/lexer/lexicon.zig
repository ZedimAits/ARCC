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

pub const CommentSpec = struct {
    line: ?[]const u8 = null,
};

pub const LiteralStart = union(enum) {
    any_of: []const []const u8,
};

pub const NumberSpec = struct {
    base: u8,
    digit_sep: ?u8 = null,
};

pub const EscapeMode = enum {
    none,
    backslash,
    doubled_end,
};

pub const DelimitedEnd = union(enum) {
    same_as_start,
    fixed: []const u8,
};

pub const DelimitedSpec = struct {
    end: DelimitedEnd,
    escape: EscapeMode = .none,
};

pub const LiteralBody = union(enum) {
    number: NumberSpec,
    exact: void,
    delimited: DelimitedSpec,
};

pub fn LiteralRule(comptime T: type) type {
    return struct {
        text: []const u8,
        kind: T,
        start: LiteralStart = .{ .any_of = &.{""} },
        body: LiteralBody,
    };
}
