const std = @import("std");
const registry = @import("../registry/tools.zig");
const env = @import("../utils/environment.zig");

/// Install all bug bounty tools from the registry
pub fn install(allocator: std.mem.Allocator) void {
    std.debug.print("Installing bug bounty tools...\n", .{});

    // Check if Go is installed
    const go_installed = env.checkGoInstallation();
    if (!go_installed) {
        std.debug.print("Go is not installed. Installing latest Go...\n", .{});
        env.installGo(allocator);
    } else {
        std.debug.print("Go is already installed.\n", .{});
    }

    // Install all tools from registry
    std.debug.print("\nInstalling tools...\n", .{});
    for (registry.TOOLS) |tool| {
        std.debug.print("  Installing {s}... ", .{tool.name});
        installTool(allocator, tool.go_path);
        std.debug.print("✓\n", .{});
    }

    std.debug.print("\n✓ All tools installed successfully!\n", .{});
}

/// Install a single tool using go install
fn installTool(allocator: std.mem.Allocator, go_path: []const u8) void {
    const argv = [_][]const u8{
        "go",
        "install",
        "-v",
        go_path,
    };

    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    _ = child.spawnAndWait() catch {
        std.debug.print("✗\n", .{});
        std.debug.print("  Warning: Failed to install from {s}\n", .{go_path});
        return;
    };
}
