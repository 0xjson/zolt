const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const sort = std.sort;
const print = std.debug.print;

/// Diff result structure
pub const DiffResult = struct {
    additions: std.ArrayList([]const u8),
    removals: std.ArrayList([]const u8),
    // Items that changed (same "key" but different value)
    changes: std.ArrayList(DiffChange),

clean(self: *DiffResult, allocator: mem.Allocator) void {
        for (self.additions.items) |item| {
            allocator.free(item);
        }
        self.additions.deinit();

        for (self.removals.items) |item| {
            allocator.free(item);
        }
        self.removals.deinit();

        for (self.changes.items) |change| {
            allocator.free(change.old_value);
            allocator.free(change.new_value);
        }
        self.changes.deinit();
    }
};

pub const DiffChange = struct {
    key: []const u8,
    old_value: []const u8,
    new_value: []const u8,
};

/// Compare two files and return diff results
pub fn diffFiles(
    allocator: mem.Allocator,
    old_file: []const u8,
    new_file: []const u8,
    options: DiffOptions,
) !DiffResult {
    // Read files
    const old_content = try readFile(allocator, old_file);
    defer allocator.free(old_content);

    const new_content = try readFile(allocator, new_file);
    defer allocator.free(new_content);

    // Split into lines
    var old_lines = std.ArrayList([]const u8).init(allocator);
    defer old_lines.deinit();

    var new_lines = std.ArrayList([]const u8).init(allocator);
    defer new_lines.deinit();

    var old_it = mem.split(u8, old_content, "\n");
    while (old_it.next()) |line| {
        if (line.len == 0) continue;
        try old_lines.append(line);
    }

    var new_it = mem.split(u8, new_content, "\n");
    while (new_it.next()) |line| {
        if (line.len == 0) continue;
        try new_lines.append(line);
    }

    // Sort lines if needed
    if (options.sort) {
        // Create mutable copies for sorting
        var old_mutable = try copyLines(allocator, old_lines.items);
        defer freeLines(allocator, old_mutable);

        var new_mutable = try copyLines(allocator, new_lines.items);
        defer freeLines(allocator, new_mutable);

        sort.sort([]const u8, old_mutable, {}, lineLessThan);
        sort.sort([]const u8, new_mutable, {}, lineLessThan);

        return try diffSorted(allocator, old_mutable, new_mutable, options);
    } else {
        return try diffUnsorted(allocator, old_lines.items, new_lines.items, options);
    }
}

/// Options for diff operation
pub const DiffOptions = struct {
    sort: bool = true,
    ignore_case: bool = false,
    ignore_whitespace: bool = false,
    consider_additions_only: bool = true,
    consider_removals: bool = false,
    unique_only: bool = true,
    // Function to extract key from line (for structured data)
    key_extractor: ?fn ([]const u8) []const u8 = null,
};

/// Diff two already-sorted arrays
fn diffSorted(
    allocator: mem.Allocator,
    old_lines: [][]const u8,
    new_lines: [][]const u8,
    options: DiffOptions,
) !DiffResult {
    var result = DiffResult{
        .additions = std.ArrayList([]const u8).init(allocator),
        .removals = std.ArrayList([]const u8).init(allocator),
        .changes = std.ArrayList(DiffChange).init(allocator),
    };

    var old_idx: usize = 0;
    var new_idx: usize = 0;

    while (old_idx < old_lines.len and new_idx < new_lines.len) {
        const old_line = old_lines[old_idx];
        const new_line = new_lines[new_idx];

        const comp = if (options.ignore_case)
            std.ascii.lowerString(allocator, old_line) catch unreachable,
            std.ascii.lowerString(allocator, new_line) catch unreachable
        else
            std.mem.order(u8, old_line, new_line);

        if (comp == .eq) {
            // Same line in both
            old_idx += 1;
            new_idx += 1;
        } else if (comp == .lt) {
            // In old but not in new (removal)
            if (options.consider_removals) {
                const copy = try allocator.dupe(u8, old_line);
                try result.removals.append(copy);
            }
            old_idx += 1;
        } else {
            // In new but not in old (addition)
            if (options.consider_additions_only or options.consider_removals) {
                const copy = try allocator.dupe(u8, new_line);
                try result.additions.append(copy);
            }
            new_idx += 1;
        }
    }

    // Remaining lines in old (removals)
    if (options.consider_removals) {
        while (old_idx < old_lines.len) : (old_idx += 1) {
            const copy = try allocator.dupe(u8, old_lines[old_idx]);
            try result.removals.append(copy);
        }
    }

    // Remaining lines in new (additions)
    while (new_idx < new_lines.len) : (new_idx += 1) {
        if (options.consider_additions_only or options.consider_removals) {
            const copy = try allocator.dupe(u8, new_lines[new_idx]);
            try result.additions.append(copy);
        }
    }

    return result;
}

/// Diff unsorted arrays (O(n^2) but preserves order)
fn diffUnsorted(
    allocator: mem.Allocator,
    old_lines: [][]const u8,
    new_lines: [][]const u8,
    options: DiffOptions,
) !DiffResult {
    var result = DiffResult{
        .additions = std.ArrayList([]const u8).init(allocator),
        .removals = std.ArrayList([]const u8).init(allocator),
        .changes = std.ArrayList(DiffChange).init(allocator),
    };

    // Build hash set of old lines for lookup
    var old_set = std.StringHashMap(void).init(allocator);
    defer old_set.deinit();

    for (old_lines) |line| {
        const key = if (options.key_extractor) |extractor|
            extractor(line)
        else if (options.ignore_case)
            std.ascii.lowerString(allocator, line) catch unreachable
        else
            line;

        try old_set.put(key, {});
    }

    // Find additions (in new but not in old)
    for (new_lines) |line| {
        const key = if (options.key_extractor) |extractor|
            extractor(line)
        else if (options.ignore_case)
            std.ascii.lowerString(allocator, line) catch unreachable
        else
            line;

        if (!old_set.contains(key)) {
            const copy = try allocator.dupe(u8, line);
            try result.additions.append(copy);
        }
    }

    // If considering removals, do the reverse
    if (options.consider_removals) {
        var new_set = std.StringHashMap(void).init(allocator);
        defer new_set.deinit();

        for (new_lines) |line| {
            const key = if (options.key_extractor) |extractor|
                extractor(line)
            else if (options.ignore_case)
                std.ascii.lowerString(allocator, line) catch unreachable
            else
                line;

            try new_set.put(key, {});
        }

        for (old_lines) |line| {
            const key = if (options.key_extractor) |extractor|
                extractor(line)
            else if (options.ignore_case)
                std.ascii.lowerString(allocator, line) catch unreachable
            else
                line;

            if (!new_set.contains(key)) {
                const copy = try allocator.dupe(u8, line);
                try result.removals.append(copy);
            }
        }
    }

    return result;
}

/// Compare two files using hash comparison (for detecting changes)
pub fn diffByHash(
    allocator: mem.Allocator,
    old_file: []const u8,
    new_file: []const u8,
) !DiffResult {
    _ = allocator;
    _ = old_file;
    _ = new_file;
    // Implementation would calculate hashes per line
    // Useful for detecting modified content, not just additions/removals
    return DiffResult{
        .additions = std.ArrayList([]const u8).init(allocator),
        .removals = std.ArrayList([]const u8).init(allocator),
        .changes = std.ArrayList(DiffChange).init(allocator),
    };
}

/// Free memory allocated for diff result
pub fn freeDiffResult(allocator: mem.Allocator, result: *DiffResult) void {
    for (result.additions.items) |item| {
        allocator.free(item);
    }
    result.additions.deinit();

    for (result.removals.items) |item| {
        allocator.free(item);
    }
    result.removals.deinit();

    for (result.changes.items) |change| {
        allocator.free(change.key);
        allocator.free(change.old_value);
        allocator.free(change.new_value);
    }
    result.changes.deinit();
}

/// Helper functions

fn readFile(allocator: mem.Allocator, path: []const u8) ![]u8 {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, stat.size);
    return content;
}

fn copyLines(allocator: mem.Allocator, lines: [][]const u8) ![][]u8 {
    var copies = try allocator.alloc([]u8, lines.len);
    for (lines, 0..) |line, i| {
        copies[i] = try allocator.dupe(u8, line);
    }
    return copies;
}

fn freeLines(allocator: mem.Allocator, lines: [][]u8) void {
    for (lines) |line| {
        allocator.free(line);
    }
    allocator.free(lines);
}

fn lineLessThan(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    return std.mem.lessThan(u8, a, b);
}

/// Generate a diff report
pub fn generateDiffReport(
    allocator: mem.Allocator,
    result: *DiffResult,
    title: []const u8,
    options: ReportOptions,
) ![]u8 {
    var report = std.ArrayList(u8).init(allocator);
    errdefer report.deinit();

    const writer = report.writer();

    // Title
    try writer.print("# {s}\n\n", .{title});

    // Summary
    try writer.print("**Additions**: {}\n", .{result.additions.items.len});
    if (options.show_removals) {
        try writer.print("**Removals**: {}\n", .{result.removals.items.len});
    }
    if (options.show_changes) {
        try writer.print("**Changes**: {}\n", .{result.changes.items.len});
    }
    try writer.print("\n", .{});

    // Additions
    if (result.additions.items.len > 0) {
        try writer.print("## Additions\n\n", .{});
        const limit = if (options.max_items > 0)
            @min(options.max_items, result.additions.items.len)
        else
            result.additions.items.len;

        for (result.additions.items[0..limit]) |item| {
            try writer.print("+ {s}\n", .{item});
        }

        if (result.additions.items.len > limit) {
            try writer.print("\n... and {} more\n", .{result.additions.items.len - limit});
        }
        try writer.print("\n", .{});
    }

    // Removals
    if (options.show_removals and result.removals.items.len > 0) {
        try writer.print("## Removals\n\n", .{});
        for (result.removals.items) |item| {
            try writer.print("- {s}\n", .{item});
        }
        try writer.print("\n", .{});
    }

    // Changes
    if (options.show_changes and result.changes.items.len > 0) {
        try writer.print("## Changes\n\n", .{});
        for (result.changes.items) |change| {
            try writer.print("~ {s}\n", .{change.key});
            try writer.print("  - {s}\n", .{change.old_value});
            try writer.print("  + {s}\n", .{change.new_value});
        }
        try writer.print("\n", .{});
    }

    return report.toOwnedSlice();
}

pub const ReportOptions = struct {
    show_removals: bool = false,
    show_changes: bool = false,
    max_items: usize = 100,
    format: Format = .markdown,
};

pub const Format = enum {
    markdown,
    json,
    html,
    csv,
};

/// Find yesterday's file based on pattern
pub fn findYesterdayFile(
    allocator: mem.Allocator,
    directory: []const u8,
    base_name: []const u8,
    date: []const u8,
) !?[]u8 {
    _ = base_name;

    // Parse today's date
    var today_parts = mem.split(u8, date, "-");
    const year = try std.fmt.parseInt(u32, today_parts.next() orelse return null, 10);
    const month = try std.fmt.parseInt(u32, today_parts.next() orelse return null, 10);
    const day = try std.fmt.parseInt(u32, today_parts.next() orelse return null, 10);

    // Calculate yesterday
    // Note: This is simplified - real implementation would handle month/year boundaries
    const yesterday_day = if (day > 1) day - 1 else 1;
    const yesterday_str = try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        year, month, yesterday_day,
    });
    defer allocator.free(yesterday_str);

    // Build file path
    var dir = fs.cwd().openDir(directory, .{ .iterate = true }) catch return null;
    defer dir.close();

    var result_path: ?[]u8 = null;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        // Check if this is yesterday's file
        const name = entry.name;
        if (mem.indexOf(u8, name, yesterday_str)) |_| {
            result_path = try allocator.dupe(u8, name);
            break;
        }
    }

    if (result_path) |path| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ directory, path });
        allocator.free(path);
        return full_path;
    }

    return null;
}

test "diffFiles - basic comparison" {
    const allocator = std.testing.allocator;

    const old_content =
        \\sub1.example.com
        \\sub2.example.com
        \\sub3.example.com
    ;

    const new_content =
        \\sub1.example.com
        \\sub2.example.com
        \\sub4.example.com
        \\sub5.example.com
    ;

    // Write test files
    try std.fs.cwd().writeFile("test_old.txt", old_content);
    try std.fs.cwd().writeFile("test_new.txt", new_content);
    defer std.fs.cwd().deleteFile("test_old.txt") catch {};
    defer std.fs.cwd().deleteFile("test_new.txt") catch {};

    var result = try diffFiles(
        allocator,
        "test_old.txt",
        "test_new.txt",
        .{ .sort = true, .consider_additions_only = true },
    );
    defer freeDiffResult(allocator, &result);

    try std.testing.expectEqual(@as(usize, 2), result.additions.items.len);
}
