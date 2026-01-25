const std = @import("std");
const string = []const u8;

pub const TokenKind = enum {
    LITERAL,
    QUOTE,
    DOUBLE_QUOTE,
    BACKSLASH,
    SPACE,
};

pub const Token = struct {
    kind: TokenKind,
    value: string,
};

pub const Lexer = struct {
    const Self = @This();

    input: string,
    index: usize = 0,
    done: bool = false,

    pub fn init(input: string) Self {
        return .{
            .input = input,
        };
    }

    pub fn copy(self: *const Self) Self {
        return .{
            .input = self.input,
            .index = self.index,
            .done = self.done,
        };
    }

    pub fn next(self: *Self) ?Token {
        if (self.index < self.input.len) {
            const char = self.peekChar();

            return switch (char) {
                '\\' => self.readBackslash(),
                '\'' => self.readQuote(),
                '"' => self.readDoubleQuote(),
                ' ' => self.readSpace(),
                else => self.readLiteral(),
            };
        }

        return null;
    }

    pub fn peek(self: *const Self) ?Token {
        var self_copy = self.copy();
        return self_copy.next();
    }

    pub fn readBackslash(self: *Self) Token {
        self.increaseIndex();
        return Token{ .kind = TokenKind.BACKSLASH, .value = "\\" };
    }

    pub fn readQuote(self: *Self) Token {
        self.increaseIndex();
        return Token{ .kind = TokenKind.QUOTE, .value = "'" };
    }

    pub fn readDoubleQuote(self: *Self) Token {
        self.increaseIndex();
        return Token{ .kind = TokenKind.DOUBLE_QUOTE, .value = "\"" };
    }

    pub fn readSpace(self: *Self) Token {
        const start = self.index;
        while (self.peekChar() == ' ') {
            self.increaseIndex();
        }

        return Token{ .kind = TokenKind.SPACE, .value = self.input[start..self.index] };
    }

    pub fn readLiteral(self: *Self) Token {
        const start = self.index;
        while (self.peekChar() != ' ' and self.peekChar() != '\'' and self.peekChar() != '"' and self.peekChar() != 0) {
            self.increaseIndex();
        }
        return Token{ .kind = TokenKind.LITERAL, .value = self.input[start..self.index] };
    }

    pub fn increaseIndex(self: *Self) void {
        self.index += 1;
    }

    fn peekChar(self: Self) u8 {
        return if (self.index >= self.input.len) 0 else self.input[self.index];
    }
};

fn testExpectToken(expected: Token, actual: ?Token) !void {
    try std.testing.expect(actual != null);
    try std.testing.expectEqual(expected.kind, actual.?.kind);
    try std.testing.expect(std.mem.eql(u8, expected.value, actual.?.value));
}

fn testCompareLexer(tokens: []const Token, lexer: *Lexer) !void {
    for (tokens) |token| {
        const peek_token = lexer.peek();
        const next_token = lexer.next();

        try testExpectToken(token, peek_token);
        try testExpectToken(token, next_token);
    }

    try std.testing.expectEqual(lexer.next(), null);
}

test "lexer - simple test" {
    const input = "echo hello world";
    var lexer = Lexer.init(input);

    const tokens = [_]Token{
        Token{ .kind = TokenKind.LITERAL, .value = "echo" },
        Token{ .kind = TokenKind.SPACE, .value = " " },
        Token{ .kind = TokenKind.LITERAL, .value = "hello" },
        Token{ .kind = TokenKind.SPACE, .value = " " },
        Token{ .kind = TokenKind.LITERAL, .value = "world" },
    };

    try testCompareLexer(&tokens, &lexer);
}

test "lexer - long space" {
    const input = "echo hello     world";
    var lexer = Lexer.init(input);

    const tokens = [_]Token{
        Token{ .kind = TokenKind.LITERAL, .value = "echo" },
        Token{ .kind = TokenKind.SPACE, .value = " " },
        Token{ .kind = TokenKind.LITERAL, .value = "hello" },
        Token{ .kind = TokenKind.SPACE, .value = "     " },
        Token{ .kind = TokenKind.LITERAL, .value = "world" },
    };

    try testCompareLexer(&tokens, &lexer);
}

test "lexer - quotes" {
    const input = "echo 'hello'     world";
    var lexer = Lexer.init(input);

    const tokens = [_]Token{
        Token{ .kind = TokenKind.LITERAL, .value = "echo" },
        Token{ .kind = TokenKind.SPACE, .value = " " },
        Token{ .kind = TokenKind.QUOTE, .value = "'" },
        Token{ .kind = TokenKind.LITERAL, .value = "hello" },
        Token{ .kind = TokenKind.QUOTE, .value = "'" },
        Token{ .kind = TokenKind.SPACE, .value = "     " },
        Token{ .kind = TokenKind.LITERAL, .value = "world" },
    };

    try testCompareLexer(&tokens, &lexer);
}
