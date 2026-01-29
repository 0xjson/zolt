const std = @import("std");

/// Valid organization types for bug bounty platforms
pub const VALID_ORGANIZATIONS = [_][]const u8{
    "hackerone",
    "bugcrowd",
    "intigriti",
};

/// Validate organization type
pub fn validateOrganization(org: []const u8) bool {
    for (VALID_ORGANIZATIONS) |valid_org| {
        if (std.mem.eql(u8, org, valid_org)) {
            return true;
        }
    }
    return false;
}

/// Validate company name (basic validation)
pub fn validateCompanyName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (name.len > 100) return false; // Reasonable length limit

    // Check for allowed characters (alphanumeric, spaces, hyphens, underscores)
    for (name) |char| {
        switch (char) {
            'a'...'z', 'A'...'Z', '0'...'9', ' ', '-', '_' => continue,
            else => return false,
        }
    }
    return true;
}

/// Validate file path exists
pub fn validateFileExists(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch return false;
    file.close();
    return true;
}

/// Validate directory path exists
pub fn validateDirectoryExists(path: []const u8) bool {
    const dir = std.fs.cwd().openDir(path, .{}) catch return false;
    dir.close();
    return true;
}

/// Validate that a path is safe (no directory traversal)
pub fn validateSafePath(path: []const u8) bool {
    if (std.mem.indexOf(u8, path, "..") != null) return false;
    if (std.mem.indexOf(u8, path, "//") != null) return false;
    if (path[0] == '/') return false; // Absolute paths not allowed in some contexts
    return true;
}

/// Validate URL format (basic check)
pub fn validateUrl(url: []const u8) bool {
    const valid_prefixes = [_][]const u8{
        "http://",
        "https://",
        "ftp://",
    };

    for (valid_prefixes) |prefix| {
        if (std.mem.startsWith(u8, url, prefix)) {
            return true;
        }
    }
    return false;
}

/// Validate domain format (basic check)
pub fn validateDomain(domain: []const u8) bool {
    if (domain.len == 0 or domain.len > 253) return false;

    // Simple domain validation - must contain at least one dot
    // and only allowed characters
    var has_dot = false;
    for (domain) |char| {
        switch (char) {
            'a'...'z', 'A'...'Z', '0'...'9', '-', '.' => {
                if (char == '.') has_dot = true;
            },
            else => return false,
        }
    }

    return has_dot and !std.mem.startsWith(u8, domain, ".") and !std.mem.endsWith(u8, domain, ".");
}

/// Validate that all required options are provided
pub fn validateRequiredOptions(comptime T: type, options: T, fields: []const []const u8) bool {
    inline for (std.meta.fields(T)) |field| {
        for (fields) |required_field| {
            if (std.mem.eql(u8, field.name, required_field)) {
                const value = @field(options, field.name);
                if (field.type == []const u8 and value.len == 0) {
                    return false;
                }
                if (@typeInfo(field.type) == .Optional and value == null) {
                    return false;
                }
            }
        }
    }
    return true;
}

/// Validate command-line arguments count
pub fn validateArgCount(min_args: usize, max_args: usize, actual: usize) bool {
    return actual >= min_args and actual <= max_args;
}

/// Print validation error and usage
pub fn printValidationError(comptime message: []const u8, args: anytype) void {
    std.debug.print("Error: " ++ message ++ "\n", args);
}
