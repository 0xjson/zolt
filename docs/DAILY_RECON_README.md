# Daily Reconnaissance Automation

Automated daily reconnaissance workflows for bug bounty hunters.

## Overview

The Daily Recon feature in Zolt provides automated, scheduled reconnaissance that runs every day and tells you **what's new** and **what changed** in your target's attack surface.

Instead of manually running reconnaissance tools and comparing results by hand, Zolt's daily recon:

1. **Automates the 6 core recon steps**:
   - Passive subdomain enumeration
   - Probe alive HTTP/HTTPS
   - Web crawling/spidering
   - JavaScript discovery and analysis
   - Parameter extraction
   - Diff comparison with yesterday

2. **Focuses on what's actionable**: Only shows you what's new since yesterday

3. **Notifies you when interesting changes happen**: New staging subdomains, API endpoints, JavaScript files, or parameters

4. **Maintains history**: Track how your target evolves over time

## Quick Start

### 1. Install Required Tools

```bash
# Install all bug bounty tools
zolt tools install

# Verify installation
subfinder -version
httpx -version
katana -version
```

### 2. Configure API Keys (Important!)

Get better passive recon results by configuring API keys:

```bash
# Create provider config for subfinder
mkdir -p ~/.config/subfinder

# Edit ~/.config/subfinder/provider-config.yaml
cat > ~/.config/subfinder/provider-config.yaml <<EOF
chaos:
  - your_chaos_key_here
securitytrails:
  - your_securitytrails_key_here
shodan:
  - your_shodan_key_here
github:
  - your_github_token_here
virustotal:
  - your_virustotal_key_here
EOF

# Also set environment variables
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

### 3. Create Your Configuration

Copy the example configuration:

```bash
cp examples/techcorp-daily-recon.toml targets/techcorp-daily-recon.toml
```

Update the target and settings:

```toml
[metadata]
target = "your-target.com"
name = "Your Target Daily Recon"

# Set your notification preferences
[notifications.providers.slack]
webhook_url = "${SLACK_WEBHOOK_URL}"
```

### 4. Run Your First Recon

```bash
# Run all 6 steps
zolt daily-recon run -c targets/techcorp-daily-recon.toml
```

This will:
- Run passive subdomain enumeration
- Probe for alive hosts
- Crawl discovered endpoints
- Find JavaScript files
- Extract parameters
- Compare with yesterday (first run creates baseline)

### 5. Review Results

Check the output:

```bash
# Summary of what changed
cat recon/daily/diff/summary_$(date +%Y-%m-%d).md

# New subdomains
cat recon/daily/diff/new_subdomains_$(date +%Y-%m-%d).txt

# New endpoints
cat recon/daily/diff/new_alive_urls_$(date +%Y-%m-%d).txt

# New parameters
cat recon/daily/diff/new_params_$(date +%Y-%m-%d).txt
```

### 6. Set Up Automation

#### Option A: Cron Job

```bash
# Edit crontab
crontab -e

# Add this line (runs daily at 2 AM)
0 2 * * * cd /home/hunter/bugbounty/techcorp.com && zolt daily-recon run -c daily-recon.toml 2>&1 >> /var/log/daily-recon.log

# Or use the provided script
0 2 * * * /home/hunter/bugbounty/automation/daily-recon-runner.sh /home/hunter/bugbounty/techcorp.com/daily-recon.toml
```

#### Option B: Systemd Timer

```bash
# Copy systemd service files
sudo cp automation/systemd/daily-recon.* /etc/systemd/system/

# Enable and start timer
sudo systemctl daemon-reload
sudo systemctl enable --now daily-recon.timer

# Check status
sudo systemctl status daily-recon.timer
sudo systemctl list-timers daily-recon*
```

#### Option C: Docker

```bash
# Build Docker image
docker build -t zolt-daily-recon .

# Run with Docker Compose
docker-compose -f automation/docker/docker-compose.yml up -d
```

## The 6 Steps Explained

### Step 1: Passive Subdomain Enumeration

**Purpose**: Discover subdomains without touching the target

**Tools**: subfinder, amass, assetfinder

**What You Get**:
```
recon/daily/passive_subdomains_YYYY-MM-DD.txt
├── List of all discovered subdomains
└── Merged from multiple sources
```

**Pro Tips**:
- Configure API keys for better results (SecurityTrails, Shodan, etc.)
- First run is baseline, subsequent runs show new additions
- Look for patterns: dev, staging, admin, api subdomains
- Check subdomain count trends (spikes = infrastructure changes)

### Step 2: Probe Alive HTTP/HTTPS

**Purpose**: Find which subdomains are actually accessible

**Tools**: httpx

**What You Get**:
```
recon/daily/httpx_YYYY-MM-DD.json
└── JSON with metadata (status, title, tech, headers, etc.)

recon/daily/alive_urls_YYYY-MM-DD.txt
└── Simple list of live URLs
```

**Pro Tips**:
- httpx JSON contains valuable info (tech stack, headers, etc.)
- Content hashes show if pages changed
- Status code changes (200→403) indicate access changes
- Technology fingerprints reveal new frameworks (potential CVEs)

### Step 3: Web Crawling/Spidering

**Purpose**: Find hidden endpoints and application paths

**Tools**: katana, gospider

**What You Get**:
```
recon/daily/crawled_urls_YYYY-MM-DD.txt
└── All discovered URLs (40,000+ on large sites)
```

**Pro Tips**:
- New paths = new functionality = potential bugs
- Look for: /admin, /api, /upload, /config, /debug
- AJAX/JSON endpoints often have vulnerabilities
- Form endpoints are XSS/CSRF candidates

### Step 4: JavaScript Discovery

**Purpose**: Find JS files for secrets and endpoint discovery

**Tools**: LinkFinder, SecretFinder

**What You Get**:
```
recon/daily/js_files_raw_YYYY-MM-DD.txt
└── URLs to JavaScript files

recon/js/downloaded/YYYY-MM-DD/
└── Downloaded JS files

recon/daily/linkfinder_YYYY-MM-DD.txt
└── Endpoints extracted from JS

recon/daily/secrets_js_YYYY-MM-DD.txt
└── Potential secrets found in JS
```

**Pro Tips**:
- JS files often contain hardcoded API keys (even test keys are valuable)
- Look for .map files (source maps with original source code)
- Internal API endpoints likely not in spider results
- Hardcoded credentials in development code

### Step 5: Parameter Extraction

**Purpose**: Find parameters for targeted testing (IDOR, XSS, SQLi)

**Tools**: unfurl, arjun

**What You Get**:
```
recon/daily/urls_with_params_YYYY-MM-DD.txt
└── URLs containing query parameters

recon/daily/param_names_YYYY-MM-DD.txt
└── Unique parameter names (id, userId, etc.)

recon/daily/arjun_params_YYYY-MM-DD.json
└── Hidden parameters discovered via active scanning
```

**Pro Tips**:
- Fresh parameters = fresh potential bugs
- id, userId, accountId = IDOR candidates
- redirect, url = open redirect/SSRF candidates
- search, q = XSS/SQLi test points

### Step 6: Diff vs Yesterday

**Purpose**: Tell you what's ACTUALLY new

**What You Get**:
```
recon/daily/diff/
├── new_subdomains_YYYY-MM-DD.txt          (New subdomains)
├── new_alive_urls_YYYY-MM-DD.txt          (New endpoints)
├── new_js_files_YYYY-MM-DD.txt            (New JS deployed)
├── new_params_YYYY-MM-DD.txt              (New parameters)
├── new_crawled_YYYY-MM-DD.txt             (New paths found)
└── summary_YYYY-MM-DD.md                  (Human readable)
```

**Pro Tips**:
- This is the MOST IMPORTANT step
- Focus on these files, not the raw data
- Set thresholds to avoid notification fatigue
- First scan = no diff (baseline), second scan = first diff

## Understanding the Diff Output

### The Summary File

```bash
cat recon/daily/diff/summary_2025-01-29.md
```

Example:
```markdown
# Daily Recon Diff Summary - 2025-01-29

**Target**: techcorp.com
**Scan Date**: Wed Jan 29 02:00:05 UTC 2025

## 🎯 New Subdomains (47)

- api-v2.techcorp.com ← NEW API VERSION!
- staging-admin.techcorp.com ← STAGING ADMIN!
- dev-backup.techcorp.com ← DEV BACKUP!
- blog.techcorp.com ← (probably low priority)

## 🌐 New Live Endpoints (12)

- https://api.techcorp.com/v2/users ← NEW API
- https://upload.techcorp.com ← FILE UPLOAD
- https://old.techcorp.com ← Status: 403 (was 200)

## 📊 Statistics

| Metric | Yesterday | Today | Change |
|--------|-----------|-------|--------|
| Subdomains | 1,200 | 1,247 | +47 |
| Live Hosts | 880 | 892 | +12 |
| JS Files | 1,276 | 1,284 | +8 |
| Parameters | 219 | 234 | +15 |

## 🚀 Recommended Actions

1. Test new API v2 endpoints for IDOR/BOLA
2. Investigate staging-admin for misconfigurations
3. Test upload.techcorp.com for file upload vulns
4. Check new JS files for hardcoded secrets
5. Test new parameters: `userId`, `accountId`
```

### What Each Diff File Contains

**new_subdomains_YYYY-MM-DD.txt**:
```
api-v2.techcorp.com
staging-admin.techcorp.com
deploy.techcorp.com
logs.techcorp.com
```

**new_alive_urls_YYYY-MM-DD.txt**:
```
https://api-v2.techcorp.com
https://upload.techcorp.com
https://staging-admin.techcorp.com
```

**new_params_YYYY-MM-DD.txt**:
```
userId
accountId
redirectUrl
searchQuery
```

**new_js_files_YYYY-MM-DD.txt**:
```
https://techcorp.com/static/app-v2.min.js
https://api.techcorp.com/docs/swagger-ui.js
https://cdn.techcorp.com/new-feature.js
```

## Notification Examples

### Slack

![Slack notification showing 47 new subdomains with api-v2.techcorp.com highlighted](https://via.placeholder.com/600x300?text=Slack+Notification)

### Discord

```
🎯 **Daily Recon Update - techcorp.com**

**New Discoveries Today:**

📌 **Subdomains**: 47 new
• api-v2.techcorp.com
• staging-admin.techcorp.com
• dev-backup.techcorp.com

🌐 **Endpoints**: 12 new
• https://api-v2.techcorp.com/v2/users
• https://upload.techcorp.com

⚠️ **Priority Actions**:
1. Test v2 API for IDOR
2. Check staging-admin config
3. Review 8 new JS files for secrets

View full report: <link>
```

### Email

Subject: `[Recon] TechCorp Daily Update - 2025-01-29`

Body: HTML summary with charts and direct links to findings

## Configuration Options

### Basic Configuration

```toml
[metadata]
target = "techcorp.com"
name = "TechCorp Production"

[global]
threads = 50
timeout = 10
rate_limit = 150
output_dir = "recon/daily"
```

### Advanced: Per-Step Configuration

```toml
[steps.passive_subdomains]
enabled = true
timeout_minutes = 30

[[steps.passive_subdomains.tools]]
name = "subfinder"
args = [
    "-d", "{target}",
    "-all",
    "-silent"
]
# Set specific configuration for this tool
critical = false  # Don't fail if this tool fails
```

### Advanced: Notifications

```toml
[[notifications.providers]]
name = "slack"
type = "slack_webhook"
webhook_url = "${SLACK_WEBHOOK_URL}"
# Only notify if more than 5 subdomains found
min_threshold = 5
# Only notify on medium/higher priority
minimum_severity = "medium"
```

### Advanced: Target-Specific Overrides

```toml
# api.techcorp.com gets more intensive scanning
[targets.api.techcorp.com]
crawl_depth = 5  # Deeper crawling on API
timeout = 30     # Longer timeout
rate_limit = 300 # Higher rate limit (internal API)
notify_threshold = 2  # More sensitive notifications

# blog.techcorp.com is low priority
[targets.blog.techcorp.com]
priority = "low"
crawl_depth = 2
notify_threshold = 20  # Only notify on big changes
enabled = false  # Skip entirely if wanted
```

### Advanced: Conditional Execution

```toml
[[steps.parameter_extraction.tools]]
name = "arjun"
# Only run on weekdays (less aggressive on weekends)
schedule = "0 0 * * 1-5"
# Only run if parameter count < 500
condition = "param_count < 500"
```

## Real-World Scenarios

### Scenario 1: New API Version Deployed

**Morning notification**:
```
🎯 api-v2.techcorp.com discovered
🎯 New endpoints in /v2/ path
🎯 8 new JS files (including swagger docs)
```

**Your action**:
1. Read API documentation
2. Test for IDOR/BOLA in user endpoints
3. Check for missing authentication
4. Subdomain takeover possibilities

**Result**: 🏆 Found IDOR in /v2/users/{userId} endpoint

### Scenario 2: Staging/Dev Environment Found

**Morning notification**:
```
🎯 staging-admin.techcorp.com discovered
🎯 No authentication required (403 yesterday, 200 today)
🎯 Internal tech stack detected
```

**Your action**:
1. Check for default credentials
2. Look for debug/development features
3. Test for configuration vulnerabilities
4. Check if data is real or synthetic

**Result**: 🏆 Found default admin:admin credentials

### Scenario 3: New Upload Functionality

**Morning notification**:
```
🎯 upload.techcorp.com is now alive
🎯 JavaScript shows /api/upload endpoint
🎯 uploadAllowedFileTypes parameter added
```

**Your action**:
1. Test file upload bypasses
2. Try different file types
3. Check for path traversal in filename
4. Test upload to unexpected directories

**Result**: 🏆 Uploaded PHP file leading to RCE

## Best Practices

### 1. Start Conservative

```toml
# Begin with light touch
[global]
rate_limit = 50
timeout = 15

[steps.crawl]
max_urls_per_host = 500
depth = 2

[notifications]
threshold = 10  # Higher threshold initially
```

### 2. Tune Thresholds

Don't get notification fatigue:

```toml
# After 1-2 weeks, adjust based on your target
[[steps.diff_comparison.comparisons]]
name = "new_subdomains"
notify_threshold = 5  # Adjust this based on typical changes
```

### 3. Use API Keys

Passive recon is 10x better with API keys:

```bash
# Get free/paid keys from:
# - SecurityTrails (excellent)
# - Shodan (good)
# - Chaos (ProjectDiscovery)
# - GitHub (for discovering dev subdomains)
# - VirusTotal (passive DNS)
```

### 4. Review False Positives

Every week, review what you marked as uninteresting:

```bash
# Check your notification logs
rgrep "notification sent" logs/ | grep -v "staging\|admin\|api"

# Adjust config to filter these
[diff_comparison.filters]
ignore_subdomains = ["blog", "shop", "docs"]
ignore_titles = ["Coming Soon", "Maintenance"]
```

### 5. Integrate with Your Workflow

```bash
# Automatically import to Burp
cat recon/daily/diff/new_alive_urls_*.txt | \
  xargs -I {} curl -x http://127.0.0.1:8080 -s -k {} > /dev/null

# Feed to ffuf for fuzzing
ffuf -u "https://api.techcorp.com/FUZZ" \
     -w recon/daily/diff/new_crawled_*.txt \
     -o recon/fuzzing_results.json
```

## Troubleshooting

### Issue: "No tools found"

```bash
# Install tools
zolt tools install

# Or install manually
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
```

### Issue: No subdomains found

```bash
# Check API keys
ls -la ~/.config/subfinder/provider-config.yaml

# Test subfinder with debug
subfinder -d target.com -all -v

# Check if target has wildcard DNS
dig target.com
```

### Issue: Getting blocked/WAF

```toml
# Reduce aggressiveness
[global]
rate_limit = 20
timeout = 20
threads = 10

[steps.probe_alive.tools.httpx]
args.delay = "500ms"  # Add delay
args.proxy = "http://your-proxy:8080"  # Use proxy
```

### Issue: Recon takes too long

```toml
# Reduce scope
[steps.crawl]
max_urls_per_host = 500
depth = 2
enabled = false  # Skip entirely if not needed

[steps.parameter_extraction]
tools.arjun.enabled = false  # This is slow
```

## Security Considerations

### Responsible Scanning

- Always respect scope defined by bug bounty program
- Use rate limiting (configured in TOML)
- Consider excluding production during business hours
- Monitor for vendor blocks/WAF responses

### Data Protection

- Keep recon data encrypted (especially if it contains secrets)
- Don't commit API keys to git (use environment variables)
- Use `.gitignore`:

```
# Bug Bounty
recon/
*.toml
.env
provider-config.yaml
```

### Privacy

- Consider using VPN/Tor for anonymity
- Use proxies when scanning sensitive targets
- Rotate IPs if needed (see `proxy` config)

## Support & Contributing

### Documentation

- Full workflow guide: `docs/DAILY_RECON_WORKFLOW.md`
- Configuration reference: see example configs
- Architecture: `docs/ARCHITECTURE.md`

### Examples

- Working example: `examples/techcorp-daily-recon.toml`
- Automation scripts: `automation/`

### Contributing

To add new tools or steps:

1. Edit the workflow configuration
2. Add tool to tool registry
3. Update documentation
4. Submit PR with test results

## License

MIT - See LICENSE file

---

**Happy Hunting!** 🎯

Remember: The goal isn't to collect data—it's to find vulnerabilities. Focus on the diff results and actionable intelligence!
