#!/usr/bin/env python3
"""Main vocab GUI application with system tray."""

import os
import sys
import threading
import time
import tempfile

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3, GLib

from db import Database
from vocab import VocabService
from windows.stats import StatsWindow
from windows.settings import SettingsWindow
from windows.add_word import AddWordDialog


# Module-level icon path for CLI
ICON_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "icons", "translate.svg")

def notify_cli(body, title="Vocab"):
    """Send notification from CLI (without self)."""
    icon_arg = f'-i "{ICON_PATH}"' if os.path.exists(ICON_PATH) else ""
    cmd = f'dbus-launch notify-send {icon_arg} -u low "{title}" "{body}"'
    os.system(cmd)


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

        # Create indicator
        self.indicator = AppIndicator3.Indicator.new(
            "vocab-app",
            "dialog-information",
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
        stats_item = Gtk.MenuItem(label="Today's Stats")
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
                    time.sleep(60)
                    continue

                # Get next word
                word = self.vocab_service.get_next_word()
                if word:
                    self.current_word = word
                    self.show_word_popup(word)

                # Wait for next review
                time.sleep(interval)

            except Exception as e:
                print(f"Review loop error: {e}")
                time.sleep(60)

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
        def on_save(settings):
            pass  # Hotkeys are hardcoded, not configurable in UI

        win = SettingsWindow(self.vocab_service, on_save)
        win.show_all()

    def on_quit(self, widget):
        """Quit application."""
        self.running = False
        self.db.close()
        Gtk.main_quit()


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--save", action="store_true", help="Save word from selection")
    parser.add_argument("--delete", action="store_true", help="Delete current word")
    parser.add_argument("--next", action="store_true", help="Show next word")
    args = parser.parse_args()
    
    # Handle CLI actions (for XFCE hotkeys)
    if args.save or args.delete or args.next:
        # Default data directory
        default_data_dir = os.path.expanduser("~/.local/share/vocab_app")
        db_path = os.path.join(default_data_dir, "vocab.db")
        
        # Check if database exists
        if not os.path.exists(db_path):
            print(f"Error: Database not found at {db_path}")
            print("Please run the GUI app first to initialize the database.")
            sys.exit(1)
        
        db = Database(db_path)
        db.connect()
        db.init_languages()  # Ensure languages are seeded
        
        # Check if custom data_dir is set and use it
        saved_data_dir = db.get_setting("data_dir")
        if saved_data_dir:
            expanded = os.path.expanduser(saved_data_dir)
            if os.path.exists(os.path.join(expanded, "vocab.db")):
                db_path = os.path.join(expanded, "vocab.db")
                db.close()
                db = Database(db_path)
                db.connect()
        
        vocab_service = VocabService(db)
        
        # Language abbreviation helper - get from DB
        def get_lang_abbrev(code):
            lang = db.get_language_by_code(code)
            return lang.abbreviation if lang else code.upper()
        
        target_lang = db.get_setting("target_lang", "ru") or "ru"
        lang_abbrev_str = get_lang_abbrev(target_lang)
        
        if args.save:
            try:
                # Try primary selection first, then clipboard
                result = os.popen("xclip -o -selection primary 2>/dev/null").read().strip()
                if not result:
                    result = os.popen("xclip -o -selection clipboard 2>/dev/null").read().strip()
                if not result and os.environ.get("WAYLAND_DISPLAY"):
                    result = os.popen("wl-paste 2>/dev/null").read().strip()
                
                if result:
                    phrase = result.lower().strip()
                    if len(phrase) >= 3:
                        success = vocab_service.add_word(phrase)
                        if not success:
                            # Word already exists - show "Already saved" with translation
                            word = vocab_service.db.get_word_by_phrase(phrase)
                            if word:
                                translation, trans_lang = vocab_service.get_translation_with_lang(word["id"])
                                if translation:
                                    abbrev = get_lang_abbrev(trans_lang) if trans_lang else "—"
                                    notify_cli(f"<b>{phrase[:20]}</b> → {translation} [{abbrev}]")
                                else:
                                    notify_cli(f"Already saved: {phrase[:30]}")
                        else:
                            # New word added
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
                        notify_cli("Word too short (min 3 chars)")
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
                    # Clear temp file so repeated deletes don't keep deleting same word
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
                # Save for --delete hotkey
                with open("/tmp/last_vocab_phrase", "w") as f:
                    f.write(phrase)
                notify_cli(body)
                vocab_service.skip_word(word["id"])
        
        db.close()
        return
    
    # Normal GUI mode
    app = VocabTrayApp()
    Gtk.main()


if __name__ == "__main__":
    main()
