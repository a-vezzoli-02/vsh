const std = @import("std");
const builtin = @import("builtin");

pub fn getPath(allocator: std.mem.Allocator) []const u8 {
    return std.process.getEnvVarOwned(allocator, "PATH") catch "";
}

pub fn getPathIterator(allocator: std.mem.Allocator) std.mem.SplitIterator(u8, .scalar) {
    return std.mem.splitScalar(u8, getPath(allocator), std.fs.path.delimiter);
}

pub fn getHome(allocator: std.mem.Allocator) []const u8 {
    return switch (builtin.os.tag) {
        .windows => return std.process.getEnvVarOwned(allocator, "USERPROFILE") catch "",
        else => std.process.getEnvVarOwned(allocator, "HOME") catch "",
    };
}
