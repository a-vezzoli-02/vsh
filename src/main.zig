const std = @import("std");
const Io = std.Io;

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
    if (std.mem.eql(u8, "exit", first)) {
        std.process.exit(0);
    } else if (std.mem.eql(u8, "echo", first)) {
        try echo(tokenizer);
    } else {
        try stdout.print("{s}: command not found\n", .{first});
    }
}

fn echo(tokenizer: *TokenizerIterator) !void {
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

const TokenizerIterator = struct {
    const Self = @This();

    command: string,
    index: usize = 0,
    done: bool = false,

    pub fn init(command: string) Self {
        return .{ .command = command };
    }

    pub fn next(self: *Self) ?string {
        const start = self.index;

        while (self.index < self.command.len - 1) {
            self.index += 1;
            switch (self.command[self.index]) {
                ' ' => {
                    const slice = self.command[start..self.index];
                    self.index += 1;
                    return slice;
                },
                else => {},
            }
        }

        if (self.done) {
            return null;
        } else {
            self.done = true;
            return self.command[start..];
        }
    }
};
