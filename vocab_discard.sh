#!/usr/bin/env bash
# vocab_discard.sh
#
# Removes the currently displayed phrase from all vocabulary files.
# Designed to be bound to a keyboard shortcut.
#
# Usage: Bind to hotkey (e.g., Ctrl+Shift+D)
# Must be called while vocab_show.sh is running

set -e

# Get script directory and load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vocab_config.sh"

# ==================== LOCKING ====================

# Acquire lock to prevent concurrent modifications
exec 9>"$LOCK_FILE_FILES"
if ! flock -n 9; then
    notify-send "Busy" "Try again"
    exit 1
fi

# ==================== VALIDATION ====================

# Check if there's a current phrase to discard
if [[ ! -f "$CURRENT_PHRASE_FILE" ]]; then
    notify-send "Discard" "No phrase to discard"
    exit 1
fi

PHRASE=$(cat "$CURRENT_PHRASE_FILE")

if [[ -z "$PHRASE" ]]; then
    notify-send "Discard" "No phrase to discard"
    exit 1
fi

# ==================== REMOVAL ====================

# Remove from vocabulary file (case-insensitive exact line match)
if [[ -f "$VOCAB_FILE" ]]; then
    grep -viFx "$PHRASE" "$VOCAB_FILE" > "$VOCAB_FILE.tmp" && mv "$VOCAB_FILE.tmp" "$VOCAB_FILE"
fi

# Remove from history (case-insensitive, match phrase after tab)
if [[ -f "$HISTORY_FILE" ]]; then
    grep -viF $'\t'"$PHRASE" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
fi

# Remove learning level (case-insensitive, match phrase followed by tab)
if [[ -f "$LEVELS_FILE" ]]; then
    grep -viF "$PHRASE"$'\t' "$LEVELS_FILE" > "$LEVELS_FILE.tmp" && mv "$LEVELS_FILE.tmp" "$LEVELS_FILE"
fi

# Remove from translation cache
if [[ -f "$CACHE_FILE" ]]; then
    grep -viF "\"$PHRASE\"" "$CACHE_FILE" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

# ==================== CLEANUP ====================

# Clear current phrase file
rm -f "$CURRENT_PHRASE_FILE"

# Notify user (truncate long phrases)
notify-send "Discarded" "${PHRASE:0:$MAX_NOTIFY}"
