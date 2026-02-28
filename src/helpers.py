#!/usr/bin/env python3
"""Shared helpers for CLI and GUI."""

import os
import subprocess


# Module-level icon path
ICON_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons", "translate.svg")


def notify_cli(body, title="Vocab"):
    """Send notification - uses libnotify via subprocess."""
    args = ["notify-send", "-u", "low", title, body]
    if os.path.exists(ICON_PATH):
        args[1:1] = ["-i", ICON_PATH]
    subprocess.run(args, check=False)


def get_clipboard_text() -> str:
    """Get text from primary selection (highlighted text) or clipboard."""
    # Primary selection first
    try:
        result = os.popen("xclip -o -selection primary 2>/dev/null").read().strip()
        if result:
            return result
    except Exception:
        pass
    
    # Wayland primary selection
    if os.environ.get("WAYLAND_DISPLAY"):
        try:
            result = os.popen("wl-paste -p 2>/dev/null").read().strip()
            if result:
                return result
        except Exception:
            pass
    
    return ""
