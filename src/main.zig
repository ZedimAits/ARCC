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
const type_interner = @import("intermediate/type_interner.zig");
const linear = @import("intermediate/linear/linear.zig");
const low = @import("intermediate/low/lower.zig");
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

    var typeInterner = type_interner.TypeInterner.init(arena);
    defer typeInterner.deinit();
    const builtin_types = try type_interner.BuiltinTypes.intern(&typeInterner);

    //########## input handling

    const input =
        \\a = 0;
        \\if (1 < 2) { ; }
        \\while (a < 3) { a = a + 1; b = 1000; }
        \\//a = "sds";
        \\//1
    ;
    const source_id: u32 = 0;

    std.debug.print("INPUT:\n{s}\n\n", .{input});

    //########## lexer

    var lexer = tinyc.Lexer.initWithSourceId(arena, input, source_id, &identInterner, &literalInterner);
    var tokenStream = tinyc.TokenStream.init(arena, &lexer);
    try dumpTokenStream(&tokenStream, &identInterner, &literalInterner, stdout_writer);

    _ = try stdout_writer.write("\n\n");

    //########## parser

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

    _ = try stdout_writer.write("\n\n");

    //########## hlir

    var hlirTree = try tinyc.lowerASTtoHL(&astTree);
    defer hlirTree.deinit();

    const hl_resolver = tinyc.HLPrintResolver{
        .ident_interner = &identInterner,
        .literal_interner = &literalInterner,
    };
    try hlirTree.writeToWith(stdout_writer, hl_resolver);
    //hlirTree.typeCheck();

    //########## mlir

    var mlirGraph = try tinyc.lowerHLtoML(&hlirTree, builtin_types);
    defer mlirGraph.deinit();

    _ = try stdout_writer.write("\n\n");
    try mlirGraph.writeTo(stdout_writer);

    //try mlirGraph.optimise();
    try mlirGraph.prepareForLL();

    //########## llir

    var llirModule = try low.lowerMLtoLL(&mlirGraph, &typeInterner, builtin_types);
    defer llirModule.deinit();

    _ = try stdout_writer.write("\n\n");
    try llirModule.writeTo(stdout_writer);

    //########## linear

    var linearProgram = try linear.linearize(&llirModule);
    defer linearProgram.deinit();

    _ = try stdout_writer.write("\n\n");
    try linearProgram.writeTo(&llirModule, stdout_writer);

    //const assembly = llirList.lower();

    //// Accessing command line arguments:
    //const args = try init.minimal.args.toSlice(arena);
    //for (args) |arg| {
    //    std.log.info("arg: {s}", .{arg});
    //}

    try stdout_writer.flush();
}

fn dumpTokenStream(
    token_stream: anytype,
    ident_interner: *const core.IdentInterner,
    literal_interner: *const core.LiteralInterner,
    writer: *std.Io.Writer,
) !void {
    const cp = token_stream.checkpoint();
    defer token_stream.restore(cp);

    try writer.print("TOKEN-STREAM:\n", .{});

    var i: usize = 0;
    var current_line: ?usize = null;
    while (true) : (i += 1) {
        const tok = token_stream.advance();
        const token_line = tok.span.line_start;
        if (current_line) |line| {
            if (token_line != line) {
                try writer.print("\n", .{});
            } else {
                try writer.print(" ", .{});
            }
        }
        current_line = token_line;

        try writer.print("{s}", .{tok.value.text()});

        switch (tok.value) {
            .identifier => |id| {
                if (ident_interner.get(id)) |name| {
                    try writer.print("(\"{s}\")", .{name});
                } else {
                    try writer.print("(id={d})", .{id.value});
                }
            },
            .literal => |id| {
                if (literal_interner.get(id)) |lit| {
                    try writer.print("(", .{});
                    try writeLiteralValue(writer, lit);
                    try writer.print(")", .{});
                } else {
                    try writer.print("(id={d})", .{id.value});
                }
            },
            else => {},
        }

        if (tok.value == .eof) break;
    }

    try writer.print("\n", .{});
}

fn writeLiteralValue(writer: *std.Io.Writer, lit: core.Literal) !void {
    switch (lit) {
        .int => |v| try writer.print("int({d})", .{v.value}),
        .float => |v| try writer.print("float({d})", .{v.value}),
        .bool => |v| try writer.print("bool({any})", .{v}),
        .string => |v| try writer.print("string(\"{s}\")", .{v}),
        .char => |v| try writer.print("char({d})", .{v}),
        .null => try writer.print("null", .{}),
    }
}
