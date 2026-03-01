#!/usr/bin/env python3
"""Application constants."""

import os

# App info
APP_NAME = "vocab_app"

# Default data directory
DEFAULT_DATA_DIR = os.path.expanduser("~/.local/share/vocab_app")

# Config directory and file
CONFIG_DIR = os.path.expanduser("~/.config/vocab_app")
CONFIG_FILE = os.path.join(CONFIG_DIR, "settings")

# Database
DEFAULT_DB_PATH = os.path.join(DEFAULT_DATA_DIR, "vocab.db")
DB_FILENAME = "vocab.db"

# Temp files
TEMP_PHRASE_FILE = "/tmp/last_vocab_phrase"

# Autostart
AUTOSTART_DIR = os.path.expanduser("~/.config/autostart")
AUTOSTART_FILE = os.path.join(AUTOSTART_DIR, f"{APP_NAME}.desktop")

# Icon directory (relative to src/)
ICON_DIR = "icons"
