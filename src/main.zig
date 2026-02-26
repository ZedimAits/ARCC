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

const core = @import("frontend/front.zig");
const tinyc = @import("language/tinyc/tinyc.zig");

pub fn main(init: std.process.Init) !void {
    //std.debug.print("All your codebase are belong to us.\n", .{});
    //std.debug.print("You have no chance to compile make your time.\n", .{});

    const arena: std.mem.Allocator = init.arena.allocator();

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var identInterner = core.IdentInterner.init(arena);
    defer identInterner.deinit();

    var literalInterner = core.LiteralInterner.init(arena);
    defer literalInterner.deinit();

    const input =
        \\a = 0;
        \\if (1 < 2) { ; }
        \\while (a < 3) { a = a + 1; b = 1000; }
        \\a = "sds";
        \\//1
    ;
    const source_id: u32 = 0;

    var lexer = tinyc.Lexer.initWithSourceId(arena, input, source_id, &identInterner, &literalInterner);
    var tokenStream = tinyc.TokenStream.init(arena, &lexer);

    const parser = tinyc.Parser.init(arena, &tokenStream);
    var astTree: tinyc.ASTTree = parser.parse() catch |err| {
        if (lexer.last_error != null) {
            lexer.printLastError();
            return;
        }
        return err;
    };
    defer astTree.deinit();

    if (lexer.last_error != null) {
        lexer.printLastError();
        return;
    }

    const resolver = core.ASTPrintResolver{
        .ident_interner = &identInterner,
        .literal_interner = &literalInterner,
    };
    try astTree.writeToWith(stdout_writer, resolver);

    var hlirTree = try tinyc.lowerASTtoHL(&astTree);
    defer hlirTree.deinit();
    //hlirTree.typeCheck();

    //var mlirGraph = hlirTree.lower();
    //mlirGraph = mlirGraph.optimise();

    //var llirList = mlirGraph.lower();
    //llirList.colorRegisters();

    //const assembly = llirList.lower();

    //// Accessing command line arguments:
    //const args = try init.minimal.args.toSlice(arena);
    //for (args) |arg| {
    //    std.log.info("arg: {s}", .{arg});
    //}

    try stdout_writer.flush();
}
