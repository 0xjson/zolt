# Zolt - Bug Bounty CLI Tool

A Zig-based CLI tool for bug bounty hunting, similar in structure to `git`.

## Features

- **Tool Management**: Install and manage bug bounty tools
- **Project Initialization**: Create structured directories for bug bounty targets
- **Modular Architecture**: Easy to extend with new tools and commands

## Installation

1. Install Zig 0.16.0-dev or later
2. Compile the tool:

```bash
zig build-exe zolt.zig
```

3. Optionally, move to your PATH:

```bash
mv zolt /usr/local/bin/
```

## Usage

### Install Bug Bounty Tools

Install all recommended bug bounty tools:

```bash
zolt tools install
```

This will:
- Check if Go is installed
- Install 15+ bug bounty tools from ProjectDiscovery and other sources

**Tools installed:**
- chaos (ProjectDiscovery)
- subfinder (Passive subdomain enumeration)
- httpx (HTTP toolkit)
- naabu (Port scanner)
- nuclei (Vulnerability scanner)
- katana (Web crawler)
- gau (GetAllUrls)
- gospider (Web spider)
- ffuf (Web fuzzer)
- amass (Attack surface mapping)
- waybackurls (Wayback Machine URLs)
- assetfinder (Domain discovery)
- anew (Append new lines to files)
- unfurl (URL analysis)
- qsreplace (Query string replacement)

### Initialize a Bug Bounty Target

Create a structured directory for a new target:

```bash
zolt init -o hackerone -c "Company Name" -w subdomains.txt
```

**Options:**
- `-o, --organization`: Organization (hackerone, bugcrowd, or intigriti)
- `-c, --company`: Company name (spaces will be converted to underscores)
- `-w, --wildcard-subdomains`: File containing wildcard subdomains (optional)

**Directory Structure Created:**

The init command creates a comprehensive directory structure:

```
Company_Name/
├── burp/
│   └── snapshots/
├── recon/
│   ├── cloud/
│   │   ├── buckets.txt
│   │   ├── history/
│   │   ├── ips.txt
│   │   ├── providers.txt
│   │   └── services.txt
│   ├── directories/
│   │   ├── admin.txt
│   │   ├── api.txt
│   │   └── history/
│   ├── js/
│   │   ├── downloaded/
│   │   ├── files.txt
│   │   ├── linkfinder.txt
│   │   ├── params.txt
│   │   └── secrets.txt
│   ├── ports/
│   │   ├── history/
│   │   ├── open.txt
│   │   └── services.txt
│   ├── screenshots/
│   │   ├── admin/
│   │   ├── alive/
│   │   └── api/
│   ├── subdomains/
│   │   ├── active/
│   │   │   ├── bruteforce.txt
│   │   │   └── permutations.txt
│   │   ├── all.txt
│   │   ├── alive.txt
│   │   ├── fdns.txt
│   │   ├── history/
│   │   └── passive/
│   │       ├── all.txt
│   │       ├── amass.txt
│   │       └── passive.txt
│   ├── tech/
│   │   └── fingerprints.txt
│   ├── urls/
│   │   ├── alive.txt
│   │   ├── crawl.txt
│   │   ├── history/
│   │   ├── params.txt
│   │   └── wayback.txt
│   └── vhosts/
│       ├── alive.txt
│       ├── candidates.txt
│       ├── history/
│       └── resolved.txt
├── findings/
│   ├── accepted/
│   ├── drafts/
│   └── submitted/
├── logs/
│   ├── daily/
│   ├── monthly/
│   └── weekly/
├── manual/
│   ├── auth/
│   ├── idor/
│   ├── logic/
│   ├── sqli/
│   └── xss/
├── mapping/
└── screenshots/
    ├── burp/
    └── poc/
```

## Example Workflow

1. **Initialize target:**
   ```bash
   zolt init -o hackerone -c "TechCorp" -w wildcards.txt
   ```

2. **Install tools:**
   ```bash
   zolt tools install
   ```

3. **Start recon:**
   ```bash
   cd TechCorp
   # Run your reconnaissance tools
   subfinder -dL recon/subdomains/passive/passive.txt -o recon/subdomains/passive/subfinder.txt
   ```

## Architecture

Zolt is designed with modularity in mind:

- **Tools Registry**: Easy to add new tools by updating the tools array
- **Command Structure**: Simple to add new commands
- **Error Handling**: Graceful handling of missing dependencies (e.g., Go not installed)

## Requirements

- Zig 0.16.0-dev or later
- Go (for installing tools)
- Linux or Unix-like environment

## Contributing

To add new tools:
1. Update the `tools` array in `installTools()` function
2. Add tool name and Go install path (format: `github.com/user/repo/cmd/tool@latest`)

## License

MIT
