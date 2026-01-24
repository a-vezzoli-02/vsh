const std = @import("std");
const env = @import("env.zig");
const builtin = @import("builtin");
const string = []const u8;

const valid_windows_executable_extensions = [_]string{ ".exe", ".cmd", ".bat", ".com" };

pub const PathContext = struct {
    const Self = @This();
    buffer: [4096]u8,
    buffer_allocator: std.heap.FixedBufferAllocator,
    allocator: std.mem.Allocator,
    pwd: string,

    pub fn initSelf(self: *Self) void {
        self.buffer = undefined;
        self.buffer_allocator = std.heap.FixedBufferAllocator.init(&self.buffer);
        self.allocator = self.buffer_allocator.allocator();
        self.pwd = std.process.getCwdAlloc(self.allocator) catch unreachable;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.pwd);
    }

    pub fn cd(self: *Self, path: string) !void {
        const new_path = try std.fs.path.resolve(self.allocator, &[_]string{ self.pwd, path });
        if (!exists(new_path)) return error.InvalidPath;

        self.allocator.free(self.pwd);
        self.pwd = new_path;
    }
};

pub fn find_first_executable_path(allocator: std.mem.Allocator, command: string) ?string {
    var path_iterator = env.getPathIterator(allocator);

    while (path_iterator.next()) |p| {
        if (exists(p)) {
            var dir = std.fs.openDirAbsolute(p, .{ .iterate = true }) catch continue;
            defer dir.close();

            var iterator = dir.iterate();

            while (iterator.next() catch continue) |entry| {
                if (entry.kind == .file and std.mem.eql(u8, entry.name, command)) {
                    if (is_executable(dir, entry)) {
                        return std.fs.path.join(allocator, &[_]string{ p, entry.name }) catch unreachable;
                    }
                }
            }
        }
    }

    return null;
}

pub fn is_executable(dir: std.fs.Dir, entry: std.fs.Dir.Entry) bool {
    if (builtin.os.tag == .windows) {
        const extension = std.fs.path.extension(entry.name);
        for (valid_windows_executable_extensions) |ext| {
            if (std.mem.eql(u8, ext, extension)) {
                return true;
            }
        }
    } else {
        const file = dir.openFile(entry.name, .{}) catch return false;
        defer file.close();

        const mode = file.mode() catch return false;
        if (mode & 0o111 != 0) {
            return true;
        }
    }

    return false;
}

pub fn exists(path: string) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}
