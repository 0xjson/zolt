const std = @import("std");
const validation = @import("validation.zig");

pub const ArgIterator = struct {
    args: []const []const u8,
    index: usize,

    pub fn init(args: []const []const u8) ArgIterator {
        return .{
            .args = args,
            .index = 0,
        };
    }

    pub fn next(self: *ArgIterator) ?[]const u8 {
        if (self.index >= self.args.len) return null;
        defer self.index += 1;
        return self.args[self.index];
    }

    pub fn peek(self: *ArgIterator) ?[]const u8 {
        if (self.index >= self.args.len) return null;
        return self.args[self.index];
    }

    pub fn skip(self: *ArgIterator) bool {
        if (self.index >= self.args.len) return false;
        self.index += 1;
        return true;
    }
};

pub const ParsedOption = struct {
    option: []const u8,
    value: ?[]const u8,
};

/// Parse command line options into a map
pub fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !std.StringHashMap([]const u8) {
    var options = std.StringHashMap([]const u8).init(allocator);
    errdefer options.deinit();

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.startsWith(u8, arg, "-")) {
            const value = if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-"))
                args[i + 1]
            else
                "";
            try options.put(arg, value);
        }
    }

    return options;
}

/// Parse option with validation
pub fn parseOptionWithValidation(
    args: []const []const u8,
    comptime short: []const u8,
    comptime long: []const u8,
    comptime error_msg: []const u8,
) ?[]const u8 {
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, short) or std.mem.eql(u8, arg, long)) {
            if (i + 1 >= args.len) {
                validation.printValidationError(error_msg, .{});
                return null;
            }
            return args[i + 1];
        }
    }
    return null;
}

/// Check if option is present
pub fn hasOption(args: []const []const u8, comptime option: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, option)) {
            return true;
        }
    }
    return false;
}

/// Print error message with context
pub fn printError(comptime message: []const u8, args: anytype) void {
    std.debug.print("Error: " ++ message ++ "\n", args);
}

/// Print warning message
pub fn printWarning(comptime message: []const u8, args: anytype) void {
    std.debug.print("Warning: " ++ message ++ "\n", args);
}

/// Print success message
pub fn printSuccess(comptime message: []const u8, args: anytype) void {
    std.debug.print("✓ " ++ message ++ "\n", args);
}

/// Print info message
pub fn printInfo(comptime message: []const u8, args: anytype) void {
    std.debug.print("Info: " ++ message ++ "\n", args);
}

/// Clear terminal screen
pub fn clearScreen() void {
    std.debug.print("\x1B[2J\x1B[H", .{});
}

/// Print colored output (if terminal supports it)
pub const Color = enum {
    red,
    green,
    yellow,
    blue,
    reset,
};

pub fn printColored(color: Color, comptime message: []const u8, args: anytype) void {
    const color_code = switch (color) {
        .red => "\x1B[31m",
        .green => "\x1B[32m",
        .yellow => "\x1B[33m",
        .blue => "\x1B[34m",
        .reset => "\x1B[0m",
    };

    std.debug.print(color_code ++ message ++ "\x1B[0m\n", args);
}

/// Progress indicator
pub const Progress = struct {
    total: usize,
    current: usize,

    pub fn init(total: usize) Progress {
        return .{
            .total = total,
            .current = 0,
        };
    }

    pub fn update(self: *Progress) void {
        self.current += 1;
        const percentage = (@as(f64, @floatFromInt(self.current)) / @as(f64, @floatFromInt(self.total))) * 100.0;
        std.debug.print("\rProgress: {d:.0}% ({d}/{d})", .{ percentage, self.current, self.total });
    }

    pub fn finish(self: *Progress) void {
        std.debug.print("\n", .{});
    }
};
