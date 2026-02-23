# Vocabulary App

A lightweight, cross-platform (X11/Wayland) Bash vocabulary learning toolkit for Linux. Save phrases, review them with spaced repetition, and track your progress.

## Features

- **Save phrases**: Select text anywhere, press a hotkey, done
- **Spaced repetition**: Words you struggle with appear more often
- **Learning levels**: Track progress from new (☆) to mastered (★★★★★)
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
sudo apt install curl jq notify-send

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
4. Stars indicate learning level: `[★★]` = level 2

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
└── vocab_levels.txt     # Learning levels (0-5)
```

## Spaced Repetition

Phrases are assigned levels 0-5:
- **Level 0** (☆): New word, shown frequently
- **Level 1-3** (★): Learning, shown less often
- **Level 4-5** (★★): Mastered, rarely shown

Each time you see a phrase, its level increases. This means words you've reviewed many times (and likely know well) appear less often than new words.

## Tips

- Autostart `vocab_show.sh` via your desktop's session settings
- Use `vocab_discard.sh` liberally - remove words you already know
- Check `vocab_stats.sh -v` to see your mastered words
- Sync `$VOCAB_DIR` via Dropbox/Syncthing for multi-device access
