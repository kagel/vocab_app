#!/bin/bash
# save_selection.sh
# Saves selected text to a storage file, avoiding duplicates and trivial selections.
# Works on both X11 and Wayland (GNOME/Sway/etc.)

# -------- CONFIG --------
STORAGE_FILE="$HOME/saved_phrases.txt"
MIN_LENGTH=3        # ignore phrases shorter than this
MAX_NOTIFY=50       # max characters shown in notification
# ------------------------

# Detect environment
if [ -n "$WAYLAND_DISPLAY" ]; then
    # Wayland
    if ! command -v wl-paste &>/dev/null; then
        notify-send "Error" "wl-clipboard not installed!"
        exit 1
    fi
    SELECTED=$(wl-paste -p 2>/dev/null)
else
    # X11
    if ! command -v xclip &>/dev/null; then
        notify-send "Error" "xclip not installed!"
        exit 1
    fi
    SELECTED=$(xclip -o -selection primary 2>/dev/null)
fi

# Trim leading/trailing whitespace and remove newlines
SELECTED=$(echo "$SELECTED" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Ignore empty or too-short selections
if [ -z "$SELECTED" ] || [ "${#SELECTED}" -lt "$MIN_LENGTH" ]; then
    notify-send "No valid selection detected"
    exit 0
fi

# Check for duplicates (case-insensitive, trimmed)
if grep -iqFx "$SELECTED" "$STORAGE_FILE" 2>/dev/null; then
    notify-send "Duplicate ignored" "${SELECTED:0:$MAX_NOTIFY}"
    exit 0
fi

# Append to storage file
echo "$SELECTED" >> "$STORAGE_FILE"

# Notification (truncate if too long)
TRUNCATED="${SELECTED:0:$MAX_NOTIFY}"
notify-send "Saved new selection" "$TRUNCATED"
