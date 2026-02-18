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
const Io = std.Io;

pub const FileReader = struct {
    const BUFFER_SIZE: usize = 64;
    file_name: []const u8,
    io: Io,
    file: Io.File,
    file_reader: Io.File.Reader,
    arena: std.heap.ArenaAllocator,
    content: [BUFFER_SIZE]u8 = undefined,
    buffer_counter: u32 = 0,
    buffer_size: u32 = 0,

    pub fn init(file_name: []const u8, io: Io) !FileReader {
        std.debug.print("Reading file: {s}\n", .{file_name});

        const cwd = Io.Dir.cwd();
        const file = try cwd.openFile(io, file_name, .{});

        const fr = file.reader(io, &.{});
        const arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        return .{
            .file_name = file_name,
            .io = io,
            .file = file,
            .file_reader = fr,
            .arena = arena,
        };
    }

    pub fn debug(self: *FileReader) void {
        std.debug.print("{s}\n", .{self.content});
    }

    pub fn read_char(self: *FileReader) !?u8 {
        if (self.buffer_counter == self.buffer_size) {
            try self._fill_buffer();
            if (self.buffer_size == 0) return null;
        }

        const char: u8 = self.content[self.buffer_counter];
        self.buffer_counter += 1;

        return char;
    }

    fn _fill_buffer(self: *FileReader) !void {
        var reader = &self.file_reader.interface;
        const bytes_read: u32 = @intCast(try reader.readSliceShort(&self.content));
        self.buffer_size = bytes_read;
        self.buffer_counter = 0;
    }

    pub fn deinit(self: *FileReader) void {
        self.file.close(self.io);
        self.arena.deinit();
    }
};
