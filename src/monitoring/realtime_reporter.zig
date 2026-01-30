const std = @import("std");
const events = @import("events.zig");
const EventBus = events.EventBus;
const events_mod = @import("events.zig");
const EventType = events_mod.EventType;
const EventData = events_mod.EventData;
const ToolEvent = events_mod.ToolEvent;
const execution_state = @import("execution_state.zig");
const ToolState = execution_state.ToolState;

/// Real-time reporter that displays tool execution status to the user
pub const RealtimeReporter = struct {
    allocator: std.mem.Allocator,
    event_bus: *EventBus,
    active_tools: std.StringHashMap(ToolInfo),
    display_format: DisplayFormat,
    last_update: i64,

    const ToolInfo = struct {
        state: ToolState,
        start_time: ?i64,
        items_found: u64,
        last_message: ?[]const u8,
    };

    /// Display format for the reporter
    pub const DisplayFormat = enum {
        tui,      // Interactive terminal UI (default)
        simple,   // Simple text output
        json,     // JSON output for scripting
        csv,      // CSV output for spreadsheets
    };

    const Self = @This();

    /// Initialize a new real-time reporter
    pub fn init(allocator: std.mem.Allocator, event_bus: *EventBus, format: DisplayFormat) !Self {
        var reporter = Self{
            .allocator = allocator,
            .event_bus = event_bus,
            .active_tools = std.StringHashMap(ToolInfo).init(allocator),
            .display_format = format,
            .last_update = std.time.timestamp(),
        };

        // Subscribe to all relevant events
        try event_bus.subscribe(handleEvent, null);

        return reporter;
    }

    /// Deinitialize the reporter
    pub fn deinit(self: *Self) void {
        var iter = self.active_tools.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.last_message) |msg| {
                self.allocator.free(msg);
            }
            self.allocator.free(entry.key_ptr.*);
        }
        self.active_tools.deinit();
    }

    /// Event handler callback
    fn handleEvent(event: ToolEvent) !void {
        _ = event; // Handled by reporter instance in start method
    }

    /// Start monitoring and displaying events
    pub fn start(self: *Self) !void {
        // Clear screen for TUI mode
        if (self.display_format == .tui) {
            std.debug.print("\x1B[2J\x1B[H", .{}); // Clear screen and move cursor to top
        }

        std.debug.print("🎯 Zolt Recon Monitoring\n", .{});
        std.debug.print("════════════════════════════════════════════════════════════\n\n", .{});

        // For now, just show we're monitoring
        // In a full implementation, this would use a separate thread to avoid blocking
        std.debug.print("Monitoring active... Press Ctrl+C to stop\n", .{});

        // Simple event loop (polling - in production use a proper event loop)
        var iteration: u32 = 0;
        while (iteration < 10) : (iteration += 1) {
            std.time.sleep(1 * std.time.ns_per_s);

            // Update display
            try self.render();
        }
    }

    /// Render the current state
    pub fn render(self: *Self) !void {
        const current_time = std.time.timestamp();

        // Only update every second to avoid excessive output
        if (current_time - self.last_update < 1) {
            return;
        }

        self.last_update = current_time;

        switch (self.display_format) {
            .tui => try self.renderTui(),
            .simple => try self.renderSimple(),
            .json => try self.renderJson(),
            .csv => try self.renderCsv(),
        }
    }

    /// Render TUI (Terminal User Interface) format
    fn renderTui(self: *Self) !void {
        // Clear previous lines and move cursor up
        std.debug.print("\x1B[2A\x1B[K", .{});

        std.debug.print("\r\n", .{});
        std.debug.print("Tool Status:\n", .{});
        std.debug.print("─────────────\n", .{});

        if (self.active_tools.count() == 0) {
            std.debug.print("No tools running\n", .{});
            return;
        }

        var iter = self.active_tools.iterator();
        while (iter.next()) |entry| {
            const tool_name = entry.key_ptr.*;
            const info = entry.value_ptr.*;

            // Determine icon and color based on state
            const (icon, color) = switch (info.state) {
                .pending => ("⏳", "\x1B[33m"), // Yellow
                .running => ("⏳", "\x1B[32m"), // Green
                .succeeded => ("✓", "\x1B[34m"), // Blue
                .failed => ("✗", "\x1B[31m"), // Red
                .crashed => ("✗", "\x1B[31m"), // Red
                .timeout => ("⏱", "\x1B[35m"), // Magenta
                .cancelled => ("⊘", "\x1B[90m"), // Gray
            };

            // Calculate elapsed time
            var elapsed = "";
            if (info.start_time) |start| {
                const elapsed_seconds = std.time.timestamp() - start;
                if (elapsed_seconds < 60) {
                    elapsed = try std.fmt.allocPrint(self.allocator, "{d}s", .{elapsed_seconds});
                } else if (elapsed_seconds < 3600) {
                    elapsed = try std.fmt.allocPrint(self.allocator, "{d}m", .{elapsed_seconds / 60});
                } else {
                    elapsed = try std.fmt.allocPrint(self.allocator, "{d}h", .{elapsed_seconds / 3600});
                }
            } else {
                elapsed = "--";
            }

            std.debug.print("{s}{s} {s} {s} {d} found\x1B[0m\n", .{
                color,
                icon,
                tool_name,
                elapsed,
                info.items_found,
            });
        }
    }

    /// Render simple text format
    fn renderSimple(self: *Self) !void {
        _ = self;
        // Simple format would be implemented here
        std.debug.print("Simple format rendering\n", .{});
    }

    /// Render JSON format
    fn renderJson(self: *Self) !void {
        _ = self;
        // JSON format would be implemented here
        std.debug.print("JSON format rendering\n", .{});
    }

    /// Render CSV format
    fn renderCsv(self: *Self) !void {
        _ = self;
        // CSV format would be implemented here
        std.debug.print("CSV format rendering\n", .{});
    }

    /// Update tool status
    pub fn updateTool(self: *Self, event: ToolEvent) !void {
        const tool_key = try std.fmt.allocPrint(self.allocator, "{s}", .{event.tool_name});
        defer self.allocator.free(tool_key);

        var info = ToolInfo{
            .state = std.meta.stringToEnum(ToolState, @tagName(event.event_type)) orelse .pending,
            .start_time = null,
            .items_found = 0,
            .last_message = null,
        };

        // Update based on event data
        switch (event.data) {
            .started => |data| {
                info.start_time = data.start_time;
            },
            .progress => |data| {
                info.items_found = data.items_found orelse 0;
                info.last_message = if (data.message) |msg|
                    try self.allocator.dupe(u8, msg)
                else
                    null;
            },
            .completed => |data| {
                info.items_found = data.items_found;
            },
            .failed => |_| {},
            .crashed => |_| {},
            .timeout => |_| {},
            .cancelled => |_| {},
            else => {},
        }

        // Update or insert tool info
        const result = try self.active_tools.getOrPut(tool_key);
        if (result.found_existing) {
            // Update existing
            if (result.value_ptr.last_message) |msg| {
                self.allocator.free(msg);
            }
            result.value_ptr.* = info;
            self.allocator.free(tool_key); // Free since we didn't use the new allocation
        } else {
            // Insert new - ownership transferred to hashmap
            // No need to free tool_key
        }
    }
};
