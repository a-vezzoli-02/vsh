const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");

const par = @import("parser.zig");
const Parser = par.Parser;
const ParserCommand = par.ParserCommand;
const Lexer = @import("lexer.zig").Lexer;
const commands = @import("commands.zig");
const fs = @import("fs.zig");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

var input_buffer: [4096]u8 = undefined;
var reader = std.fs.File.stdin().readerStreaming(&input_buffer);
const stdin = &reader.interface;

const string = []const u8;

test "main" {
    std.testing.refAllDecls(@This());
}

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

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        try handle_command(
            arena.allocator(),
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
    var lexer = Lexer.init(command);
    var parser: Parser = undefined;
    parser.initSelf(allocator);
    defer parser.deinit();

    const parser_command = try parser.parseLexer(&lexer);

    if (parser_command) |*pcom| {
        try handle_command_tokenize_first(
            allocator,
            path_context,
            pcom,
        );
    } else {
        try stdout.print("\n", .{});
    }
}

fn handle_command_tokenize_first(
    allocator: std.mem.Allocator,
    path_context: *fs.PathContext,
    parser_command: *const ParserCommand,
) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const command = commands.find_executable(allocator, parser_command.name.value);
    if (command) |c| {
        const context = commands.ExecutableContext{
            .allocator = arena_allocator,
            .stdout = stdout,
            .parser_command = parser_command,
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
        try stdout.print("{s}: command not found\n", .{parser_command.name.value});
    }
}
