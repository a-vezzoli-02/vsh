const std = @import("std");
const Io = std.Io;

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

var input_buffer: [4096]u8 = undefined;
var reader = std.fs.File.stdin().readerStreaming(&input_buffer);
const stdin = &reader.interface;

pub fn main() !void {
    while (true) {
        const command = try prompt_new_line();
        try handle_command(command);
    }
}

fn prompt_new_line() !?[]const u8 {
    try stdout.print("$ ", .{});
    return try stdin.takeDelimiter('\n');
}

fn handle_command(command: ?[]const u8) !void {
    if (command) |c| {
        if (c.len == 0) {
            try stdout.print("\n", .{});
        } else {
            try stdout.print("{s}: command not found\n", .{c});
        }
    } else {
        try stdout.print("\n", .{});
    }
}
