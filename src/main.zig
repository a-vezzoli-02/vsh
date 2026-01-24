const std = @import("std");
const Io = std.Io;

const TokenizerIterator = @import("tokenizer.zig").TokenizerIterator;
const commands = @import("commands.zig");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

var input_buffer: [4096]u8 = undefined;
var reader = std.fs.File.stdin().readerStreaming(&input_buffer);
const stdin = &reader.interface;

const string = []const u8;

pub fn main() !void {
    while (true) {
        const command = try prompt_new_line();
        try handle_command(command);
    }
}

fn prompt_new_line() !?string {
    try stdout.print("$ ", .{});
    return try stdin.takeDelimiter('\n');
}

fn handle_command(command: ?string) !void {
    if (command) |c| {
        if (c.len == 0) {
            try stdout.print("\n", .{});
        } else {
            try handle_command_tokenize(c);
        }
    } else {
        try stdout.print("\n", .{});
    }
}

fn handle_command_tokenize(command: string) !void {
    var tokenizer = TokenizerIterator.init(command);
    const first = tokenizer.next();
    if (first) |f| {
        try handle_command_tokenize_first(f, &tokenizer);
    } else {
        try stdout.print("\n", .{});
    }
}

fn handle_command_tokenize_first(first: string, tokenizer: *TokenizerIterator) !void {
    const command = commands.find_command(first);
    if (command) |c| {
        return c.handler(stdout, tokenizer);
    } else {
        try stdout.print("{s}: command not found\n", .{first});
    }
}
