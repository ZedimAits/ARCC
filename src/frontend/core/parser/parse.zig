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





//
//
//
//
//Parameterlisten
//Argumentlisten
//Enum-Member
//Imports
//Tuple-Typen
//pub fn parseList(
//    ts: *TokenStream,
//    parseElem: fn (*TokenStream) !Node,
//    sep: TokenKind,
//    end: TokenKind,
//    out: *std.ArrayList(Node),
//) !void {
//    if (match(ts, end)) return;
//
//    while (true) {
//        try out.append(try parseElem(ts));
//
//        if (match(ts, end)) break;
//        _ = try expect(ts, sep);
//    }
//}
//
//
//
//
//Für:
//( ... )
//{ ... }
//[ ... ]
//< ... >
//pub fn parseDelimited(
//    ts: *TokenStream,
//    open: TokenKind,
//    close: TokenKind,
//    body: fn (*TokenStream) void,
//) void {
//    _ = expect(ts, open) catch return;
//    body(ts);
//
//    if (!match(ts, close))
//        syncUntil(ts, &.{close});
//}
//
//
//
//pub const Diagnostic = struct {
//    code: DiagCode,
//    span: Span,
//    found: TokenKind,
//    expected: Category,
//};
