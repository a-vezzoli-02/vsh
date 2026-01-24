const TokenizerIterator = @import("tokenizer.zig").TokenizerIterator;
const std = @import("std");
const Io = std.Io;
const IoError = Io.Writer.Error;
const string = []const u8;

const Command = struct {
    name: string,
    handler: *const fn (*Io.Writer, *TokenizerIterator) IoError!void,
};

const commands: [3]Command = [_]Command{
    .{ .name = "exit", .handler = exit_cmd },
    .{ .name = "echo", .handler = echo_cmd },
    .{ .name = "type", .handler = type_cmd },
};

pub fn find_command(first: string) ?Command {
    for (commands) |command| {
        if (std.mem.eql(u8, command.name, first)) {
            return command;
        }
    }
    return null;
}

fn exit_cmd(stdout: *Io.Writer, tokenizer: *TokenizerIterator) IoError!void {
    _ = tokenizer;
    _ = stdout;
    std.process.exit(0);
}

fn echo_cmd(stdout: *Io.Writer, tokenizer: *TokenizerIterator) IoError!void {
    var is_first = true;
    while (tokenizer.next()) |arg| {
        if (!is_first) {
            try stdout.print(" ", .{});
        } else {
            is_first = false;
        }
        try stdout.print("{s}", .{arg});
    }
    try stdout.print("\n", .{});
}

fn type_cmd(stdout: *Io.Writer, tokenizer: *TokenizerIterator) IoError!void {
    const arg = tokenizer.next();
    if (arg) |a| {
        const command = find_command(a);
        if (command) |_| {
            try stdout.print("{s} is a shell builtin\n", .{a});
        } else {
            try stdout.print("{s}: not found\n", .{a});
        }
    } else {
        try stdout.print("type: missing arg\n", .{});
    }
}
