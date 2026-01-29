const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "zolt",
        .root_source_file = b.path("zolt.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the executable
    b.installArtifact(exe);

    // Run the app
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing args to the run command
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const test_step = b.step("test", "Run all tests");

    // Test commands
    const test_commands = b.addTest(.{
        .root_source_file = b.path("src/commands/init.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_tools = b.addTest(.{
        .root_source_file = b.path("src/commands/tools.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_registry = b.addTest(.{
        .root_source_file = b.path("src/registry/tools.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_utils = b.addTest(.{
        .root_source_file = b.path("src/utils/validation.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_step.dependOn(&test_commands.step);
    test_step.dependOn(&test_tools.step);
    test_step.dependOn(&test_registry.step);
    test_step.dependOn(&test_utils.step);
}
