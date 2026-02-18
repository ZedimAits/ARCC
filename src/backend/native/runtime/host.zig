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

export fn host_stdin_fd() i32 {
    return 0;
}

export fn host_stdout_fd() i32 {
    return 1;
}

export fn host_stderr_fd() i32 {
    return 2;
}

export fn host_write(fd: i32, buf: [*]const u8, len: i32) i32 {
    const slice = buf[0..@intCast(len)];
    return @intCast(std.posix.write(fd, slice) catch -1);
}

export fn host_malloc(size: usize) ?*u8 {
    return std.heap.c_allocator.alloc(u8, size) catch null;
}

export fn host_free(ptr: ?*u8) void {
    if (ptr) |p|
        std.heap.c_allocator.free(p[0..0]);
}
