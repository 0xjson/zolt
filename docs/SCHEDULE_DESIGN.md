# Zolt Scheduled Automation - CLI UX Design

## Overview

The scheduled automation feature allows bug bounty hunters to configure and run daily reconnaissance automatically, track changes over time, and be notified when new attack surface is discovered.

## Core Concepts

### 1. Schedule Configuration (`daily-recon.toml`)

A schedule configuration file defines what reconnaissance to run, when to run it, and where to store results.

```

### Configuration Sections Explained

**[schedule]** - Basic scheduling information
- `name`: Human-readable name for this schedule
- `enabled`: Whether to enable this schedule
- `cron`: Cron expression for precise scheduling
- `interval`: Simple interval (daily, weekly, hourly)
- `retention_days`: How many days of history to keep
- `targets`: Files to monitor for changes

**[validation]** - Pre-run checks
- `required_files`: Files that must exist before running
- `min_file_size`: Minimum size for required files

**[[recon_phase]]** - A logical grouping of reconnaissance tools
- `name`: Phase name (e.g., "subdomain-enumeration")
- `enabled`: Enable/disable entire phase
- `priority`: Execution order (lower = first)
- `parallel`: Run tools in parallel within phase
- `depends_on`: Phases that must complete first

**[[recon_phase.tools]]** - Individual tools to run
- `name`: Tool name for logging
- `command`: Shell command to execute
- `timeout`: Max execution time
- `retry_count`: Retry on failure
- `success_codes`: Exit codes considered success
- `continue_on_failure`: Continue schedule if this tool fails

**[notifications]** - Alert configuration
- Multiple notification channels (Discord, Slack, Email)
- Smart notifications (only on changes)
- Preview of new findings included

**[diff]** - Diff viewing configuration
- Multiple diff tool support
- Configurable comparison categories
- Rich preview options

## 2. CLI Commands

### Core Commands

#### `zolt schedule create`

Create a new schedule configuration.

```bash
# Interactive mode
zolt schedule create

# Quick create with template
zolt schedule create --name "TechCorp Daily" --template daily-recon

# Create from existing config
zolt schedule create --config /path/to/config.toml

# Set cron expression
zolt schedule create --cron "0 2 * * *" --name "Nightly Recon"
```

**Interactive prompts:**
- Schedule name
- Cron expression or interval
- Recon phases to include
- Notification preferences
- Output locations

**Output:**
```
✓ Created schedule configuration: daily-recon.toml
  Schedule: "TechCorp Daily Recon"
  Runs: Daily at 02:00 UTC
  Phases: 3 (subdomain-enumeration, domain-validation, url-discovery)
  Tools: 5 tools configured
  Notifications: Discord enabled

Next steps:
  zolt schedule validate daily-recon.toml
  zolt schedule start daily-recon.toml
```

#### `zolt schedule list`

List all configured schedules with their status.

```bash
# List all schedules
zolt schedule list

# Show detailed view
zolt schedule list --detailed

# Show only running schedules
zolt schedule list --status running

# Show only enabled schedules
zolt schedule list --enabled
```

**Output:**
```
Configured Schedules

✓ techcorp-daily.toml
  Name: TechCorp Daily Recon
  Status: Running (PID: 12345)
  Schedule: Daily at 02:00 UTC
  Last Run: 2025-01-29 02:00:15 (successful)
  Next Run: 2025-01-30 02:00:00
  Phases: 3 | Tools: 5
  Notifications: Discord ✓
  Changes: +12 subdomains, +45 URLs (last run)

○ payment-processing.toml
  Name: Payment Processing Weekly
  Status: Stopped
  Schedule: Weekly on Sunday 03:00 UTC
  Last Run: 2025-01-26 03:05:22 (successful)
  Next Run: 2025-02-02 03:00:00
  Phases: 2 | Tools: 3
  Notifications: Slack ✓

⚠ mobile-app.toml
  Name: Mobile App Recon
  Status: Error
  Schedule: Daily at 04:00 UTC
  Last Run: 2025-01-29 04:15:33 (failed)
  Error: Tool 'amass' timed out after 10m
  Next Run: 2025-01-30 04:00:00

Summary: 3 schedules, 1 running, 1 error
```

#### `zolt schedule start`

Start a schedule (run once or start daemon).

```bash
# Start schedule daemon
zolt schedule start daily-recon.toml

# Run once (foreground)
zolt schedule start daily-recon.toml --once

# Start with custom config directory
zolt schedule start daily-recon.toml --config-dir ./config

# Start and follow logs
zolt schedule start daily-recon.toml --follow

# Run immediately (ignore schedule)
zolt schedule start daily-recon.toml --force
```

**Output:**
```
✓ Starting schedule: daily-recon.toml
  Schedule: TechCorp Daily Recon
  Mode: Daemon (scheduled runs)
  PID: 12345
  Log: logs/zolt-schedule-techcorp-daily.log

  Initializing...
  ✓ Validated configuration (5 tools, 3 phases)
  ✓ Required files found
  ✓ Notification channels ready (Discord)

  Next run: 2025-01-30 02:00:00 UTC (in 14h 23m)

  Commands:
    zolt schedule status daily-recon.toml
    zolt schedule stop daily-recon.toml
    zolt schedule logs daily-recon.toml --follow
```

#### `zolt schedule stop`

Stop a running schedule.

```bash
# Stop by config file
zolt schedule stop daily-recon.toml

# Stop by schedule name
zolt schedule stop --name "TechCorp Daily Recon"

# Stop all schedules
zolt schedule stop --all

# Stop and keep current data
zolt schedule stop daily-recon.toml --keep-data
```

**Output:**
```
✓ Stopping schedule: daily-recon.toml
  PID: 12345
  Sending graceful shutdown signal...

  ✓ Schedule stopped successfully
  Runtime: 3 days, 14 hours
  Runs completed: 4
  Last run: 2025-01-29 02:00:15

  Data preserved:
    recon/history/ (12 MB)
    logs/zolt-schedule-techcorp-daily.log
```

#### `zolt schedule status`

Get detailed status of a schedule.

```bash
# Status of specific schedule
zolt schedule status daily-recon.toml

# Watch status (updates every 5s)
zolt schedule status daily-recon.toml --watch

# Show run history
zolt schedule status daily-recon.toml --history
```

**Output:**
```
Schedule Status: daily-recon.toml

● Status: Running (PID: 12345, uptime: 2d 14h)
● Name: TechCorp Daily Recon
● Schedule: Daily at 02:00 UTC
● Config: /home/user/bounty/TechCorp/daily-recon.toml

Runs:
  Total: 4
  Successful: 4
  Failed: 0
  Average Duration: 28m 15s

Last Run (2025-01-29 02:00:15):
  Duration: 31m 42s
  Status: ✓ Successful
  Changes Detected: Yes
    + subdomains: 12 new
    + urls: 45 new
    + ports: 3 new

Phases:
  1. subdomain-enumeration (priority: 1)
     Status: ✓ Completed (14m 22s)
     Tools: 2/2 successful

  2. domain-validation (priority: 2)
     Status: ✓ Completed (8m 15s)
     Tools: 1/1 successful

  3. url-discovery (priority: 3)
     Status: ✓ Completed (9m 05s)
     Tools: 2/2 successful

Notifications:
  Discord: ✓ Delivered (2s delay)
  Slack: Not configured
  Email: Not configured

Next Run: 2025-01-30 02:00:00 UTC (in 14h 23m)

Resources:
  CPU Usage: 12%
  Memory: 256 MB
  Disk: 12 MB (history)
  Log: logs/zolt-schedule-techcorp-daily.log
```

### Diff and Results Commands

#### `zolt schedule diff`

View differences between runs.

```bash
# Show diff from last run
zolt schedule diff daily-recon.toml

# Show diff from specific date
zolt schedule diff daily-recon.toml --date 2025-01-28

# Show diff between two runs
zolt schedule diff daily-recon.toml --from 2025-01-28 --to 2025-01-29

# Show specific category diff
zolt schedule diff daily-recon.toml --category subdomains

# Show diff with custom tool
zolt schedule diff daily-recon.toml --tool delta

# Show only new items (no context)
zolt schedule diff daily-recon.toml --brief
```

**Output:**
```
Recon Diff: daily-recon.toml
Comparing: 2025-01-28 → 2025-01-29

Subdomains (+12 new):
  api-internal.techcorp.com
  dev-api.techcorp.com
  staging-admin.techcorp.com
  mobile-backend.techcorp.com
  test-api.techcorp.com
  ... and 7 more

URLs (+45 new):
  https://api-internal.techcorp.com/v1/users
  https://api-internal.techcorp.com/v1/admin
  https://dev-api.techcorp.com/swagger
  https://staging-admin.techcorp.com/login
  https://mobile-backend.techcorp.com/api/v2
  ... and 40 more

Ports (+3 new):
  mobile-backend.techcorp.com:8443 (https-alt)
  api-internal.techcorp.com:8080 (http-proxy)
  staging-admin.techcorp.com:5000 (upnp)

To see full details:
  zolt schedule diff daily-recon.toml --all
  zolt schedule report daily-recon.toml --date 2025-01-29
```

#### `zolt schedule report`

Generate detailed reports.

```bash
# Generate report for last run
zolt schedule report daily-recon.toml

# Generate report for specific date
zolt schedule report daily-recon.toml --date 2025-01-29

# Generate report with specific format
zolt schedule report daily-recon.toml --format markdown
zolt schedule report daily-recon.toml --format json
zolt schedule report daily-recon.toml --format html

# Generate summary report across multiple runs
zolt schedule report daily-recon.toml --summary --days 7

# Save report to file
zolt schedule report daily-recon.toml --output report.md
```

**Output:**
```
Generating report for daily-recon.toml...
✓ Report generated: recon/history/reports/2025-01-29-report.md

Report Summary:
  Date: 2025-01-29
  Duration: 31m 42s
  Status: Successful

  New Findings:
    ✓ Subdomains: 12 new (total: 1,247)
    ✓ URLs: 45 new (total: 15,892)
    ✓ Ports: 3 new (total: 892)

  Notable Changes:
    • New internal API discovered: api-internal.techcorp.com
    • New staging environment: staging-admin.techcorp.com
    • New mobile backend endpoint discovered

  Full Report: recon/history/reports/2025-01-29-report.md
```

**Sample Markdown Report:**

```markdown
# Reconnaissance Report - TechCorp
**Date:** 2025-01-29 02:00:15 UTC
**Duration:** 31m 42s
**Status:** ✓ Successful
**Schedule:** daily-recon.toml

## Summary

| Category | New | Total | Change |
|----------|-----|-------|--------|
| Subdomains | +12 | 1,247 | +0.97% |
| URLs | +45 | 15,892 | +0.28% |
| Open Ports | +3 | 892 | +0.34% |

## New Subdomains

1. **api-internal.techcorp.com** - New internal API endpoint
2. **dev-api.techcorp.com** - Development API
3. **staging-admin.techcorp.com** - Staging admin panel
4. **mobile-backend.techcorp.com** - Mobile application backend
5. **test-api.techcorp.com** - Test API instance

... (7 more)

## New URLs (Top 10)

1. https://api-internal.techcorp.com/v1/users
2. https://api-internal.techcorp.com/v1/admin
3. https://dev-api.techcorp.com/swagger
4. https://staging-admin.techcorp.com/login
5. https://mobile-backend.techcorp.com/api/v2

... (40 more)

## Tool Execution Summary

| Phase | Tool | Duration | Status |
|-------|------|----------|--------|
| subdomain-enumeration | subfinder | 5m 12s | ✓ |
| subdomain-enumeration | amass | 9m 10s | ✓ |
| domain-validation | httpx | 8m 15s | ✓ |
| url-discovery | gau | 4m 32s | ✓ |
| url-discovery | katana | 4m 33s | ✓ |

## Recommendations

1. **Investigate internal API** - New internal API discovered that may reveal additional functionality
2. **Check staging environment** - Staging admin panel may have weaker security controls
3. **Review mobile backend** - New mobile API endpoints may have different authentication

---
*Generated by Zolt - Bug Bounty Automation Tool*
```

### Management Commands

#### `zolt schedule validate`

Validate a schedule configuration.

```bash
# Validate config file
zolt schedule validate daily-recon.toml

# Validate with detailed output
zolt schedule validate daily-recon.toml --verbose

# Validate and check tools are installed
zolt schedule validate daily-recon.toml --check-tools

# Validate with strict mode (fail on warnings)
zolt schedule validate daily-recon.toml --strict
```

**Output:**
```
Validating schedule: daily-recon.toml

✓ Configuration syntax valid
✓ Schedule section present
✓ 3 recon phases defined
✓ 5 tools configured
✓ Notification settings valid
✓ Diff settings valid
✓ Output settings valid
✓ All required files exist
✓ History directory writable
✓ Log directory writable

Phase: subdomain-enumeration
  ✓ subfinder: command valid, timeout 5m
  ✓ amass: command valid, timeout 10m

Phase: domain-validation
  ✓ httpx: command valid, timeout 15m

Phase: url-discovery
  ✓ gau: command valid, timeout 10m
  ✓ katana: command valid, timeout 20m

Notifications:
  ✓ Discord: webhook URL configured
  ⚠ Slack: not enabled (optional)
  ⚠ Email: not enabled (optional)

Advanced Checks:
  ✓ Tool availability check (optional): --check-tools
  ✓ Cron expression: "0 2 * * *" (valid)

Validation: ✓ Passed (2 warnings)
```

If validation fails:

```
✗ Validation failed: daily-recon.toml

Errors:
  × Phase 'url-discovery': Missing required field 'priority'
  × Tool 'subfinder': Command references file that doesn't exist:
      recon/subdomains/passive/passive.txt
  × Notification Discord: Webhook URL not configured
  × Cron expression "0 25 * * *" is invalid (hour must be 0-23)

Warnings:
  ⚠ Phase 'domain-validation': No tools defined
  ⚠ Retention period 365 days may use significant disk space

Fix these issues and run validate again.
```

#### `zolt schedule edit`

Edit a schedule configuration.

```bash
# Open in default editor
zolt schedule edit daily-recon.toml

# Open in specific editor
zolt schedule edit daily-recon.toml --editor vim

# Edit specific section
zolt schedule edit daily-recon.toml --section schedule

# Add a new tool interactively
zolt schedule edit daily-recon.toml --add-tool
```

#### `zolt schedule logs`

View schedule logs.

```bash
# View logs
zolt schedule logs daily-recon.toml

# Follow logs in real-time
zolt schedule logs daily-recon.toml --follow

# View last N lines
zolt schedule logs daily-recon.toml --tail 100

# View logs for specific date
zolt schedule logs daily-recon.toml --date 2025-01-29

# Search logs
zolt schedule logs daily-recon.toml --grep "error"
```

**Output:**
```
==> logs/zolt-schedule-techcorp-daily.log <==

2025-01-29 02:00:00 [INFO] Starting scheduled run
2025-01-29 02:00:01 [INFO] Phase 1/3: subdomain-enumeration (priority: 1)
2025-01-29 02:00:01 [INFO] Tool: subfinder (timeout: 5m)
2025-01-29 02:02:13 [INFO] Tool completed: subfinder (2m 12s)
2025-01-29 02:02:13 [INFO] Tool: amass (timeout: 10m)
2025-01-29 02:11:23 [INFO] Tool completed: amass (9m 10s)
2025-01-29 02:11:23 [INFO] Phase completed: subdomain-enumeration (11m 22s)
2025-01-29 02:11:24 [INFO] Phase 2/3: domain-validation (priority: 2)
2025-01-29 02:11:24 [INFO] Tool: httpx (timeout: 15m)
2025-01-29 02:19:39 [INFO] Tool completed: httpx (8m 15s)
2025-01-29 02:19:39 [INFO] Phase completed: domain-validation (8m 15s)
2025-01-29 02:19:40 [INFO] Phase 3/3: url-discovery (priority: 3)
2025-01-29 02:19:40 [INFO] Tool: gau (timeout: 10m)
2025-01-29 02:22:42 [INFO] Tool completed: gau (3m 2s)
2025-01-29 02:22:42 [INFO] Tool: katana (timeout: 20m)
2025-01-29 02:27:14 [INFO] Tool completed: katana (4m 32s)
2025-01-29 02:27:14 [INFO] Phase completed: url-discovery (7m 34s)
2025-01-29 02:27:15 [INFO] Run completed: 27m 15s
2025-01-29 02:27:16 [INFO] Changes detected: +12 subdomains, +45 URLs
2025-01-29 02:27:18 [INFO] Discord notification sent (2s)
2025-01-29 02:27:18 [INFO] Markdown report generated: recon/history/reports/2025-01-29-report.md
2025-01-29 02:27:19 [INFO] Run completed successfully
```

#### `zolt schedule clean`

Clean up old data based on retention policy.

```bash
# Clean based on retention policy
zolt schedule clean daily-recon.toml

# Clean older than N days
zolt schedule clean daily-recon.toml --older-than 30

# Preview what would be deleted
zolt schedule clean daily-recon.toml --dry-run

# Clean all schedules
zolt schedule clean --all
```

**Output:**
```
Cleaning schedule: daily-recon.toml
Retention policy: 30 days

Will be deleted:
  recon/history/2024-12-15-subdomains.txt (45 days old)
  recon/history/2024-12-15-urls.txt (45 days old)
  recon/history/2024-12-16-subdomains.txt (44 days old)
  recon/history/2024-12-16-urls.txt (44 days old)
  ... (28 files total, 156 MB)

Proceed? [y/N]: y

✓ Cleaned 28 files (156 MB)
✓ History now contains 30 days of data
```

### Utility Commands

#### `zolt schedule templates`

List available schedule templates.

```bash
zolt schedule templates

# Show template details
zolt schedule templates --show daily-recon
```

**Output:**
```
Available Templates:

  daily-recon
    Standard daily reconnaissance
    Phases: 4 (subdomain, validation, url-discovery, port-scan)
    Tools: 8 tools
    Duration: ~45 minutes

  quick-recon
    Fast reconnaissance for frequent runs
    Phases: 2 (subdomain, validation)
    Tools: 3 tools
    Duration: ~15 minutes

  comprehensive-recon
    Thorough reconnaissance with all tools
    Phases: 6 (subdomain, validation, url, js, ports, vuln-scan)
    Tools: 15 tools
    Duration: ~2-3 hours

  custom
    Start with empty configuration

Use: zolt schedule create --template <name>
```

#### `zolt schedule export`

Export schedule data.

```bash
# Export schedule config
zolt schedule export daily-recon.toml

# Export with all historical data
zolt schedule export daily-recon.toml --include-history

# Export as zip
zolt schedule export daily-recon.toml --output schedule.zip

# Export specific date range
zolt schedule export daily-recon.toml --from 2025-01-01 --to 2025-01-31
```

#### `zolt schedule import`

Import schedule data.

```bash
# Import schedule
zolt schedule import schedule.zip

# Import to specific location
zolt schedule import schedule.zip --target ./bounty/

# Import with rename
zolt schedule import schedule.zip --rename techcorp-daily
```

## 3. Common Workflows

### Setting Up First Schedule

```bash
# Step 1: Initialize target (already done)
zolt init -o hackerone -c "TechCorp" -w wildcards.txt
cd TechCorp

# Step 2: Install tools (already done)
zolt tools install

# Step 3: Create initial subdomain list
echo "techcorp.com" > recon/subdomains/passive/passive.txt

# Step 4: Create schedule configuration
zolt schedule create
# Interactive prompts:
#   - Name: TechCorp Daily Recon
#   - Interval: daily
#   - Time: 02:00 UTC
#   - Notifications: Discord
#   - Template: daily-recon

# Step 5: Validate configuration
zolt schedule validate daily-recon.toml

# Step 6: Test run (foreground)
zolt schedule start daily-recon.toml --once

# Step 7: Review results
zolt schedule diff daily-recon.toml

# Step 8: Start daemon
zolt schedule start daily-recon.toml

# Step 9: Check status
zolt schedule status daily-recon.toml

# Step 10: View logs
zolt schedule logs daily-recon.toml --follow
```

### Daily Workflow

```bash
# Morning check - see what changed overnight
zolt schedule diff daily-recon.toml

# Generate report for review
zolt schedule report daily-recon.toml --format markdown --output review.md

# Check status of all schedules
zolt schedule list --detailed

# Review any failed runs
zolt schedule status daily-recon.toml --history

# If investigating a specific change
zolt schedule diff daily-recon.toml --category subdomains

# Generate weekly summary
zolt schedule report daily-recon.toml --summary --days 7
```

### Adding New Tool to Existing Schedule

```bash
# Edit schedule
zolt schedule edit daily-recon.toml

# Or add tool via CLI
zolt schedule edit daily-recon.toml --add-tool

# Interactive prompts:
#   - Phase: url-discovery
#   - Tool name: gospider
#   - Command: gospider -S recon/subdomains/alive.txt -o recon/urls/spider.txt
#   - Timeout: 15m
#   - Retry count: 1

# Validate changes
zolt schedule validate daily-recon.toml

# Test run
cp daily-recon.toml test-config.toml
zolt schedule start test-config.toml --once

# If successful, start new version
zolt schedule stop daily-recon.toml
zolt schedule start daily-recon.toml
```

### Troubleshooting Failed Run

```bash
# Check status for error
zolt schedule status daily-recon.toml

# View logs around failure
zolt schedule logs daily-recon.toml --date 2025-01-28 | grep -A 20 -B 5 ERROR

# Run manually to reproduce
zolt schedule start daily-recon.toml --once --force

# Check if tools are installed
which subfinder amass httpx

# Check if target files exist
ls -la recon/subdomains/passive/passive.txt

# Re-validate config
zolt schedule validate daily-recon.toml --check-tools

# Once fixed, restart
zolt schedule stop daily-recon.toml
zolt schedule start daily-recon.toml
```

## 4. Configuration Validation

### Pre-Run Validation

Before each run, zolt validates:

1. **Configuration Syntax**: TOML syntax validation
2. **Required Sections**: schedule, at minimum one phase
3. **File Existence**: All target files and required files exist
4. **Command Validity**: Tools referenced in commands are installed
5. **Directory Permissions**: Can write to output directories
6. **Notification Configs**: Webhooks and credentials are valid
7. **Cron Expression**: Valid cron syntax (if using cron)
8. **Phase Dependencies**: No circular dependencies
9. **Resource Limits**: Reasonable timeout and retry values

### Validation Rules

```toml
# Schedule must have name and either cron or interval
[schedule]
name = "My Recon"           # Required, max 100 chars
cron = "0 2 * * *"          # Required if interval not set
interval = "daily"          # Required if cron not set
enabled = true              # Optional, default: true

# Each phase must have name and priority
[[recon_phase]]
name = "subdomain-enum"     # Required, unique within schedule
priority = 1                # Required, 1-100
enabled = true              # Optional, default: true
parallel = false            # Optional, default: false

# Each tool must have name and command
[[recon_phase.tools]]
name = "subfinder"          # Required
timeout = "5m"              # Required, format: <number><unit>
retry_count = 2             # Optional, default: 1
continue_on_failure = true  # Optional, default: true
command = "subfinder ..."   # Required
```

### Validation Errors and Warnings

**Errors (prevent execution):**
- Missing required field
- Invalid cron expression
- Circular dependencies
- Required file not found
- Timeout value too large (>24h)
- Invalid retry count (<0 or >10)

**Warnings (execution continues):**
- Optional notification not configured
- Very long timeout (suspicious)
- High retry count (may indicate flaky tool)
- Large retention period (disk usage)
- Tool not found in PATH (with --check-tools)

## 5. Notification Design

### Discord Notification

![Discord Embed](https://via.placeholder.com/500x300?text=Discord+Embed)

```json
{
  "embeds": [{
    "title": "🎯 Recon Complete: TechCorp",
    "color": 3066993,
    "fields": [
      {
        "name": "Runtime",
        "value": "31m 42s",
        "inline": true
      },
      {
        "name": "Status",
        "value": "✓ Successful",
        "inline": true
      },
      {
        "name": "New Subdomains",
        "value": "+12",
        "inline": true
      },
      {
        "name": "New URLs",
        "value": "+45",
        "inline": true
      }
    ],
    "timestamp": "2025-01-29T02:31:15Z"
  }]
}
```

### Slack Notification

```json
{
  "text": "Recon Complete: TechCorp",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🎯 Recon Complete: TechCorp"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Runtime:*\n31m 42s"
        },
        {
          "type": "mrkdwn",
          "text": "*Status:*\n✓ Successful"
        },
        {
          "type": "mrkdwn",
          "text": "*New Subdomains:*\n+12"
        },
        {
          "type": "mrkdwn",
          "text": "*New URLs:*\n+45"
        }
      ]
    }
  ]
}
```

### Email Notification

**Subject:** 🎯 Zolt Recon Update: TechCorp (+12 subdomains, +45 URLs)

```
Reconnaissance completed successfully for TechCorp.

Summary:
• Runtime: 31m 42s
• New subdomains: 12
• New URLs: 45
• New ports: 3

Notable Findings:

1. api-internal.techcorp.com
   New internal API endpoint discovered.

2. staging-admin.techcorp.com
   New staging admin panel.

3. mobile-backend.techcorp.com
   New mobile backend API.

View full report: recon/history/reports/2025-01-29-report.md

Report generated by Zolt
```

## 6. Exit Codes

- `0` - Success
- `1` - General error
- `2` - Configuration error
- `3` - Validation failed
- `4` - Schedule not found
- `5` - Permission denied
- `6` - Tool dependency missing
- `7` - File not found
- `8` - Network error
- `10` - Schedule already running
- `11` - Schedule not running
- `20` - Notification failed

## 7. Help and Documentation

### Main Help

```bash
zolt schedule --help
```

**Output:**
```
zolt-schedule - Automated reconnaissance scheduling

Usage:
  zolt schedule <command> [options]

Commands:
  create      Create a new schedule configuration
  list        List all configured schedules
  start       Start a schedule (daemon or once)
  stop        Stop a running schedule
  status      Get detailed status of a schedule
  diff        View differences between runs
  report      Generate reports
  validate    Validate schedule configuration
  edit        Edit schedule configuration
  logs        View schedule logs
  clean       Clean up old data
  templates   List available templates
  export      Export schedule data
  import      Import schedule data

Options:
  -h, --help     Show this help message
  -v, --version  Show version information

Examples:
  zolt schedule create                 # Interactive create
  zolt schedule list                   # List schedules
  zolt schedule start daily-recon.toml # Start schedule daemon
  zolt schedule status daily-recon.toml # Check status
  zolt schedule diff daily-recon.toml  # View changes

Run 'zolt schedule <command> --help' for more information.
```

### Command-Specific Help

```bash
zolt schedule start --help
```

**Output:**
```
Start a schedule (run once or start daemon)

Usage:
  zolt schedule start <config> [options]

Arguments:
  <config>  Path to schedule configuration file (TOML)

Options:
      --once         Run once and exit (foreground)
      --follow       Follow logs after starting
      --force        Run immediately, ignore schedule
      --config-dir   Custom configuration directory
  -h, --help         Show this help message

Examples:
  zolt schedule start daily-recon.toml            # Start daemon
  zolt schedule start daily-recon.toml --once     # Run once
  zolt schedule start daily-recon.toml --follow   # Start and follow logs
  zolt schedule start daily-recon.toml --force    # Run immediately

Exit Codes:
  0  - Success
  1  - General error
  3  - Configuration validation failed
  10 - Schedule already running

The daemon will:
  • Validate configuration
  • Set up logging
  • Wait for next scheduled run
  • Execute reconnaissance phases
  • Generate diffs and reports
  • Send notifications
  • Clean old data based on retention
```

## 8. Configuration Examples

### Minimal Configuration

```toml
[schedule]
name = "Minimal Recon"
interval = "daily"

[[recon_phase]]
name = "subdomains"
priority = 1

[[recon_phase.tools]]
name = "subfinder"
command = "subfinder -d techcorp.com -o subdomains.txt"
timeout = "10m"
```

### Advanced Configuration

```toml
[schedule]
name = "Comprehensive Recon"
cron = "0 3 * * 0"  # Sunday 3 AM
retention_days = 90
timezone = "America/New_York"

[validation]
required_files = ["domains.txt"]

[[recon_phase]]
name = "passive-recon"
priority = 1
parallel = false

[[recon_phase.tools]]
name = "subfinder"
command = "subfinder -dL domains.txt -o passive/subfinder.txt"
timeout = "15m"
retry_count = 3

[[recon_phase.tools]]
name = "amass"
command = "amass enum -df domains.txt -o passive/amass.txt"
timeout = "30m"
retry_count = 2

[[recon_phase.tools]]
name = "assetfinder"
command = "assetfinder --subs-only < domains.txt > passive/assetfinder.txt"
timeout = "10m"

[[recon_phase]]
name = "active-recon"
priority = 2
parallel = false
depends_on = ["passive-recon"]

[[recon_phase.tools]]
name = "dns-resolution"
command = "cat passive/*.txt | anew all.txt | dnsx -o resolved.txt"
timeout = "20m"

[[recon_phase.tools]]
name = "bruteforce"
command = "puredns bruteforce wordlist.txt domains.txt -o bruteforce.txt"
timeout = "30m"
retry_count = 1

[[recon_phase]]
name = "validation"
priority = 3
parallel = true
depends_on = ["active-recon"]

[[recon_phase.tools]]
name = "httpx"
command = "cat resolved.txt bruteforce.txt | httpx -o alive.txt"
timeout = "20m"

[[recon_phase.tools]]
name = "nmap"
command = "cat alive.txt | naabu -o ports.txt"
timeout = "25m"

[[recon_phase]]
name = "content-discovery"
priority = 4
parallel = false
depends_on = ["validation"]

[[recon_phase.tools]]
name = "gau"
command = "cat alive.txt | gau > urls.txt"
timeout = "15m"

[[recon_phase.tools]]
name = "katana"
command = "katana -list alive.txt -o crawled.txt"
timeout = "30m"

[[recon_phase.tools]]
name = "gospider"
command = "gospider -S alive.txt -o spider.txt"
timeout = "20m"

[notifications]
enabled = true
notify_on = "change"
include_stats = true
include_preview = false  # Too many URLs to preview

[notifications.discord]
enabled = true
webhook_url = "${DISCORD_WEBHOOK}"
mention_user_id = "123456789"
color = 3066993

[output]
log_level = "info"
save_raw_output = true
compress_after_days = 3
history_dir = "recon/history"
markdown_report = true
json_report = true

[diff]
tool = "delta"
compare_categories = ["subdomains", "urls", "ports"]
context_lines = 2
max_preview_items = 50
```

## 9. Error Handling

### Error Recovery Strategies

**Tool Failure:**
- Log error with context
- If `continue_on_failure = true`, continue to next tool
- If `continue_on_failure = false`, stop phase and notify
- Retry if `retry_count > 0`
- Capture stdout/stderr for debugging

**Network Failure:**
- Retry with exponential backoff
- Log warning after each retry
- Fail tool after max retries
- Continue based on `continue_on_failure`

**Configuration Error:**
- Validate before starting schedule
- Fail fast with clear error messages
- Suggest fixes where possible
- Log validation results

**Permission Error:**
- Check file permissions on startup
- Log specific permission issue
- Suggest chmod command if applicable
- Exit with code 5

**Missing Tool:**
- Check tool availability on startup (with --check-tools)
- Log specific missing tool
- Suggest installation command
- Exit with code 6

### User-Facing Error Messages

**Good:**
```
Error: Tool 'amass' not found in PATH

zolt requires amass for this schedule. Install it:
  go install -v github.com/owasp-amass/amass/v4/...@master

Or update the schedule to remove this tool.
```

**Good:**
```
Error: Configuration validation failed

In daily-recon.toml:
  Line 45: Invalid timeout value "5x"
    Expected format: <number><unit> (e.g., "5m", "30s", "1h")

Line 45: timeout = "5x"
                    ^
```

**Bad (too technical):**
```
Error: std.fs.Dir.OpenError.AccessDenied
```

**Bad (unclear next steps):**
```
Error: Something went wrong
```

## 10. Integration with Existing Zolt Commands

The schedule command integrates seamlessly with existing zolt functionality:

```bash
# Initialize target
zolt init -o hackerone -c "TechCorp" -w wildcards.txt
cd TechCorp

# Install tools
zolt tools install

# Create schedule based on target structure
zolt schedule create --template daily-recon

# Tools work with zolt directory structure
# recon/subdomains/passive/*.txt
# recon/subdomains/all.txt
# recon/subdomains/alive.txt
# recon/urls/*.txt
# logs/

# Use other zolt commands alongside schedules
zolt schedule start daily-recon.toml &
zolt manual scan # (future command)
```

## 11. Future Enhancements

**Planned features:**
- Web dashboard for schedule management
- API for programmatic access
- Machine learning for anomaly detection
- Integration with bug bounty platforms
- Collaborative features (team schedules)
- Mobile notifications
- Cloud storage for history
- Graphical diff visualization
- Export to other formats (CSV, XML)
- Integration with vulnerability scanners
- Auto-escalation for critical findings

**Configuration enhancements:**
- Conditionals (run tool only if file changed)
- Variables and templating
- Include other config files
- Environment-specific configs
- Secret management integration
- Tool version pinning

**Monitoring enhancements:**
- Metrics and stats collection
- Performance profiling
- Resource usage tracking
- Success rate analytics
- Alert on anomalies
- Health check endpointstoml
# daily-recon.toml

[schedule]
name = "TechCorp Daily Recon"
enabled = true
# Run at 2 AM every day
cron = "0 2 * * *"
# Or use simple syntax: "daily", "weekly", "hourly"
interval = "daily"
# Keep last 30 days of results
retention_days = 30

targets = [
    "recon/subdomains/all.txt",
    "recon/urls/alive.txt"
]

[[recon_phase]]
name = "subdomain-enumeration"
enabled = true
priority = 1
# Run tools sequentially within phase
parallel = false

[[recon_phase.tools]]
name = "subfinder"
command = "subfinder -dL recon/subdomains/passive/passive.txt -o recon/subdomains/passive/subfinder.txt"
timeout = "5m"

[[recon_phase.tools]]
name = "amass"
command = "amass enum -df recon/subdomains/passive/passive.txt -o recon/subdomains/passive/amass.txt"
timeout = "10m"

[[recon_phase]]
name = "domain-validation"
enabled = true
priority = 2
parallel = true  # Run in parallel

[[recon_phase.tools]]
name = "httpx"
command = "cat recon/subdomains/passive/*.txt | anew recon/subdomains/all.txt | httpx -o recon/subdomains/alive.txt"
timeout = "15m"

[[recon_phase]]
name = "url-discovery"
enabled = true
priority = 3
parallel = false

[[recon_phase.tools]]
name = "gau"
command = "cat recon/subdomains/alive.txt | gau --threads 5 >> recon/urls/wayback.txt"
timeout = "10m"

[[recon_phase.tools]]
name = "katana"
command = "katana -list recon/subdomains/alive.txt -o recon/urls/crawl.txt"
timeout = "20m"

[notifications]
enabled = true
# Notify only if new subdomains or URLs found
on_change_only = true

[notifications.discord]
enabled = true
webhook_url = "${DISCORD_WEBHOOK}"
mention_user_id = "123456789"

[notifications.slack]
enabled = false
webhook_url = "${SLACK_WEBHOOK}"
channel = "#recon"

[notifications.email]
enabled = false
smtp_server = "smtp.gmail.com"
smtp_port = 587
username = "${EMAIL_USER}"
password = "${EMAIL_PASS}"
to = "hunter@example.com"

[output]
# Log level: debug, info, warning, error
log_level = "info"
# Save raw tool output
save_raw_output = true
# Directory for storing historical results
history_dir = "recon/history"
# Generate markdown report
markdown_report = true

[diff]
# Tools to use for showing differences
tool = "delta"  # or "diff-so-fancy", "native"
# What to compare
compare_fields = ["subdomains", "urls", "ports"]
# Show context lines
context_lines = 3
