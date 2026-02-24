#!/usr/bin/env bash
# vocab_show.sh
#
# Continuous vocabulary popup loop with spaced repetition.
# - Shows random phrases periodically
# - Reveals translation after delay
# - Tracks learning levels (0-5)
# - Prioritizes words you struggle with
#
# Usage: ./vocab_show.sh
# Stop: Ctrl+C or 'killall vocab_show.sh'

set -e

# Get script directory and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vocab_config.sh"

# ==================== SETUP & LOCKING ====================

# Cleanup function: remove lock on exit
cleanup() {
    rm -f "$LOCK_FILE_LOOP"
    rm -f "$CURRENT_PHRASE_FILE"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Prevent multiple instances (exclusive lock on fd 9)
exec 9>"$LOCK_FILE_LOOP"
if ! flock -n 9; then
    notify-send -u critical "Vocab Error" "Another instance is already running"
    exit 1
fi

# ==================== DEPENDENCY CHECK ====================

for cmd in curl jq notify-send awk date; do
    command -v "$cmd" >/dev/null || {
        notify-send -u critical "Vocab Error" "$cmd missing"
        exit 1
    }
done

# ==================== FILE INITIALIZATION ====================

# Create files if they don't exist
[[ -f "$CACHE_FILE" ]] || touch "$CACHE_FILE"
[[ -f "$HISTORY_FILE" ]] || touch "$HISTORY_FILE"
[[ -f "$LEVELS_FILE" ]] || touch "$LEVELS_FILE"

# Verify vocabulary file has content
if [[ ! -s "$VOCAB_FILE" ]]; then
    notify-send -u critical "Vocab Error" "File empty:\n$VOCAB_FILE"
    exit 1
fi

# ==================== IN-MEMORY CACHE ====================

declare -A CACHE_TRANS
declare -A PHRASE_LEVELS

load_cache() {
    CACHE_TRANS=()
    while IFS=$'\t' read -r phrase trans; do
        [[ -z "$phrase" ]] && continue
        phrase="${phrase#\"}"
        phrase="${phrase%\"}"
        trans="${trans#\"}"
        trans="${trans%\"}"
        CACHE_TRANS["$phrase"]="$trans"
    done < "$CACHE_FILE"
}

load_levels() {
    PHRASE_LEVELS=()
    while IFS=$'\t' read -r phrase level; do
        [[ -z "$phrase" || -z "$level" ]] && continue
        [[ "$level" =~ ^[0-9]+$ ]] || continue
        PHRASE_LEVELS["$phrase"]="$level"
    done < "$LEVELS_FILE"
}

get_cached_translation() {
    local phrase="$1"
    echo "${CACHE_TRANS["$phrase"]}"
}

get_level() {
    local phrase="$1"
    echo "${PHRASE_LEVELS["$phrase"]:-0}"
}

increment_level() {
    local phrase="$1"
    local current_level=${PHRASE_LEVELS["$phrase"]:-0}
    local new_level=$((current_level + 1))
    [[ $new_level -gt 5 ]] && new_level=5
    PHRASE_LEVELS["$phrase"]="$new_level"
    
    # Update levels file (remove old entry case-insensitively)
    grep -viF "$phrase"$'\t' "$LEVELS_FILE" > "$LEVELS_FILE.tmp" 2>/dev/null || true
    printf '%s\t%s\n' "$phrase" "$new_level" >> "$LEVELS_FILE.tmp"
    mv "$LEVELS_FILE.tmp" "$LEVELS_FILE"
}

# Load initial cache and levels
load_cache
load_levels

# ==================== SPACED REPETITION ====================

# Get selection weight based on level (lower = shown less often)
get_weight() {
    local level="$1"
    case "$level" in
        0) echo 100 ;;
        1) echo 50 ;;
        2) echo 25 ;;
        3) echo 12 ;;
        4) echo 6 ;;
        5) echo 3 ;;
        *) echo 25 ;;
    esac
}

# Weighted random selection using cumulative weights (O(n) instead of O(n*weight))
weighted_select() {
    local -n arr=$1
    local total=0
    local phrase weight
    
    for phrase in "${arr[@]}"; do
        local level=${PHRASE_LEVELS["$phrase"]:-0}
        ((total += $(get_weight "$level")))
    done
    
    local rand=$((RANDOM * RANDOM % total))
    local running=0
    
    for phrase in "${arr[@]}"; do
        local level=${PHRASE_LEVELS["$phrase"]:-0}
        ((running += $(get_weight "$level")))
        ((rand < running)) && { echo "$phrase"; return; }
    done
    
    echo "${arr[0]}"
}

# ==================== CACHE FUNCTIONS ====================

# get_cached_translation and translate_phrase are now in vocab_config.sh

# ==================== UTILITY FUNCTIONS ====================

# Trim history file if it exceeds max lines
prune_history() {
    if [[ $(wc -l < "$HISTORY_FILE") -gt $MAX_HISTORY_LINES ]]; then
        tail -n "$MAX_HISTORY_LINES" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" \
            && mv -f "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

# ==================== MAIN LOOP ====================

echo "Vocab loop started. Interval: $SLEEP_INTERVAL seconds"
echo "Press Ctrl+C to stop."

while true; do
    
    # Load all phrases using awk (faster than sed+grep in subshell)
    mapfile -t ALL_LINES < <(awk 'NF {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}' "$VOCAB_FILE")
    
    # Skip if no phrases available
    [[ ${#ALL_LINES[@]} -eq 0 ]] && sleep "$SLEEP_INTERVAL" && continue
    
    # Get recently shown phrases as associative array for O(1) lookup
    declare -A recent_set
    tail -n "$RECENT_LIMIT" "$HISTORY_FILE" | while IFS=$'\t' read -r _ phrase; do
        [[ -n "$phrase" ]] && recent_set["$phrase"]=1
    done
    
    # Build list of phrases not in recent set
    choose_from=()
    for line in "${ALL_LINES[@]}"; do
        [[ -z "${recent_set["$line"]}" ]] && choose_from+=("$line")
    done
    
    # Fallback to all if filtered empty
    [[ ${#choose_from[@]} -eq 0 ]] && choose_from=("${ALL_LINES[@]}")
    
    # Select phrase using weighted selection (spaced repetition)
    original=$(weighted_select choose_from)
    
    # Skip if somehow empty
    [[ ${#original} -lt 2 ]] && sleep "$SLEEP_INTERVAL" && continue
    
    # Save current phrase for discard script
    echo "$original" > "$CURRENT_PHRASE_FILE"
    
    # Record in history with timestamp
    echo "$(date +%s)	$original" >> "$HISTORY_FILE"
    prune_history
    
    # Increment learning level
    increment_level "$original"
    
    # Get translation (from cache or API)
    translated=$(translate_phrase "$original")
    
    if [[ -z "$translated" ]]; then
        sleep "$SLEEP_INTERVAL"
        continue
    fi
    
    # Build level indicator (stars)
    level=$(get_level "$original")
    level_indicator=""
    for ((i=0; i<level; i++)); do
        level_indicator+="★"
    done
    [[ -n "$level_indicator" ]] && level_indicator=" [$level_indicator]"
    
    # Show phrase first (without translation)
    notify-send -i "$ICON_TRANSLATE" -u "$NOTIFY_URGENCY" -t $((REVEAL_DELAY * 1000)) \
        "" "<b>$original</b>$level_indicator"
    
    # Wait before revealing translation
    sleep "$REVEAL_DELAY"
    
    # Show phrase with translation
    notify-send -i "$ICON_TRANSLATE" -u "$NOTIFY_URGENCY" -t "$NOTIFY_TIMEOUT" \
        "" "<b>$original</b>$level_indicator\n→ $translated"
    
    # Wait until next word
    sleep "$SLEEP_INTERVAL"
    
done
