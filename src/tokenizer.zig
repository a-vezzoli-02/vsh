const string = []const u8;

pub const TokenizerIterator = struct {
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
