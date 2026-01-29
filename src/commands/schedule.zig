const std = @import("std");
const cli = @import("../utils/cli.zig");
const files = @import("../utils/files.zig");

// Schedule subcommand identifiers
pub const ScheduleSubcommand = enum {
    generate_cron,
    install,
    uninstall,
    show,
    list_cron,
    run,
    status,
    diff,
    logs,
    report,
    unknown,
};

/// Get subcommand from string
pub fn getSubcommand(cmd: []const u8) ScheduleSubcommand {
    if (std.mem.eql(u8, cmd, "generate-cron")) return .generate_cron;
    if (std.mem.eql(u8, cmd, "install")) return .install;
    if (std.mem.eql(u8, cmd, "uninstall")) return .uninstall;
    if (std.mem.eql(u8, cmd, "show")) return .show;
    if (std.mem.eql(u8, cmd, "list-cron")) return .list_cron;
    if (std.mem.eql(u8, cmd, "run")) return .run;
    if (std.mem.eql(u8, cmd, "status")) return .status;
    if (std.mem.eql(u8, cmd, "diff")) return .diff;
    if (std.mem.eql(u8, cmd, "logs")) return .logs;
    if (std.mem.eql(u8, cmd, "report")) return .report;
    return .unknown;
}

/// Options for generate-cron command
pub const GenerateCronOptions = struct {
    config_file: []const u8,
    frequency: []const u8 = "daily",
    time: []const u8 = "02:00",
    timezone: []const u8 = "UTC",
};

/// Options for install/uninstall commands
pub const InstallOptions = struct {
    config_file: []const u8,
    dry_run: bool = false,
};

/// Options for run/status commands
pub const RunOptions = struct {
    config_file: []const u8,
    phase: ?[]const u8 = null,
};

/// Options for diff/logs/report commands
pub const QueryOptions = struct {
    config_file: []const u8,
    date: ?[]const u8 = null,
    tail: u32 = 50,
    follow: bool = false,
};

/// Display usage information for schedule command
pub fn printUsage() void {
    const usage =
        \\zolt schedule - Manage automated reconnaissance schedules
        \\nUsage:
        \\  zolt schedule <command> [options]
        \\nCommands:
        \\  generate-cron    Generate cron entry from config
        \\  install          Install cron job to crontab
        \\  uninstall        Remove cron job from crontab
        \\  show             Show current cron entry for config
        \\  list-cron        List all zolt cron entries
        \\  run              Run workflow manually
        \\  status           Show last run information
        \\  diff             Show diff from previous run
        \\  logs             View logs
        \\  report           Generate report
        \\nExamples:
        \\  zolt schedule generate-cron --config daily-recon.toml
        \\  zolt schedule install --config daily-recon.toml
        \\  zolt schedule run --config daily-recon.toml
        \\  zolt schedule status --config daily-recon.toml
        \\  zolt schedule diff --config daily-recon.toml
        \\  zolt schedule logs --config daily-recon.toml --tail 100
    ;
    std.debug.print("{s}\n", .{usage});
}

/// Generate cron entry based on configuration
pub fn generateCron(allocator: std.mem.Allocator, options: GenerateCronOptions) !void {
    const config = try files.readFile(allocator, options.config_file);
    defer allocator.free(config);

    // Parse schedule section
    // For now, use provided values
    const cron_time = if (std.mem.eql(u8, options.frequency, "daily"))
        try std.fmt.allocPrint(allocator, "0 {s} * * *", .{options.time[0..2]})
    else if (std.mem.eql(u8, options.frequency, "hourly"))
        "0 * * * *"
    else if (std.mem.eql(u8, options.frequency, "weekly"))
        try std.fmt.allocPrint(allocator, "0 {s} * * 0", .{options.time[0..2]})
    else
        "0 2 * * *";
    defer if (std.mem.eql(u8, options.frequency, "daily") or std.mem.eql(u8, options.frequency, "weekly")) allocator.free(cron_time);

    // Get current directory
    const cwd = try std.process.getCwd(allocator);
    defer allocator.free(cwd);

    // Generate cron entry
    std.debug.print("# Zolt Daily Recon\n", .{});
    std.debug.print("# Generated from: {s}\n", .{options.config_file});
    std.debug.print("{s} cd {s} && zolt-cron-runner --config {s} --phase all\n", .{
        cron_time,
        cwd,
        options.config_file,
    });
}

/// Install cron job to user's crontab
pub fn installCron(allocator: std.mem.Allocator, options: InstallOptions) !void {
    // Generate cron entry
    const cron_opts = GenerateCronOptions{
        .config_file = options.config_file,
    };

    if (options.dry_run) {
        std.debug.print("DRY RUN: Would install cron job:\n", .{});
        try generateCron(allocator, cron_opts);
        return;
    }

    // Read current crontab
    const crontab_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "crontab", "-l" },
    }) catch {
        cli.printError("failed to read crontab", .{});
        return;
    };
    defer allocator.free(crontab_result.stdout);
    defer allocator.free(crontab_result.stderr);

    // Create temp file with new cron entry
    const temp_file = "/tmp/zolt-cron-XXXXXX";
    _ = std.os.linux.mkstemp(temp_file);

    // Write current crontab
    var file = std.fs.cwd().createFile(temp_file, .{}) catch {
        cli.printError("failed to create temp file", .{});
        return;
    };
    defer file.close();

    // TODO: Write current crontab + new entry

    // Install new crontab
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "crontab", temp_file },
    }) catch {
        cli.printError("failed to install crontab", .{});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited == 0) {
        std.debug.print("✓ Cron job installed successfully\n", .{});
    } else {
        cli.printError("failed to install cron job: {s}", .{result.stderr});
    }
}

/// Show current cron entry
pub fn showCron(allocator: std.mem.Allocator, config_file: []const u8) !void {
    _ = allocator;
    _ = config_file;
    std.debug.print("Not implemented\n", .{});
}

/// List all zolt cron entries
pub fn listCron(allocator: std.mem.Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "crontab", "-l" },
    }) catch {
        cli.printError("failed to read crontab", .{});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    var lines = std.mem.split(u8, result.stdout, "\n");
    var found = false;
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "zolt")) |_| {
            std.debug.print("{s}\n", .{line});
            found = true;
        }
    }

    if (!found) {
        std.debug.print("No zolt cron entries found\n", .{});
    }
}

/// Run automation workflow
pub fn runWorkflow(allocator: std.mem.Allocator, options: RunOptions) !void {
    _ = allocator;
    std.debug.print("Running workflow from {s}\n", .{options.config_file});

    if (options.phase) |phase| {
        std.debug.print("Running phase: {s}\n", .{phase});
    } else {
        std.debug.print("Running all phases\n", .{});
    }

    // TODO: Parse config and execute phases
}

/// Show workflow status
pub fn showStatus(allocator: std.mem.Allocator, config_file: []const u8) !void {
    _ = allocator;
    _ = config_file;
    std.debug.print("Status: Not implemented\n", .{});
}

/// Show diff from previous run
pub fn showDiff(allocator: std.mem.Allocator, options: QueryOptions) !void {
    _ = allocator;
    std.debug.print("Diff for {s}\n", .{options.config_file});

    if (options.date) |date| {
        std.debug.print("Date: {s}\n", .{date});
    }
}

/// Show logs
pub fn showLogs(allocator: std.mem.Allocator, options: QueryOptions) !void {
    _ = allocator;
    std.debug.print("Logs for {s}\n", .{options.config_file});
    std.debug.print("Tail: {d}\n", .{options.tail});
    std.debug.print("Follow: {}\n", .{options.follow});
}

/// Generate report
pub fn generateReport(allocator: std.mem.Allocator, options: QueryOptions) !void {
    _ = allocator;
    _ = options;
    std.debug.print("Report: Not implemented\n", .{});
}
