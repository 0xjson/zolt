#!/bin/bash
# Daily Reconnaissance Automation Runner
# This script orchestrates the 6-step daily recon workflow

set -e

# Configuration
CONFIG_FILE="${1:-daily-recon.toml}"
WORKING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${WORKING_DIR}/recon/daily"
DATE=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="${OUTPUT_DIR}/logs/recon_${DATE}.log"
mkdir -p "${OUTPUT_DIR}/logs"

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

# Check prerequisites
check_requirements() {
    log "Checking requirements..."

    local missing_tools=()

    for tool in subfinder httpx katana unfurl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Run: zolt tools install"
        exit 1
    fi

    # Extract target from config
    TARGET=$(grep -E '^target\s*=' "${CONFIG_FILE}" | cut -d'"' -f2)
    if [ -z "$TARGET" ]; then
        error "No target configured in ${CONFIG_FILE}"
        exit 1
    fi

    log "Requirements satisfied. Target: ${BLUE}${TARGET}${NC}"
}

# Step 1: Passive Subdomain Enumeration
step1_passive_subdomains() {
    log "${BLUE}███████ Step 1: Passive Subdomain Enumeration${NC}"

    local output_file="${OUTPUT_DIR}/passive_subdomains_${DATE}.txt"

    # Run subfinder
    log "  Running subfinder..."
    subfinder -d "$TARGET" -all -nC -silent -o "${OUTPUT_DIR}/subfinder_${DATE}.txt"
    local subfinder_count=$(wc -l < "${OUTPUT_DIR}/subfinder_${DATE}.txt" 2>/dev/null || echo 0)
    log "    Found ${subfinder_count} subdomains"

    # Run assetfinder
    log "  Running assetfinder..."
    assetfinder --subs-only "$TARGET" > "${OUTPUT_DIR}/assetfinder_${DATE}.txt"
    local assetfinder_count=$(wc -l < "${OUTPUT_DIR}/assetfinder_${DATE}.txt" 2>/dev/null || echo 0)
    log "    Found ${assetfinder_count} subdomains"

    # Merge results
    log "  Merging results..."
    cat "${OUTPUT_DIR}/"{subfinder,assetfinder}_"${DATE}.txt" 2>/dev/null |
        sort -u |
        grep -E '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$' |
        sort -u > "$output_file"

    local total_count=$(wc -l < "$output_file")
    log "  ${GREEN}✓${NC} Total subdomains: ${total_count}"

    # Compare with yesterday
    if [ -f "${OUTPUT_DIR}/passive_subdomains_${YESTERDAY}.txt" ]; then
        local new_count=$(comm -13 \
            <(sort "${OUTPUT_DIR}/passive_subdomains_${YESTERDAY}.txt") \
            <(sort "$output_file") | wc -l)
        log "  ${GREEN}✓${NC} New subdomains since yesterday: ${new_count}"

        if [ "$new_count" -gt 5 ]; then
            comm -13 \
                <(sort "${OUTPUT_DIR}/passive_subdomains_${YESTERDAY}.txt") \
                <(sort "$output_file") > "${OUTPUT_DIR}/diff/new_subdomains_${DATE}.txt"
        fi
    fi
}

# Step 2: Probe Alive HTTP/HTTPS
step2_probe_alive() {
    log "${BLUE}███████ Step 2: Probing for Live Hosts${NC}"

    local input_file="${OUTPUT_DIR}/passive_subdomains_${DATE}.txt"
    local output_file="${OUTPUT_DIR}/httpx_${DATE}.json"

    if [ ! -f "$input_file" ]; then
        warn "  No subdomain file found, skipping..."
        return
    fi

    log "  Probing ${BLUE}$(wc -l < "$input_file")${NC} subdomains with httpx..."

    httpx -l "$input_file" \
        -title -tech-detect -status-code -content-length \
        -follow-redirects -random-agent \
        -timeout 10 -threads 50 -rl 150 \
        -json -o "$output_file"

    local alive_count=$(jq -r '.url' "$output_file" 2>/dev/null | wc -l)
    log "  ${GREEN}✓${NC} Live hosts found: ${alive_count}"

    # Extract URLs and IPs
    jq -r '.url' "$output_file" > "${OUTPUT_DIR}/alive_urls_${DATE}.txt"
    jq -r '.host' "$output_file" > "${OUTPUT_DIR}/alive_ips_${DATE}.txt"

    # Compare with yesterday
    if [ -f "${OUTPUT_DIR}/alive_urls_${YESTERDAY}.txt" ]; then
        local new_count=$(comm -13 \
            <(sort "${OUTPUT_DIR}/alive_urls_${YESTERDAY}.txt") \
            <(sort "${OUTPUT_DIR}/alive_urls_${DATE}.txt") | wc -l)

        if [ "$new_count" -gt 0 ]; then
            log "  ${GREEN}✓${NC} New active endpoints: ${new_count}"
            comm -13 \
                <(sort "${OUTPUT_DIR}/alive_urls_${YESTERDAY}.txt") \
                <(sort "${OUTPUT_DIR}/alive_urls_${DATE}.txt") > "${OUTPUT_DIR}/diff/new_alive_urls_${DATE}.txt"
        fi
    fi
}

# Step 3: Web Crawling
step3_crawl() {
    log "${BLUE}███████ Step 3: Web Crawling${NC}"

    local input_file="${OUTPUT_DIR}/alive_urls_${DATE}.txt"

    if [ ! -f "$input_file" ]; then
        warn "  No alive URLs file found, skipping..."
        return
    fi

    log "  Crawling ${BLUE}$(wc -l < "$input_file")${NC} URLs with katana..."

    katana -list "$input_file" \
        -headless \
        -timeout 10 -threads 30 -concurrency 20 \
        -fetch-timeout 5 -depth 3 \
        -js-crawl -field-scope "rdn" \
        -silent -output "${OUTPUT_DIR}/katana_${DATE}.txt"

    local crawl_count=$(wc -l < "${OUTPUT_DIR}/katana_${DATE}.txt" 2>/dev/null || echo 0)
    log "  ${GREEN}✓${NC} URLs crawled: ${crawl_count}"

    # Also run gospider
    log "  Crawling with gospider..."
    gospider -S "$input_file" \
        -o "${OUTPUT_DIR}/gospider_${DATE}" \
        -t 30 -c 20 -d 3 \
        --js --sitemap --robots --quiet

    if [ -f "${OUTPUT_DIR}/gospider_${DATE}/urls.txt" ]; then
        local gospider_count=$(wc -l < "${OUTPUT_DIR}/gospider_${DATE}/urls.txt")
        log "  ${GREEN}✓${NC} gospider found: ${gospider_count} URLs"

        # Merge results
        cat "${OUTPUT_DIR}/katana_${DATE}.txt" \
           "${OUTPUT_DIR}/gospider_${DATE}/urls.txt" 2>/dev/null | \
           sort -u > "${OUTPUT_DIR}/crawled_urls_${DATE}.txt"
    else
        cp "${OUTPUT_DIR}/katana_${DATE}.txt" "${OUTPUT_DIR}/crawled_urls_${DATE}.txt"
    fi

    local total_crawled=$(wc -l < "${OUTPUT_DIR}/crawled_urls_${DATE}.txt" 2>/dev/null || echo 0)
    log "  ${GREEN}✓${NC} Total crawled URLs: ${total_crawled}"
}

# Step 4: JavaScript Discovery
step4_js_discovery() {
    log "${BLUE}███████ Step 4: JavaScript Discovery${NC}"

    local input_file="${OUTPUT_DIR}/crawled_urls_${DATE}.txt"

    if [ ! -f "$input_file" ]; then
        warn "  No crawled URLs file found, skipping..."
        return
    fi

    # Extract JS URLs
    log "  Extracting JavaScript files..."
    grep -E '\.js(?:\?|$)' "$input_file" | \
        grep -v '\.json' | \
        sort -u > "${OUTPUT_DIR}/js_files_raw_${DATE}.txt"

    local js_count=$(wc -l < "${OUTPUT_DIR}/js_files_raw_${DATE}.txt" 2>/dev/null || echo 0)
    log "  ${GREEN}✓${NC} JavaScript files found: ${js_count}"

    # Download JS files
    if [ "$js_count" -gt 0 ] && [ "$js_count" -lt 5000 ]; then
        log "  Downloading JS files..."
        mkdir -p "recon/js/downloaded/${DATE}"
        wget -i "${OUTPUT_DIR}/js_files_raw_${DATE}.txt" \
            -P "recon/js/downloaded/${DATE}/" \
            -q --timeout=10 --tries=2 -N
    fi

    # Compare with yesterday
    if [ -f "${OUTPUT_DIR}/js_files_raw_${YESTERDAY}.txt" ]; then
        local new_js=$(comm -13 \
            <(sort "${OUTPUT_DIR}/js_files_raw_${YESTERDAY}.txt") \
            <(sort "${OUTPUT_DIR}/js_files_raw_${DATE}.txt") | wc -l)

        if [ "$new_js" -gt 0 ]; then
            log "  ${GREEN}✓${NC} New JavaScript files: ${new_js}"
        fi
    fi
}

# Step 5: Parameter Extraction
step5_parameter_extraction() {
    log "${BLUE}███████ Step 5: Parameter Extraction${NC}"

    local input_file="${OUTPUT_DIR}/crawled_urls_${DATE}.txt"

    if [ ! -f "$input_file" ]; then
        warn "  No crawled URLs file found, skipping..."
        return
    fi

    # Extract URLs with parameters
    log "  Extracting URLs with parameters..."
    grep '?[^ ]' "$input_file" | sort -u > "${OUTPUT_DIR}/urls_with_params_${DATE}.txt"

    local param_url_count=$(wc -l < "${OUTPUT_DIR}/urls_with_params_${DATE}.txt" 2>/dev/null || echo 0)
    log "  ${GREEN}✓${NC} URLs with parameters: ${param_url_count}"

    # Extract parameter names with unfurl
    if command -v unfurl &> /dev/null; then
        log "  Extracting parameter names..."
        unfurl keys < "${OUTPUT_DIR}/urls_with_params_${DATE}.txt" | \
            sort -u > "${OUTPUT_DIR}/param_names_${DATE}.txt"

        local param_count=$(wc -l < "${OUTPUT_DIR}/param_names_${DATE}.txt" 2>/dev/null || echo 0)
        log "  ${GREEN}✓${NC} Unique parameter names: ${param_count}"
    fi

    # Run arjun on top URLs (if installed)
    if command -v arjun &> /dev/null && [ -f "${OUTPUT_DIR}/alive_urls_${DATE}.txt" ]; then
        log "  Running arjun parameter discovery..."
        head -100 "${OUTPUT_DIR}/alive_urls_${DATE}.txt" | \
            arjun -oJ -o "${OUTPUT_DIR}/arjun_params_${DATE}.json" \
                  -t 30 -q
    fi

    # Compare with yesterday
    if [ -f "${OUTPUT_DIR}/param_names_${YESTERDAY}.txt" ]; then
        local new_params=$(comm -13 \
            <(sort "${OUTPUT_DIR}/param_names_${YESTERDAY}.txt") \
            <(sort "${OUTPUT_DIR}/param_names_${DATE}.txt") | wc -l)

        if [ "$new_params" -gt 0 ]; then
            log "  ${GREEN}✓${NC} New parameters: ${new_params}"
        fi
    fi
}

# Step 6: Diff Generation
step6_diff_comparison() {
    log "${BLUE}███████ Step 6: Diff vs Yesterday${NC}"

    mkdir -p "${OUTPUT_DIR}/diff"

    local has_changes=false
    local change_count=0

    # Generate diff summary
    {
        echo "# Daily Recon Diff Summary - ${DATE}"
        echo ""
        echo "**Target**: ${TARGET}"
        echo "**Scan Date**: $(date)"
        echo ""
    } > "${OUTPUT_DIR}/diff/summary_${DATE}.md"

    # Check each file type
    for file_type in "subdomains" "alive_urls" "js_files_raw" "param_names" "crawled_urls"; do
        local today_file="${OUTPUT_DIR}/${file_type}_${DATE}.txt"
        local yesterday_file="${OUTPUT_DIR}/${file_type}_${YESTERDAY}.txt"

        if [ ! -f "$today_file" ]; then
            continue
        fi

        if [ -f "$yesterday_file" ]; then
            local additions=$(comm -13 <(sort "$yesterday_file") <(sort "$today_file") | wc -l)

            if [ "$additions" -gt 0 ]; then
                log "  ${file_type}: +${additions} new entries"
                comm -13 <(sort "$yesterday_file") <(sort "$today_file") > "${OUTPUT_DIR}/diff/new_${file_type}_${DATE}.txt"

                {
                    echo "## New $(echo $file_type | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g') (+${additions})"
                    echo ""
                    head -20 "${OUTPUT_DIR}/diff/new_${file_type}_${DATE}.txt" | sed 's/^/- /'
                    echo ""
                } >> "${OUTPUT_DIR}/diff/summary_${DATE}.md"

                has_changes=true
                ((change_count++))
            fi
        else
            warn "  No yesterday file for ${file_type}, skipping diff"
        fi
    done

    if [ "$has_changes" = true ]; then
        log "  ${GREEN}✓${NC} Diff generated: ${change_count} types of changes detected"
        cat "${OUTPUT_DIR}/diff/summary_${DATE}.md" | tee -a "${LOG_FILE}"
    else
        log "  No significant changes detected"
    fi
}

# Send notifications
send_notifications() {
    log "${BLUE}███████ Sending Notifications${NC}"

    local summary_file="${OUTPUT_DIR}/diff/summary_${DATE}.md"

    if [ ! -f "$summary_file" ] || [ "$has_changes" = false ]; then
        log "  No notifications to send"
        return
    fi

    # Slack notification
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        log "  Sending Slack notification..."

        local new_subs=$(wc -l < "${OUTPUT_DIR}/diff/new_subdomains_${DATE}.txt" 2>/dev/null || echo 0)
        local new_urls=$(wc -l < "${OUTPUT_DIR}/diff/new_alive_urls_${DATE}.txt" 2>/dev/null || echo 0)

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🎯 Daily Recon: ${TARGET}\",\"attachments\":[{\"color\":\"good\",\"title\":\"New Discoveries\",\"text\":\"Subdomains: ${new_subs}\nEndpoints: ${new_urls}\",\"footer\":\"Zolt Daily Recon\"}]}" \
            "$SLACK_WEBHOOK_URL" \
            2>&1 | tee -a "${LOG_FILE}"
    fi

    # Discord notification
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
        log "  Sending Discord notification..."

        local message="🎯 **Daily Recon: ${TARGET}**\n\n"
        message+="**New discoveries today:**\n"

        for file in "${OUTPUT_DIR}"/diff/new_*.txt; do
            if [ -f "$file" ]; then
                local count=$(wc -l < "$file")
                local name=$(basename "$file" | sed 's/new_//' | sed 's/_[0-9]*-[0-9]*-[0-9]*\.txt//' | tr '_' ' ')
                message+="• ${name}: ${count}\n"
            fi
        done

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"content\":\"$message\"}" \
            "$DISCORD_WEBHOOK_URL" \
            2>&1 | tee -a "${LOG_FILE}"
    fi
}

# Main execution
main() {
    log "======================================"
    log "Starting Daily Reconnaissance"
    log "Date: ${DATE}"
    log "Config: ${CONFIG_FILE}"
    log "======================================"

    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}/diff"

    # Record start time
    START_TIME=$(date +%s)

    # Run all steps
    step1_passive_subdomains
    step2_probe_alive
    step3_crawl
    step4_js_discovery
    step5_parameter_extraction
    step6_diff_comparison
    send_notifications

    # Record end time
    END_TIME=$(date +%s)
    DURATION=$(( (END_TIME - START_TIME) / 60 ))

    log "======================================"
    log "Daily Recon Complete!"
    log "Duration: ${DURATION} minutes"
    log "Results: ${OUTPUT_DIR}"
    log "Logs: ${LOG_FILE}"
    log "======================================"

    # Cleanup temp files
    rm -f "${OUTPUT_DIR}/"subfinder_"${DATE}".txt "${OUTPUT_DIR}/"assetfinder_"${DATE}".txt
}

# Trap errors
trap 'error "Script failed on line $LINENO"' ERR

# Run main function
main "$@"
