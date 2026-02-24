#!/usr/bin/env bash
# vocab_stats.sh
#
# Display vocabulary learning statistics.
# Shows total words, reviews, and progress by learning level.
#
# Usage:
#   ./vocab_stats.sh       # Basic stats
#   ./vocab_stats.sh -v    # Verbose (shows mastered phrases)

set -euo pipefail

# Get script directory and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vocab_config.sh"

# ==================== COUNT TOTALS ====================

# Count total phrases in vocabulary
total_words=0
if [[ -f "$VOCAB_FILE" ]]; then
    total_words=$(grep -c '.' "$VOCAB_FILE" 2>/dev/null || echo 0)
fi

# Count total reviews in history
words_reviewed=0
if [[ -f "$HISTORY_FILE" ]]; then
    words_reviewed=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
fi

# ==================== TIME-BASED STATISTICS ====================

# Initialize counters
today_count=0
week_count=0
month_count=0

# Current timestamp for comparisons
now=$(date +%s)
day_secs=$((60 * 60 * 24))

# Calculate start of today, this week, and this month
today_start=$(date -d 'today 00:00:00' +%s)
week_start=$(date -d 'last Sunday 00:00:00' +%s)
month_start=$(date -d "$(date +%Y-%m-01) 00:00:00" +%s)

# Count reviews in each time period
if [[ -f "$HISTORY_FILE" ]]; then
    while IFS=$'\t' read -r timestamp phrase; do
        # Skip malformed entries
        [[ -z "$timestamp" ]] && continue
        [[ "$timestamp" =~ ^[0-9]+$ ]] || continue
        
        # Count reviews from each period
        if ((timestamp >= today_start)); then
            today_count=$((today_count + 1))
        fi
        if ((timestamp >= week_start)); then
            week_count=$((week_count + 1))
        fi
        if ((timestamp >= month_start)); then
            month_count=$((month_count + 1))
        fi
    done < "$HISTORY_FILE"
fi

# ==================== LEVEL DISTRIBUTION ====================

now=$(date +%s)

new_count=0
short_interval=0
long_interval=0

if [[ -f "$LEVELS_FILE" ]]; then
    while IFS=$'\t' read -r phrase interval due ease; do
        [[ -z "$phrase" || -z "$interval" ]] && continue
        [[ "$interval" =~ ^[0-9]+$ ]] || continue
        
        if [[ -z "$due" || $due -eq 0 || $due -lt $now ]]; then
            new_count=$((new_count + 1))
        elif [[ $interval -le 7 ]]; then
            short_interval=$((short_interval + 1))
        else
            long_interval=$((long_interval + 1))
        fi
    done < "$LEVELS_FILE"
fi

# ==================== DISPLAY ====================

# Print formatted statistics box
# Using printf for proper alignment
printf '╔════════════════════════════════════╗\n'
printf '║       VOCABULARY STATISTICS        ║\n'
printf '╠════════════════════════════════════╣\n'
printf '║  Total phrases:        %10s  ║\n' "$total_words"
printf '║  Total reviews:        %10s  ║\n' "$words_reviewed"
printf '╠════════════════════════════════════╣\n'
printf '║  Today:                %10s  ║\n' "$today_count"
printf '║  This week:            %10s  ║\n' "$week_count"
printf '║  This month:           %10s  ║\n' "$month_count"
printf '╠════════════════════════════════════╣\n'
printf '║  Progress by interval:             ║\n'
printf '║  ✎ Due/overdue:        %10s  ║\n' "$new_count"
printf '║  → Short (≤7 days):    %10s  ║\n' "$short_interval"
printf '║  ✓ Long (>7 days):     %10s  ║\n' "$long_interval"
printf '╚════════════════════════════════════╝\n'

# ==================== VERBOSE OUTPUT ====================

if [[ "${1:-}" == "-v" ]] && [[ -f "$LEVELS_FILE" ]]; then
    echo ""
    echo "Words with long intervals (>30 days):"
    
    while IFS=$'\t' read -r phrase interval due ease; do
        [[ -z "$phrase" || -z "$interval" ]] && continue
        [[ "$interval" =~ ^[0-9]+$ ]] || continue
        [[ $interval -le 30 ]] && continue
        
        if [[ $interval -lt 365 ]]; then
            label="$interval days"
        else
            label="$((interval / 365)) yr"
        fi
        
        echo "  [$label] ${phrase:0:50}"
    done < "$LEVELS_FILE" | tail -10
fi
