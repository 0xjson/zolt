const std = @import("std");
const events = @import("events.zig");
const EventBus = events.EventBus;
const ToolEvent = events.ToolEvent;
const EventType = events.EventType;
const execution_state = @import("execution_state.zig");
const ToolExecution = execution_state.ToolExecution;
const ToolState = execution_state.ToolState;
const ResourceMetrics = execution_state.ResourceMetrics;

/// Monitors running processes for crashes, timeouts, and resource usage
pub const HealthChecker = struct {
    allocator: std.mem.Allocator,
    event_bus: *EventBus,
    poll_interval_ms: u64,      // How often to check (milliseconds)
    resource_warning_threshold: ResourceMetrics,  // When to warn

    const Self = @This();

    /// Initialize health checker
    pub fn init(
        allocator: std.mem.Allocator,
        event_bus: *EventBus,
        poll_interval_ms: u64,
    ) Self {
        return Self{
            .allocator = allocator,
            .event_bus = event_bus,
            .poll_interval_ms = poll_interval_ms,
            .resource_warning_threshold = ResourceMetrics{
                .cpu_percent = 80.0,      // Warn at 80% CPU
                .memory_mb = 2048,        // Warn at 2GB RAM
                .disk_read_mb = 100,      // Warn at 100MB/s read
                .disk_write_mb = 100,     // Warn at 100MB/s write
                .network_rx_mb = 50,      // Warn at 50MB/s rx
                .network_tx_mb = 50,      // Warn at 50MB/s tx
            },
        };
    }

    /// Monitor a running process
    pub fn monitorProcess(
        self: *Self,
        execution: *ToolExecution,
        child: *std.process.Child,
    ) !void {
        const pid = child.id;

        std.debug.print("[HealthChecker] Monitoring PID {d} for tool {s}\n", .{
            pid,
            execution.tool_name,
        });

        // Check process until it exits
        while (true) {
            // Sleep for poll interval
            std.time.sleep(self.poll_interval_ms * std.time.ns_per_ms);

            // Check if process is still alive
            const is_alive = self.isProcessAlive(pid);

            if (!is_alive) {
                std.debug.print("[HealthChecker] Process {d} no longer alive\n", .{pid});

                // Check exit status
                const status = self.getProcessStatus(pid);

                if (status.exited) {
                    std.debug.print("[HealthChecker] Process exited with code {d}\n", .{status.code});
                    execution.markCompleted(std.time.timestamp(), status.code);

                    // Publish event
                    const event = ToolEvent{
                        .event_type = .tool_failed,
                        .timestamp = std.time.timestamp(),
                        .execution_id = execution.id,
                        .tool_name = execution.tool_name,
                        .phase_name = execution.phase_name,
                        .data = EventData{ .failed = .{
                            .end_time = std.time.timestamp(),
                            .exit_code = status.code,
                            .duration_ms = 0, // Will be calculated
                            .error = "Process exited",
                            .partial_output = null,
                        } },
                    };
                    try self.event_bus.publish(event);
                } else if (status.signaled) {
                    std.debug.print("[HealthChecker] Process killed by signal {d}\n", .{status.signal});
                    execution.markCrashed(std.time.timestamp(), status.signal);

                    // Publish crash event
                    const event = events.toolCrashed(
                        execution.id,
                        execution.tool_name,
                        execution.phase_name,
                        std.time.timestamp(),
                        status.signal,
                        status.core_dumped,
                        0, // duration will be calculated
                    );
                    try self.event_bus.publish(event);
                }
                break;
            }

            // Process still alive, check resource usage
            const resources = self.getResourceUsage(pid) catch continue;
            execution.updateResourceUsage(resources);

            // Check for resource warnings
            if (resources.memory_mb > self.resource_warning_threshold.memory_mb) {
                std.debug.print(
                    \\[HealthChecker] WARNING: High memory usage for {s}: {d}MB
                    \\
                    \\
                    \\
                    ,
                    .{
                        execution.tool_name,
                        resources.memory_mb,
                    },
                );

                const event = ToolEvent{
                    .event_type = .resource_warning,
                    .timestamp = std.time.timestamp(),
                    .execution_id = execution.id,
                    .tool_name = execution.tool_name,
                    .phase_name = execution.phase_name,
                    .data = EventData{ .resource = resources },
                };
                try self.event_bus.publish(event);
            }

            // Check for timeout
            if (execution.start_time) |start| {
                const elapsed_ms = (std.time.timestamp() - start) * 1000;
                if (execution.timeout_ms) |timeout| {
                    if (elapsed_ms > timeout) {
                        std.debug.print(
                            \\[HealthChecker] Timeout reached for {s}, killing process
                            \\
                            ,
                            .{execution.tool_name},
                        );

                        // Send SIGTERM for graceful shutdown
                        std.os.kill(pid, std.os.SIG.TERM) catch {};

                        // Wait a bit, then SIGKILL if still alive
                        std.time.sleep(2 * std.time.ns_per_s);
                        if (self.isProcessAlive(pid)) {
                            std.os.kill(pid, std.os.SIG.KILL) catch {};
                        }

                        execution.markTimeout(std.time.timestamp());

                        const event = events.toolTimeout(
                            execution.id,
                            execution.tool_name,
                            execution.phase_name,
                            std.time.timestamp(),
                            timeout,
                            elapsed_ms,
                            null,
                        );
                        try self.event_bus.publish(event);
                        break;
                    }
                }
            }
        }
    }

    /// Check if a process is still alive
    fn isProcessAlive(self: *Self, pid: u32) bool {
        _ = self;

        // Send signal 0 to check if process exists
        const result = std.os.linux.kill(@intCast(pid), 0);
        return result == 0;
    }

    /// Get exit status of a process
    fn getProcessStatus(self: *Self, pid: u32) struct {
        exited: bool,
        code: i32,
        signaled: bool,
        signal: i32,
        core_dumped: bool,
    } {
        _ = self;
        _ = pid;

        // Try to get exit status from waitpid (non-blocking)
        var status: i32 = 0;
        const result = std.os.linux.waitpid(@intCast(pid), &status, std.os.linux.W.NOCHANG);

        if (result > 0) {
            if (std.os.linux.W.IFEXITED(status)) {
                return .{
                    .exited = true,
                    .code = std.os.linux.W.EXITS(status),
                    .signaled = false,
                    .signal = 0,
                    .core_dumped = false,
                };
            } else if (std.os.linux.W.IFSIGNALED(status)) {
                return .{
                    .exited = false,
                    .code = 0,
                    .signaled = true,
                    .signal = std.os.linux.W.TERMS(status),
                    .core_dumped = std.os.linux.W.CORED(status),
                };
            }
        }

        // Can't determine status, assume still running
        return .{
            .exited = false,
            .code = 0,
            .signaled = false,
            .signal = 0,
            .core_dumped = false,
        };
    }

    /// Get current resource usage for a process
    fn getResourceUsage(self: *Self, pid: u32) !ResourceMetrics {
        _ = self;

        // This is a simplified version - in production, you'd read from /proc/{pid}/stat
        // and /proc/{pid}/status on Linux
        var metrics = ResourceMetrics{};

        // Try to read from /proc/{pid}/statm for memory usage (Linux-specific)
        const proc_path = try std.fmt.allocPrint(
            self.allocator,
            "/proc/{d}/statm",
            .{pid},
        );
        defer self.allocator.free(proc_path);

        if (std.fs.cwd().readFile(self.allocator, proc_path)) |content| {
            defer self.allocator.free(content);

            // Parse statm format: size resident share text lib data dt
            var it = std.mem.tokenize(u8, content, " ");
            if (it.next()) |size_str| {
                if (std.fmt.parseInt(u64, size_str, 10)) |size_pages| {
                    // Convert pages to MB (assuming 4KB pages)
                    metrics.memory_mb = size_pages * 4 / 1024;
                } else |_| {}
            }
        } else |_| {}

        return metrics;
    }

    /// Monitor multiple processes until all complete
    pub fn monitorProcesses(
        self: *Self,
        executions: []const ToolExecution,
        children: []const *std.process.Child,
    ) !void {
        if (executions.len != children.len) {
            return error.MismatchedArrayLengths;
        }

        const threads = try self.allocator.alloc(std.Thread, executions.len);
        defer self.allocator.free(threads);

        // Spawn monitoring thread for each process
        for (executions, 0..) |execution, i| {
            threads[i] = try std.Thread.spawn(.{}, monitorSingleProcess, .{
                self,
                execution,
                children[i],
            });
        }

        // Wait for all monitoring threads to complete
        for (threads) |thread| {
            thread.join();
        }
    }
};

/// Wrapper function for monitoring a single process
fn monitorSingleProcess(
    self: *HealthChecker,
    execution: *const ToolExecution,
    child: *std.process.Child,
) void {
    // Clone execution to get mutable pointer
    var exec_copy = execution.clone(self.allocator) catch return;
    defer {
        self.allocator.free(exec_copy.command);
        if (exec_copy.output_file) |f| self.allocator.free(f);
        if (exec_copy.error_message) |e| self.allocator.free(e);
        self.allocator.free(exec_copy.id);
        self.allocator.free(exec_copy.tool_name);
        self.allocator.free(exec_copy.phase_name);
    }

    self.monitorProcess(&exec_copy, child) catch |err| {
        std.debug.print("Error monitoring process: {}\n", .{err});
    };
}
