#!/bin/bash
# vocab_save.sh
#
# Saves currently selected text to vocabulary storage.
# - Works on both X11 and Wayland
# - Avoids duplicates
# - Ignores short/trivial selections
#
# Usage: Bind to a keyboard shortcut
# Example: Ctrl+Super+S -> /path/to/vocab_save.sh

set -e

# Get script directory for sourcing config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/vocab_config.sh"

# ==================== DEPENDENCY CHECK ====================

for cmd in jq curl; do
    command -v "$cmd" >/dev/null || {
        notify-send "Error" "$cmd missing"
        exit 1
    }
done

# ==================== MAIN ====================

# Acquire lock to prevent concurrent file modifications
# Uses fd 9, released automatically on script exit
exec 9>"$LOCK_FILE_FILES"
if ! flock -n 9; then
    notify-send "Busy" "Try again"
    exit 1
fi

# Detect display server and get primary selection
if [ -n "$WAYLAND_DISPLAY" ]; then
    # Wayland: use wl-paste from wl-clipboard package
    if ! command -v wl-paste &>/dev/null; then
        notify-send "Error" "wl-clipboard not installed!"
        exit 1
    fi
    SELECTED=$(wl-paste -p 2>/dev/null)
else
    # X11: use xclip for primary selection
    if ! command -v xclip &>/dev/null; then
        notify-send "Error" "xclip not installed!"
        exit 1
    fi
    SELECTED=$(xclip -o -selection primary 2>/dev/null)
fi

# Normalize: lowercase, remove CR/LF, trim leading/trailing whitespace
SELECTED=$(echo "$SELECTED" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Skip empty or too-short selections
if [ -z "$SELECTED" ] || [ "${#SELECTED}" -lt "$MIN_LENGTH" ]; then
    notify-send -i "$ICON_TRANSLATE" "No valid selection detected"
    exit 0
fi

# Check for duplicates (case-insensitive exact match, though phrases are stored lowercase)
if grep -iqFx "$SELECTED" "$VOCAB_FILE" 2>/dev/null; then
    existing_trans=$(get_cached_translation "$SELECTED")
    if [[ -n "$existing_trans" ]]; then
        notify-send -i "$ICON_TRANSLATE" "Already saved" "${SELECTED:0:$MAX_NOTIFY} → $existing_trans"
    else
        new_trans=$(translate_phrase "$SELECTED") || new_trans=""
        if [[ -n "$new_trans" ]]; then
            notify-send -i "$ICON_TRANSLATE" "Already saved" "${SELECTED:0:$MAX_NOTIFY} → $new_trans"
        else
            notify-send -i "$ICON_TRANSLATE" "Already saved" "${SELECTED:0:$MAX_NOTIFY}"
        fi
    fi
    exit 0
fi

# Append to vocabulary file
echo "$SELECTED" >> "$VOCAB_FILE"

# Store for discard script
echo "$SELECTED" > "$CURRENT_PHRASE_FILE"

# Get and cache translation
translation=$(translate_phrase "$SELECTED") || translation=""

# Confirm to user (truncate long phrases)
TRUNCATED="${SELECTED:0:$MAX_NOTIFY}"
if [[ -n "$translation" ]]; then
    notify-send -i "$ICON_TRANSLATE" "Saved" "$TRUNCATED → $translation"
else
    notify-send -i "$ICON_TRANSLATE" "Saved new selection" "$TRUNCATED"
fi
