#!/bin/bash
# Notification sender for daily reconnaissance
# Sends formatted notifications via Slack, Discord, Email

CONFIG_FILE="${1:-daily-recon.toml}"
DATE="${2:-$(date +%Y-%m-%d)}"
OUTPUT_DIR="recon/daily"

# Check if significant changes
SUMMARY_FILE="${OUTPUT_DIR}/diff/summary_${DATE}.md"
if [ ! -f "$SUMMARY_FILE" ]; then
    echo "No summary file found"
    exit 0
fi

# Get counts
NEW_SUBS=$(wc -l < "${OUTPUT_DIR}/diff/new_subdomains_${DATE}.txt" 2>/dev/null || echo 0)
NEW_URLS=$(wc -l < "${OUTPUT_DIR}/diff/new_alive_urls_${DATE}.txt" 2>/dev/null || echo 0)
NEW_JS=$(wc -l < "${OUTPUT_DIR}/diff/new_js_files_raw_${DATE}.txt" 2>/dev/null || echo 0)
NEW_PARAMS=$(wc -l < "${OUTPUT_DIR}/diff/new_param_names_${DATE}.txt" 2>/dev/null || echo 0)

THRESHOLD=5

total_changes=$((NEW_SUBS + NEW_URLS + NEW_JS + NEW_PARAMS))

if [ "$total_changes" -lt "$THRESHOLD" ]; then
    echo "Only $total_changes changes found, below threshold of $THRESHOLD"
    exit 0
fi

# Slack notification
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    echo "Sending Slack notification..."

    # Build attachment fields
    fields=""
    [ "$NEW_SUBS" -gt 0 ] && fields+=",{\"title\":\"New Subdomains\",\"value\":\"$NEW_SUBS\",\"short\":true}"
    [ "$NEW_URLS" -gt 0 ] && fields+=",{\"title\":\"New Endpoints\",\"value\":\"$NEW_URLS\",\"short\":true}"
    [ "$NEW_JS" -gt 0 ] && fields+=",{\"title\":\"New JS Files\",\"value\":\"$NEW_JS\",\"short\":true}"
    [ "$NEW_PARAMS" -gt 0 ] && fields+=",{\"title\":\"New Params\",\"value\":\"$NEW_PARAMS\",\"short\":true}"

    # Remove leading comma
    fields="${fields:1}"

    # Get top 5 new subdomains
    top_subs=$(head -5 "${OUTPUT_DIR}/diff/new_subdomains_${DATE}.txt" 2>/dev/null | sed 's/^/• /' | paste -sd '\n')

    curl -X POST -H 'Content-type: application/json' \
        --data "{
            \"text\": \"🎯 Daily Recon Alert\",
            \"attachments\": [{
                \"color\": \"good\",
                \"title\": \"techcorp.com - Daily Update\",
                \"text\": \"${top_subs}\n\nView full report for details\",
                \"fields\": [${fields}],
                \"footer\": \"Zolt Recon\",
                \"ts\": $(date +%s)
            }]
        }" \
        "$SLACK_WEBHOOK_URL"
fi

# Discord notification
if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
    echo "Sending Discord notification..."

    message="🎯 **Daily Recon Update - techcorp.com**\n\n"
    message+="**New Discoveries Today:**\n\n"

    [ "$NEW_SUBS" -gt 0 ] && message+="📌 **Subdomains**: ${NEW_SUBS} new\n"
    [ "$NEW_URLS" -gt 0 ] && message+="🌐 **Endpoints**: ${NEW_URLS} new\n"
    [ "$NEW_JS" -gt 0 ] && message+="📄 **JS Files**: ${NEW_JS} new\n"
    [ "$NEW_PARAMS" -gt 0 ] && message+="⚙️  **Parameters**: ${NEW_PARAMS} new\n"

    message+="\n**Top New Subdomains:**\n\`
    head -5 "${OUTPUT_DIR}/diff/new_subdomains_${DATE}.txt" 2>/dev/null
    message+="\`\n"

    curl -X POST -H 'Content-type: application/json' \
        --data "{\"content\":\"$message\"}" \
        "$DISCORD_WEBHOOK_URL"
fi
