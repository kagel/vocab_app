# Vocabulary App

A lightweight, cross-platform (X11/Wayland) Bash vocabulary learning toolkit for Linux. Save phrases, review them with spaced repetition, and track your progress.

## Features

- **Save phrases**: Select text anywhere, press a hotkey, done
- **Spaced repetition**: SM-2 algorithm for optimal review scheduling
- **Learning levels**: Shows next review interval (1 day → 3 days → 2 mo → 1 yr)
- **Translation cache**: Automatic translation via Google Translate API
- **Stats dashboard**: See words learned, reviews today/week/month
- **Cross-platform**: Works on X11 and Wayland automatically
- **Case-insensitive**: "Hello" and "hello" are treated as the same phrase

## Scripts

| Script | Purpose |
|--------|---------|
| `vocab_save.sh` | Save selected text to vocabulary |
| `vocab_show.sh` | Continuous popup loop with translations |
| `vocab_discard.sh` | Remove current phrase (bind to hotkey) |
| `vocab_stats.sh` | Display learning statistics |
| `vocab_config.sh` | Shared configuration |

## Dependencies

```bash
# Core
sudo apt install curl notify-send

# X11
sudo apt install xclip

# Wayland
sudo apt install wl-clipboard
```

## Installation

1. Clone or copy scripts to a folder:
   ```bash
   mkdir -p ~/vocab_app/scripts
   cd ~/vocab_app/scripts
   # Copy scripts here
   chmod +x *.sh
   ```

2. Bind keyboard shortcuts:
   - `vocab_save.sh` → `Ctrl+Alt+S` (save selection)
   - `vocab_discard.sh` → `Ctrl+Alt+D` (discard current phrase)

3. Start the popup loop:
   ```bash
   ./vocab_show.sh
   ```

## Usage

### Saving Phrases
1. Select text in any application
2. Press your `vocab_save.sh` hotkey
3. Phrase is saved (lowercased, deduplicated)

### Reviewing
1. Run `vocab_show.sh` (autostart recommended)
2. Phrases appear periodically as notifications
3. Wait for translation to reveal
4. Brackets show next review interval: `[1 day]`, `[3 days]`, `[2 mo]`

### Discarding Boring Phrases
1. When a phrase appears you already know
2. Press your `vocab_discard.sh` hotkey
3. Phrase is removed from all files

### Checking Stats
```bash
./vocab_stats.sh        # Basic stats
./vocab_stats.sh -v     # Show mastered phrases
```

## Configuration

Edit `vocab_config.sh`:

```bash
# Base directory (all files stored here)
VOCAB_DIR="$HOME/Dropbox/vocab_app"

# Translation target language
TARGET_LANG="ru"

# Popup timing
SLEEP_INTERVAL=600      # Seconds between words
REVEAL_DELAY=4          # Seconds before showing translation

# SM-2 Spaced Repetition
SM2_INITIAL_INTERVAL=1  # Days for first review
SM2_EASE_FACTOR=2.5      # Interval multiplier
SM2_MIN_EASE=1.3         # Minimum ease factor
SM2_MAX_INTERVAL=180     # Maximum interval (days)

# File limits
MAX_CACHE_LINES=5000
MAX_HISTORY_LINES=1000
```

## File Structure

```
$VOCAB_DIR/
├── saved_phrases.txt    # Your vocabulary
├── translated_cache.txt # Cached translations
├── vocab_history.txt    # Review history
└── vocab_levels.txt     # SM-2 data: phrase | interval | due_date | ease_factor
```

## Spaced Repetition

Uses the **SM-2 algorithm** with passive time-based scheduling:

- **First review**: 1 day interval
- **Subsequent reviews**: `interval × ease_factor` (default 2.5x)
- **Ease factor**: Increases slightly with each review (minimum 1.3)
- **Maximum interval**: 180 days (≈6 months)

Words become "due" after their interval passes. Overdue words are prioritized for review. New words have highest priority since they have no due date.

## Tips

- Autostart `vocab_show.sh` via your desktop's session settings
- Use `vocab_discard.sh` liberally - remove words you already know
- Check `vocab_stats.sh -v` to see your mastered words
- Sync `$VOCAB_DIR` via Dropbox/Syncthing for multi-device access
