





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
