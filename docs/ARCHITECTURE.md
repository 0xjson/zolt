# Zolt Architecture Documentation

## Overview

Zolt is a modular CLI tool for bug bounty hunting, designed with clear separation of concerns for easy maintenance and extensibility.

## Directory Structure

```
zolt/
├── zolt.zig                 # Main entry point
├── build.zig               # Build configuration
├── README.md               # User documentation
├── docs/
│   └── ARCHITECTURE.md     # This file
└── src/
    ├── commands/           # Command implementations
    │   ├── init.zig       # `zolt init` command
    │   └── tools.zig      # `zolt tools` command
    ├── registry/          # Data and configuration
    │   └── tools.zig      # Tool registry (15+ tools)
    └── utils/             # Utility modules
        ├── cli.zig        # CLI helpers and printing
        ├── environment.zig # Environment checks (Go, etc.)
        ├── files.zig      # File operations
        └── validation.zig # Input validation

```

## Module Responsibilities

### 1. Commands Layer (`src/commands/`)

#### init.zig - Project Initialization
- **Purpose**: Create structured directory for bug bounty targets
- **Exports**:
  - `InitOptions` struct
  - `initialize()` function
- **Key Functions**:
  - `createDirectoryStructure()` - Creates 27 directories
  - `createReconFiles()` - Creates 35 empty recon files
- **Dependencies**: Uses `utils/files.zig` for file operations

#### tools.zig - Tool Installation
- **Purpose**: Install bug bounty tools via `go install`
- **Exports**:
  - `install()` function
- **Key Functions**:
  - `installTool()` - Installs a single tool
- **Dependencies**: Uses `registry/tools.zig` and `utils/environment.zig`

### 2. Registry Layer (`src/registry/`)

#### tools.zig - Tool Definitions
- **Purpose**: Central registry of all bug bounty tools
- **Exports**:
  - `Tool` struct (name, description, go_path, category)
  - `Category` enum (9 categories)
  - `TOOLS` array (15 tools)
  - Helper functions: `getToolByName()`, `getToolsByCategory()`
- **Design**: Easy to add new tools by adding to the TOOLS array

### 3. Utils Layer (`src/utils/`)

#### cli.zig - CLI Helpers
- **Purpose**: Command-line interface utilities
- **Exports**:
  - `ArgIterator` struct for parsing args
  - `Progress` struct for progress bars
  - Print functions with formatting
  - Color printing support

#### environment.zig - Environment Detection
- **Purpose**: Check system environment and dependencies
- **Exports**:
  - `checkGoInstallation()` - Checks if Go is installed
  - `installGo()` - Instructions for installing Go
  - `commandExists()` - Check if command is available
  - `directoryExists()` - Check if directory exists

#### files.zig - File Operations
- **Purpose**: All file and directory operations
- **Exports**:
  - `createEmptyFile()` - Create files
  - `createDirectory()` - Create directories
  - `createFiles()` - Batch create files
  - `createDirectories()` - Batch create directories
  - `readFile()`, `writeFile()`, `copyFile()` - File I/O
  - `deleteFile()`, `deleteDirectory()` - Cleanup

#### validation.zig - Input Validation
- **Purpose**: Validate user input and options
- **Exports**:
  - `validateOrganization()` - Validate bug bounty platforms
  - `validateCompanyName()` - Validate company names
  - `validateFileExists()` - Check file accessibility
  - `validateDomain()` - Validate domain format
  - `validateUrl()` - Validate URL format

### 4. Main Entry Point (`zolt.zig`)

- **Purpose**: Route commands to appropriate modules
- **Responsibilities**:
  - Parse main command (`tools`, `init`)
  - Route to command modules
  - Handle option parsing for `init` command
  - Validate options before passing to commands

## Adding New Features

### Adding a New Tool

1. Edit `src/registry/tools.zig`
2. Add to `TOOLS` array:

```zig
Tool{
    .name = "newtool",
    .description = "Description of tool",
    .go_path = "github.com/user/repo/cmd/tool@latest",
    .category = .utility,
}
```

### Adding a New Command

1. Create new file in `src/commands/` (e.g., `scan.zig`)
2. Export options struct and main function
3. Add to `zolt.zig`:
   - Import the module
   - Add to main command router
   - Add option parsing if needed

### Adding a New Utility Module

1. Create new file in `src/utils/`
2. Export public functions
3. Import in modules that need it

## Best Practices

1. **Separation of Concerns**:
   - Commands handle user interaction
   - Registry holds data
   - Utils handle low-level operations

2. **Error Handling**:
   - Use explicit error handling with `try`/`catch`
   - Provide clear error messages via `cli.printError()`

3. **Testing**:
   - Each module can be tested independently
   - Run `zig build test` to run all tests

4. **Documentation**:
   - Document all public functions
   - Keep README.md updated

## Building and Running

```bash
# Build
zig build

# Run
zig build run -- tools install

# Test
zig build test

# Install
zig build install
```

## Future Enhancements

Potential modules to add:
- `src/recon/` - Reconnaissance workflow automation
- `src/reporting/` - Report generation
- `src/config/` - Configuration management
- `src/plugins/` - Plugin system for custom tools
