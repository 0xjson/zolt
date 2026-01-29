const std = @import("std");

pub const InitOptions = struct {
    organization: []const u8,
    company: []const u8,
    wildcard_subdomains_file: ?[]const u8,
};

/// Initialize bug bounty target directory structure
pub fn initialize(allocator: std.mem.Allocator, options: InitOptions) void {
    const target_dir = replaceSpacesWithUnderscores(allocator, options.company) catch {
        std.debug.print("Error: failed to process company name\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(target_dir);

    std.debug.print("Initializing bug bounty target for {s}...\n", .{target_dir});

    // Create directory structure
    createDirectoryStructure(allocator, target_dir);

    // Create empty recon files
    createReconFiles(allocator, target_dir);

    std.debug.print("\n✓ Successfully initialized {s}/\n", .{target_dir});
}

/// Replace spaces with underscores in company name
fn replaceSpacesWithUnderscores(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, input.len);
    for (input, 0..) |char, i| {
        if (char == ' ') {
            result[i] = '_';
        } else {
            result[i] = char;
        }
    }
    return result;
}

/// Create complete directory structure for bug bounty target
fn createDirectoryStructure(allocator: std.mem.Allocator, target: []const u8) void {
    std.debug.print("\nCreating directory structure...\n", .{});

    // Directory structure as defined in requirements
    const base_dirs = [_][]const u8{
        "burp/snapshots",
        "recon/subdomains/history",
        "recon/subdomains/passive",
        "recon/subdomains/active",
        "recon/urls/history",
        "recon/js/downloaded",
        "recon/vhosts/history",
        "recon/cloud/history",
        "recon/directories/history",
        "recon/ports/history",
        "recon/screenshots/alive",
        "recon/screenshots/admin",
        "recon/screenshots/api",
        "recon/tech",
        "mapping",
        "manual/auth",
        "manual/idor",
        "manual/sqli",
        "manual/xss",
        "manual/logic",
        "findings/drafts",
        "findings/submitted",
        "findings/accepted",
        "screenshots/burp",
        "screenshots/poc",
        "logs/daily",
        "logs/weekly",
        "logs/monthly",
    };

    for (base_dirs) |dir| {
        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ target, dir }) catch continue;
        defer allocator.free(full_path);
        std.fs.cwd().makePath(full_path) catch {
            std.debug.print("  Failed: {s}\n", .{full_path});
            continue;
        };
        std.debug.print("  Created: {s}\n", .{full_path});
    }
}

/// Create empty recon files for tracking reconnaissance data
fn createReconFiles(allocator: std.mem.Allocator, target: []const u8) void {
    std.debug.print("\nCreating recon files...\n", .{});

    // Files to create for reconnaissance
    const recon_files = [_][]const u8{
        // Subdomain reconnaissance
        "recon/subdomains/passive/passive.txt",
        "recon/subdomains/passive/amass.txt",
        "recon/subdomains/passive/all.txt",
        "recon/subdomains/active/bruteforce.txt",
        "recon/subdomains/active/permutations.txt",
        "recon/subdomains/fdns.txt",
        "recon/subdomains/all.txt",
        "recon/subdomains/alive.txt",

        // URL reconnaissance
        "recon/urls/crawl.txt",
        "recon/urls/wayback.txt",
        "recon/urls/params.txt",
        "recon/urls/alive.txt",

        // Directory reconnaissance
        "recon/directories/admin.txt",
        "recon/directories/api.txt",

        // Port reconnaissance
        "recon/ports/open.txt",
        "recon/ports/services.txt",

        // Tech reconnaissance
        "recon/tech/fingerprints.txt",

        // JavaScript reconnaissance
        "recon/js/files.txt",
        "recon/js/linkfinder.txt",
        "recon/js/secrets.txt",
        "recon/js/params.txt",

        // Virtual hosts reconnaissance
        "recon/vhosts/candidates.txt",
        "recon/vhosts/resolved.txt",
        "recon/vhosts/alive.txt",

        // Cloud reconnaissance
        "recon/cloud/ips.txt",
        "recon/cloud/providers.txt",
        "recon/cloud/buckets.txt",
        "recon/cloud/services.txt",
    };

    for (recon_files) |file| {
        const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ target, file }) catch continue;
        defer allocator.free(full_path);
        const file_handle = std.fs.cwd().createFile(full_path, .{}) catch {
            std.debug.print("  Failed: {s}\n", .{full_path});
            continue;
        };
        file_handle.close();
        std.debug.print("  Created: {s}\n", .{full_path});
    }
}
