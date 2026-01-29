const std = @import("std");

/// Check if Go is installed and available in PATH
pub fn checkGoInstallation() bool {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{"go", "version"},
    }) catch {
        return false;
    };

    defer {
        std.heap.page_allocator.free(result.stdout);
        std.heap.page_allocator.free(result.stderr);
    }

    return result.term.Exited == 0;
}

/// Get Go version if installed
pub fn getGoVersion() ?[]const u8 {
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &.{"go", "version"},
    }) catch {
        return null;
    };

    defer {
        std.heap.page_allocator.free(result.stderr);
    }

    if (result.term.Exited == 0) {
        return result.stdout;
    } else {
        std.heap.page_allocator.free(result.stdout);
        return null;
    }
}

/// Install Go (placeholder - provides instructions)
pub fn installGo(allocator: std.mem.Allocator) void {
    _ = allocator;
    std.debug.print("  Please install Go manually from https://golang.org/dl/\n", .{});
    std.debug.print("  After installation, make sure 'go' is in your PATH\n", .{});
    std.debug.print("  Then run 'zolt tools install' again\n", .{});
    std.process.exit(1);
}

/// Check if a command exists in PATH
pub fn commandExists(allocator: std.mem.Allocator, command: []const u8) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "which", command },
    }) catch {
        return false;
    };

    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    return result.term.Exited == 0;
}

/// Get current working directory
pub fn getCurrentDirectory(allocator: std.mem.Allocator) ![]const u8 {
    return std.fs.cwd().realpathAlloc(allocator, ".");
}

/// Check if directory exists
pub fn directoryExists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch {
        return false;
    };
    return true;
}

/// Check if file exists
pub fn fileExists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch {
        return false;
    };
    return true;
}

/// Create directory if it doesn't exist
pub fn ensureDirectoryExists(path: []const u8) !void {
    std.fs.cwd().makePath(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}
