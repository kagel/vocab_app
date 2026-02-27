# Vocabulary App

A lightweight vocabulary learning app with system tray and spaced repetition. Supports both Linux desktop (XFCE, GNOME, etc.) with GTK.

## Features

- **System tray**: Runs in background with tray icon
- **Save phrases**: Select text anywhere, press a hotkey, done
- **Spaced repetition**: SM-2 algorithm for optimal review scheduling
- **Auto-translation**: Automatic translation via Google Translate
- **Stats dashboard**: See words learned, streak, reviews today
- **Autostart**: Automatically starts on login

## GUI App (Recommended)

Located in `gui/` folder - modern GTK3 interface with system tray.

### Setup

```bash
cd gui
./setup.sh
```

### Running

```bash
source venv/bin/activate
python3 vocab_gui.py
```

### Keyboard Shortcuts (XFCE)

Configure in XFCE Settings → Keyboard → Application Shortcuts:

| Command | Purpose |
|---------|---------|
| `python3 /path/to/vocab_gui.py --save` | Save selected text |
| `python3 /path/to/vocab_gui.py --delete` | Delete current word |
| `python3 /path/to/vocab_gui.py --next` | Show next word |

### Settings

- Review interval (30min - 8hours)
- Target language (ru, es, fr, de, it, pt, ja, zh, ko)
- Autostart on login
- Custom data directory

## Bash Scripts (Legacy)

Original bash-based version in project root.

| Script | Purpose |
|--------|---------|
| `vocab_save.sh` | Save selected text to vocabulary |
| `vocab_show.sh` | Continuous popup loop with translations |
| `vocab_discard.sh` | Remove current phrase |
| `vocab_stats.sh` | Display learning statistics |
| `vocab_config.sh` | Shared configuration |

### Dependencies (Bash)

```bash
# Core
sudo apt install curl notify-send

# X11
sudo apt install xclip

# Wayland
sudo apt install wl-clipboard
```

## Spaced Repetition

Uses the **SM-2 algorithm**:

- **First review**: 1 day interval
- **Subsequent reviews**: `interval × ease_factor` (default 2.5x)
- **Ease factor**: Increases slightly with each review (minimum 1.3)
- **Maximum interval**: 180 days (≈6 months)

## Data Storage

- Default: `~/.local/share/vocab_app/vocab.db`
- Custom path can be set in settings
