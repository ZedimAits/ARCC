const std = @import("std");

pub fn TokenStream(comptime L: type) type {
    const Token = L.SpannedToken;
    const TokenKind = L.TokenKind;

    return struct {
        lexer: *L,
        buf: std.ArrayList(Token),
        pos: usize = 0,

        pub fn init(alloc: std.mem.Allocator, lexer: *L) @This() {
            return .{
                .lexer = lexer,
                .buf = std.ArrayList(Token).init(alloc),
            };
        }

        fn fill(self: *@This(), n: usize) void {
            while (self.buf.items.len <= n) {
                const t = self.lexer.next() orelse Token{ .eof = {} };
                self.buf.append(t) catch unreachable;

                if (t.kind() == .eof) break;
            }
        }

        pub fn peek(self: *@This()) TokenKind {
            self.fill(self.pos);
            return self.buf.items[self.pos];
        }

        pub fn peekN(self: *@This(), n: usize) TokenKind {
            self.fill(self.pos + n);
            return self.buf.items[self.pos + n];
        }

        pub fn advance(self: *@This()) TokenKind {
            const t = self.peek();
            self.pos += 1;
            return t;
        }

        pub fn checkpoint(self: *const @This()) usize {
            return self.pos;
        }

        pub fn restore(self: *@This(), p: usize) void {
            self.pos = p;
        }

        pub fn speculate(self: *@This(), f: fn (*TokenStream) bool) bool {
            const cp = self.checkpoint();
            if (f(self)) return true;
            self.restore(cp);
            return false;
        }

        pub fn match(self: *@This(), k: TokenKind) bool {
            if (self.peek().kind() == k) {
                _ = self.advance();
                return true;
            }
            return false;
        }

        pub fn expect(self: *@This(), k: TokenKind) !Token {
            if (self.peek().kind() == k)
                return self.advance();
            return error.UnexpectedToken;
        }
    };
}
