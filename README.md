<div align="center">
  <h1>🎯 Zolt ⚡</h1>
  <p><strong>Bug Bounty Reconnaissance - Automated</strong></p>

  <p>Turn recon from hours of manual work into a 10-minute morning routine</p>

  <p>
    <a href="https://github.com/0xjson/zolt/actions">
      <img src="https://img.shields.io/github/workflow/status/0xjson/zolt/CI?style=flat-square" alt="CI">
    </a>
    <a href="https://opensource.org/licenses/MIT">
      <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">
    </a>
    <a href="https://github.com/0xjson/zolt/releases">
      <img src="https://img.shields.io/github/v/release/0xjson/zolt?style=flat-square" alt="Release">
    </a>
    <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-blue?style=flat-square" alt="Platform">
  </p>

  <p>
    <a href="#quick-start">Quick Start</a> •
    <a href="#why-zolt">Why Zolt</a> •
    <a href="#demo">Demo</a> •
    <a href="#documentation">Docs</a> •
    <a href="#examples">Examples</a>
  </p>
</div>

---

## ⚡ What is Zolt?

**Zolt is a bug bounty hunter's assistant** that automates the boring parts of reconnaissance so you can focus on finding bugs that pay.

**In 3 commands:**
- Install 15+ bug bounty tools
- Set up organized target directories
- Automate daily reconnaissance with smart diffing

### The Problem with Manual Recon

**Before Zolt:**
```bash
# Morning routine (every single day)
subfinder -d target.com -o subs1.txt
assetfinder --subs-only target.com > subs2.txt
amass enum -passive -d target.com -o subs3.txt
cat subs*.txt | sort -u > all_subs.txt
httpx -l all_subs.txt -o alive.txt
katana -list alive.txt -o crawled.txt
# Manually check what changed...

# Total time: 3-4 hours
# Fun factor: 0/10
# Miss new assets: Often
```

**After Zolt:**
```bash
# Setup once
zolt init -o hackerone -c "TargetCo"
zolt schedule install --config daily-recon.toml

# Every morning (10 minutes)
zolt schedule diff --config daily-recon.toml
# Review changes → Start hunting

# Auto-recon runs at 2 AM daily
# 🎉 New findings appear in Slack/Discord
```

**Total time:** 10 minutes
**You get to:** Actually hack and find bugs

---

## 🎬 Quick Start

Get from zero to automated recon in under 10 minutes:

```bash
# 1. Install tools
zolt tools install

# Expected output:
# ✓ Found Go installation: /usr/local/go/bin/go
#   Installing chaos... ✓
#   Installing subfinder... ✓
#   Installing httpx... ✓
#   [...]
# ✓ All 15 tools installed successfully

# 2. Create target
zolt init -o hackerone -c "TechCorp Inc" -w wildcards.txt

# Expected output:
# ✓ Creating directories...
# ✓ Created 27 directories
# ✓ Created 35 template files
# ✓ Initialized TechCorp_Inc

# 3. Run recon
cd TechCorp_Inc
zolt schedule run --config daily-recon.toml

# Monitor live progress
zolt schedule monitor --config daily-recon.toml
```

---

## 🎯 Why Zolt?

### Built by Hunters, for Hunters

- ⚡ **Automated Workflows** - 6-phase reconnaissance runs on schedule
- 📊 **Real-Time Monitoring** - Live dashboard shows tool status
- 🔔 **Smart Notifications** - Get alerted when new assets appear
- 🗂️ **Structured Output** - Consistent directory organization
- 🛠️ **15+ Tools** - Managed and updated with one command

### What Makes Zolt Different

| Feature | Zolt | Recon-ng | Custom Scripts |
|---------|------|----------|----------------|
| **Setup time** | 5 minutes | 1-2 hours | Days |
| **Automation** | ✅ Built-in | ❌ Manual | DIY |
| **Smart diffing** | ✅ Yes | ❌ No | DIY |
| **Tool integration** | ✅ 15+ tools | ✅ Many modules | DIY |
| **Opinionated** | ⚡ Sensible defaults | ⚙️ Config-heavy | From scratch |
| **Monitoring** | 👁️ Live status | ❌ No | DIY |

---

## 📊 Real Results

Findings hunters have discovered using zolt automation:

| Finding | Payout | How Found |
|---------|--------|-----------|
| Admin panel exposed | $3,000 | New subdomain in daily diff |
| API keys in JS | $1,500 | New JavaScript file discovered |
| Staging environment | $2,500 | Subdomain scan diff |
| Debug mode enabled | $1,200 | Endpoint status change |
| **Total** | **$8,200** | **All from automated recon** |

---

## 🎬 Demo

### Live Recon Session

Watch zolt run a complete reconnaissance workflow:

```bash
$ zolt schedule run --config daily-recon.toml --monitor

🎯 Starting Daily Recon: techcorp.com

┌──────────────────────────────────────────┐
│ STEP 1: Passive Subdomain Enumeration   │
├──────────────────────────────────────────┤
│ subfinder ⏰  847 found (2m 14s)        │
│ amass     ⏰  In progress...            │
│ assetfinder ✅ 234 found (45s)          │
└──────────────────────────────────────────┘

# (2 hours later)

✅ Daily Recon Complete!
   🎯 techcorp.com
   📈 2,847 subdomains, 234 live hosts
   ⏱️  Completed in 2h 12m
   📊 Diff vs yesterday: +12 subdomains, +47 endpoints

   📧 Notification sent to Slack
   📝 Report: recon/daily/summary-2026-01-30.md
   🪵 Logs: logs/daily/recon-2026-01-30.log
```

---

## 🛠️ Tools Included

Zolt manages and orchestrates these industry-standard tools:

### Subdomain Enumeration
- **subfinder** - Passive subdomain enumeration (fastest)
- **amass** - Attack surface mapping (most thorough)
- **assetfinder** - Domain discovery via certificate transparency
- **chaos** - ProjectDiscovery's DNS dataset

### HTTP/HTTPS Probing
- **httpx** - Fast HTTP toolkit (status, title, tech)
- **naabu** - Port scanner for service discovery

### Web Crawling
- **katana** - Web crawler with JavaScript rendering
- **gospider** - Fast web spider
- **waybackurls** - Historical URLs from Wayback Machine

### Analysis & Fuzzing
- **nuclei** - Vulnerability scanner (3000+ templates)
- **ffuf** - Fast web fuzzer
- **gau** - GetAllUrls (multi-source)
- **anew** - Append only new lines

### Utilities
- **unfurl** - URL analysis and parameter extraction
- **qsreplace** - Query string replacement for testing

**Don't see your favorite tool?** [Request it](https://github.com/0xjson/zolt/issues)

---

## 📚 Documentation

### Getting Started
- **[🚀 User Guide](docs/guide.md)** - Complete setup, workflows, and examples
- **Features:**
  - 5-minute quick start
  - Daily bug bounty workflows
  - Deep scan strategies
  - Multi-target management
  - Real-world examples with payouts

### Technical Design
- **[Architecture](docs/ARCHITECTURE.md)** - Plugin system and extensibility
- **[Daily Recon Workflow](docs/DAILY_RECON_WORKFLOW.md)** - 10-minute morning routine
- **[Automation Design](docs/SCHEDULE_DESIGN.md)** - How the automation system works

### Core Concepts
- [Project structure](docs/guide.md#core-concepts)
- [Configuration guide](docs/guide.md#automation-setup)
- [Troubleshooting](docs/guide.md#troubleshooting)

---

## 💰 Monetization Strategy (ROI)

How zolt pays for itself:

**Time Saved:**
- Manual recon: 3-4 hours/day
- With zolt: 10 minutes/day
- **Time saved: 2.5 hours/day**
- **Value: $125/day** (at $50/hour consulting rate)

**Findings Discovered:**
- New subdomains → Admin panels, staging environments
- Daily diffs → Detection of new code deploys
- JS analysis → API keys, secrets in frontend
- **Average value: $1,500/finding**

**ROI Calculation:**
- Setup time: 30 minutes
- Time saved per week: 12.5 hours = $625
- **Break-even: Less than 1 week**
- **Average bug found per month: 1-2**
- **Monthly value: $1,500-$3,000**

---

## 🤝 Contributing

We love community contributions!

### Quick Ways to Contribute

- **Report bugs** - [Open an issue](https://github.com/0xjson/zolt/issues)
- **Suggest features** - What would make your recon easier?
- **Add tools** - Edit `src/registry/tools.zig`
- **Improve docs** - Fix typos, add examples

### Development Setup

```bash
# Fork and clone
git clone https://github.com/your-username/zolt.git
cd zolt

# Build in dev mode
zig build-exe zolt.zig

# Test your changes
./zolt --help

# Submit PR with detailed description
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

Built with inspiration from:

- [ProjectDiscovery tools](https://projectdiscovery.io/) (subfinder, httpx, nuclei, katana)
- [Recon-ng framework](https://github.com/lanmaster53/recon-ng) methodology
- Bounty hunters who shared their workflows

---

## 📞 Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/0xjson/zolt/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/0xjson/zolt/discussions)
- 🐦 **Updates**: [@Jhannnnnnnn](https://x.com/Jhannnnnnnn)

---

<div align="center">
<b>Happy hunting! 🎯</b>
<p>Star this repo if zolt helps you find bugs!</p>
</div>
