const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");

const par = @import("parser.zig");
const Parser = par.Parser;
const ParserCommand = par.ParserCommand;
const Lexer = @import("lexer.zig").Lexer;
const Options = @import("options.zig").Options;
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

    var options = Options{};

    while (true) {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const command = try prompt_new_line(arena_allocator, &options, &path_context);

        try handle_command(
            arena_allocator,
            &options,
            &path_context,
            command,
        );
    }
}

fn prompt_new_line(allocator: std.mem.Allocator, options: *const Options, path_context: *const fs.PathContext) !?string {
    if (options.show_pwd) {
        if (options.tail_pwd == 0) {
            try stdout.print("{s}", .{path_context.pwd});
        } else {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();

            var list = std.ArrayList(string).empty;

            var reached_root = false;
            var components = try std.fs.path.componentIterator(path_context.pwd);
            if (components.last()) |last| {
                try list.append(arena_allocator, last.name);

                for (1..options.tail_pwd) |_| {
                    if (components.previous()) |next| {
                        try list.append(arena_allocator, next.name);
                    } else {
                        reached_root = true;
                        break;
                    }
                }
            }

            std.mem.reverse(string, list.items);
            const concat = try std.mem.join(arena_allocator, "/", list.items);

            if (reached_root) {
                try stdout.print("/", .{});
            }
            try stdout.print("{s}", .{concat});
        }
    }
    try stdout.print("$ ", .{});
    return try stdin.takeDelimiter('\n');
}

fn handle_command(
    allocator: std.mem.Allocator,
    options: *Options,
    path_context: *fs.PathContext,
    command: ?string,
) !void {
    if (command) |c| {
        if (c.len == 0) {
            try stdout.print("\n", .{});
        } else {
            try handle_command_tokenize(
                allocator,
                options,
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
    options: *Options,
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
            options,
            path_context,
            pcom,
        );
    } else {
        try stdout.print("\n", .{});
    }
}

fn handle_command_tokenize_first(
    allocator: std.mem.Allocator,
    options: *Options,
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
            .options = options,
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
