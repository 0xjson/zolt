const std = @import("std");
const env = @import("environment.zig");

/// Create an empty file at the specified path
pub fn createEmptyFile(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    file.close();
}

/// Create a directory structure (multiple levels)
pub fn createDirectory(path: []const u8) !void {
    try std.fs.cwd().makePath(path);
}

/// Write content to a file
pub fn writeFile(_: std.mem.Allocator, path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(content);
}

/// Read file content
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024);
}

/// Append content to a file
pub fn appendToFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .write_only });
    defer file.close();

    try file.seekFromEnd(0);
    try file.writeAll(content);
}

/// Copy a file from source to destination
pub fn copyFile(source: []const u8, destination: []const u8) !void {
    const source_file = try std.fs.cwd().openFile(source, .{});
    defer source_file.close();

    const dest_file = try std.fs.cwd().createFile(destination, .{});
    defer dest_file.close();

    const size_limit = 100 * 1024 * 1024;
    var buffer: [8192]u8 = undefined;
    var total_copied: u64 = 0;

    while (true) {
        const bytes_read = try source_file.read(&buffer);
        if (bytes_read == 0) break;

        if (total_copied + bytes_read > size_limit) {
            return error.FileTooLarge;
        }

        try dest_file.writeAll(buffer[0..bytes_read]);
        total_copied += bytes_read;
    }
}

/// Delete a file
pub fn deleteFile(path: []const u8) !void {
    try std.fs.cwd().deleteFile(path);
}

/// Delete a directory and all its contents (recursive)
pub fn deleteDirectory(path: []const u8) !void {
    try std.fs.cwd().deleteTree(path);
}

/// Get file size
pub fn getFileSize(path: []const u8) !u64 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    return stat.size;
}

/// List files in a directory
pub fn listFiles(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(allocator);
    defer result.deinit();

    var dir = try std.fs.cwd().openIterableDir(path, .{});
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file) {
            try result.append(try allocator.dupe(u8, entry.name));
        }
    }

    return result.toOwnedSlice();
}

/// Create multiple empty files at once
pub fn createFiles(allocator: std.mem.Allocator, base_path: []const u8, files: []const []const u8) void {
    for (files) |file| {
        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_path, file }) catch continue;
        defer allocator.free(full_path);

        createEmptyFile(full_path) catch |err| {
            std.debug.print("  Failed to create {s}: {}\n", .{ full_path, err });
            continue;
        };
        std.debug.print("  Created: {s}\n", .{full_path});
    }
}

/// Create multiple directories at once
pub fn createDirectories(allocator: std.mem.Allocator, base_path: []const u8, dirs: []const []const u8) void {
    for (dirs) |dir| {
        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_path, dir }) catch continue;
        defer allocator.free(full_path);

        createDirectory(full_path) catch |err| {
            std.debug.print("  Failed to create {s}: {}\n", .{ full_path, err });
            continue;
        };
        std.debug.print("  Created: {s}\n", .{full_path});
    }
}
