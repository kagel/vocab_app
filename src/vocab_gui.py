#!/usr/bin/env python3
"""Main vocab GUI application with system tray."""

import os
import sys
import threading
import time
import subprocess
import argparse
import pyperclip

from db import Database
from vocab import VocabService


# Module-level icon path for CLI
ICON_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "icons", "translate.svg")

def notify_cli(body, title="Vocab"):
    """Send notification - uses libnotify via subprocess (works on most Linux desktops)."""
    args = ["notify-send", "-u", "low", title, body]
    if os.path.exists(ICON_PATH):
        args[1:1] = ["-i", ICON_PATH]
    subprocess.run(args, check=False)


def run_cli():
    """Handle CLI actions (for desktop hotkeys)."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--save", action="store_true", help="Save word from selection")
    parser.add_argument("--delete", action="store_true", help="Delete current word")
    parser.add_argument("--next", action="store_true", help="Show next word")
    args = parser.parse_args()
    
    if not (args.save or args.delete or args.next):
        return False
    
    default_data_dir = os.path.expanduser("~/.local/share/vocab_app")
    db_path = os.path.join(default_data_dir, "vocab.db")
    
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        print("Please run the GUI app first to initialize the database.")
        sys.exit(1)
    
    db = Database(db_path)
    db.connect()
    db.init_languages()
    
    saved_data_dir = db.get_setting("data_dir")
    if saved_data_dir:
        expanded = os.path.expanduser(saved_data_dir)
        if os.path.exists(os.path.join(expanded, "vocab.db")):
            db_path = os.path.join(expanded, "vocab.db")
            db.close()
            db = Database(db_path)
            db.connect()
    
    vocab_service = VocabService(db)
    
    def get_lang_abbrev(code):
        lang = db.get_language_by_code(code)
        return lang.abbreviation if lang else code.upper()

    if args.save:
        try:
            result = pyperclip.paste().strip()
            
            if result:
                phrase = result.lower().strip()
                if len(phrase) >= 1:
                    success = vocab_service.add_word(phrase)
                    if not success:
                        word = vocab_service.db.get_word_by_phrase(phrase)
                        if word:
                            translation, trans_lang = vocab_service.get_translation_with_lang(word["id"])
                            if translation:
                                abbrev = get_lang_abbrev(trans_lang) if trans_lang else "—"
                                notify_cli(f"<b>{phrase[:20]}</b> → {translation} [{abbrev}]")
                            else:
                                notify_cli(f"Already saved: {phrase[:30]}")
                    else:
                        word = vocab_service.db.get_word_by_phrase(phrase)
                        if word:
                            translation, trans_lang = vocab_service.get_translation_with_lang(word["id"])
                            if translation:
                                abbrev = get_lang_abbrev(trans_lang) if trans_lang else "—"
                                notify_cli(f"<b>{phrase[:20]}</b> → {translation} [{abbrev}]")
                            else:
                                notify_cli(f"Word saved: {phrase[:30]}")
                        else:
                            notify_cli(f"Word saved: {phrase[:30]}")
                else:
                    notify_cli("Word too short (min 1 char)")
            else:
                notify_cli("No text selected")
        except Exception as e:
            notify_cli(f"Error: {e}")
    
    if args.delete:
        temp_file = "/tmp/last_vocab_phrase"
        if os.path.exists(temp_file):
            with open(temp_file) as f:
                phrase = f.read().strip()
            if phrase:
                vocab_service.delete_word(phrase)
                notify_cli(f"Word deleted: {phrase[:30]}")
                os.remove(temp_file)
    
    if args.next:
        word = vocab_service.get_next_word()
        if word:
            translation, trans_lang = vocab_service.get_translation_with_lang(word["id"])
            phrase = word.get("phrase", "")
            interval = word.get("interval_days", 1)
            interval_str = f"{interval} day" if interval == 1 else f"{interval} days"
            abbrev = get_lang_abbrev(trans_lang) if trans_lang else "—"
            body = f"<b>{phrase}</b> [{interval_str}]"
            if translation:
                body += f"\n→ {translation} [{abbrev}]"
            with open("/tmp/last_vocab_phrase", "w") as f:
                f.write(phrase)
            notify_cli(body)
            vocab_service.skip_word(word["id"])
    
    db.close()
    return True

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3

from windows.stats import StatsWindow
from windows.settings import SettingsWindow
from windows.add_word import AddWordDialog


class VocabTrayApp:
    """Main application with system tray."""

    # Default data directory
    DEFAULT_DATA_DIR = os.path.expanduser("~/.local/share/vocab_app")

    def __init__(self):
        # Initialize database
        self.data_dir = self.DEFAULT_DATA_DIR
        os.makedirs(self.data_dir, exist_ok=True)
        db_path = os.path.join(self.data_dir, "vocab.db")

        self.db = Database(db_path)
        self.db.connect()
        self.db.init_schema()

        # Set default settings if not set
        self._init_default_settings()

        # Initialize services
        self.vocab_service = VocabService(self.db)

        # State
        self.current_word = None
        self.paused_until = 0
        self.running = True
        self.settings_changed = threading.Event()

        # Create indicator with custom icon
        tray_icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons", "tray.svg")
        self.indicator = AppIndicator3.Indicator.new(
            "vocab-app",
            tray_icon_path if os.path.exists(tray_icon_path) else "dialog-information",
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.create_menu())

        # Start review loop
        self.review_thread = threading.Thread(target=self.review_loop, daemon=True)
        self.review_thread.start()

    def notify(self, body, title="Vocab"):
        """Send notification with icon."""
        notify_cli(body, title)

    def _init_default_settings(self):
        """Initialize default settings if not set."""
        defaults = {
            "review_interval": "3600",
            "target_lang": "ru",
            "translation_provider": "google",
            "autostart": "false",
            "data_dir": "",
        }
        for key, value in defaults.items():
            if self.db.get_setting(key) is None:
                self.db.set_setting(key, value)

    def create_menu(self):
        """Create tray menu."""
        menu = Gtk.Menu()

        # Show next word
        next_item = Gtk.MenuItem(label="Show Next Word")
        next_item.connect("activate", self.on_show_next)
        menu.append(next_item)

        # Today's stats
        stats_item = Gtk.MenuItem(label="Stats")
        stats_item.connect("activate", self.on_show_stats)
        menu.append(stats_item)

        # Add word
        add_item = Gtk.MenuItem(label="Add Word")
        add_item.connect("activate", self.on_add_word)
        menu.append(add_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Pause
        self.pause_item = Gtk.MenuItem(label="Pause (1 hour)")
        self.pause_item.connect("activate", self.on_pause)
        menu.append(self.pause_item)

        # Settings
        settings_item = Gtk.MenuItem(label="Settings")
        settings_item.connect("activate", self.on_settings)
        menu.append(settings_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Quit
        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect("activate", self.on_quit)
        menu.append(quit_item)

        menu.show_all()
        return menu

    def review_loop(self):
        """Background review loop."""
        while self.running:
            try:
                # Reload settings each iteration to pick up changes
                settings = self.vocab_service.get_settings()
                interval = int(settings.get("review_interval", 3600))

                # Check if paused
                if time.time() < self.paused_until:
                    self.settings_changed.wait(60)
                    continue

                # Get next word
                word = self.vocab_service.get_next_word()
                if word:
                    self.current_word = word
                    self.show_word_popup(word)
                    # Wait for interval, but check every minute for settings changes
                    for _ in range(interval // 60):
                        if not self.running:
                            break
                        self.settings_changed.wait(60)
                        self.settings_changed.clear()
                else:
                    # No words due, check again in 5 minutes
                    self.settings_changed.wait(300)
                    self.settings_changed.clear()

            except Exception as e:
                print(f"Review loop error: {e}")
                self.settings_changed.wait(60)

    def show_word_popup(self, word):
        """Show word popup notification."""
        phrase = word.get("phrase", "")
        interval = word.get("interval_days", 1)

        # Format interval
        if interval == 1:
            interval_str = "1 day"
        elif interval < 30:
            interval_str = f"{interval} days"
        elif interval < 365:
            interval_str = f"{interval // 30} mo"
        else:
            interval_str = f"{interval // 365} yr"

        # Get translation for current target language
        settings = self.vocab_service.get_settings()
        target_lang = settings.get("target_lang", "ru")
        translation = self.vocab_service.get_translation(word["id"])
        
        # Get language abbreviation from vocab_service
        languages = self.vocab_service.get_languages()
        lang_abbrev_str = target_lang.upper()
        for lang in languages:
            if lang.code == target_lang:
                lang_abbrev_str = lang.abbreviation
                break

        # Show notification
        body = f"<b>{phrase}</b> [{interval_str}]"
        if translation:
            body += f"\n→ {translation} [{lang_abbrev_str}]"

        # Save to temp file for --delete hotkey
        with open("/tmp/last_vocab_phrase", "w") as f:
            f.write(phrase)

        # Use notify for popup
        self.notify(body)

        # Skip word after showing
        self.vocab_service.skip_word(word["id"])

    def get_current_phrase(self):
        """Get current word from temp file or memory."""
        # Try temp file first (for CLI compatibility)
        temp_file = "/tmp/last_vocab_phrase"
        if os.path.exists(temp_file):
            with open(temp_file) as f:
                return f.read().strip()

        # Fall back to current word
        return self.current_word.get("phrase") if self.current_word else None

    # Menu handlers
    def on_show_next(self, widget):
        """Show next word immediately."""
        word = self.vocab_service.get_next_word()
        if word:
            self.current_word = word
            self.show_word_popup(word)
            self.indicator.set_label(str(word.get("phrase", ""))[:20], "vocab-app")

    def on_show_stats(self, widget):
        """Show stats window."""
        win = StatsWindow(self.vocab_service)
        win.show_all()

    def on_add_word(self, widget):
        """Show add word dialog."""
        def on_add(word):
            self.indicator.set_label(word[:20], "vocab-app")

        win = AddWordDialog(self.vocab_service, on_add)
        win.show_all()

    def on_pause(self, widget):
        """Pause reviews for 1 hour."""
        self.paused_until = time.time() + 3600
        self.pause_item.set_label("Resume")
        self.pause_item.disconnect_by_func(self.on_pause)
        self.pause_item.connect("activate", self.on_resume)

    def on_resume(self, widget):
        """Resume reviews."""
        self.paused_until = 0
        self.pause_item.set_label("Pause (1 hour)")
        self.pause_item.disconnect_by_func(self.on_resume)
        self.pause_item.connect("activate", self.on_pause)

    def on_settings(self, widget):
        """Show settings window."""
        win = SettingsWindow(self.vocab_service)
        win.show_all()

    def on_quit(self, widget):
        """Quit application."""
        self.running = False
        self.db.close()
        Gtk.main_quit()


def main():
    """Main entry point."""
    if run_cli():
        return
    
    app = VocabTrayApp()
    Gtk.main()


if __name__ == "__main__":
    main()
