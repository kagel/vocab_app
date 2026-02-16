#!/usr/bin/env bash
# translate_pop.sh
# One-time: pick random phrase → check cache → translate if needed → notify → exit
# Cache: ~/Dropbox/translated_cache.txt    format: "original"\t"translated" (tab separated)
# Keeps only the last MAX_CACHE_LINES entries after each new append

# ================= CONFIG =================
VOCAB_FILE="$HOME/Dropbox/saved_phrases.txt"
CACHE_FILE="$HOME/Dropbox/translated_cache.txt"
TARGET_LANG="ru"
MAX_CACHE_LINES=5000                      # ← adjust as needed (e.g. 2000, 10000)

NOTIFY_TIMEOUT=14000
NOTIFY_URGENCY="normal"
# ==========================================

# Required tools
for cmd in curl jq notify-send shuf tail; do
    command -v "$cmd" >/dev/null || {
        notify-send -u critical "Vocab Error" "$cmd missing (install curl jq libnotify-bin coreutils)"
        exit 1
    }
done

if [[ ! -s "$VOCAB_FILE" ]]; then
    notify-send -u critical "Vocab Error" "File empty or missing:\n$VOCAB_FILE"
    exit 1
fi

# Create cache file if missing
[[ -f "$CACHE_FILE" ]] || touch "$CACHE_FILE"

# Pick random trimmed line
original=$(shuf -n 1 -- "$VOCAB_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ ${#original} -lt 2 ]]; then
    notify-send -u low -t 6000 "Vocab" "Skipped too short phrase"
    exit 0
fi

# Escape original for safe exact grep (basic pattern escape)
original_escaped=$(printf '%s' "$original" | sed 's/[][\.|$(){}?+*^]/\\&/g')

# Check cache (exact match, quoted original)
cached=$(grep -P -m 1 "^\"\Q$original_escaped\E\"\t" "$CACHE_FILE" 2>/dev/null \
         | cut -f2- | sed 's/^"//;s/"$//')

if [[ -n "$cached" ]]; then
    translated="$cached"
else
    # URL-encode
    q_encoded=$(printf '%s' "$original" | jq -sRr @uri)

    # Google Translate unofficial
    response=$(curl -s -m 12 \
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${TARGET_LANG}&dt=t&q=${q_encoded}")

    if [[ $? -ne 0 || -z "$response" ]]; then
        notify-send -u low -t 8000 "Vocab" "Cannot reach Google Translate"
        exit 1
    fi

    translated=$(echo "$response" | jq -r '.[0][0][0] // empty' 2>/dev/null)

    if [[ -z "$translated" ]]; then
        notify-send -u low -t 8000 "Vocab" "Translation failed for:\n$original"
        exit 1
    fi

    translated=$(echo "$translated" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Append new entry (quoted + tab + quoted)
    printf '"%s"\t"%s"\n' "$original" "$translated" >> "$CACHE_FILE"

    # Trim cache to last MAX_CACHE_LINES lines (efficient, uses tail)
    if [[ $(wc -l < "$CACHE_FILE") -gt $MAX_CACHE_LINES ]]; then
        tail -n "$MAX_CACHE_LINES" "$CACHE_FILE" > "$CACHE_FILE.tmp" \
            && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
    fi
fi

# Show notification
notify-send -u "$NOTIFY_URGENCY" -t "$NOTIFY_TIMEOUT" \
    "" \
    "<b>$original</b>\n→ $translated"
