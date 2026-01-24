const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");

const TokenizerIterator = @import("tokenizer.zig").TokenizerIterator;
const commands = @import("commands.zig");
const fs = @import("fs.zig");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

var input_buffer: [4096]u8 = undefined;
var reader = std.fs.File.stdin().readerStreaming(&input_buffer);
const stdin = &reader.interface;

const string = []const u8;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator, const is_smp = switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), false },
        .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, true },
    };
    defer if (!is_smp) {
        _ = debug_allocator.deinit();
    };

    var path_context: fs.PathContext = undefined;
    path_context.initSelf();
    defer path_context.deinit();

    while (true) {
        const command = try prompt_new_line();
        try handle_command(
            allocator,
            &path_context,
            command,
        );
    }
}

fn prompt_new_line() !?string {
    try stdout.print("$ ", .{});
    return try stdin.takeDelimiter('\n');
}

fn handle_command(
    allocator: std.mem.Allocator,
    path_context: *fs.PathContext,
    command: ?string,
) !void {
    if (command) |c| {
        if (c.len == 0) {
            try stdout.print("\n", .{});
        } else {
            try handle_command_tokenize(
                allocator,
                path_context,
                c,
            );
        }
    } else {
        try stdout.print("\n", .{});
    }
}

fn handle_command_tokenize(
    allocator: std.mem.Allocator,
    path_context: *fs.PathContext,
    command: string,
) !void {
    var tokenizer = TokenizerIterator.init(command);
    const first = tokenizer.next();
    if (first) |f| {
        try handle_command_tokenize_first(
            allocator,
            path_context,
            f,
            &tokenizer,
        );
    } else {
        try stdout.print("\n", .{});
    }
}

fn handle_command_tokenize_first(
    allocator: std.mem.Allocator,
    path_context: *fs.PathContext,
    first: string,
    tokenizer: *TokenizerIterator,
) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const command = commands.find_executable(allocator, first);
    if (command) |c| {
        const context = commands.ExecutableContext{
            .allocator = arena_allocator,
            .stdout = stdout,
            .tokenizer = tokenizer,
            .path = path_context,
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
