# Daily Reconnaissance Automation Workflow

## Overview

This document describes the practical daily reconnaissance automation workflow for bug bounty hunters using Zolt. The system runs 6 automated steps daily, compares results with previous days, and notifies hunters of actionable changes.

## The 6-Step Daily Recon Process

### Step 1: Passive Subdomain Enumeration
**Purpose**: Discover new subdomains without direct interaction with the target

**What it does**:
- Runs multiple passive subdomain enumeration tools in parallel
- Merges results into a unified subdomain list
- Validates domain formats and removes duplicates
- Stores historical data for trending analysis

**Tools Used**:
- **subfinder**: Fast, comprehensive passive sources (requires API keys for best results)
- **amass**: Thorough enumeration with various data sources
- **assetfinder**: Simple and effective passive discovery

**Practical Output**:
```
recon/daily/passive_subdomains_2025-01-29.txt
├── Contains: 1,247 subdomains
├── Format: One domain per line
└── Time to complete: ~30-45 minutes
```

**What Hunters Care About**:
- New subdomains discovered since yesterday
- Subdomain count trends (spikes indicate infrastructure changes)
- Previously unknown attack surface

**Real-World Considerations**:
- API keys configured for services like SecurityTrails, Shodan, Chaos, etc.
- Some sources have daily rate limits (configurable in rate_limiting section)
- Results improve dramatically with paid API keys
- Store results in source control to track changes over time

---

### Step 2: Probe Alive HTTP/HTTPS
**Purpose**: Determine which subdomains have active web services

**What it does**:
- Takes subdomains from Step 1
- Probes for HTTP/HTTPS services
- Extracts metadata (title, tech stack, status codes, content length)
- Identifies redirect chains
- Outputs both JSON (for analysis) and plain URLs

**Tools Used**:
- **httpx**: Fast HTTP toolkit with comprehensive probing features

**Practical Output**:
```
recon/daily/httpx_2025-01-29.json
├── Contains: 892 live endpoints with metadata
├── Format: NDJSON (Newline Delimited JSON)
└ury information (title, server, tech, etc.)

recon/daily/alive_urls_2025-01-29.txt
├── Simple list of live URLs (protocol + host)
└── Format: https://subdomain.target.com (one per line)
```

**Example httpx JSON Output**:
```json
{
  "timestamp": "2025-01-29T10:30:15Z",
  "url": "https://api.techcorp.com",
  "input": "api.techcorp.com",
  "title": "TechCorp API Documentation",
  "scheme": "https",
  "port": "443",
  "path": "/",
  "body_preview": "<!DOCTYPE html><html lang=\"en\">...",
  "status_code": 200,
  "content_length": 18472,
  "content_type": "text/html; charset=utf-8",
  "server": "nginx/1.18.0",
  "response_time": "0.124s",
  "jarm": "27d27d27d29d27d21d27d27d27d27df5e9e9e9e9e9e9e9e9e9e9e9e9e9e9e",
  "hash": {
    "body_md5": "a1b2c3d4e5f60718293a4b5c6d7e8f90",
    "body_mmh3": "-123456789",
    "body_sha256": "e3b0c44298fc1c149afbf4c8996fb924...",
    "header_md5": "f9e8d7c6b5a4938271605f4e3d2c1ba0",
    "header_sha256": "e3b0c44298fc1c149afbf4c8996fb924..."
  },
  "technologies": [
    "Nginx",
    "Google Font API",
    "jQuery",
    "Bootstrap"
  ]
}
```

**What Hunters Care About**:
- New endpoints that weren't alive yesterday
- Changes in status codes (200 → 403 might indicate WAF deployment)
- New technologies detected (potential new attack vectors)
- Content length changes (indicates page updates)
- Redirect chains (potential subdomain takeovers)

**Real-World Considerations**:
- Set appropriate timeouts (10-15 seconds)
- Use rate limiting to avoid triggering defenses
- Some hosts may block based on user-agent (use random agents)
- Consider using proxy rotation for sensitive targets
- Store IPs for infrastructure mapping

---

### Step 3: Web Crawling/Spidering
**Purpose**: Discover hidden endpoints, directories, and functionality

**What it does**:
- Takes live URLs from Step 2
- Crawls each website to find links
- Discovers: directories, files, API endpoints, forms
- Handles JavaScript-rendered content
- Respects scope (same domain crawling)

**Tools Used**:
- **katana**: Modern crawler with headless browser support
- **gospider**: Fast, JavaScript-aware spider

**Practical Output**:
```
recon/daily/crawled_urls_2025-01-29.txt
├── Contains: 45,672 unique URLs discovered
├── Format: Full URLs, one per line
└── Sorted by domain for easier analysis
```

**What Hunters Care About**:
- New application paths discovered
- Administrative interfaces (/admin, /dashboard, etc.)
- API endpoints (/api/, /v1/, /graphql)
- Upload functionality
- Debug endpoints
- Hidden parameters in URLs
- Form endpoints (potential XSS/CSRF)

**Real-World Considerations**:
- Set depth limits (3-5 levels deep) to avoid infinite crawling
- Configure max URLs per host (prevent crawler traps)
- Some sites have anti-bot protections (require delay configurations)
- Respect robots.txt if doing ethical crawling
- Watch for "honeytrap" URLs that detect crawlers
- Use headless mode for JavaScript-heavy applications
- Takes 1-3 hours depending on target size

---

### Step 4: JavaScript Discovery
**Purpose**: Find JavaScript files for secrets, endpoints, and logic analysis

**What it does**:
- Extracts JavaScript file URLs from crawled data
- Downloads JS files locally
- Runs analysis tools to find: API endpoints, secrets, hidden parameters

**Tools Used**:
- **grep**: Extract .js URLs from crawled data
- **wget**: Download JS files locally
- **LinkFinder**: Extract endpoints from JavaScript code

**Practical Output**:
```
recon/daily/js_files_raw_2025-01-29.txt
├── Contains: 1,284 JavaScript URLs
└── Format: https://target.com/static/app.js

recon/js/downloaded/2025-01-29/
├── 1,284 downloaded JS files
└── Stored locally for analysis

recon/daily/linkfinder_2025-01-29.txt
├── Contains: API endpoints found in JS
└── Example: /api/internal/v1/users, /admin/config
```

**What Hunters Care About**:
- **Hardcoded secrets**: API keys, tokens, credentials in JS
- **Hidden API endpoints**: Internal APIs not linked elsewhere
- **Debug functionality**: console.log statements with sensitive data
- **Comments with information**: TODOs, developer notes, internal URLs
- **Third-party integrations**: Analytics keys, tracking IDs
- **Routing logic**: SPA routes revealing hidden functionality

**Real-World Considerations**:
- Some JS files are massive (single page app bundles)
- Minified code is harder to analyze automatically
- Source maps (.js.map files) contain original source code
- Webpack chunks reveal module structure
- API keys in client-side JS are often test/staging keys
- Use tools like `SecretFinder` or custom regex for secrets
- Check for .map files automatically

---

### Step 5: Parameter Extraction
**Purpose**: Identify parameters for testing (XSS, SQLi, IDOR, etc.)

**What it does**:
- Extracts URLs containing parameters (?param=value)
- Uses tools to discover hidden parameters
- Groups parameters by name for targeted testing

**Tools Used**:
- **unfurl**: Extract parameter names from URLs
- **grep**: Find URLs with query parameters
- **arjun**: Active parameter discovery tool

**Practical Output**:
```
recon/daily/urls_with_params_2025-01-29.txt
├── Contains: 8,492 URLs with parameters
└── Format: Full URLs with query strings

recon/daily/param_names_2025-01-29.txt
├── Contains: 234 unique parameter names
└── Format: One parameter name per line

recon/daily/params_by_name_2025-01-29.txt
├── Grouped by parameter name
└── Example:
    ==== id ====
    https://api.techcorp.com/user?id=123
    https://api.techcorp.com/post?id=456
    ==== search ====
    https://techcorp.com/search?q=test

recon/daily/arjun_params_2025-01-29.json
├── Discovered hidden parameters via active scanning
└── JSON format with parameter details
```

**What Hunters Care About**:
- **Common parameters**: id, userId, accountId (potential IDOR)
- **Search parameters**: q, query, search (potential XSS)
- **URL parameters**: url, redirect, next (potential SSRF/open redirect)
- **File parameters**: file, upload, image (potential file upload vulns)
- **New parameters**: Recently added parameters might have bugs
- **Parameter changes**: New accepted values or types

**Real-World Considerations**:
- Arjun is active (sends requests) - rate limit appropriately
- Some parameters are CSRF tokens or session IDs (not interesting)
- RESTful URLs can have "parameters" in path (/user/123 vs /user?id=123)
- GraphQL endpoints have different parameter structures
- Some parameters are only on POST requests (need spider to find forms)
- Create custom wordlists from historical parameters

---

### Step 6: Diff vs Yesterday
**Purpose**: Find what's new, changed, or removed - the actionable intelligence

**What it does**:
- Compares today's results with yesterday's
- Shows only new additions (or changes if configured)
- Generates summary reports
- Triggers notifications for significant changes

**Comparison Points**:
```
1. New subdomains discovered
   - Yesterday: 1,200 subdomains
   - Today: 1,247 subdomains
   - New: 47 subdomains ⚠️

2. New alive endpoints
   - New HTTP services: 12
   - Services that went down: 3

3. New JavaScript files
   - Recently deployed JS: 8 files
   - Potential for new secrets/endpoints

4. New parameters discovered
   - New URL parameters: 15
   - Good candidates for testing

5. New crawled paths
   - New application paths: 234
   - Includes: /api/v2, /admin/new-feature
```

**Practical Output Structure**:
```
recon/daily/diff/
├── new_subdomains_2025-01-29.txt         (47 new subdomains)
├── new_alive_urls_2025-01-29.txt         (12 new endpoints)
├── new_js_files_2025-01-29.txt           (8 new JS files)
├── new_params_2025-01-29.txt             (15 new parameter names)
├── new_crawled_2025-01-29.txt            (234 new paths)
└── summary_2025-01-29.md                 (Human-readable summary)
```

**Example Diff Summary**:
```markdown
# Daily Recon Summary - 2025-01-29

**Target**: techcorp.com
**Scan Duration**: 4 hours 23 minutes
**Comparison**: vs 2025-01-28

## 🎯 New Subdomains (47)

### High Priority
- `api-v2.techcorp.com` - New API version
- `staging-admin.techcorp.com` - Staging environment
- `dev-backup.techcorp.com` - Development backup server

## 🌐 New Live Endpoints (12)

### Interesting Changes
- https://api.techcorp.com/v2/users → Status: 200 (New API version!)
- https://old.techcorp.com → Status changed: 200 → 403 (Possibly restricted)
- https://upload.techcorp.com → New file upload service

## 📊 Statistics

| Metric | Yesterday | Today | Change |
|--------|-----------|-------|--------|
| Total Subdomains | 1,200 | 1,247 | +47 |
| Live Endpoints | 880 | 892 | +12 |
| JS Files | 1,276 | 1,284 | +8 |
| Parameters | 219 | 234 | +15 |
| Crawled URLs | 45,438 | 45,672 | +234 |

## 🚀 Recommended Actions

1. **Test new API v2 endpoints** for IDOR, BOLA vulnerabilities
2. **Investigate staging-admin.techcorp.com** - potential misconfiguration
3. **Test upload.techcorp.com** for file upload vulnerabilities
4. **Check new JavaScript files** for hardcoded secrets
5. **Test new parameters**: `userId`, `accountId`, `redirectUrl`

---
Generated by Zolt Daily Recon
```

**What Hunters Care About**:
- **New attack surface**: Recently deployed infrastructure
- **Changes in status**: New 200s, 403s, 302s indicating changes
- **Technology changes**: New tech stack = potential new vulnerabilities
- **Parameter additions**: Fresh code often has fresh bugs
- **Trends**: Gradual increases might indicate gradual development

**Real-World Considerations**:
- Use `diff -u` or similar for line-by-line comparison
- Consider using `comm` command to find additions only
- Store hashes of content to detect changes (not just additions)
- Sometimes "removals" are important (deprecated services might have leftover vulnerabilities)
- Set intelligent thresholds (notify on 5+ new subdomains, not 1)
- False positives: CDN changes, maintenance pages, temporary redirects

---

## How Diff Works in Practice

### Diff Implementation

The comparison uses simple but effective techniques:

1. **Line-by-line comparison** (for subdomain lists, parameter lists)
   ```bash
   # Find new subdomains (in today but not yesterday)
   comm -13 <(sort subdomains_yesterday.txt) <(sort subdomains_today.txt) > new_subdomains.txt

   # Find subdomains that disappeared
   comm -23 <(sort subdomains_yesterday.txt) <(sort subdomains_today.txt) > removed_subdomains.txt
   ```

2. **Content-based comparison** (for JSON data)
   ```bash
   # Compare specific fields from JSON
   jq -r '.url' httpx_today.json > urls_today.txt
   jq -r '.url' httpx_yesterday.json > urls_yesterday.txt
   comm -13 urls_yesterday.txt urls_today.txt > new_urls.txt
   ```

3. **Hash-based comparison** (detect changes in content)
   ```bash
   # Create checksums of JS files to detect modifications
   find js_downloads/ -type f -exec md5sum {} \; > js_checksums.txt
   diff js_checksums_yesterday.txt js_checksums_today.txt
   ```

### Diff Strategy Options

```toml
[steps.diff_comparison]
# Show what's new (most common for bug bounty)
show_additions = true

# Show what was removed (sometimes interesting)
show_removals = false

# Show what's changed (e.g., status code changes)
show_modifications = true

# Only show if above threshold
notify_threshold = 5
```

### Intelligent Diffing

Beyond simple line comparison:

1. **Grouping by category**:
   - Group new paths by host/subdomain
   - Group parameters by application section

2. **Prioritization**:
   - Prioritize subdomains with certain keywords (`staging`, `dev`, `api`, `admin`)
   - Prioritize endpoints with interesting status codes
   - Prioritize new technologies

3. **Correlation**:
   - Link new subdomains with new endpoints
   - Link new deployments with new paths
   - Link technology changes with vulnerability patterns

---

## Notification Strategy

### When to Notify

Configure intelligent thresholds to avoid notification fatigue:

```toml
[[steps.diff_comparison.comparisons]]
name = "new_subdomains"
notify_threshold = 5  # Only notify if 5+ new subdomains
# Less than 5 is noise, more than 5 is actionable

[[steps.diff_comparison.comparisons]]
name = "new_alive_endpoints"
notify_threshold = 10  # Only notify if 10+ new endpoints

[[steps.diff_comparison.comparisons]]
name = "new_javascript_files"
notify_threshold = 3  # Even 3 new JS files could have secrets

[[steps.diff_comparison.comparisons]]
name = "new_parameters"
notify_threshold = 15  # New parameters = new functionality
```

### Severity Levels

```toml
# Define what constitutes high/medium/low priority
[priority_rules]

# High priority - Immediate attention
[[priority_rules.high]]
type = "subdomain"
pattern = "(staging|dev|test|backup|internal|admin)"
reason = "Potentially sensitive environment"

[[priority_rules.high]]
type = "endpoint"
pattern = "(upload|import|export|backup|config|admin)"
reason = "High-risk functionality"

[[priority_rules.high]]
type = "technology"
pattern = "(wordpress|joomla|drupal)"
reason = "Known CMS with common vulnerabilities"

# Medium priority - Investigate soon
[[priority_rules.medium]]
type = "parameter"
pattern = "(id|userId|accountId|uid)"
reason = "Potential IDOR"

[[priority_rules.medium]]
type = "endpoint"
status_code = 403
reason = "Access forbidden - might be bypassable"

# Low priority - Review when convenient
[[priority_rules.low]]
type = "parameter"
pattern = "(search|q|query)"
reason = "Potential XSS but common"
```

### Notification Channels

**Slack Example**:
```json
{
  "text": "🎯 Daily Recon Alert - techcorp.com",
  "attachments": [
    {
      "color": "warning",
      "title": "47 New Subdomains Discovered",
      "text": "• api-v2.techcorp.com\n• staging-admin.techcorp.com\n• dev-backup.techcorp.com\n\n<https://link-to-full-report|View Full Report>",
      "fields": [
        {
          "title": "Priority",
          "value": "High",
          "short": true
        },
        {
          "title": "Scan Time",
          "value": "4h 23m",
          "short": true
        }
      ]
    }
  ]
}
```

**Discord Example**:
```
@here 🎯 Daily Recon Update - techcorp.com

**New Subdomains**: 47 🔥
- api-v2.techcorp.com (New API!)
- staging-admin.techcorp.com
- dev-backup.techcorp.com

**New Endpoints**: 12
- https://api.techcorp.com/v2/users
- https://upload.techcorp.com

**Action Items**:
1. Test new API endpoints
2. Check staging-admin for misconfig
3. Analyze 8 new JS files for secrets

View full report: <link>
```

---

## Real-World Scheduling Scenarios

### Simple Cron Setup

```bash
#!/bin/bash
# daily-recon.sh

# Run daily recon at 2 AM UTC
cd /home/hunter/bugbounty/techcorp.com
zolt daily-recon run -c daily-recon.toml

# Exit code handling
if [ $? -eq 2 ]; then
    # Exit code 2 = significant changes detected
    echo "Interesting changes found, check notifications"
elif [ $? -eq 0 ]; then
    echo "Recon completed, no significant changes"
else
    echo "Recon failed, check logs"
    exit 1
fi
```

Add to crontab:
```cron
# Run daily recon at 2 AM UTC
0 2 * * * /home/hunter/bugbounty/daily-recon.sh >> /var/log/daily-recon.log 2>&1

# Clean up old data (older than 30 days) on Sundays at 3 AM
0 3 * * 0 find /home/hunter/bugbounty/techcorp.com/recon/daily -mtime +30 -delete
```

### Systemd Timer (Modern Alternative)

**/etc/systemd/system/daily-recon.service**:
```ini
[Unit]
Description=Daily Reconnaissance for TechCorp
After=network.target

[Service]
Type=oneshot
User=hunter
WorkingDirectory=/home/hunter/bugbounty/techcorp.com
ExecStart=/usr/local/bin/zolt daily-recon run -c daily-recon.toml
StandardOutput=append:/var/log/daily-recon.log
StandardError=append:/var/log/daily-recon-error.log
Environment="SLACK_WEBHOOK_URL=https://hooks.slack.com/..."
Environment="DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/..."
```

**/etc/systemd/system/daily-recon.timer**:
```ini
[Unit]
Description=Run Daily Recon Every Morning
Requires=daily-recon.service

[Timer]
# Run daily at 2 AM UTC
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable the timer:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now daily-recon.timer

# Check timer status
systemctl list-timers daily-recon.timer
```

### Advanced Scheduling Strategies

**Scenario 1: Multiple Targets**
```bash
#!/bin/bash
# recon-all-targets.sh

targets=(
    "techcorp.com"
    "example-corp.com"
    "another-corp.com"
)

for target in "${targets[@]}"; do
    echo "[$target] Starting recon at $(date)"
    cd /home/hunter/bugbounty/$target

    # Run with low priority (nice)
    nice -n 15 zolt daily-recon run -c daily-recon.toml

    # Wait 10 minutes between targets to avoid rate limits
    sleep 600
done
```

**Scenario 2: Staggered Steps (Intensive Targets)**
```bash
#!/bin/bash
# intensive-target-recon.sh
# For targets that need more careful rate limiting

# Step 1: Passive (safe to run anytime)
zolt daily-recon run-step -s passive_subdomains

# Wait 2 hours
sleep 7200

# Step 2-3: Probing and crawling (more aggressive)
zolt daily-recon run-step -s probe_alive,crawl

# Wait 4 hours
sleep 14400

# Step 4-5: JS and parameter extraction
zolt daily-recon run-step -s js_discovery,parameter_extraction

# Step 6: Diff
zolt daily-recon run-step -s diff_comparison
```

**Scenario 3: Maintenance Windows**
```toml
# Configure different scan times for different targets
[schedules]

[schedules.techcorp.com]
cron = "0 2 * * *"  # 2 AM daily
priority = "high"

[schedules.staging.techcorp.com]
cron = "0 6 * * *"  # 6 AM daily (after deployments)
priority = "low"
enabled = false  # Disable for lower priority domains

[schedules.blog.techcorp.com]
cron = "0 4 * * 0"  # Sunday 4 AM weekly
priority = "low"
```

---

## Avoiding Redundant Work

### 1. Incremental Scanning

Don't rescan everything if only some data changed:

```toml
[performance]
# Use incremental mode when possible
incremental = true

# If less than X% of subdomains changed, only scan new ones
incremental_threshold = 10  # 10%

# Example: If yesterday had 1000 subdomains, today has 1050
# Only scan the 50 new ones (5% change), not all 1050
```

### 2. Result Caching

Cache results for expensive operations:

```toml
[caching]
enabled = true
# Cache directory
directory = ".recon-cache"
# Cache TTL (in hours)
ttl_hours = 24

# What to cache
[cache_rules]
# Cache JS file analysis (content rarely changes)
cache_js_analysis = true

# Cache parameter extraction (URLs are the same)
cache_params = true

# Don't cache (always fresh)
cache_subdomains = false
cache_alive_hosts = false
```

### 3. Duplicate Detection

Beyond simple line comparison:

```toml
[deduplication]
# Consider these subdomains the same
equivalent_subdomains = [
    # With/without www
    ["www.target.com", "target.com"],
    # Different regions pointing to same infra
    ["us.target.com", "eu.target.com"],
]

# Ignore these patterns (CDN, etc.)
ignore_patterns = [
    "*.cloudfront.net",
    "*.akamaiedge.net",
    "*.googleusercontent.com"
]
```

### 4. Smart Re-scanning

Only rescan when necessary:

```toml
[smart_scanning]
# Don't rescan if recon completed successfully recently
skip_if_recent = "6h"  # Skip if scan within last 6 hours

# Rescan triggers
[smart_scanning.triggers]
# Rescan if new subdomains found
on_new_subdomains = true

# Rescan if deployment detected
on_technology_change = true

# Rescan on schedule regardless
force_rescan_after = "24h"
```

---

## What to Do with Diff Results

### Analysis Workflow

```bash
#!/bin/bash
# analyze-diff-results.sh

echo "=== Processing Daily Recon Diff ==="

# 1. Review new subdomains
echo "[1/5] Checking new subdomains..."
if [ -s recon/daily/diff/new_subdomains_*.txt ]; then
    new_count=$(wc -l < recon/daily/diff/new_subdomains_*.txt)
    echo "  Found $new_count new subdomains"

    # Quick port scan on new subdomains
    cat recon/daily/diff/new_subdomains_*.txt | naabu -p 80,443,8000,8080,8443 -silent > quick_ports.txt

    # Check for interesting subdomain names
    grep -E '(staging|dev|test|backup|internal|admin)' recon/daily/diff/new_subdomains_*.txt > high_priority_subdomains.txt
fi

# 2. Review new endpoints
echo "[2/5] Checking new endpoints..."
if [ -s recon/daily/diff/new_alive_urls_*.txt ]; then
    # Check which technologies are new
    # (Compare today's tech with yesterday's)
    echo "  New endpoints require manual investigation"
fi

# 3. Analyze JavaScript
echo "[3/5] Analyzing new JavaScript..."
if [ -s recon/daily/diff/new_js_files_*.txt ]; then
    # Download new JS files
    cat recon/daily/diff/new_js_files_*.txt | wget -i - -P recon/js/new/

    # Run secret finders
    for js in recon/js/new/*.js; do
        echo "Checking $js for secrets..."
        grep -iEo 'api[key_]?[a-z0-9]{20,}' "$js" && echo "  ⚠️  Potential API key in $js"
    done
fi

# 4. Test new parameters
echo "[4/5] Testing new parameters..."
if [ -s recon/daily/diff/new_params_*.txt ]; then
    # Feed new parameters into testing tools
    cat recon/daily/diff/new_params_*.txt | while read param; do
        # Build list of URLs with this parameter
        grep "$param" recon/daily/urls_with_params_*.txt > test_urls.txt

        # Quick SQLi test (if parameter looks injectable)
        if [[ "$param" =~ ^(id|userId|search|query)$ ]]; then
            echo "  Testing $param for SQLi..."
            sqlmap -m test_urls.txt --batch --level 1
        fi
    done
fi

# 5. Generate target list for fuzzing
echo "[5/5] Generating fuzzing targets..."
# Create list of new paths without parameters
# (Good candidates for directory fuzzing)
cat recon/daily/diff/new_crawled_*.txt | grep -v '?' > fuzz_targets.txt

echo "=== Analysis Complete ==="
echo "Next steps:"
echo "1. Manually review high_priority_subdomains.txt"
echo "2. Test API endpoints: $(wc -l < recon/daily/alive_urls_*.txt) URLs available"
echo "3. Fuzz new paths: $(wc -l < fuzz_targets.txt) targets ready"
echo "4. Check Burp session files in burp/snapshots/"
```

### Priority Matrix

Create a priority ranking system for diff results:

| Priority | Type | Criteria | Action |
|----------|------|----------|--------|
| **P1** | New subdomain | Contains: admin, staging, dev, internal, backup | Immediate manual investigation |
| **P1** | Status change | Changed to 200 OK | Verify if new functionality |
| **P1** | New tech | Framework with known CVEs | Research specific CVEs |
| **P2** | New parameter | id, userId, accountId | Test for IDOR |
| **P2** | New endpoint | /api/, /upload/, /import | Test functionality |
| **P2** | New JS files | Any JS file | Check for secrets |
| **P3** | New crawled path | /about, /contact, etc. | Low priority, review if time |

### Integration with Testing Tools

**Direct integration examples**:

```bash
# Feed new URLs to Burp Suite
# Burp can listen on port 8080
cat recon/daily/diff/new_alive_urls_*.txt | while read url; do
    curl -x http://127.0.0.1:8080 -s -k "$url" > /dev/null
done

# Import to Postman for API testing
# Convert httpx JSON to Postman collection
jq '[.url] | {info: {name: "New Endpoints", schema: "https://schema.getpostman.com/"},
     item: map({name: ., request: {url: ., method: "GET"}})}' \
  recon/daily/httpx_*.json > postman_collection.json

# Parameter discovery for SQLi/XSS
cat recon/daily/diff/new_params_*.txt | while read param; do
    # Generate test URLs with common payloads
    grep "$param" recon/daily/urls_with_params_*.txt | \
    qsreplace "<script>alert(1)</script>" > xss_test_urls.txt
    qsreplace "' OR '1'='1" > sqli_test_urls.txt
done

# Subdomain takeover checks on new subdomains
cat recon/daily/diff/new_subdomains_*.txt | subzy --hide_fails
```

### Daily Workflow Checklist

**Morning (Review Results)**:
- [ ] Read diff summary
- [ ] Check notification alerts
- [ ] Review P1 findings first
- [ ] Look at new subdomains for interesting names
- [ ] Check new endpoints for status changes

**Afternoon (Testing)**:
- [ ] Test P1 items thoroughly
- [ ] Quick scan P2 items
- [ ] Download and analyze new JS files
- [ ] Feed URLs to Burp/Postman
- [ ] Start light fuzzing on new paths

**Evening (Documentation)**:
- [ ] Document findings in notes/
- [ ] Update Burp project with new scope
- [ ] Create target lists for tomorrow
- [ ] Review what didn't work (FPs, errors)
- [ ] Check if any findings warrant immediate report

**Weekly**:
- [ ] Review weekly aggregated data
- [ ] Look for patterns/trends
- [ ] Check which recon tools are most effective
- [ ] Update tool configurations
- [ ] Review false positives and adjust thresholds

---

## Advanced Configurations

### Environment-Based Configurations

```toml
# Development target - run full recon
[environments.development]
steps.passive_subdomains.enabled = true
steps.probe_alive.enabled = true
steps.crawl.tools.katana.args.depth = 5
steps.parameter_extraction.tools.arjun.enabled = true
rate_limit = 50  # Be gentle

# Production target - passive only
[environments.production]
steps.passive_subdomains.enabled = true
steps.probe_alive.enabled = true
# No crawling on production (too aggressive)
steps.crawl.enabled = false
steps.parameter_extraction.tools.arjun.enabled = false
rate_limit = 10  # Very conservative

# Staging target - most aggressive
[environments.staging]
steps.passive_subdomains.enabled = true
steps.probe_alive.enabled = true
steps.crawl.tools.katana.args.depth = 10  # Deep crawl
steps.parameter_extraction.tools.arjun.enabled = true
# Active parameter discovery on staging
custom_tools = ["nuclei", "ffuf"]
```

### Multi-Target Management

```bash
# Directory structure for multiple targets
bugbounty/
├── techcorp.com/
│   ├── daily-recon.toml
│   ├── recon/
│   └── targets.txt  # List of scoped domains
├── example-corp.com/
│   ├── daily-recon.toml
│   ├── recon/
│   └── targets.txt
└── run-all-recon.sh
```

**Multi-target runner**:
```bash
#!/bin/bash
# run-all-recon.sh

TARGETS_DIR="/home/hunter/bugbounty"

for target_dir in $(ls -d $TARGETS_DIR/*/); do
    target_name=$(basename $target_dir)
    echo "Starting recon for $target_name..."

    cd $target_dir

    # Check if target was scanned in last 24h
    if find recon/daily -name "summary_*.md" -mtime -1 | grep -q .; then
        echo "  Already scanned recently, skipping"
        continue
    fi

    zolt daily-recon run -c daily-recon.toml &
    # Add 30 min delay between targets
    sleep 1800
done

wait  # Wait for all to complete

echo "All targets scanned!"
```

---

## Useful Output Formats

### 1. Recon Summary Dashboard (HTML)

Generate an HTML dashboard for visual overview:

```html
<!-- recon/daily/reports/daily_2025-01-29.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Daily Recon - TechCorp - 2025-01-29</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>Daily Recon Dashboard</h1>

    <!-- Key Metrics -->
    <div class="metrics">
        <div class="card">
            <h3>New Subdomains</h3>
            <div class="big-number">47</div>
            <div class="change positive">+3.9%</div>
        </div>
        <div class="card">
            <h3>Live Endpoints</h3>
            <div class="big-number">892</div>
            <div class="change positive">+12</div>
        </div>
        <!-- More cards... -->
    </div>

    <!-- Charts -->
    <canvas id="trendsChart"></canvas>

    <script>
    // Show 30-day trends
    const ctx = document.getElementById('trendsChart');
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['Jan-28', 'Jan-29'],
            datasets: [{
                label: 'Subdomains',
                data: [1200, 1247],
                borderColor: 'rgb(75, 192, 192)',
            }]
        }
    });
    </script>
</body>
</html>
```

### 2. JSON API Output

Machine-readable format for integration:

```json
{
  "metadata": {
    "date": "2025-01-29",
    "target": "techcorp.com",
    "scan_duration": "4h 23m"
  },
  "summary": {
    "total_subdomains": 1247,
    "new_subdomains": 47,
    "total_endpoints": 892,
    "new_endpoints": 12,
    "javascript_files": 1284,
    "new_javascript_files": 8,
    "parameters_found": 234,
    "new_parameters": 15
  },
  "diff": {
    "new_subdomains": [
      "api-v2.techcorp.com",
      "staging-admin.techcorp.com",
      "dev-backup.techcorp.com"
    ],
    "new_endpoints": [
      {
        "url": "https://api.techcorp.com/v2/users",
        "status": 200,
        "technology": ["nginx", "express"]
      }
    ]
  },
  "recommendations": [
    "Test new API v2 endpoints for IDOR",
    "Investigate staging-admin subdomain",
    "Check new JS files for secrets"
  ]
}
```

### 3. CSV Output for Spreadsheets

```csv
date,resource_type,name,url,status,priority,action_required
2025-01-29,subdomain,api-v2.techcorp.com,,,high,Manual investigation required
2025-01-29,endpoint,/v2/users,https://api.techcorp.com,200,high,Test for IDOR
2025-01-29,js_file,app.js,https://cdn.techcorp.com,200,medium,Check for secrets
```

---

## Configuration Management

### Environment Variables

Use environment variables for sensitive configs:

```bash
# ~/.zolt/env file
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
export SMTP_HOST="smtp.gmail.com"
export SMTP_USER="hunter@email.com"
export SMTP_PASS="app_password"
export SMTP_TO="myphone@tmomail.net"

# API Keys
export SECURITYTRAILS_API_KEY="..."
export SHODAN_API_KEY="..."
export CHAOS_API_KEY="..."
export GITHUB_TOKEN="..."
```

Load before running:
```bash
source ~/.zolt/env
zolt daily-recon run -c daily-recon.toml
```

### Per-Target Configurations

Override global settings for specific targets:

```toml
# In daily-recon.toml

# High-priority target - intensive scanning
[targets."*.techcorp.com"]
crawl_depth = 5
arjun_url_limit = 500
rate_limit = 150
notify_threshold = 3

# Low-priority target - minimal scanning
[targets."blog.techcorp.com"]
enabled = true
crawl_depth = 2
arjun_enabled = false
notify_threshold = 20  # Only notify if significant changes

# Out of scope - don't scan
[targets."shop.techcorp.com"]
enabled = false
```

### Secret Management

Don't put secrets in TOML files:

```toml
# Good - use environment variables
[notifications.providers.slack]
webhook_url = "${SLACK_WEBHOOK_URL}"

# Bad - hardcoded secret
webhook_url = "https://hooks.slack.com/services/T123/B456/xyz789"
```

Use tools like:
- HashiCorp Vault
- AWS Secrets Manager
- 1Password CLI
- Bitwarden CLI

---

## Troubleshooting Common Issues

### Issue 1: Too Many False Positives

**Problem**: Getting notified every day with minor changes

**Solutions**:
```toml
# Increase thresholds
notify_threshold = 10  # Was 5

# Add ignore patterns
[diff_comparison.filters]
ignore_status_codes = [301, 302, 401]  # Redirects/auth required
ignore_content_length_diff = 100  # Ignore minor size changes
ignore_technologies = ["CDN77", "Cloudflare"]  # Ignore CDN changes

# Filter out maintenance pages
ignore_titles = ["Maintenance", "Coming Soon", "Under Construction"]
```

### Issue 2: Recon Takes Too Long

**Problem**: Scan takes 8+ hours, not finishing before next scan

**Solutions**:
```toml
[performance]
# Reduce concurrency
max_concurrent_steps = 1  # Run one step at a time

# Reduce scope
[steps.crawl.tools.katana]
args.depth = 2  # Down from 5
args.max_urls_per_host = 500  # Down from 1000

# Skip expensive tools when not needed
[steps.parameter_extraction.tools.arjun]
enabled = false  # Skip for now, run weekly instead

# Use incremental mode
incremental = true
incremental_threshold = 5  # Only scan if >5% change
```

### Issue 3: Rate Limiting / Blocks

**Problem**: Getting blocked by target's WAF

**Solutions**:
```toml
[global]
# Reduce rate
rate_limit = 50  # Down from 150
timeout = 15  # Longer timeout

# Add delays
[steps.probe_alive.tools.httpx]
args.delay = "200ms"  # Delay between requests

# Use proxies
args.proxy = "http://127.0.0.1:8080"  # Tor, VPN, or pool

# Rotate user agents
args.random_agent = true
```

### Issue 4: Storage Running Out

**Problem**: Recon data filling up disk

**Solutions**:
```toml
[global]
retention_days = 14  # Down from 30

# Compress old data
[archiving]
enabled = true
compress_after_days = 7
compression_format = "gzip"

# Don't store full response bodies
[steps.probe_alive.tools.httpx]
args.store_response = false  # Don't save HTML
```

### Issue 5: Missing API Keys

**Problem**: subfinder, amass not returning good results

**Solutions**:
```bash
# Set up API keys
cat > ~/.config/subfinder/provider-config.yaml <<EOF
chaos:
  - CHAOS_API_KEY_here
securitytrails:
  - SECURITYTRAILS_API_KEY_here
shodan:
  - SHODAN_API_KEY_here
github:
  - GITHUB_TOKEN_1
  - GITHUB_TOKEN_2
virustotal:
  - VIRUSTOTAL_API_KEY_here
EOF

# Verify keys are working
subfinder -d target.com -silent | wc -l  # Should be > 100
```

---

## Success Metrics

Track recon effectiveness:

```toml
[metrics]
enabled = true
database = "recon_metrics.sqlite"

# Track these metrics
track_findings = true      # Did recon lead to vulnerabilities?
track_time_taken = true    # How long does each step take?
track_data_volume = true   # How many subdomains/URLs found?
track_tool_success = true  # Which tools are most effective?
```

**Example Metrics Output**:
```json
{
  "date": "2025-01-29",
  "target": "techcorp.com",
  "steps": {
    "passive_subdomains": {
      "duration": "35m 12s",
      "subdomains_found": 1247,
      "tools": {
        "subfinder": {"found": 892, "duration": "12m"},
        "amass": {"found": 1156, "duration": "28m"},
        "assetfinder": {"found": 456, "duration": "5m"}
      }
    },
    "probe_alive": {
      "duration": "1h 15m",
      "endpoints_alive": 892
    }
  },
  "vulnerabilities_found": 3,
  "unique_to_recon": 2  # 2 vulns only found because of daily recon
}
```

---

## Conclusion

This daily reconnaissance workflow provides bug bounty hunters with:

1. **Automation**: Run 6 reconnaissance steps automatically
2. **Intelligence**: Know what's new, changed, or interesting
3. **Actionability**: Clear priorities on what to test first
4. **Efficiency**: No wasted effort on old information
5. **History**: Track how targets evolve over time
6. **Scalability**: Handle multiple targets systematically

The key is the **diff comparison** - knowing what's different from yesterday is what makes daily recon valuable. Otherwise, you're just accumulating data without insight.

**Best Practices**:
- Start with conservative settings, increase intensity gradually
- Tune thresholds to your notification preferences
- Focus on diff results, not total data collected
- Integrate with your existing tools (Burp, Postman, etc.)
- Review metrics monthly to optimize tool selection
- Keep API keys updated for best passive recon results

Happy hunting! 🎯
