<div align="center">
  <h1>🎯 Zolt User Guide</h1>
  <p><strong>Bug Bounty Reconnaissance - From Setup to Payouts</strong></p>

  <p>
    <a href="#installation--setup">Installation</a> •
    <a href="#core-concepts">Concepts</a> •
    <a href="#daily-bug-bounty-workflow">Daily Workflow</a> •
    <a href="#deep-scan-workflow">Deep Scan</a> •
    <a href="#troubleshooting">Troubleshooting</a>
  </p>
</div>

---

## 🚀 Quick Start (5 minutes)

Get from zero to automated recon in under 10 minutes:

```bash
# 1. Install zolt (requires Zig 0.16.0+)
git clone https://github.com/0xjson/zolt.git
cd zolt && zig build-exe zolt.zig && sudo mv zolt /usr/local/bin/

# 2. Install 15+ bug bounty tools
zolt tools install

# 3. Initialize your first target
zolt init -o hackerone -c "Example Corp"

# 4. Start automated daily recon
cd Example_Corp
zolt schedule run --config daily-recon.toml

# 5. Check results tomorrow
zolt schedule diff --config daily-recon.toml
```

**That's it.** Your reconnaissance now runs itself.

---

## 📋 Table of Contents

1. [Installation & Setup](#installation--setup)
2. [Core Concepts](#core-concepts)
3. [Daily Bug Bounty Workflow](#daily-bug-bounty-workflow)
4. [Deep Scan Workflow](#deep-scan-workflow)
5. [Managing Multiple Targets](#managing-multiple-targets)
6. [Triage & Finding Management](#triage--finding-management)
7. [Automation Setup](#automation-setup)
8. [Real-World Examples](#real-world-examples)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Configuration](#advanced-configuration)

---

## Installation & Setup

### Prerequisites

- **Zig 0.16.0-dev or later**: [Install Zig](https://ziglang.org/download/)
- **Go 1.20+**: Required for tool installation
- **Linux/macOS**: Zolt is optimized for Unix-like systems
- **8GB+ RAM**: Recommended for smooth operation

### Step-by-Step Installation

```bash
# Clone zolt
git clone https://github.com/0xjson/zolt.git
cd zolt

# Build
zig build-exe zolt.zig

# Move to PATH
sudo mv zolt /usr/local/bin/

# Verify
zolt --version
```

**Expected output:**
```
zolt version 0.1.0
```

### Tool Installation

Install 15+ bug bounty tools with one command:

```bash
zolt tools install

# Expected output:
# ✓ Found Go installation: /usr/local/go/bin/go
#   Installing chaos... ✓
#   Installing subfinder... ✓
#   Installing httpx... ✓
#   [...]
# ✓ All 15 tools installed successfully to ~/go/bin
```

**What gets installed:**
- **Passive Recon**: subfinder, amass, assetfinder, chaos
- **HTTP Toolkit**: httpx, naabu
- **Web Crawling**: katana, gospider, gau
- **Fuzzing**: ffuf
- **Utilities**: anew, unfurl, qsreplace

**Installation Issues?** See [Troubleshooting](#troubleshooting-common-tool-issues)

---

## Core Concepts

### Project Structure

Zolt creates an organized directory for each target:

```
TechCorp/
├── recon/                    # All reconnaissance data
│   ├── subdomains/          # Subdomain discoveries
│   │   ├── all.txt
│   │   ├── alive.txt        # HTTP/HTTPS accessible
│   │   └── passive/         # Passive enum results
│   ├── urls/                # Discovered URLs
│   │   ├── alive.txt
│   │   ├── crawl.txt        # Spider results
│   │   └── params.txt       # URLs with parameters
│   ├── js/                  # JavaScript files
│   │   ├── files.txt
│   │   ├── downloaded/      # Downloaded JS for analysis
│   │   └── secrets.txt      # Extracted secrets
│   ├── ports/               # Port scan results
│   ├── tech/                # Technology fingerprints
│   └── screenshots/         # Visual snapshots
├── findings/                # Your bug reports
│   ├── drafts/              # Work in progress
│   ├── submitted/           # Sent to programs
│   └── accepted/            # Accepted bugs (🎉)
├── logs/                    # Daily scan logs
├── manual/                  # Manual testing notes
│   ├── xss/                 # XSS vectors
│   ├── sqli/                # SQLi tests
│   └── idor/                # IDOR findings
└── screenshots/             # Proof-of-concepts
```

### The Zolt Philosophy

**1. Structured Directories**
Every target gets the same organized structure. No more hunting for data.

**2. Tool Orchestration**
Zolt doesn't reinvent tools—it manages them. Run 15+ tools with one config.

**3. Automation-First**
Daily reconnaissance runs on autopilot. You review results, not run commands.

**4. Diff-Driven**
Focus on what's **new**, not what's there. New subdomains = new attack surface.

---

## Daily Bug Bounty Workflow

This is the **morning routine** that should take < 10 minutes.

### Step 1: Check Overnight Results (2 min)

```bash
cd TechCorp

# See what changed in the last 24h
zolt schedule diff --config daily-recon.toml

# Expected output:
# 🎯 Target: techcorp.com
# 📅 Scan: 2026-01-30 02:00:00 UTC (Completed in 47m)
#
# ┌───────────────────────┬───────┬────────┐
# │ Metric                │ Found │ Changed│
# ├───────────────────────┼───────┼────────┤
# │ Total Subdomains      │ 3,847 │ +12 🆕│
# │ Live Endpoints        │ 234   │ +47 🆕│
# │ JavaScript Files      │ 156   │ +3  🆕│
# │ URLs with Parameters  │ 1,239 │ +89 🆕│
# └───────────────────────┴───────┴────────┘
```

### Step 2: Review High-Value Changes (5 min)

Check the most promising new targets:

```bash
# Show new subdomains with HTTP status
zolt recon show --diff subdomains --status

# Expected output:
# api-v2.techcorp.com           [200]  nginx  ← New API!
# admin-staging.techcorp.com    [401]  Apache ← Staging!
# dev-backup.techcorp.com       [403]  nginx
# 👆 Start with staging environments
```

**What to look for:**
- ✅ New API versions (api-v2, api-new)
- ✅ Staging/dev environments
- ✅ Admin panels
- ✅ Backup servers
- ✅ New technology stacks

### Step 3: Investigate Interesting Finds (3 min)

```bash
# Check what's on that staging subdomain
cat recon/subdomains/alive.txt | grep "staging"
# Shows: admin-staging.techcorp.com

# Quick port scan
naabu -host admin-staging.techcorp.com -p 8443,8080,8000

# If 8443 open, check what it is
httpx -u https://admin-staging.techcorp.com:8443 -title
# Shows: Admin Dashboard - Login
```

### Step 4: Start Manual Testing

```bash
# In your manual testing directory
cd manual/auth/

# Test for default credentials
# Test admin:admin, admin:password, etc.

# If you find something
cp poc.png findings/drafts/auth-bypass-staging-001/
```

**Total time: < 10 minutes** to know if today is a "test this" day.

---

## Deep Scan Workflow

For when you've identified a promising target and want to dig deep.

### When to Use Deep Scan

Use this when:
- ✅ New subdomain with interesting tech stack
- ✅ Staging/dev environment discovered
- ✅ Admin panel found
- ✅ You've found low-hanging fruit, time to go deep

### Running a Comprehensive Scan

```bash
# Use the comprehensive template
cp templates/comprehensive-recon.toml deep-scan-techcorp.toml

# Edit to focus on your target subdomain
vim deep-scan-techcorp.toml
```

**Example configuration:**
```toml
[metadata]
name = "Deep Scan - API v2"
target = "api-v2.techcorp.com"
description = "Full recon on new API endpoint"

[steps]
# Enable all phases
passive_subdomains = true
probe_alive = true
crawl = true
js_discovery = true
parameter_extraction = true
port_scan = true        # Enable port scanning
vulnerability_scan = true  # Run nuclei

[steps.port_scan]
# Focus on common API ports
ports = [80, 443, 8000-9000, 3000, 5000, 7000, 8080, 8443]

[steps.crawl.tools.katana]
# Crawl deeper on interesting targets
depth = 5
max_urls = 5000
```

### Execute the Deep Scan

```bash
# Run manually (takes 2-3 hours)
zolt recon run --config deep-scan-techcorp.toml

# Or set up temporary schedule (run overnight)
zolt schedule install --config deep-scan-techcorp.toml --once
```

### Deep Scan Results Analysis

After completion, analyze results:

```bash
# 1. Check for new technologies
cat recon/tech/fingerprints.txt | sort | uniq -c | sort -rn

# 2. Review JavaScript files for secrets
grep -E "(api_key|secret|token|password)" recon/js/secrets.txt

# 3. Find all login/admin endpoints
grep -iE "(login|admin|dashboard|panel)" recon/urls/crawled.txt

# 4. Extract all parameters for fuzzing
cat recon/urls/params.txt | unfurl keys | sort -u > params-to-test.txt
```

---

## Managing Multiple Targets

Juggling 5+ bug bounty programs? Here's how to stay organized.

### Directory Structure

```
~/bounty/
├── Program1_Hackerone/
│   ├── daily-recon.toml
│   └── targets.txt
├── Program2_Bugcrowd/
│   ├── daily-recon.toml
│   └── targets.txt
├── Program3_Intigriti/
├── archives/                    # Old/inactive programs
└── active-programs.txt          # Track what's active
```

### Multi-Target Automation

Run recon on ALL active targets overnight:

```bash
#!/bin/bash
# ~/bounty/run-all-recon.sh

cd ~/bounty

for dir in */; do
    if [ -f "$dir/daily-recon.toml" ]; then
        echo "Starting recon for $dir"
        cd "$dir"

        # Run in background
        zolt schedule run --config daily-recon.toml &

        cd ..
    fi
done

echo "All recon jobs started. Check results in the morning."
```

Make it a cron job:
```bash
# Run every night at 2 AM
0 2 * * * /home/user/bounty/run-all-recon.sh
```

### Morning Review Workflow

```bash
cd ~/bounty

# Check all programs at once
for dir in */; do
    echo "=== $dir ==="
    cd "$dir"
    zolt schedule status --config daily-recon.toml
    cd ..
done | grep -E "(completed|found|error)"

# Focus on programs with significant changes
```

---

## Triage & Finding Management

### Finding Directory Structure

```
findings/
├── drafts/                     # Active research
│   ├── xss-api-v2-001/        # XSS on api-v2
│   │   ├── poc.png            # Screenshot
│   │   ├── request.txt        # HTTP request
│   │   ├── notes.md           # Your notes
│   │   └── severity.md        # Impact assessment
│   └── sqli-admin-001/        # SQLi on admin
├── submitted/                   # Sent to programs
│   └── xss-api-v2-001-submitted/
└── accepted/                    # Paid findings
    ├── $500/
    └── $1000/
```

### Triage Workflow

When you find something interesting:

```bash
# 1. Create finding directory
mkdir -p findings/drafts/potential-xss-001
cd findings/drafts/potential-xss-001

# 2. Document immediately (while you have it open)
cat > notes.md << 'EOF'
# Finding: Reflected XSS on search parameter

## Reproduction
1. Visit https://target.com/search?q=test
2. Change q parameter to: <script>alert(1)</script>
3. Alert pops up

## Impact
Medium - Cookie theft possible

## Evidence
- Screenshot: poc.png
- Request: request.txt
- Full URL: https://target.com/search?q=<script>alert(1)</script>

## Notes
- Discovered via daily recon: crawled-2026-01-30.txt
- Might need to bypass WAF
EOF

# 3. Take screenshot
# (Use your screenshot tool)

# 4. Save request
cat > request.txt << 'EOF'
GET /search?q=<script>alert(1)</script> HTTP/1.1
Host: target.com
User-Agent: Mozilla/5.0...
EOF
```

### Severity Tagging

Tag your drafts by potential payout:

```bash
# Tag based on impact
cd findings/drafts/

# Critical (RCE, full account takeover)
mv sqli-admin-001/ critical-sqli-admin-001/

# High (XSS, sensitive data leak)
mv xss-api-key-001/ high-xss-api-key-001/

# Medium (some impact but limited)
mv open-redirect-001/ medium-open-redirect-001/

# Then work on critical/high first
```

---

## Automation Setup

### Getting Started with Automation

**Step 1: Copy template**
```bash
cd TechCorp
cp templates/daily-recon.toml .
```

**Step 2: Customize to your target**
```toml
[metadata]
name = "TechCorp Daily Recon"
version = "1.0"
target = "techcorp.com"

# Adjust based on program scope
[scope]
include = ["*.techcorp.com", "techcorp.io"]
exclude = ["blog.techcorp.com", "status.techcorp.com"]

# Your notification preferences
[notifications]
slack_webhook = "https://hooks.slack.com/..."
discord_webhook = "https://discord.com/api/webhooks/..."
```

**Step 3: Test manually first**
```bash
# Dry run first
zolt schedule run --config daily-recon.toml --dry-run

# Run once to verify
zolt schedule run --config daily-recon.toml
```

**Step 4: Install cron job**
```bash
# Install daily at 2 AM
zolt schedule install --config daily-recon.toml --time 02:00

# Verify it worked
crontab -l | grep zolt
```

### Advanced Automation Patterns

**1. Different Schedules for Different Targets**

```toml
# High-value target - scan twice daily
[schedule]
frequency = "12h"  # Every 12 hours

# Low-value target - scan weekly
[schedule]
frequency = "weekly"
day = "sunday"
time = "03:00"
```

**2. API Rate Limit Management**

```toml
[rate_limiting]

# Respect Shodan API limits
[rate_limiting.providers.shodan]
daily_quota = 100
strategy = "delay"  # Slow down when near limit

# Stop completely when reaching VirusTotal limits
[rate_limiting.providers.virustotal]
daily_quota = 500
strategy = "stop"
```

**3. Conditional Notifications**

```toml
[notifications]
enabled = true

# Only notify if finding something interesting
min_threshold = 10  # Only if 10+ new findings

# Or notify on specific conditions
notify_if = [
    "new_subdomains > 5",
    "new_endpoints > 20",
    "contains_keyword('staging')",
    "contains_keyword('dev')"
]
```

---

## Real-World Examples

### Example 1: New Program Onboarding

**Scenario:** HackerOne invited you to a new private program

**Your steps:**
```bash
# 1. Initialize target
zolt init -o hackerone -c "NewStartup" -w wildcards.txt

# 2. First, stealthy recon to establish baseline
cd NewStartup
zolt schedule run --config templates/comprehensive-recon.toml

# (Wait 3-4 hours)

# 3. Review baseline
zolt schedule report --config comprehensive-recon.toml

# Findings:
# - 2,847 subdomains
# - 183 live hosts
# - 12 staging/dev environments ← Start here!

# 4. Deep dive on staging environments
mkdir staging-recon
vim staging-recon/config.toml
# Configure focused scan on admin-staging.newstartup.com

# 5. Find something interesting in logs
grep -i "admin" recon/urls/crawled.txt
# Found: https://admin-staging.newstartup.com/admin/login.php

# 6. Manual testing reveals default credentials!
# admin:admin works → Report submitted → $2,500 bounty
```

**Key takeaway:** Daily automation found the target, manual testing found the bug

---

### Example 2: Regression Hunting

**Scenario:** Company pushes new code every Friday

**Strategy:** Monitor for new JavaScript files (often contain secrets)

```bash
# In daily-recon.toml
[steps.js_discovery]
enabled = true
download_js = true

# Set up daily automation
zolt schedule install --config daily-recon.toml

# Check every Monday morning
zolt schedule diff --config daily-recon.toml --type js

# Alert email shows:
# 🎯 New JS files discovered: 3
#   - app-v2.4.1.js
#   - admin-dashboard.js  ← Interesting!

# Download and analyze
cat recon/js/downloaded/latest/admin-dashboard.js | grep -i "api_"
# Found: const API_KEY = "sk_live_51H..."

# Check if hardcoded API key!
# Test against their API → Works!
# Report → $1,500 bounty
```

---

### Example 3: Asset Acquisition

**Scenario:** Company announces they acquired another startup

```bash
# Add new root domains to targets
echo "acquired-startup.com" >> recon/subdomains/passive/targets.txt

# Run aggressive passives
subfinder -dL recon/subdomains/passive/targets.txt \
  -all -recursive -o recon/subdomains/all-new.txt

# Find overlap/new infrastructure
# Look for:
# - Shared authentication
# - Common subdomains (api, internal)
# - Certificate transparency logs

# Common scenario: Auth system shared across domains
# Cookie works on both domains → Find XSS on less secure domain
# → Session cookie → Account takeover on main domain
```

---

## Troubleshooting

### Common Tool Installation Issues

**Problem:** `zolt tools install` fails with "go: command not found"

**Solution:**
```bash
# Install Go
# Ubuntu/Debian
sudo apt update && sudo apt install golang

# macOS
brew install go

# Verify
go version

# Re-run
zolt tools install
```

**Problem:** "permission denied" when installing tools

**Solution:**
```bash
# Check Go bin directory in PATH
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc

# Re-run
zolt tools install
```

---

### Daily Recon Failures

**Problem:** Cron job not running

**Debugging:**
```bash
# Check if cron is running
ps aux | grep cron

# Check cron logs
grep CRON /var/log/syslog

# Common issue: Wrong path in cron
# Cron doesn't load your .bashrc
# Fix: Use full paths in crontab

# Edit cron
crontab -e
# Change:
# 0 2 * * * zolt schedule run...
# To:
# 0 2 * * * /usr/local/bin/zolt schedule run...
```

**Problem:** Recon runs but finds nothing

```bash
# Debug step by step

# 1. Check if subfinder works manually
subfinder -d techcorp.com -silent | head -10
# If no results: Check your internet, DNS

# 2. Check config file
cat daily-recon.toml | grep target
# Make sure target is correct

# 3. Check logs
zolt schedule logs --config daily-recon.toml --tail 100

# Common issue: Target in config doesn't match actual target
```

**Problem:** Running out of disk space

```bash
# Check recon directory size
du -sh recon/
# 50GB?! Time to clean up

# Use zolt's retention policy
# Edit daily-recon.toml
[global]
retention_days = 30  # Keep last 30 days

# Or manually clean old logs
find recon/ -name "*.txt" -mtime +30 -delete
find logs/ -name "*.log" -mtime +30 -delete
```

---

### Performance Issues

**Problem:** Recon takes too long (12+ hours)

```bash
# Solutions:

# 1. Reduce threads
[global]
threads = 25  # Down from default 50

# 2. Limit scope
[scope]
exclude = [
    "*.blog.techcorp.com",
    "*.docs.techcorp.com"
]

# 3. Skip heavy tools
[steps.passive_subdomains.tools.amass]
enabled = false  # Amass is thorough but slow

# 4. Reduce depth
[steps.crawl.tools.katana]
depth = 2  # Instead of 3-5
```

**Problem:** System becomes unresponsive during recon

```bash
# Limit memory usage
[performance]
max_memory_mb = 2048  # 2GB limit

# Or use nice/ionice to lower priority
# In crontab:
0 2 * * * nice -n 19 ionice -c 3 zolt schedule run...

# Better: Use zolt's built-in resource management
[performance]
throttle_on_high_cpu = true
pause_on_memory_warning = true
```

---

## Frequently Asked Questions

**Q: How much does zolt cost?**
A: Zolt is free and open-source. Some tools have API costs (Shodan, etc.), but all have free tiers.

**Q: Can I contribute tools to zolt?**
A: Yes! Edit `/src/registry/tools.zig` and submit a PR.

**Q: How is zolt different from recon-ng?**
A: Recon-ng requires manual module configuration. Zolt has opinionated automation built-in.

**Q: Will I get rate-limited?**
A: Possibly. Zolt includes rate limiting. Space out scans and use API keys.

**Q: Can I run zolt in Docker?**
A: Yes! See examples/docker-setup.md

---

## Getting Help

- **Documentation**: https://github.com/0xjson/zolt
- **Issues**: Create an issue on GitHub
- **Discord**: (community link)
- **X/Twitter**: @Jhannnnnnnn (https://x.com/Jhannnnnnnn)

**Debug Mode:**
```bash
# Run with verbose logging
zolt schedule run --config daily.toml --verbose 2>&1 | tee debug.log

# Share debug.log when asking for help
```

---

## Advanced Configuration

### Custom Tool Configuration

**Adding a new tool to zolt:**

```toml
# Edit daily-recon.toml
[[steps.passive_subdomains.tools]]
name = "my-custom-tool"
command = "my-tool"
args = [
    "-d", "{target}",
    "-o", "{output_dir}/my-tool_{date}.txt"
]
timeout_minutes = 30
category = "passive"
```

### Webhook Integration

**Discord Notifications:**
```bash
# Get webhook URL
# Discord → Server Settings → Integrations → Webhooks

export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

**Slack Notifications:**
```bash
# Slack App → Incoming Webhooks
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

---

<div align="center">
<b>Happy hunting! 🎯</b>
<p><em>May your diffs be fruitful and your bounties high.</em></p>
</div>
