# Save Selection Script

A lightweight, cross-platform (X11/Wayland) Bash script to quickly save selected text to a file on Linux. Designed for intelligent deduplication, trimming, and notifications, making it ideal for capturing phrases, ideas, or language learning snippets.

## Features

- Works on X11 and Wayland automatically.
- Deduplicates intelligently:
  - Case-insensitive
  - Ignores leading/trailing whitespace
  - Ignores trivial/very short selections (configurable).
- Desktop notifications for:
  - New phrase saved
  - Duplicate ignored
  - Invalid selection
- Minimal dependencies, fully local, and future-proof.

## Dependencies

**X11:** `xclip`
```bash
sudo apt install xclip
```

**Wayland:** `wl-clipboard`
```bash
sudo apt install wl-clipboard
```

**Notifications:** `notify-send` (usually provided by `libnotify-bin`)
```bash
sudo apt install libnotify-bin
```

## Installation

1. Download or copy the script to your home directory:
   ```bash
   cp save_selection.sh ~/save_selection.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x ~/save_selection.sh
   ```

3. Create the storage file (if it doesn't exist):
   ```bash
   touch ~/saved_phrases.txt
   ```

4. Assign a keyboard shortcut in your desktop environment:
   - **Command:** `/home/yourusername/save_selection.sh`
   - **Shortcut:** e.g., `Ctrl+Alt+S`

## Usage

1. Select text anywhere (browser, terminal, editor, etc.).
2. Press your keyboard shortcut (e.g., `Ctrl+Alt+S`).
3. The selected text is saved to `~/saved_phrases.txt` if it is not a duplicate.
4. Desktop notifications indicate:
   - New phrase saved
   - Duplicate ignored
   - No valid selection

**Notes:**
- Very short selections (less than `MIN_LENGTH`, default 3 characters) are ignored.
- Notifications show a maximum of `MAX_NOTIFY` characters (default 50) for readability.

## Configuration

You can tweak the script by editing the following variables at the top of `save_selection.sh`:

```bash
STORAGE_FILE="$HOME/saved_phrases.txt"  # Path to storage file
MIN_LENGTH=3                            # Minimum length of phrase to save
MAX_NOTIFY=50                           # Max characters shown in notifications
```

## Optional Improvements / Future Enhancements

- Add categories/tags via `dmenu` or `rofi` to organize phrases.
- Maintain a rolling history for undo.
- Export saved phrases to Markdown, Anki, or JSON.
- Auto-copy saved phrase back to clipboard for instant reuse.
- Limit storage file size automatically if it grows too large.
- Add search functionality to quickly find previously saved phrases.
