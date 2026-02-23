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

# ==================== BEHAVIOR SETTINGS ====================
# Translation target language (ISO 639-1 code)
TARGET_LANG="ru"

# Minimum phrase length to save (shorter = ignored)
MIN_LENGTH=3

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
