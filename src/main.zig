const std = @import("std");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

pub fn main() !void {
    // TODO: Uncomment the code below to pass the first stage
    try stdout.print("$ ", .{});

    var input_buffer: [4096]u8 = undefined;
    var reader = std.fs.File.stdin().readerStreaming(&input_buffer);
    const stdin = &reader.interface;

    const command = try stdin.takeDelimiter('\n');

    if (command) |c| {
        try stdout.print("{s}: command not found\n", .{c});
    } else {
        try stdout.print("EOF\n", .{});
    }
}
