const std = @import("std");
const lex = @import("lexer.zig");
const Lexer = lex.Lexer;
const Token = lex.Token;
const TokenKind = lex.TokenKind;

const string = []const u8;

pub const ParserLiteral = struct {
    tokens: []const Token,
    value: string,
};
pub const ParserCommand = struct {
    name: ParserLiteral,
    args: []const ParserLiteral,
};

pub const Parser = struct {
    const Self = @This();

    arena_allocator: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    pub fn initSelf(self: *Self, allocator: std.mem.Allocator) void {
        self.arena_allocator = std.heap.ArenaAllocator.init(allocator);
        self.allocator = self.arena_allocator.allocator();
    }

    pub fn deinit(self: *Self) void {
        self.arena_allocator.deinit();
    }

    pub fn parseLexer(self: *Self, lexer: *Lexer) !?ParserCommand {
        var nodes = std.ArrayList(ParserLiteral).initCapacity(self.allocator, 1) catch unreachable;
        var buffer = std.ArrayList(Token).initCapacity(self.allocator, 1) catch unreachable;

        var ignore_space = false;
        while (lexer.next()) |token| {
            if (token.kind == .SPACE and !ignore_space) {
                try nodes.append(self.allocator, try literal(self.allocator, try buffer.toOwnedSlice(self.allocator)));
                buffer.clearRetainingCapacity();
            } else {
                if (token.kind == .QUOTE) {
                    ignore_space = !ignore_space;
                }
                try buffer.append(self.allocator, token);
            }
        }

        if (ignore_space) {
            return error.UnexpectedEOF;
        }

        if (buffer.items.len > 0) {
            try nodes.append(self.allocator, try literal(self.allocator, try buffer.toOwnedSlice(self.allocator)));
            buffer.clearRetainingCapacity();
        }

        if (nodes.items.len == 0) {
            return null;
        }

        return command(nodes.items);
    }
};

fn command(nodes: []const ParserLiteral) ParserCommand {
    return ParserCommand{ .name = nodes[0], .args = nodes[1..] };
}

fn literal(allocator: std.mem.Allocator, tokens: []const Token) !ParserLiteral {
    var filtered = std.ArrayList(string).initCapacity(allocator, 1) catch unreachable;
    for (tokens) |token| {
        if (token.kind != .QUOTE) {
            filtered.append(allocator, token.value) catch unreachable;
        }
    }

    const joined: string = try std.mem.join(allocator, "", filtered.items);
    return ParserLiteral{ .value = joined, .tokens = tokens };
}

fn testParse(input: string, expected: ParserCommand) !void {
    var lexer = Lexer.init(input);

    var parser: Parser = undefined;
    parser.initSelf(std.testing.allocator);
    defer parser.deinit();

    const actual = try parser.parseLexer(&lexer);
    try std.testing.expectEqualDeep(expected, actual);
}

test "parser - single word" {
    const input = "echo";

    const expected =
        ParserCommand{
            .name = ParserLiteral{ .value = "echo", .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "echo" }} },
            .args = &[_]ParserLiteral{},
        };

    try testParse(input, expected);
}

test "parser - simple test" {
    const input = "echo hello world";

    const expected =
        ParserCommand{
            .name = ParserLiteral{ .value = "echo", .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "echo" }} },
            .args = &[_]ParserLiteral{
                ParserLiteral{
                    .value = "hello",
                    .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "hello" }},
                },
                ParserLiteral{
                    .value = "world",
                    .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "world" }},
                },
            },
        };

    try testParse(input, expected);
}

test "parser - long space" {
    const input = "echo hello     world";

    const expected =
        ParserCommand{
            .name = ParserLiteral{ .value = "echo", .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "echo" }} },
            .args = &[_]ParserLiteral{
                ParserLiteral{
                    .value = "hello",
                    .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "hello" }},
                },
                ParserLiteral{
                    .value = "world",
                    .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "world" }},
                },
            },
        };

    try testParse(input, expected);
}

test "parser - quote" {
    const input = "echo 'hello' world";

    const expected =
        ParserCommand{
            .name = ParserLiteral{ .value = "echo", .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "echo" }} },
            .args = &[_]ParserLiteral{
                ParserLiteral{
                    .value = "hello",
                    .tokens = &[_]Token{
                        Token{ .kind = TokenKind.QUOTE, .value = "'" },
                        Token{ .kind = TokenKind.LITERAL, .value = "hello" },
                        Token{ .kind = TokenKind.QUOTE, .value = "'" },
                    },
                },
                ParserLiteral{
                    .value = "world",
                    .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "world" }},
                },
            },
        };

    try testParse(input, expected);
}

test "parser - double word quote" {
    const input = "echo 'hello world'";

    const expected =
        ParserCommand{
            .name = ParserLiteral{ .value = "echo", .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "echo" }} },
            .args = &[_]ParserLiteral{
                ParserLiteral{
                    .value = "hello world",
                    .tokens = &[_]Token{
                        Token{ .kind = TokenKind.QUOTE, .value = "'" },
                        Token{ .kind = TokenKind.LITERAL, .value = "hello" },
                        Token{ .kind = TokenKind.SPACE, .value = " " },
                        Token{ .kind = TokenKind.LITERAL, .value = "world" },
                        Token{ .kind = TokenKind.QUOTE, .value = "'" },
                    },
                },
            },
        };

    try testParse(input, expected);
}

test "parser - empty quote" {
    const input = "echo hello''world";

    const expected =
        ParserCommand{
            .name = ParserLiteral{ .value = "echo", .tokens = &[_]Token{Token{ .kind = TokenKind.LITERAL, .value = "echo" }} },
            .args = &[_]ParserLiteral{
                ParserLiteral{
                    .value = "helloworld",
                    .tokens = &[_]Token{
                        Token{ .kind = TokenKind.LITERAL, .value = "hello" },
                        Token{ .kind = TokenKind.QUOTE, .value = "'" },
                        Token{ .kind = TokenKind.QUOTE, .value = "'" },
                        Token{ .kind = TokenKind.LITERAL, .value = "world" },
                    },
                },
            },
        };

    try testParse(input, expected);
}
