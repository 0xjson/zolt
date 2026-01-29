const std = @import("std");
const cli = @import("../utils/cli.zig");

// Notification subcommands
pub const NotifySubcommand = enum {
    send,
    test,
    unknown,
};

/// Get subcommand from string
pub fn getSubcommand(cmd: []const u8) NotifySubcommand {
    if (std.mem.eql(u8, cmd, "send")) return .send;
    if (std.mem.eql(u8, cmd, "test")) return .test;
    return .unknown;
}

/// Display notification usage
pub fn printUsage() void {
    const usage =
        \\zolt notify - Send notifications about reconnaissance results
        \\nUsage:
        \\  zolt notify <command> [options]
        \\nCommands:
        \\  send      Send notifications from diff results
        \\  test      Test notification configuration
        \\nExamples:
        \\  zolt notify send --config daily-recon.toml --date 2026-01-29
        \\  zolt notify test --config daily-recon.toml
    ;
    std.debug.print("{s}\n", .{usage});
}

/// Send notification based on diff results
pub fn sendNotification(allocator: std.mem.Allocator, config_file: []const u8, date: ?[]const u8) !void {
    _ = allocator;
    _ = date;

    std.debug.print("Sending notification for {s}\n", .{config_file});

    // TODO:
    // 1. Read config for notification settings
    // 2. Check if diff results exist
    // 3. Calculate change percentage
    // 4. If above threshold, send notifications
    // 5. Support Discord, Slack, and Email
    // 6. Format message with stats and top findings

    std.debug.print("Notification: Not fully implemented\n", .{});
}

/// Test notification configuration
pub fn testNotification(allocator: std.mem.Allocator, config_file: []const u8) !void {
    _ = allocator;
    std.debug.print("Testing notification configuration: {s}\n", .{config_file});

    // TODO:
    // 1. Read config for notification providers
    // 2. Send test message to each configured provider
    // 3. Report success/failure for each

    std.debug.print("Test notification: Not implemented\n", .{});
}
