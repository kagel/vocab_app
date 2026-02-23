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

for cmd in curl jq notify-send shuf tail grep sed wc awk date; do
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

# ==================== SPACED REPETITION FUNCTIONS ====================

# Get learning level for a phrase (0-5, default 0)
# Uses case-insensitive matching
get_level() {
    local phrase="$1"
    local level
    level=$(grep -iF "$phrase" "$LEVELS_FILE" 2>/dev/null | head -1 | cut -f2)
    echo "${level:-0}"
}

# Increment phrase level (capped at 5)
# Higher level = seen more often = needs more practice
increment_level() {
    local phrase="$1"
    local current_level
    current_level=$(get_level "$phrase")
    local new_level=$((current_level + 1))
    [[ $new_level -gt 5 ]] && new_level=5
    
    # Update levels file (remove old entry case-insensitively)
    # Match phrase followed by tab to avoid partial matches
    grep -viF "$phrase"$'\t' "$LEVELS_FILE" > "$LEVELS_FILE.tmp" 2>/dev/null || true
    printf '%s\t%s\n' "$phrase" "$new_level" >> "$LEVELS_FILE.tmp"
    mv "$LEVELS_FILE.tmp" "$LEVELS_FILE"
}

# Get selection weight based on level
# Lower level = lower weight = shown less often
# This creates inverse spaced repetition effect
get_weight() {
    local level="$1"
    case "$level" in
        0) echo 100 ;;  # New word: very likely
        1) echo 50 ;;   # Seen once
        2) echo 25 ;;   # Learning
        3) echo 12 ;;   # Getting familiar
        4) echo 6 ;;    # Almost mastered
        5) echo 3 ;;    # Mastered: rarely shown
        *) echo 25 ;;
    esac
}

# Weighted random selection
# Phrases with higher weights are more likely to be picked
weighted_shuffle() {
    local -a phrases=("${!1}")
    local -a weighted=()
    
    for phrase in "${phrases[@]}"; do
        local level
        level=$(get_level "$phrase")
        local weight
        weight=$(get_weight "$level")
        # Add phrase 'weight' times to array
        for ((i=0; i<weight; i++)); do
            weighted+=("$phrase")
        done
    done
    
    # Random pick from weighted pool
    printf '%s\n' "${weighted[@]}" | shuf -n 1
}

# ==================== CACHE FUNCTIONS ====================

# Get cached translation for a phrase (case-insensitive)
# Returns translation if found, empty string if not
# Uses grep for speed (faster than bash loop for large files)
get_cached_translation() {
    local phrase="$1"
    
    # Use -F for fixed string matching (safe with special chars like . * [ ?)
    # Pattern: "phrase"\t matches our cache format at line start
    local line
    line=$(grep -iF "\"$phrase\""$'\t' "$CACHE_FILE" 2>/dev/null | head -n 1)

    if [[ -n "$line" ]]; then
        # Extract translation (everything after first tab)
        local trans="${line#*$'\t'}"
        # Strip surrounding quotes
        trans="${trans#\"}"
        echo "${trans%\"}"
    fi
}

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
    
    # Load all phrases from vocabulary file
    # Trim whitespace and skip empty lines
    mapfile -t ALL_LINES < <(
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$VOCAB_FILE" | grep -v '^$'
    )
    
    # Skip if no phrases available
    [[ ${#ALL_LINES[@]} -eq 0 ]] && sleep "$SLEEP_INTERVAL" && continue
    
    # Get recently shown phrases to avoid repetition
    RECENT=$(tail -n "$RECENT_LIMIT" "$HISTORY_FILE")
    
    # Identify phrases not yet in translation cache
    mapfile -t UNSEEN < <(
        for line in "${ALL_LINES[@]}"; do
            [[ -z $(get_cached_translation "$line") ]] && echo "$line"
        done
    )
    
    # Prefer unseen phrases, fallback to all
    if [[ ${#UNSEEN[@]} -gt 0 ]]; then
        choose_from=("${UNSEEN[@]}")
    else
        choose_from=("${ALL_LINES[@]}")
    fi
    
    # Filter out recently shown phrases (case-insensitive)
    filtered=()
    for line in "${choose_from[@]}"; do
        echo "$RECENT" | grep -iqFx "$line" || filtered+=("$line")
    done

    if [[ ${#filtered[@]} -gt 0 ]]; then
        choose_from=("${filtered[@]}")
    fi
    
    # Select phrase using weighted shuffle (spaced repetition)
    original=$(weighted_shuffle choose_from[@])
    
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
    cached=$(get_cached_translation "$original")
    
    if [[ -n "$cached" ]]; then
        # Use cached translation
        translated="$cached"
    else
        # Call Google Translate API
        q_encoded=$(printf '%s' "$original" | jq -sRr @uri)
        
        response=$(curl -s -m 12 \
            "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${TARGET_LANG}&dt=t&q=${q_encoded}")
        
        # Extract translation from JSON response
        translated=$(echo "$response" | jq -r '.[0][0][0] // empty')
        
        # Skip if translation failed
        if [[ -z "$translated" ]]; then
            sleep "$SLEEP_INTERVAL"
            continue
        fi
        
        # Normalize translation
        translated=$(echo "$translated" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Save to cache (quoted format: "phrase"\t"translation")
        printf '"%s"\t"%s"\n' "$original" "$translated" >> "$CACHE_FILE"
        
        # Prune cache if too large
        if [[ $(wc -l < "$CACHE_FILE") -gt $MAX_CACHE_LINES ]]; then
            tail -n "$MAX_CACHE_LINES" "$CACHE_FILE" > "$CACHE_FILE.tmp" \
                && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
        fi
    fi
    
    # Build level indicator (stars)
    level=$(get_level "$original")
    level_indicator=""
    for ((i=0; i<level; i++)); do
        level_indicator+="★"
    done
    [[ -n "$level_indicator" ]] && level_indicator=" [$level_indicator]"
    
    # Show phrase first (without translation)
    notify-send -u "$NOTIFY_URGENCY" -t $((REVEAL_DELAY * 1000)) \
        "" "<b>$original</b>$level_indicator"
    
    # Wait before revealing translation
    sleep "$REVEAL_DELAY"
    
    # Show phrase with translation
    notify-send -u "$NOTIFY_URGENCY" -t "$NOTIFY_TIMEOUT" \
        "" "<b>$original</b>$level_indicator\n→ $translated"
    
    # Wait until next word
    sleep "$SLEEP_INTERVAL"
    
done
