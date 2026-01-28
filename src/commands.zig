const ParserCommand = @import("parser.zig").ParserCommand;
const std = @import("std");
const Options = @import("options.zig").Options;
const Io = std.Io;
const IoError = Io.Writer.Error;
const string = []const u8;
const fs = @import("fs.zig");

pub const ExecutableContext = struct {
    allocator: std.mem.Allocator,
    options: *Options,
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
    .{ .name = "set", .handler = set_cmd },
    .{ .name = "show", .handler = show_cmd },
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

fn set_cmd(context: ExecutableContext) IoError!void {
    if (context.parser_command.args.len < 2) {
        try context.stdout.print("type: missing arg(s)\n", .{});
    }

    if (context.parser_command.args.len > 2) {
        try context.stdout.print("type: too many args\n", .{});
    }

    const field_name = context.parser_command.args[0];
    const value = context.parser_command.args[1];

    if (std.mem.eql(u8, field_name.value, "show_pwd")) {
        context.options.show_pwd = std.mem.eql(u8, value.value, "true");
    } else if (std.mem.eql(u8, field_name.value, "tail_pwd")) {
        context.options.tail_pwd = std.fmt.parseInt(u8, value.value, 10) catch {
            try context.stdout.print("set: {s} is not a positive number\n", .{value.value});
            return;
        };
    } else {
        try context.stdout.print("set: unknown field {s}\n", .{field_name.value});
    }
}

fn show_cmd(context: ExecutableContext) IoError!void {
    const arg = if (context.parser_command.args.len > 0) context.parser_command.args[0].value else "";

    if (std.mem.eql(u8, arg, "show_pwd") or arg.len == 0) {
        try context.stdout.print("show_pwd: {s}\n", .{if (context.options.show_pwd) "true" else "false"});
    }
    if (std.mem.eql(u8, arg, "tail_pwd") or arg.len == 0) {
        try context.stdout.print("tail_pwd: {d}\n", .{context.options.tail_pwd});
    }
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
