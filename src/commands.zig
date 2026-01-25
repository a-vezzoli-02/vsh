const ParserCommand = @import("parser.zig").ParserCommand;
const std = @import("std");
const Io = std.Io;
const IoError = Io.Writer.Error;
const string = []const u8;
const fs = @import("fs.zig");

pub const ExecutableContext = struct {
    allocator: std.mem.Allocator,
    stdout: *Io.Writer,
    parser_command: *const ParserCommand,
    path: *fs.PathContext,
};

const Command = struct {
    is_builtin: bool = true,
    name: string,
    handler: *const fn (ExecutableContext) IoError!void,
};

const Executable = union(enum) {
    command: Command,
    path: string,
};

const commands = [_]Command{
    .{ .name = "exit", .handler = exit_cmd },
    .{ .name = "echo", .handler = echo_cmd },
    .{ .name = "type", .handler = type_cmd },
    .{ .name = "pwd", .handler = pwd_cmd },
    .{ .name = "cd", .handler = cd_cmd },
};

pub fn find_executable(allocator: std.mem.Allocator, name: string) ?Executable {
    for (commands) |command| {
        if (std.mem.eql(u8, command.name, name)) {
            return Executable{ .command = command };
        }
    }

    const path = fs.find_first_executable_path(allocator, name);

    if (path) |p| {
        return Executable{ .path = p };
    }

    return null;
}

fn exit_cmd(context: ExecutableContext) IoError!void {
    _ = context;
    std.process.exit(0);
}

fn echo_cmd(context: ExecutableContext) IoError!void {
    var is_first = true;
    for (context.parser_command.args) |arg| {
        if (!is_first) {
            try context.stdout.print(" ", .{});
        } else {
            is_first = false;
        }
        try context.stdout.print("{s}", .{arg.value});
    }
    try context.stdout.print("\n", .{});
}

fn type_cmd(context: ExecutableContext) IoError!void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (context.parser_command.args.len < 1) {
        try context.stdout.print("type: missing arg\n", .{});
    }

    if (context.parser_command.args.len > 1) {
        try context.stdout.print("type: too many args\n", .{});
    }

    const arg = context.parser_command.args[0];

    const command = find_executable(allocator, arg.value);
    if (command) |c| {
        switch (c) {
            .command => |cmd| {
                try context.stdout.print("{s} is a shell builtin\n", .{cmd.name});
            },
            .path => |path| {
                try context.stdout.print("{s} is {s}\n", .{ arg.value, path });
            },
        }
    } else {
        try context.stdout.print("{s}: not found\n", .{arg.value});
    }
}

fn pwd_cmd(context: ExecutableContext) IoError!void {
    try context.stdout.print("{s}\n", .{context.path.pwd});
}

fn cd_cmd(context: ExecutableContext) IoError!void {
    const arg = if (context.parser_command.args.len > 0) context.parser_command.args[0].value else "";
    context.path.cd(context.allocator, arg) catch |err| switch (err) {
        error.InvalidPath => try context.stdout.print("cd: {s}: No such file or directory\n", .{arg}),
        else => try context.stdout.print("cd: {s}: {s}\n", .{ arg, @errorName(err) }),
    };
}

pub fn run_path_executable(context: ExecutableContext) IoError!void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argv = std.ArrayList(string).initCapacity(allocator, 1) catch unreachable;
    argv.append(allocator, context.parser_command.name.value) catch unreachable;

    for (context.parser_command.args) |arg| {
        argv.append(allocator, arg.value) catch unreachable;
    }

    var child = std.process.Child.init(argv.items, allocator);
    child.cwd = context.path.pwd;
    child.stdout_behavior = .Inherit;
    child.stdin_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = child.spawnAndWait() catch |err| {
        try context.stdout.print("failed to run {s}: {s}\n", .{ argv.items[0], @errorName(err) });
    };
}
