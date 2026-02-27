# Vocabulary App

A lightweight vocabulary learning app with system tray and spaced repetition. Supports Linux desktop (XFCE, GNOME, etc.) with GTK.

## Features

- **System tray**: Runs in background with tray icon
- **Save phrases**: Select text anywhere, press a hotkey, done
- **Spaced repetition**: SM-2 algorithm for optimal review scheduling
- **Auto-translation**: Automatic translation via Google Translate
- **Stats dashboard**: See words learned, streak, reviews today
- **Autostart**: Automatically starts on login
- **Multiple languages**: Support for 9 target languages

## Screenshots

### Popup Notification
![Popup](docs/screenshot-popup.png)

### Add Word Dialog
![Add Word](docs/screenshot-add-word.png)

### Settings Window
![Settings](docs/screenshot-settings.png)

### Statistics Window
![Stats](docs/screenshot-stats.png)

## GUI App (Recommended)

Located in `src/` folder - modern GTK3 interface with system tray.

### Setup

```bash
./setup.sh
```

### Running

```bash
source venv/bin/activate
python3 src/vocab_gui.py
```

### Keyboard Shortcuts (XFCE)

Configure in XFCE Settings → Keyboard → Application Shortcuts:

| Command | Purpose |
|---------|---------|
| `python3 /path/to/src/vocab_gui.py --save` | Save selected text |
| `python3 /path/to/src/vocab_gui.py --delete` | Delete current word |
| `python3 /path/to/src/vocab_gui.py --next` | Show next word |

### Settings

- **Review interval**: How often to show words (30min - 8hours)
- **Target language**: Translation language (Russian, Spanish, French, German, Italian, Portuguese, Japanese, Chinese, Korean)
- **Autostart**: Automatically starts on system login
- **Custom data directory**: Store database elsewhere

### Database Location

- Default: `~/.local/share/vocab_app/vocab.db`
- Can be changed in settings

## Spaced Repetition

Uses the **SM-2 algorithm**:

- **First review**: 1 day interval
- **Subsequent reviews**: `interval × ease_factor` (default 2.5x)
- **Ease factor**: Increases slightly with each review (minimum 1.3)
- **Maximum interval**: 180 days (≈6 months)

## Troubleshooting

### No popup appears
- Make sure `notify-send` is installed: `sudo apt install libnotify-bin`
- Check that desktop notifications are enabled in your system settings

### Words don't appear in review
- The app shows words that are due for review (based on interval)
- Make sure your target language matches the translations you want to review

### Icons not showing
- If tray icon or popup icon doesn't appear, check file permissions on `icons/` folder
