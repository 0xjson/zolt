const std = @import("std");
const execution_state = @import("execution_state.zig");
const ToolExecution = execution_state.ToolExecution;
const ResourceMetrics = execution_state.ResourceMetrics;

/// All possible event types in the monitoring system
pub const EventType = enum {
    tool_started,          // Tool began execution
    tool_progress,         // Periodic progress update
    tool_completed,        // Tool finished successfully
    tool_failed,           // Tool finished with error
    tool_crashed,          // Process crashed/terminated
    tool_timeout,          // Tool exceeded timeout
    tool_cancelled,        // User or system cancelled
    phase_start,           // Phase began
    phase_completed,       // Phase finished
    phase_failed,          // Phase failed
    phase_cancelled,       // Phase cancelled
    resource_warning,      // High resource usage
    state_change,          // Any state transition
    retry_attempt,         // Retry started
};

/// Event data with type-specific payloads
pub const EventData = union(enum) {
    started: struct {
        command: []const u8,
        pid: u32,
        start_time: i64,
    },
    progress: struct {
        percent: ?f32,          // 0.0 to 100.0, null if not available
        message: ?[]const u8,   // Human-readable message
        items_found: ?u64,      // Number of items found so far
    },
    completed: struct {
        end_time: i64,
        exit_code: i32,
        duration_ms: i64,
        output_size: u64,
        items_found: u64,
    },
    failed: struct {
        end_time: i64,
        exit_code: i32,
        duration_ms: i64,
        error_msg: []const u8,
        partial_output: ?[]const u8,
    },
    crashed: struct {
        end_time: i64,
        signal: i32,
        core_dumped: bool,
        duration_ms: i64,
    },
    timeout: struct {
        end_time: i64,
        timeout_ms: u64,
        duration_ms: i64,
        partial_output: ?[]const u8,
    },
    cancelled: struct {
        end_time: i64,
        reason: []const u8,
    },
    resource: ResourceMetrics,
    retry: struct {
        attempt: u32,
        reason: []const u8,
    },
};

/// Event representing a tool lifecycle change
pub const ToolEvent = struct {
    event_type: EventType,
    timestamp: i64,                    // Unix timestamp (seconds)
    execution_id: []const u8,          // Unique execution ID
    tool_name: []const u8,             // Tool name
    phase_name: []const u8,            // Phase name
    data: EventData,                   // Event-specific data

    const Self = @This();

    /// Create a new event
    pub fn init(
        event_type: EventType,
        execution_id: []const u8,
        tool_name: []const u8,
        phase_name: []const u8,
        data: EventData,
    ) Self {
        return Self{
            .event_type = event_type,
            .timestamp = std.time.timestamp(),
            .execution_id = execution_id,
            .tool_name = tool_name,
            .phase_name = phase_name,
            .data = data,
        };
    }

    /// Format event as JSON for persistence or transmission
    pub fn toJson(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var json_object = std.StringHashMap(std.json.Value).init(allocator);
        defer {
            var iter = json_object.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.*.deinit();
            }
            json_object.deinit();
        }

        try json_object.put("event_type", std.json.Value{ .string = @tagName(self.event_type) });
        try json_object.put("timestamp", std.json.Value{ .integer = self.timestamp });
        try json_object.put("execution_id", std.json.Value{ .string = self.execution_id });
        try json_object.put("tool_name", std.json.Value{ .string = self.tool_name });
        try json_object.put("phase_name", std.json.Value{ .string = self.phase_name });

        // Add data based on type
        var data_map = std.StringHashMap(std.json.Value).init(allocator);
        defer data_map.deinit();

        switch (self.data) {
            .started => |data| {
                try data_map.put("command", std.json.Value{ .string = data.command });
                try data_map.put("pid", std.json.Value{ .integer = @intCast(data.pid) });
                try data_map.put("start_time", std.json.Value{ .integer = data.start_time });
            },
            .progress => |data| {
                if (data.percent) |p| {
                    try data_map.put("percent", std.json.Value{ .float = p });
                }
                if (data.message) |msg| {
                    try data_map.put("message", std.json.Value{ .string = msg });
                }
                if (data.items_found) |items| {
                    try data_map.put("items_found", std.json.Value{ .integer = @intCast(items) });
                }
            },
            .completed => |data| {
                try data_map.put("end_time", std.json.Value{ .integer = data.end_time });
                try data_map.put("exit_code", std.json.Value{ .integer = @intCast(data.exit_code) });
                try data_map.put("duration_ms", std.json.Value{ .integer = data.duration_ms });
                try data_map.put("output_size", std.json.Value{ .integer = @intCast(data.output_size) });
                try data_map.put("items_found", std.json.Value{ .integer = @intCast(data.items_found) });
            },
            .failed => |data| {
                try data_map.put("end_time", std.json.Value{ .integer = data.end_time });
                try data_map.put("exit_code", std.json.Value{ .integer = @intCast(data.exit_code) });
                try data_map.put("duration_ms", std.json.Value{ .integer = data.duration_ms });
                try data_map.put("error", std.json.Value{ .string = data.error_msg });
                if (data.partial_output) |output| {
                    try data_map.put("partial_output", std.json.Value{ .string = output });
                }
            },
            .crashed => |data| {
                try data_map.put("end_time", std.json.Value{ .integer = data.end_time });
                try data_map.put("signal", std.json.Value{ .integer = @intCast(data.signal) });
                try data_map.put("core_dumped", std.json.Value{ .bool = data.core_dumped });
                try data_map.put("duration_ms", std.json.Value{ .integer = data.duration_ms });
            },
            .timeout => |data| {
                try data_map.put("end_time", std.json.Value{ .integer = data.end_time });
                try data_map.put("timeout_ms", std.json.Value{ .integer = @intCast(data.timeout_ms) });
                try data_map.put("duration_ms", std.json.Value{ .integer = data.duration_ms });
                if (data.partial_output) |output| {
                    try data_map.put("partial_output", std.json.Value{ .string = output });
                }
            },
            .cancelled => |data| {
                try data_map.put("end_time", std.json.Value{ .integer = data.end_time });
                try data_map.put("reason", std.json.Value{ .string = data.reason });
            },
            .resource => |data| {
                try data_map.put("cpu_percent", std.json.Value{ .float = data.cpu_percent });
                try data_map.put("memory_mb", std.json.Value{ .integer = @intCast(data.memory_mb) });
                try data_map.put("disk_read_mb", std.json.Value{ .integer = @intCast(data.disk_read_mb) });
                try data_map.put("disk_write_mb", std.json.Value{ .integer = @intCast(data.disk_write_mb) });
                try data_map.put("network_rx_mb", std.json.Value{ .integer = @intCast(data.network_rx_mb) });
                try data_map.put("network_tx_mb", std.json.Value{ .integer = @intCast(data.network_tx_mb) });
            },
            .retry => |data| {
                try data_map.put("attempt", std.json.Value{ .integer = @intCast(data.attempt) });
                try data_map.put("reason", std.json.Value{ .string = data.reason });
            },
        }

        try json_object.put("data", std.json.Value{ .object = data_map });
        // Don't deinit data_map as it's now owned by json_object

        const value = std.json.Value{ .object = json_object };
        // Don't deinit json_object as it's now owned by value

        const json_string = try std.json.stringifyAlloc(allocator, value, .{});
        return json_string;
    }
};

/// Callback function for event subscribers
pub const EventCallback = *const fn (event: ToolEvent) anyerror!void;

/// Subscriber to events with optional filtering
pub const Subscriber = struct {
    callback: EventCallback,
    event_filter: ?EventType,  // Only receive specific event type, or null for all

    /// Check if this subscriber should receive the event
    pub fn shouldReceive(self: *const Subscriber, event: *const ToolEvent) bool {
        if (self.event_filter) |filter| {
            return event.event_type == filter;
        }
        return true;
    }
};

/// Event bus for publish/subscribe pattern
pub const EventBus = struct {
    subscribers: std.ArrayList(Subscriber),
    allocator: std.mem.Allocator,
    lock: std.Thread.Mutex,  // Thread-safe

    const Self = @This();

    /// Initialize a new event bus
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .subscribers = @TypeOf(subscribers).init(allocator),
            .allocator = allocator,
            .lock = std.Thread.Mutex{},
        };
    }

    /// Deinitialize the event bus
    pub fn deinit(self: *Self) void {
        self.subscribers.deinit(self.allocator);
    }

    /// Subscribe to events
    pub fn subscribe(self: *Self, callback: EventCallback, event_filter: ?EventType) !void {
        self.lock.lock();
        defer self.lock.unlock();

        const subscriber = Subscriber{
            .callback = callback,
            .event_filter = event_filter,
        };
        try self.subscribers.append(subscriber);
    }

    /// Unsubscribe a callback (removes first matching callback)
    pub fn unsubscribe(self: *Self, callback: EventCallback) void {
        self.lock.lock();
        defer self.lock.unlock();

        for (self.subscribers.items, 0..) |subscriber, i| {
            if (subscriber.callback == callback) {
                _ = self.subscribers.orderedRemove(i);
                break;
            }
        }
    }

    /// Publish an event to all subscribers
    pub fn publish(self: *Self, event: ToolEvent) !void {
        self.lock.lock();
        defer self.lock.unlock();

        for (self.subscribers.items) |subscriber| {
            if (subscriber.shouldReceive(&event)) {
                try subscriber.callback(event);
            }
        }
    }

    /// Get number of subscribers
    pub fn subscriberCount(self: *Self) usize {
        self.lock.lock();
        defer self.lock.unlock();
        return self.subscribers.items.len;
    }
};

/// Convenience function to create a tool started event
pub fn toolStarted(
    execution_id: []const u8,
    tool_name: []const u8,
    phase_name: []const u8,
    command: []const u8,
    pid: u32,
    start_time: i64,
) ToolEvent {
    return ToolEvent.init(
        .tool_started,
        execution_id,
        tool_name,
        phase_name,
        EventData{ .started = .{
            .command = command,
            .pid = pid,
            .start_time = start_time,
        } },
    );
}

/// Convenience function to create a tool progress event
pub fn toolProgress(
    execution_id: []const u8,
    tool_name: []const u8,
    phase_name: []const u8,
    percent: ?f32,
    message: ?[]const u8,
    items_found: ?u64,
) ToolEvent {
    return ToolEvent.init(
        .tool_progress,
        execution_id,
        tool_name,
        phase_name,
        EventData{ .progress = .{
            .percent = percent,
            .message = message,
            .items_found = items_found,
        } },
    );
}

/// Convenience function to create a tool completed event
pub fn toolCompleted(
    execution_id: []const u8,
    tool_name: []const u8,
    phase_name: []const u8,
    end_time: i64,
    exit_code: i32,
    duration_ms: i64,
    output_size: u64,
    items_found: u64,
) ToolEvent {
    return ToolEvent.init(
        .tool_completed,
        execution_id,
        tool_name,
        phase_name,
        EventData{ .completed = .{
            .end_time = end_time,
            .exit_code = exit_code,
            .duration_ms = duration_ms,
            .output_size = output_size,
            .items_found = items_found,
        } },
    );
}

/// Convenience function to create a tool failed event
pub fn toolFailed(
    execution_id: []const u8,
    tool_name: []const u8,
    phase_name: []const u8,
    end_time: i64,
    exit_code: i32,
    duration_ms: i64,
    error_msg: []const u8,
    partial_output: ?[]const u8,
) ToolEvent {
    return ToolEvent.init(
        .tool_failed,
        execution_id,
        tool_name,
        phase_name,
        EventData{ .failed = .{
            .end_time = end_time,
            .exit_code = exit_code,
            .duration_ms = duration_ms,
            .error_msg = error_msg,
            .partial_output = partial_output,
        } },
    );
}

/// Convenience function to create a tool crashed event
pub fn toolCrashed(
    execution_id: []const u8,
    tool_name: []const u8,
    phase_name: []const u8,
    end_time: i64,
    signal: i32,
    core_dumped: bool,
    duration_ms: i64,
) ToolEvent {
    return ToolEvent.init(
        .tool_crashed,
        execution_id,
        tool_name,
        phase_name,
        EventData{ .crashed = .{
            .end_time = end_time,
            .signal = signal,
            .core_dumped = core_dumped,
            .duration_ms = duration_ms,
        } },
    );
}
