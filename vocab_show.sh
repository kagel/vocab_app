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

for cmd in curl notify-send awk date; do
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
declare -A PHRASE_DATA

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
    PHRASE_DATA=()
    while IFS=$'\t' read -r phrase interval due ease; do
        [[ -z "$phrase" ]] && continue
        PHRASE_DATA[$phrase]="$interval|$due|$ease"
    done < "$LEVELS_FILE"
}

get_cached_translation() {
    local phrase="$1"
    echo "${CACHE_TRANS["$phrase"]}"
}

get_sm2_data() {
    local phrase="$1"
    [[ -z "$phrase" ]] && echo "$SM2_INITIAL_INTERVAL|0|$SM2_EASE_FACTOR" && return
    local data="${PHRASE_DATA[$phrase]}"
    if [[ -z "$data" ]]; then
        echo "$SM2_INITIAL_INTERVAL|0|$SM2_EASE_FACTOR"
    else
        echo "$data"
    fi
}

get_interval() {
    local phrase="$1"
    local interval
    interval=$(get_sm2_data "$phrase" | cut -d'|' -f1)
    echo "${interval:-1}"
}

update_sm2() {
    local phrase="$1"
    local now=$(date +%s)
    
    local interval due ease
    read -r interval due ease <<< "$(get_sm2_data "$phrase" | tr '|' ' ')"
    
    interval=${interval:-$SM2_INITIAL_INTERVAL}
    ease=${ease:-$SM2_EASE_FACTOR}
    due=${due:-0}
    
    local new_interval new_due new_ease
    
    if [[ $due -ne 0 && $((now - due)) -lt 0 ]]; then
        new_ease=$ease
        new_interval=$interval
    else
        new_ease=$(awk "BEGIN {printf \"%.1f\", $ease + 0.1}")
        [[ $(awk "BEGIN {print $new_ease < $SM2_MIN_EASE}") -eq 1 ]] && new_ease=$SM2_MIN_EASE
        
        new_interval=$(awk "BEGIN {printf \"%.0f\", $interval * $new_ease}")
        [[ $new_interval -gt $SM2_MAX_INTERVAL ]] && new_interval=$SM2_MAX_INTERVAL
    fi
    
    new_due=$((now + new_interval * 86400))
    
    PHRASE_DATA[$phrase]="$new_interval|$new_due|$new_ease"
    
    grep -viF "$phrase"$'\t' "$LEVELS_FILE" > "$LEVELS_FILE.tmp" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\n' "$phrase" "$new_interval" "$new_due" "$new_ease" >> "$LEVELS_FILE.tmp"
    mv "$LEVELS_FILE.tmp" "$LEVELS_FILE"
}

# Load initial cache, levels, and vocabulary
load_cache
load_levels

mapfile -t ALL_LINES < <(awk 'NF {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}' "$VOCAB_FILE")

# ==================== SPACED REPETITION ====================

get_urgency() {
    local phrase="$1"
    local now=$(date +%s)
    local interval due ease
    read -r interval due ease <<< "$(get_sm2_data "$phrase" | tr '|' ' ')"
    
    if [[ -z "$due" || $due -eq 0 ]]; then
        echo 100
        return
    fi
    
    local overdue=$((now - due))
    
    if ((overdue > 0)); then
        echo $((100 + overdue / 3600))
    else
        echo 10
    fi
}

weighted_select() {
    local -n arr=$1
    local total=0
    local phrase urgency
    
    for phrase in "${arr[@]}"; do
        ((total += $(get_urgency "$phrase")))
    done
    
    local rand=$((RANDOM * RANDOM % total))
    local running=0
    
    for phrase in "${arr[@]}"; do
        ((running += $(get_urgency "$phrase")))
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

iteration=0

while true; do
    
    # Reload vocab periodically to pick up new words
    if (( ++iteration % RELOAD_EVERY == 0 )); then
        mapfile -t ALL_LINES < <(awk 'NF {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}' "$VOCAB_FILE")
    fi
    
    # Skip if no phrases available
    [[ ${#ALL_LINES[@]} -eq 0 ]] && sleep "$SLEEP_INTERVAL" && continue
    
    # Get recently shown phrases for O(1) lookup
    declare -A recent_set
    while IFS=$'\t' read -r _ phrase; do
        [[ -n "$phrase" ]] && recent_set["$phrase"]=1
    done < <(tail -n "$RECENT_LIMIT" "$HISTORY_FILE")
    
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
    
    # Update SM-2 intervals
    update_sm2 "$original"
    
    # Get translation (from cache or API)
    translated=$(translate_phrase "$original")
    
    if [[ -z "$translated" ]]; then
        sleep "$SLEEP_INTERVAL"
        continue
    fi
    
    # Get interval info
    interval=$(get_interval "$original")
    if [[ $interval -eq 1 ]]; then
        interval_indicator="1 day"
    elif [[ $interval -lt 30 ]]; then
        interval_indicator="$interval days"
    elif [[ $interval -lt 365 ]]; then
        interval_indicator="$((interval / 30)) mo"
    else
        interval_indicator="$((interval / 365)) yr"
    fi
    interval_indicator=" [$interval_indicator]"
    
    # Show phrase first (without translation)
    notify-send -i "$ICON_TRANSLATE" -u "$NOTIFY_URGENCY" -t $((REVEAL_DELAY * 1000)) \
        "" "<b>$original</b>$interval_indicator"
    
    # Wait before revealing translation
    sleep "$REVEAL_DELAY"
    
    # Show phrase with translation
    notify-send -i "$ICON_TRANSLATE" -u "$NOTIFY_URGENCY" -t "$NOTIFY_TIMEOUT" \
        "" "<b>$original</b>$interval_indicator\n→ $translated"
    
    # Wait until next word
    sleep "$SLEEP_INTERVAL"
    
done
