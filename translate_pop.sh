#!/usr/bin/env bash
# translate_pop_loop.sh
# Continuous smart vocab popup loop

# ================= CONFIG =================
VOCAB_FILE="$HOME/Dropbox/saved_phrases.txt"
CACHE_FILE="$HOME/Dropbox/translated_cache.txt"
HISTORY_FILE="$HOME/Dropbox/vocab_history.txt"

TARGET_LANG="ru"
MAX_CACHE_LINES=5000
RECENT_LIMIT=30

SLEEP_INTERVAL=1800          # seconds between words (30 min)
REVEAL_DELAY=4               # seconds before showing translation
NOTIFY_TIMEOUT=14000
NOTIFY_URGENCY="low"
# ==========================================

for cmd in curl jq notify-send shuf tail grep sed wc awk; do
    command -v "$cmd" >/dev/null || {
        notify-send -u critical "Vocab Error" "$cmd missing"
        exit 1
    }
done

[[ -f "$CACHE_FILE" ]] || touch "$CACHE_FILE"
[[ -f "$HISTORY_FILE" ]] || touch "$HISTORY_FILE"

if [[ ! -s "$VOCAB_FILE" ]]; then
    notify-send -u critical "Vocab Error" "File empty:\n$VOCAB_FILE"
    exit 1
fi

echo "Vocab loop started. Interval: $SLEEP_INTERVAL seconds"
echo "Press Ctrl+C to stop."

while true; do

    mapfile -t ALL_LINES < <(
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$VOCAB_FILE" | grep -v '^$'
    )

    [[ ${#ALL_LINES[@]} -eq 0 ]] && sleep "$SLEEP_INTERVAL" && continue

    RECENT=$(tail -n "$RECENT_LIMIT" "$HISTORY_FILE")

    # Prefer unseen
    mapfile -t UNSEEN < <(
        for line in "${ALL_LINES[@]}"; do
            grep -Fxq "\"$line\"" "$CACHE_FILE" || echo "$line"
        done
    )

    if [[ ${#UNSEEN[@]} -gt 0 ]]; then
        choose_from=("${UNSEEN[@]}")
    else
        choose_from=("${ALL_LINES[@]}")
    fi

    # Avoid recently shown
    filtered=()
    for line in "${choose_from[@]}"; do
        echo "$RECENT" | grep -Fxq "$line" || filtered+=("$line")
    done

    if [[ ${#filtered[@]} -gt 0 ]]; then
        choose_from=("${filtered[@]}")
    fi

    original=$(printf "%s\n" "${choose_from[@]}" | shuf -n 1)

    [[ ${#original} -lt 2 ]] && sleep "$SLEEP_INTERVAL" && continue

    echo "$original" >> "$HISTORY_FILE"

    original_escaped=$(printf '%s' "$original" | sed 's/[][\.|$(){}?+*^]/\\&/g')

    cached=$(grep -P -m 1 "^\"\Q$original_escaped\E\"\t" "$CACHE_FILE" 2>/dev/null \
             | cut -f2- | sed 's/^"//;s/"$//')

    if [[ -n "$cached" ]]; then
        translated="$cached"
    else
        q_encoded=$(printf '%s' "$original" | jq -sRr @uri)

        response=$(curl -s -m 12 \
            "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${TARGET_LANG}&dt=t&q=${q_encoded}")

        translated=$(echo "$response" | jq -r '.[0][0][0] // empty')

        if [[ -z "$translated" ]]; then
            sleep "$SLEEP_INTERVAL"
            continue
        fi

        translated=$(echo "$translated" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        printf '"%s"\t"%s"\n' "$original" "$translated" >> "$CACHE_FILE"

        if [[ $(wc -l < "$CACHE_FILE") -gt $MAX_CACHE_LINES ]]; then
            tail -n "$MAX_CACHE_LINES" "$CACHE_FILE" > "$CACHE_FILE.tmp" \
                && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
        fi
    fi

    # Show word first
    notify-send -u "$NOTIFY_URGENCY" -t $((REVEAL_DELAY * 1000)) \
        "" "<b>$original</b>"

    sleep "$REVEAL_DELAY"

    # Show translation
    notify-send -u "$NOTIFY_URGENCY" -t "$NOTIFY_TIMEOUT" \
        "" "<b>$original</b>\n→ $translated"

    sleep "$SLEEP_INTERVAL"

done