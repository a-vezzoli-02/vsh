const std = @import("std");

pub fn getPath(allocator: std.mem.Allocator) []const u8 {
    return std.process.getEnvVarOwned(allocator, "PATH") catch "";
}

pub fn getPathIterator(allocator: std.mem.Allocator) std.mem.SplitIterator(u8, .scalar) {
    return std.mem.splitScalar(u8, getPath(allocator), std.fs.path.delimiter);
}
