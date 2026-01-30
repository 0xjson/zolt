const std = @import("std");
const tools_cmd = @import("src/commands/tools.zig");
const init_cmd = @import("src/commands/init.zig");
const schedule_cmd = @import("src/commands/schedule.zig");
const validation = @import("src/utils/validation.zig");
const cli = @import("src/utils/cli.zig");

const usage =
    \\zolt - Bug Bounty CLI Tool
    \\
    \\Usage:
    \\  zolt <command> [options]
    \\
    \\Commands:
    \\  tools install     Install all bug bounty tools
    \\  init              Initialize a new bug bounty target
    \\
    \\Examples:
    \\  zolt tools install
    \\  zolt init -o hackerone -c "Assa Abloy" -w subdomains.txt
    \\
    \\Options:
    \\  init:
    \\    -o, --organization <name>    Organization (hackerone|bugcrowd|intigriti)
    \\    -c, --company <name>         Company name
    \\    -w, --wildcard-subdomains <file> File containing subdomains
    \\
    \\@actuallyzolt zolt v0.1.0
;

pub fn main() u8 {
    const allocator = std.heap.page_allocator;

    // Parse args using 0.15.2 API
    const args = std.process.argsAlloc(allocator) catch {
        std.debug.print("Failed to parse args\n", .{});
        return 1;
    };
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(usage, .{});
        return 0;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "tools")) {
        // Existing tools command logic
        if (args.len < 3 or !std.mem.eql(u8, args[2], "install")) {
            cli.printError("tools expects a subcommand (install)", .{});
            std.debug.print(usage, .{});
            return 1;
        }

        tools_cmd.install(allocator);
    } else if (std.mem.eql(u8, command, "init")) {
        // Parse options from args[2..]
        if (args.len < 4) {
            cli.printError("init requires options (-o, -c)", .{});
            std.debug.print(usage, .{});
            return 1;
        }

        // Build args slice starting from index 2
        var args_list: [100][]const u8 = undefined;
        var count: usize = 0;

        for (2..args.len) |i| {
            if (count >= 100) break;
            args_list[count] = args[i];
            count += 1;
        }

        const options = parseInitOptions(allocator, args_list[0..count]) catch {
            return 1;
        };
        defer if (options.company.len > 0) allocator.free(options.company);

        init_cmd.initialize(allocator, options);
    } else if (std.mem.eql(u8, command, "schedule")) {
        // New schedule command from subagent designs
        if (args.len < 3) {
            schedule_cmd.printUsage();
            return 1;
        }

        const subcommand = schedule_cmd.getSubcommand(args[2]);

        // Build args slice starting from index 3 for subcommand parsing
        var args_list: [100][]const u8 = undefined;
        var count: usize = 0;

        for (3..args.len) |i| {
            if (count >= 100) break;
            args_list[count] = args[i];
            count += 1;
        }

        switch (subcommand) {
            .generate_cron => {
                const opts = parseGenerateCronOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.generateCron(allocator, opts) catch {
                    cli.printError("failed to generate cron", .{});
                    return 1;
                };
            },
            .install => {
                const opts = parseInstallOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.installCron(allocator, opts) catch {
                    cli.printError("failed to install cron", .{});
                    return 1;
                };
            },
            .list_cron => {
                schedule_cmd.listCron(allocator) catch {
                    cli.printError("failed to list cron", .{});
                    return 1;
                };
            },
            .show => {
                if (count == 0 or !std.mem.eql(u8, args_list[0], "--config")) {
                    cli.printError("--config <file> required", .{});
                    return 1;
                }
                schedule_cmd.showCron(allocator, args_list[1]) catch {
                    cli.printError("failed to show cron", .{});
                    return 1;
                };
            },
            .run => {
                const opts = parseRunOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.runWorkflow(allocator, opts) catch {
                    cli.printError("failed to run workflow", .{});
                    return 1;
                };
            },
            .status => {
                if (count == 0 or !std.mem.eql(u8, args_list[0], "--config")) {
                    cli.printError("--config <file> required", .{});
                    return 1;
                }
                schedule_cmd.showStatus(allocator, args_list[1]) catch {
                    cli.printError("failed to show status", .{});
                    return 1;
                };
            },
            .monitor => {
                const opts = parseRunOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.monitorWorkflow(allocator, opts) catch |err| {
                    std.debug.print("Error: {}\n", .{err});
                    cli.printError("failed to monitor workflow", .{});
                    return 1;
                };
            },
            .diff => {
                const opts = parseQueryOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.showDiff(allocator, opts) catch {
                    cli.printError("failed to show diff", .{});
                    return 1;
                };
            },
            .logs => {
                const opts = parseQueryOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.showLogs(allocator, opts) catch {
                    cli.printError("failed to show logs", .{});
                    return 1;
                };
            },
            .report => {
                const opts = parseQueryOptions(allocator, args_list[0..count]) catch {
                    return 1;
                };
                schedule_cmd.generateReport(allocator, opts) catch {
                    cli.printError("failed to generate report", .{});
                    return 1;
                };
            },
            else => {
                schedule_cmd.printUsage();
                return 1;
            },
        }
    } else {
        cli.printError("unknown command '{s}'", .{command});
        std.debug.print(usage, .{});
        return 1;
    }

    return 0;
}

/// Parse init command options
fn parseInitOptions(allocator: std.mem.Allocator, args: []const []const u8) !init_cmd.InitOptions {
    var options = init_cmd.InitOptions{
        .organization = "",
        .company = "",
        .wildcard_subdomains_file = null,
    };

    var organization_set = false;
    var company_set = false;
    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--organization")) {
            if (i + 1 >= args.len) {
                cli.printError("-o/--organization requires a value", .{});
                std.process.exit(1);
            }
            const org = args[i + 1];
            i += 1;

            if (!validation.validateOrganization(org)) {
                cli.printError("organization must be one of: hackerone, bugcrowd, intigriti", .{});
                std.process.exit(1);
            }

            options.organization = org;
            organization_set = true;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--company")) {
            if (i + 1 >= args.len) {
                cli.printError("-c/--company requires a value", .{});
                std.process.exit(1);
            }
            const company = args[i + 1];
            i += 1;

            if (!validation.validateCompanyName(company)) {
                cli.printError("invalid company name", .{});
                std.process.exit(1);
            }

            options.company = try replaceSpacesWithUnderscores(allocator, company);
            company_set = true;
        } else if (std.mem.eql(u8, arg, "-w") or std.mem.eql(u8, arg, "--wildcard-subdomains")) {
            if (i + 1 >= args.len) {
                cli.printError("-w/--wildcard-subdomains requires a file path", .{});
                std.process.exit(1);
            }

            const file_path = args[i + 1];
            i += 1;

            if (!validation.validateFileExists(file_path)) {
                cli.printError("file not found: {s}", .{file_path});
                std.process.exit(1);
            }

            options.wildcard_subdomains_file = file_path;
        } else {
            cli.printError("unknown option '{s}'", .{arg});
            std.debug.print(usage, .{});
            std.process.exit(1);
        }
    }

    if (!organization_set or !company_set) {
        cli.printError("-o/--organization and -c/--company are required", .{});
        std.debug.print(usage, .{});
        std.process.exit(1);
    }

    return options;
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

/// Parse generate-cron command options
fn parseGenerateCronOptions(_: std.mem.Allocator, args: []const []const u8) !schedule_cmd.GenerateCronOptions {
    var options = schedule_cmd.GenerateCronOptions{
        .config_file = "",
        .frequency = "daily",
        .time = "02:00",
        .timezone = "UTC",
    };

    var config_set = false;
    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--config")) {
            if (i + 1 >= args.len) {
                cli.printError("--config requires a file path", .{});
                std.process.exit(1);
            }
            options.config_file = args[i + 1];
            i += 1;
            config_set = true;
        } else if (std.mem.eql(u8, arg, "--frequency")) {
            if (i + 1 >= args.len) {
                cli.printError("--frequency requires a value", .{});
                std.process.exit(1);
            }
            options.frequency = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--time")) {
            if (i + 1 >= args.len) {
                cli.printError("--time requires a time value", .{});
                std.process.exit(1);
            }
            options.time = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--timezone")) {
            if (i + 1 >= args.len) {
                cli.printError("--timezone requires a timezone", .{});
                std.process.exit(1);
            }
            options.timezone = args[i + 1];
            i += 1;
        } else {
            cli.printError("unknown option '{s}'", .{arg});
            schedule_cmd.printUsage();
            std.process.exit(1);
        }
    }

    if (!config_set) {
        cli.printError("--config <file> is required", .{});
        std.process.exit(1);
    }

    return options;
}

/// Parse install command options
fn parseInstallOptions(_: std.mem.Allocator, args: []const []const u8) !schedule_cmd.InstallOptions {
    var options = schedule_cmd.InstallOptions{
        .config_file = "",
        .dry_run = false,
    };

    var config_set = false;
    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--config")) {
            if (i + 1 >= args.len) {
                cli.printError("--config requires a file path", .{});
                std.process.exit(1);
            }
            options.config_file = args[i + 1];
            i += 1;
            config_set = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            options.dry_run = true;
        } else {
            cli.printError("unknown option '{s}'", .{arg});
            schedule_cmd.printUsage();
            std.process.exit(1);
        }
    }

    if (!config_set) {
        cli.printError("--config <file> is required", .{});
        std.process.exit(1);
    }

    return options;
}

/// Parse run command options
fn parseRunOptions(_: std.mem.Allocator, args: []const []const u8) !schedule_cmd.RunOptions {
    var options = schedule_cmd.RunOptions{
        .config_file = "",
        .phase = null,
    };

    var config_set = false;
    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--config")) {
            if (i + 1 >= args.len) {
                cli.printError("--config requires a file path", .{});
                std.process.exit(1);
            }
            options.config_file = args[i + 1];
            i += 1;
            config_set = true;
        } else if (std.mem.eql(u8, arg, "--phase")) {
            if (i + 1 >= args.len) {
                cli.printError("--phase requires a phase name", .{});
                std.process.exit(1);
            }
            options.phase = args[i + 1];
            i += 1;
        } else {
            cli.printError("unknown option '{s}'", .{arg});
            schedule_cmd.printUsage();
            std.process.exit(1);
        }
    }

    if (!config_set) {
        cli.printError("--config <file> is required", .{});
        std.process.exit(1);
    }

    return options;
}

/// Parse query command options (for diff/logs/report)
fn parseQueryOptions(_: std.mem.Allocator, args: []const []const u8) !schedule_cmd.QueryOptions {
    var options = schedule_cmd.QueryOptions{
        .config_file = "",
        .date = null,
        .tail = 50,
        .follow = false,
    };

    var config_set = false;
    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--config")) {
            if (i + 1 >= args.len) {
                cli.printError("--config requires a file path", .{});
                std.process.exit(1);
            }
            options.config_file = args[i + 1];
            i += 1;
            config_set = true;
        } else if (std.mem.eql(u8, arg, "--date")) {
            if (i + 1 >= args.len) {
                cli.printError("--date requires a date value", .{});
                std.process.exit(1);
            }
            options.date = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, arg, "--tail")) {
            if (i + 1 >= args.len) {
                cli.printError("--tail requires a number", .{});
                std.process.exit(1);
            }
            options.tail = std.fmt.parseUnsigned(u32, args[i + 1], 10) catch |err| {
                cli.printError("invalid tail value: {}", .{err});
                std.process.exit(1);
            };
            i += 1;
        } else if (std.mem.eql(u8, arg, "--follow")) {
            options.follow = true;
        } else {
            cli.printError("unknown option '{s}'", .{arg});
            schedule_cmd.printUsage();
            std.process.exit(1);
        }
    }

    if (!config_set) {
        cli.printError("--config <file> is required", .{});
        std.process.exit(1);
    }

    return options;
}
