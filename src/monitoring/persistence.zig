const std = @import("std");
const execution_state = @import("execution_state.zig");
const ToolExecution = execution_state.ToolExecution;

/// Persists tool execution state to disk for crash resilience and monitoring
pub const StatePersister = struct {
    state_dir: []const u8,      // Directory for state files (.zolt/status)
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize a new state persister
    pub fn init(allocator: std.mem.Allocator, state_dir: []const u8) Self {
        return Self{
            .state_dir = state_dir,
            .allocator = allocator,
        };
    }

    /// Ensure the state directory exists
    pub fn ensureDirectoryExists(self: *const Self) !void {
        _ = std.fs.cwd().makePath(self.state_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };
    }

    /// Save execution state to disk (atomic write)
    pub fn saveState(self: *const Self, execution: *const ToolExecution) !void {
        // Ensure directory exists
        try self.ensureDirectoryExists();

        // Generate filename: {tool}-{execution_id}.json.tmp
        const temp_file = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.json.tmp",
            .{ self.state_dir, execution.tool_name, execution.id },
        );
        defer self.allocator.free(temp_file);

        const final_file = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.json",
            .{ self.state_dir, execution.tool_name, execution.id },
        );
        defer self.allocator.free(final_file);

        // Serialize to JSON
        const json_data = try execution.toJson(self.allocator);
        defer self.allocator.free(json_data);

        // Write to temp file (atomic operation)
        var file = try std.fs.cwd().createFile(temp_file, .{});
        defer file.close();

        try file.writeAll(json_data);

        // Atomic rename: temp -> final
        try std.fs.cwd().rename(temp_file, final_file);
    }

    /// Load execution state from disk
    pub fn loadState(self: *const Self, execution_id: []const u8, tool_name: []const u8) ?ToolExecution {
        const filename = std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.json",
            .{ self.state_dir, tool_name, execution_id },
        ) catch return null;
        defer self.allocator.free(filename);

        const file = std.fs.cwd().openFile(filename, .{}) catch return null;
        defer file.close();

        const size = file.getEndPos() catch return null;
        const json_data = self.allocator.alloc(u8, size) catch return null;
        defer self.allocator.free(json_data);

        const bytes_read = file.readAll(json_data) catch return null;
        if (bytes_read != size) return null;

        var execution = execution_state.fromJson(self.allocator, json_data[0..bytes_read]) catch return null;
        return execution;
    }

    /// Load all states for a specific phase
    pub fn loadPhaseStates(self: *const Self, phase_name: []const u8) !std.ArrayList(ToolExecution) {
        var states = std.ArrayList(ToolExecution).init(self.allocator);
        errdefer states.deinit();

        // Open state directory
        var dir = std.fs.cwd().openDir(self.state_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                return states; // Empty list if directory doesn't exist
            }
            return err;
        };
        defer dir.close();

        var iter = dir.iterator();
        while (try iter.next()) |entry| {
            // Look for JSON files
            if (std.mem.endsWith(u8, entry.name, ".json")) {
                // Extract tool name from filename (format: tool-id.json)
                if (std.mem.indexOf(u8, entry.name, "-")) |dash_idx| {
                    const tool_name = entry.name[0..dash_idx];

                    // Read the file
                    const file = dir.openFile(entry.name, .{}) catch continue;
                    defer file.close();

                    const size = file.getEndPos() catch continue;
                    const json_data = self.allocator.alloc(u8, size) catch continue;
                    defer self.allocator.free(json_data);

                    const bytes_read = file.readAll(json_data) catch continue;
                    if (bytes_read != size) continue;

                    var execution = execution_state.fromJson(self.allocator, json_data[0..bytes_read]) catch continue;
                    errdefer self.allocator.free(execution.command);

                    // Filter by phase
                    if (std.mem.eql(u8, execution.phase_name, phase_name)) {
                        try states.append(execution);
                    } else {
                        // Clean up if not adding
                        self.allocator.free(execution.command);
                        if (execution.output_file) |f| self.allocator.free(f);
                        if (execution.error_message) |e| self.allocator.free(e);
                    }
                }
            }
        }

        return states;
    }

    /// Load all states in the directory
    pub fn loadAllStates(self: *const Self) !std.ArrayList(ToolExecution) {
        var states = std.ArrayList(ToolExecution).init(self.allocator);
        errdefer states.deinit();

        var dir = std.fs.cwd().openDir(self.state_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                return states; // Return empty list if directory doesn't exist
            }
            return err;
        };
        defer dir.close();

        var iter = dir.iterator();
        while (try iter.next()) |entry| {
            if (std.mem.endsWith(u8, entry.name, ".json")) {
                const file = dir.openFile(entry.name, .{}) catch continue;
                defer file.close();

                const size = file.getEndPos() catch continue;
                const json_data = self.allocator.alloc(u8, size) catch continue;
                defer self.allocator.free(json_data);

                const bytes_read = file.readAll(json_data) catch continue;
                if (bytes_read != size) continue;

                var execution = execution_state.fromJson(self.allocator, json_data[0..bytes_read]) catch continue;
                try states.append(execution);
            }
        }

        return states;
    }

    /// Remove a state file
    pub fn removeState(self: *const Self, execution_id: []const u8, tool_name: []const u8) !void {
        const filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.json",
            .{ self.state_dir, tool_name, execution_id },
        );
        defer self.allocator.free(filename);

        std.fs.cwd().deleteFile(filename) catch |err| {
            if (err != error.FileNotFound) {
                return err;
            }
        };
    }

    /// Clean up old state files (older than specified seconds)
    pub fn cleanupOldStates(self: *const Self, max_age_seconds: i64) !usize {
        var removed_count: usize = 0;
        const current_time = std.time.timestamp();

        var dir = std.fs.cwd().openDir(self.state_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                return 0; // Nothing to clean up
            }
            return err;
        };
        defer dir.close();

        var iter = dir.iterator();
        while (try iter.next()) |entry| {
            if (std.mem.endsWith(u8, entry.name, ".json")) {
                // Get file metadata to check age
                var stat = entry.stat();
                const file_time = stat.mtime;

                if (current_time - file_time > max_age_seconds) {
                    dir.deleteFile(entry.name) catch continue;
                    removed_count += 1;
                }
            }
        }

        return removed_count;
    }
};

/// Session manager for tracking multiple reconnaissance sessions
pub const SessionManager = struct {
    base_dir: []const u8,      // Base directory for sessions (.zolt/)
    current_session: ?[]const u8, // Current active session ID
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize session manager
    pub fn init(allocator: std.mem.Allocator, base_dir: []const u8) Self {
        return Self{
            .base_dir = base_dir,
            .current_session = null,
            .allocator = allocator,
        };
    }

    /// Create a new session
    pub fn createSession(self: *Self, session_id: []const u8) !void {
        // Create session directory: .zolt/sessions/{session_id}
        const session_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/sessions/{s}",
            .{ self.base_dir, session_id },
        );
        defer self.allocator.free(session_dir);

        try std.fs.cwd().makePath(session_dir);

        // Create state subdirectory
        const state_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/status",
            .{ session_dir },
        );
        defer self.allocator.free(state_dir);

        try std.fs.cwd().makePath(state_dir);

        self.current_session = try self.allocator.dupe(u8, session_id);
    }

    /// Get the state directory for the current session
    pub fn getCurrentStateDir(self: *const Self) ?[]const u8 {
        if (self.current_session) |session_id| {
            const state_dir = std.fmt.allocPrint(
                self.allocator,
                "{s}/sessions/{s}/status",
                .{ self.base_dir, session_id },
            ) catch return null;
            return state_dir;
        }
        return null;
    }

    /// List all sessions
    pub fn listSessions(self: *const Self) !std.ArrayList([]const u8) {
        var sessions = std.ArrayList([]const u8).init(self.allocator);
        errdefer sessions.deinit();

        const sessions_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/sessions",
            .{self.base_dir},
        );
        defer self.allocator.free(sessions_dir);

        var dir = std.fs.cwd().openDir(sessions_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                return sessions; // Empty list
            }
            return err;
        };
        defer dir.close();

        var iter = dir.iterator();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                const session_name = try self.allocator.dupe(u8, entry.name);
                try sessions.append(session_name);
            }
        }

        return sessions;
    }
};
