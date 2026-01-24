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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const command = commands.find_executable(allocator, first);
    if (command) |c| {
        const context = commands.ExecutableContext{
            .allocator = allocator,
            .stdout = stdout,
            .tokenizer = tokenizer,
        };
        switch (c) {
            .command => |cmd| {
                return cmd.handler(context);
            },
            .path => {
                return commands.run_path_executable(context);
            },
        }
    } else {
        try stdout.print("{s}: command not found\n", .{first});
    }
}
