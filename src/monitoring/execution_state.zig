const std = @import("std");

/// Current execution state of a tool
pub const ToolState = enum {
    pending,      // Waiting to run
    starting,     // Process spawning
    running,      // Currently executing
    succeeded,    // Completed successfully
    failed,       // Completed with error
    crashed,      // Process terminated unexpectedly
    timeout,      // Exceeded time limit
    cancelled,    // User or system cancelled
};

/// Resource usage metrics for a tool execution
pub const ResourceMetrics = struct {
    cpu_percent: f32 = 0.0,
    memory_mb: u64 = 0,
    disk_read_mb: u64 = 0,
    disk_write_mb: u64 = 0,
    network_rx_mb: u64 = 0,
    network_tx_mb: u64 = 0,
};

/// Represents a single tool execution
pub const ToolExecution = struct {
    id: []const u8,                    // Unique execution ID
    tool_name: []const u8,             // Tool name from registry
    phase_name: []const u8,            // Recon phase name
    state: ToolState,                  // Current execution state
    pid: ?u32,                         // Process ID (if running)
    start_time: ?i64,                  // Unix timestamp (seconds)
    end_time: ?i64,                    // Unix timestamp (seconds)
    exit_code: ?i32,                   // Process exit code
    command: []const u8,               // Full command executed
    output_file: ?[]const u8,          // Path to output file
    error_message: ?[]const u8,        // Error description
    resource_usage: ResourceMetrics,   // CPU, memory, etc.
    retry_count: u32,                  // Number of retries attempted
    timeout_ms: ?u64,                  // Timeout in milliseconds

    const Self = @This();

    /// Format the execution as a JSON string for persistence
    pub fn toJson(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var json_object = std.StringHashMap(std.json.Value).init(allocator);
        defer {
            var iter = json_object.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.*.deinit();
            }
            json_object.deinit();
        }

        try json_object.put("id", std.json.Value{ .string = self.id });
        try json_object.put("tool_name", std.json.Value{ .string = self.tool_name });
        try json_object.put("phase_name", std.json.Value{ .string = self.phase_name });
        try json_object.put("state", std.json.Value{ .string = @tagName(self.state) });

        if (self.pid) |pid| {
            try json_object.put("pid", std.json.Value{ .integer = @intCast(pid) });
        }

        if (self.start_time) |start| {
            try json_object.put("start_time", std.json.Value{ .integer = start });
        }

        if (self.end_time) |end| {
            try json_object.put("end_time", std.json.Value{ .integer = end });
        }

        if (self.exit_code) |code| {
            try json_object.put("exit_code", std.json.Value{ .integer = code });
        }

        try json_object.put("command", std.json.Value{ .string = self.command });

        if (self.output_file) |file| {
            try json_object.put("output_file", std.json.Value{ .string = file });
        }

        if (self.error_message) |msg| {
            try json_object.put("error_message", std.json.Value{ .string = msg });
        }

        if (self.timeout_ms) |timeout| {
            try json_object.put("timeout_ms", std.json.Value{ .integer = @intCast(timeout) });
        }

        try json_object.put("retry_count", std.json.Value{ .integer = self.retry_count });

        // Add resource usage
        var resource_map = std.StringHashMap(std.json.Value).init(allocator);
        defer resource_map.deinit();

        try resource_map.put("cpu_percent", std.json.Value{ .float = self.resource_usage.cpu_percent });
        try resource_map.put("memory_mb", std.json.Value{ .integer = @intCast(self.resource_usage.memory_mb) });
        try resource_map.put("disk_read_mb", std.json.Value{ .integer = @intCast(self.resource_usage.disk_read_mb) });
        try resource_map.put("disk_write_mb", std.json.Value{ .integer = @intCast(self.resource_usage.disk_write_mb) });
        try resource_map.put("network_rx_mb", std.json.Value{ .integer = @intCast(self.resource_usage.network_rx_mb) });
        try resource_map.put("network_tx_mb", std.json.Value{ .integer = @intCast(self.resource_usage.network_tx_mb) });

        try json_object.put("resource_usage", std.json.Value{ .object = resource_map });
        // Don't deinit resource_map as it's now owned by json_object

        const value = std.json.Value{ .object = json_object };
        // Don't deinit json_object as it's now owned by value

        const json_string = try std.json.stringifyAlloc(allocator, value, .{});
        return json_string;
    }

    /// Update resource usage metrics
    pub fn updateResourceUsage(self: *Self, metrics: ResourceMetrics) void {
        self.resource_usage = metrics;
    }

    /// Mark the execution as started
    pub fn markStarted(self: *Self, pid: u32, start_time: i64) void {
        self.pid = pid;
        self.start_time = start_time;
        self.state = .running;
    }

    /// Mark the execution as completed
    pub fn markCompleted(self: *Self, end_time: i64, exit_code: i32) void {
        self.end_time = end_time;
        self.exit_code = exit_code;
        self.state = if (exit_code == 0) .succeeded else .failed;
    }

    /// Mark the execution as crashed
    pub fn markCrashed(self: *Self, end_time: i64, signal: i32) void {
        self.end_time = end_time;
        self.exit_code = -signal;
        self.state = .crashed;
    }

    /// Mark the execution as timed out
    pub fn markTimeout(self: *Self, end_time: i64) void {
        self.end_time = end_time;
        self.state = .timeout;
    }
};

/// Parse ToolExecution from JSON
pub fn fromJson(allocator: std.mem.Allocator, json_str: []const u8) !ToolExecution {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const root = parsed.value;

    // Required fields
    const id = root.object.get("id").?.string;
    const tool_name = root.object.get("tool_name").?.string;
    const phase_name = root.object.get("phase_name").?.string;

    // Optional fields (with defaults)
    var execution = ToolExecution{
        .id = id,
        .tool_name = tool_name,
        .phase_name = phase_name,
        .state = std.meta.stringToEnum(ToolState, root.object.get("state").?.string) orelse .pending,
        .pid = if (root.object.get("pid")) |p| @intCast(p.integer) else null,
        .start_time = if (root.object.get("start_time")) |s| s.integer else null,
        .end_time = if (root.object.get("end_time")) |e| e.integer else null,
        .exit_code = if (root.object.get("exit_code")) |c| @intCast(c.integer) else null,
        .command = if (root.object.get("command")) |c| c.string else "",
        .output_file = if (root.object.get("output_file")) |f| f.string else null,
        .error_message = if (root.object.get("error_message")) |e| e.string else null,
        .resource_usage = ResourceMetrics{},
        .retry_count = if (root.object.get("retry_count")) |r| @intCast(r.integer) else 0,
        .timeout_ms = if (root.object.get("timeout_ms")) |t| @intCast(t.integer) else null,
    };

    // Parse resource usage if present
    if (root.object.get("resource_usage")) |usage| {
        if (usage.object.get("cpu_percent")) |cpu| {
            execution.resource_usage.cpu_percent = cpu.float;
        }
        if (usage.object.get("memory_mb")) |mem| {
            execution.resource_usage.memory_mb = @intCast(mem.integer);
        }
        // ... parse other metrics
    }

    return execution;
}

/// Clone a ToolExecution (useful for creating modified copies)
pub fn clone(self: *const ToolExecution, allocator: std.mem.Allocator) !ToolExecution {
    const copy = ToolExecution{
        .id = try allocator.dupe(u8, self.id),
        .tool_name = try allocator.dupe(u8, self.tool_name),
        .phase_name = try allocator.dupe(u8, self.phase_name),
        .state = self.state,
        .pid = self.pid,
        .start_time = self.start_time,
        .end_time = self.end_time,
        .exit_code = self.exit_code,
        .command = try allocator.dupe(u8, self.command),
        .output_file = if (self.output_file) |f| try allocator.dupe(u8, f) else null,
        .error_message = if (self.error_message) |e| try allocator.dupe(u8, e) else null,
        .resource_usage = self.resource_usage,
        .retry_count = self.retry_count,
        .timeout_ms = self.timeout_ms,
    };
    return copy;
}
