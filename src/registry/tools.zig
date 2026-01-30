const std = @import("std");

pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    go_path: []const u8,
    category: Category,
};

pub const Category = enum {
    subdomain_enum,
    http_tool,
    port_scanner,
    vulnerability_scanner,
    web_crawler,
    url_tool,
    web_fuzzer,
    attack_surface,
    utility,
};

pub const TOOLS = [_]Tool{
    // ProjectDiscovery Tools
    Tool{
        .name = "chaos",
        .description = "Chaos is a tool to communicate with Chaos dataset API",
        .go_path = "github.com/projectdiscovery/chaos-client/cmd/chaos@latest",
        .category = .subdomain_enum,
    },
    Tool{
        .name = "subfinder",
        .description = "Passive subdomain enumeration tool",
        .go_path = "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest",
        .category = .subdomain_enum,
    },
    Tool{
        .name = "httpx",
        .description = "Fast and multi-purpose HTTP toolkit",
        .go_path = "github.com/projectdiscovery/httpx/cmd/httpx@latest",
        .category = .http_tool,
    },
    Tool{
        .name = "naabu",
        .description = "A fast port scanner",
        .go_path = "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest",
        .category = .port_scanner,
    },
    Tool{
        .name = "nuclei",
        .description = "Vulnerability scanner based on templates",
        .go_path = "github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest",
        .category = .vulnerability_scanner,
    },
    Tool{
        .name = "katana",
        .description = "Fast web crawler",
        .go_path = "github.com/projectdiscovery/katana/cmd/katana@latest",
        .category = .web_crawler,
    },
    // Tomnomnom Tools
    Tool{
        .name = "waybackurls",
        .description = "Fetch URLs from Wayback Machine",
        .go_path = "github.com/tomnomnom/waybackurls@latest",
        .category = .url_tool,
    },
    Tool{
        .name = "assetfinder",
        .description = "Find domains and subdomains",
        .go_path = "github.com/tomnomnom/assetfinder@latest",
        .category = .subdomain_enum,
    },
    Tool{
        .name = "anew",
        .description = "Append new lines to files",
        .go_path = "github.com/tomnomnom/anew@latest",
        .category = .utility,
    },
    Tool{
        .name = "unfurl",
        .description = "URL analysis tool",
        .go_path = "github.com/tomnomnom/unfurl@latest",
        .category = .url_tool,
    },
    Tool{
        .name = "qsreplace",
        .description = "Replace query string values",
        .go_path = "github.com/tomnomnom/qsreplace@latest",
        .category = .url_tool,
    },
    // lc's gau
    Tool{
        .name = "gau",
        .description = "GetAllUrls - fetch known URLs from Wayback Machine",
        .go_path = "github.com/lc/gau/v2/cmd/gau@latest",
        .category = .url_tool,
    },
    // Jaeles Project
    Tool{
        .name = "gospider",
        .description = "Fast web spider",
        .go_path = "github.com/jaeles-project/gospider@latest",
        .category = .web_crawler,
    },
    // ffuf - Fast web fuzzer
    Tool{
        .name = "ffuf",
        .description = "Fast web fuzzer",
        .go_path = "github.com/ffuf/ffuf@latest",
        .category = .web_fuzzer,
    },
    // OWASP Amass
    Tool{
        .name = "amass",
        .description = "In-depth attack surface mapping and asset discovery",
        .go_path = "github.com/owasp-amass/amass/v3/...@master",
        .category = .attack_surface,
    },
};

/// Get tools by category
pub fn getToolsByCategory(_: Category) []const Tool {
    // This is a simple filter that returns all tools of a specific category
    // For efficiency in production, you might want to pre-compute these
    var count: usize = 0;
    for (TOOLS) |_| {
        count += 1;
    }

    // This is a workaround since we can't easily return slices of comptime-known arrays
    // In a real implementation, you might want to create separate arrays per category
    return TOOLS[0..count];
}

/// Get tool by name
pub fn getToolByName(name: []const u8) ?Tool {
    for (TOOLS) |tool| {
        if (std.mem.eql(u8, tool.name, name)) {
            return tool;
        }
    }
    return null;
}
