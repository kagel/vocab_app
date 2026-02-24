#!/usr/bin/env bash
# vocab_stats.sh
#
# Display vocabulary learning statistics.
# Shows total words, reviews, and progress by learning level.
#
# Usage:
#   ./vocab_stats.sh       # Basic stats
#   ./vocab_stats.sh -v    # Verbose (shows mastered phrases)

set -e

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

# Initialize level counters (0-5)
level_counts=(0 0 0 0 0 0)

# Count phrases at each level
if [[ -f "$LEVELS_FILE" ]]; then
    while IFS=$'\t' read -r phrase level; do
        [[ -z "$level" ]] && continue
        [[ "$level" =~ ^[0-9]+$ ]] || continue
        level_counts[$level]=$((level_counts[level] + 1))
    done < "$LEVELS_FILE"
fi

# Aggregate into categories
new_words=${level_counts[0]}
learning=$((level_counts[1] + level_counts[2] + level_counts[3]))
mastered=$((level_counts[4] + level_counts[5]))

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
printf '║  Progress by level:                ║\n'
printf '║  ☆ New (0):            %10s  ║\n' "${level_counts[0]}"
printf '║  ★ Level 1-3:          %10s  ║\n' "$learning"
printf '║  ★★ Level 4-5:         %10s  ║\n' "$mastered"
printf '╚════════════════════════════════════╝\n'

# ==================== VERBOSE OUTPUT ====================

# If -v flag, show recently mastered phrases
if [[ "$1" == "-v" ]] && [[ -f "$LEVELS_FILE" ]]; then
    echo ""
    echo "Recently mastered (level 4-5):"
    
    while IFS=$'\t' read -r phrase level; do
        # Skip non-mastered phrases
        [[ "$level" =~ ^[4-5]$ ]] || continue
        
        # Build star indicator
        stars=""
        for ((i=0; i<level; i++)); do
            stars+="★"
        done
        
        # Display (truncate long phrases)
        echo "  [$stars] ${phrase:0:50}"
    done < "$LEVELS_FILE" | tail -10
fi
