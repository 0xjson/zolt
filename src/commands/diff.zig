const std = @import("std");
const cli = @import("../utils/cli.zig");
const files = @import("../utils/files.zig");

// Diff subcommands
pub const DiffSubcommand = enum {
    run,
    show,
    history,
    unknown,
};

/// Get subcommand from string
pub fn getSubcommand(cmd: []const u8) DiffSubcommand {
    if (std.mem.eql(u8, cmd, "run")) return .run;
    if (std.mem.eql(u8, cmd, "show")) return .show;
    if (std.mem.eql(u8, cmd, "history")) return .history;
    return .unknown;
}

/// Display diff usage
pub fn printUsage() void {
    const usage =
        \\zolt diff - Compare reconnaissance results with previous runs
        \\nUsage:
        \\  zolt diff <command> [options]
        \\nCommands:
        \\  run       Run diff comparison on tracked files
        \\  show      Show diff results
        \\  history   Manage history files
        \\nExamples:
        \\  zolt diff run --config daily-recon.toml --date 2026-01-29
        \\  zolt diff show --config daily-recon.toml --type subdomains
        \\  zolt diff history --config daily-recon.toml --clean
    ;
    std.debug.print("{s}\n", .{usage});
}

/// Run diff comparison
pub fn runDiff(allocator: std.mem.Allocator, config_file: []const u8, date: ?[]const u8) !void {
    // Read config to get comparison settings
    const config_content = try files.readFile(allocator, config_file);
    defer allocator.free(config_content);

    // Use provided date or today's date
    const today = date orelse try getCurrentDate(allocator);
    defer if (date == null) allocator.free(today);

    std.debug.print("Running diff for date: {s}\n", .{today});

    // TODO: Parse config and get comparison.track entries
    // For each tracked file:
    // 1. Check if history file exists for previous date
    // 2. Run comm/sort/uniq to find differences
    // 3. Save diff results
    // 4. Show statistics

    std.debug.print("Diff comparison completed\n", .{});
}

/// Get current date (YYYY-MM-DD)
fn getCurrentDate(allocator: std.mem.Allocator) ![]const u8 {
    // Simple implementation for now
    return try allocator.dupe(u8, "2026-01-29");
}

/// Show diff results
pub fn showDiff(allocator: std.mem.Allocator, config_file: []const u8, filter_type: ?[]const u8) !void {
    _ = allocator;
    std.debug.print("Diff results for {s}\n", .{config_file});

    if (filter_type) |ftype| {
        std.debug.print("Filter: {s}\n", .{ftype});
    }

    // TODO: Read diff results from files and display
    std.debug.print("Show diff: Not fully implemented\n", .{});
}

/// Manage history files
pub fn manageHistory(allocator: std.mem.Allocator, config_file: []const u8, action: []const u8) !void {
    _ = allocator;
    _ = config_file;

    if (std.mem.eql(u8, action, "clean")) {
        std.debug.print("Cleaning old history files...\n", .{});
        // TODO: Remove history files older than retention period
    } else if (std.mem.eql(u8, action, "list")) {
        std.debug.print("Listing history files...\n", .{});
        // TODO: List all history files
    } else {
        cli.printError("unknown action '{s}'", .{action});
    }
}
