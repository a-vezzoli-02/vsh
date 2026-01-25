const string = []const u8;

pub const TokenizerIterator = struct {
    const Self = @This();

    command: string,
    index: usize = 0,
    done: bool = false,
    single_quote: bool = false,

    pub fn init(command: string) Self {
        return .{ .command = command };
    }

    pub fn reset(self: *Self) void {
        self.index = 0;
        self.done = false;
    }

    pub fn copy(self: Self) Self {
        return .{
            .command = self.command,
            .index = self.index,
            .done = self.done,
        };
    }

    pub fn next(self: *Self) ?string {
        const start = self.index;

        while (self.index < self.command.len - 1) {
            self.index += 1;
            switch (self.command[self.index]) {
                ' ' => {
                    if (!self.single_quote) {
                        const slice = self.command[start..self.index];
                        self.index += 1;
                        return slice;
                    }
                },
                '\'' => self.single_quote = !self.single_quote,
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
