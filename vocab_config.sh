#!/usr/bin/env bash
# vocab_config.sh
# Shared configuration for vocabulary scripts
# Source this file: source /path/to/vocab_config.sh

# ==================== BASE DIRECTORY ====================
# All vocabulary files will be stored here
# Override with: VOCAB_DIR=/custom/path source vocab_config.sh
VOCAB_DIR="${VOCAB_DIR:-$HOME/Dropbox/vocab_app}"

# Create directory if it doesn't exist
mkdir -p "$VOCAB_DIR"

# ==================== FILE PATHS ====================
# Derived from VOCAB_DIR (no need to change these)
VOCAB_FILE="$VOCAB_DIR/saved_phrases.txt"
CACHE_FILE="$VOCAB_DIR/translated_cache.txt"
HISTORY_FILE="$VOCAB_DIR/vocab_history.txt"
LEVELS_FILE="$VOCAB_DIR/vocab_levels.txt"

# Lock files (prevent concurrent access)
LOCK_FILE_LOOP="/tmp/vocab_loop.lock"
LOCK_FILE_FILES="/tmp/vocab_files.lock"

# Temp file for current phrase (used by discard)
CURRENT_PHRASE_FILE="/tmp/last_vocab_phrase"

# ==================== ICONS ====================
# Bundled icons (relative to script directory)
VOCAB_ICON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/icons"
ICON_TRANSLATE="$VOCAB_ICON_DIR/translate.svg"

# ==================== BEHAVIOR SETTINGS ====================
# Translation target language (ISO 639-1 code)
TARGET_LANG="ru"

# Minimum phrase length to save (shorter = ignored)
MIN_LENGTH=3

# ==================== SPACED REPETITION SETTINGS ====================
SM2_INITIAL_INTERVAL=1
SM2_EASE_FACTOR=2.5
SM2_MIN_EASE=1.3
SM2_MAX_INTERVAL=180

# ==================== POPUP LOOP SETTINGS ====================
# Seconds between showing words
SLEEP_INTERVAL=600

# Seconds before revealing translation
REVEAL_DELAY=4

# Notification display time (milliseconds)
NOTIFY_TIMEOUT=14000

# Notification urgency: low, normal, critical
NOTIFY_URGENCY="low"

# ==================== CACHE & HISTORY LIMITS ====================
# Max lines in translation cache
MAX_CACHE_LINES=5000

# Max lines in history file
MAX_HISTORY_LINES=1000

# Avoid showing these many most recent phrases
RECENT_LIMIT=30

# ==================== DISPLAY SETTINGS ====================
# Max characters shown in notifications
MAX_NOTIFY=50

# ==================== TRANSLATION FUNCTIONS ====================

get_cached_translation() {
    local phrase="$1"
    local line
    line=$(grep -iF "\"$phrase\""$'\t' "$CACHE_FILE" 2>/dev/null | head -n 1)
    
    if [[ -n "$line" ]]; then
        local trans="${line#*$'\t'}"
        trans="${trans#\"}"
        echo "${trans%\"}"
    fi
}

translate_phrase() {
    local phrase="$1"
    local translated
    
    cached=$(get_cached_translation "$phrase")
    
    if [[ -n "$cached" ]]; then
        echo "$cached"
        return 0
    fi
    
    local response
    response=$(curl -s -m 12 --data-urlencode "q=$phrase" \
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${TARGET_LANG}&dt=t")
    
    translated=$(echo "$response" | sed -n 's/\[\[\["\([^"]*\)".*/\1/p')
    
    if [[ -z "$translated" || "$translated" == "$response" ]]; then
        return 1
    fi
    
    translated=$(echo "$translated" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    printf '"%s"\t"%s"\n' "$phrase" "$translated" >> "$CACHE_FILE"
    
    if [[ $(wc -l < "$CACHE_FILE") -gt $MAX_CACHE_LINES ]]; then
        tail -n "$MAX_CACHE_LINES" "$CACHE_FILE" > "$CACHE_FILE.tmp" \
            && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
    fi
    
    echo "$translated"
}
