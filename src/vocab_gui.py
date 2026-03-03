#!/usr/bin/env python3
"""Main vocab GUI application with system tray."""

import os
import sys
import threading
import time

import gi

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3

from constants import CONFIG_FILE, TEMP_PHRASE_FILE
from helpers import notify_cli, init_vocab_service
from windows.stats import StatsWindow
from windows.settings import SettingsWindow
from windows.add_word import AddWordDialog
from windows.word_browser import WordBrowserWindow


class VocabTrayApp:
    """Main application with system tray."""

    def _get_desktop_environment(self) -> str:
        """Detect desktop environment."""
        xdg_current_desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
        if "gnome" in xdg_current_desktop:
            return "gnome"
        if "kde" in xdg_current_desktop or "plasma" in xdg_current_desktop:
            return "kde"
        if "xfce" in xdg_current_desktop:
            return "xfce"
        if "ubuntu" in xdg_current_desktop:
            return "ubuntu"
        return "unknown"

    def __init__(self):
        # Config file path
        self.config_file = CONFIG_FILE
        
        # Initialize services
        self.vocab_service = init_vocab_service(self.config_file)
        if not self.vocab_service:
            error_dialog = Gtk.MessageDialog(
                None,
                Gtk.DialogFlags.DESTROY_WITH_PARENT,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                "Failed to initialize database. Check your settings."
            )
            error_dialog.run()
            sys.exit(1)
        
        # Set default settings if not set
        self._init_default_settings()

        # State
        self.current_word = None
        self.paused_until = 0
        self.running = True
        self.settings_changed = threading.Event()

        # Create indicator with custom icon
        tray_icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons", "tray_text.svg")
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

        # GNOME tray warning (one-time)
        if self._get_desktop_environment() in ("gnome", "ubuntu"):
            if not self.vocab_service.get_setting("gnome_tray_warning_shown"):
                self.notify("GNOME detected. If tray icon is missing, install 'Top Icons' or 'Tray Icons' extension.", "Vocab")
                self.vocab_service.set_setting("gnome_tray_warning_shown", "true")

        # Word of the Day (delayed to not block startup)
        threading.Timer(2.0, self.check_wotd).start()

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
        }
        for key, value in defaults.items():
            if self.vocab_service.get_setting(key) is None:
                self.vocab_service.set_setting(key, value)

    def create_menu(self):
        """Create tray menu."""
        menu = Gtk.Menu()

        # Show next word
        next_item = Gtk.MenuItem(label="Show next word")
        next_item.connect("activate", self.on_show_next)
        menu.append(next_item)

        # Pause
        self.pause_item = Gtk.MenuItem(label="Pause (1 hour)")
        self.pause_item.connect("activate", self.on_pause)
        menu.append(self.pause_item)

        # Separator
        sep1 = Gtk.MenuItem(label="───────────")
        sep1.set_sensitive(False)
        menu.append(sep1)

        # Add word
        add_item = Gtk.MenuItem(label="Add word")
        add_item.connect("activate", self.on_add_word)
        menu.append(add_item)

        # Word Browser
        browser_item = Gtk.MenuItem(label="Word Browser")
        browser_item.connect("activate", self.on_word_browser)
        menu.append(browser_item)

        # Stats
        stats_item = Gtk.MenuItem(label="Stats")
        stats_item.connect("activate", self.on_show_stats)
        menu.append(stats_item)

        # Settings
        settings_item = Gtk.MenuItem(label="Settings")
        settings_item.connect("activate", self.on_settings)
        menu.append(settings_item)

        # Separator
        sep2 = Gtk.MenuItem(label="───────────")
        sep2.set_sensitive(False)
        menu.append(sep2)

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
        body = self.vocab_service.get_next_word_notification()
        if body:
            self.notify(body)

    def check_wotd(self):
        """Check and show Word of the Day if enabled."""
        try:
            wotd = self.vocab_service.get_word_of_the_day()
            if wotd:
                result, success = self.vocab_service.save_wotd_to_vocab(wotd['word'], wotd['translation'])
                if success:
                    body = f"<b>{wotd['word']}</b> [{wotd['level']}]\n→ {wotd['translation']}\n\nSaved to your words!"
                else:
                    body = f"<b>{wotd['word']}</b> [{wotd['level']}]\n→ {wotd['translation']}"
                self.notify(body, "Word of the Day")
        except Exception as e:
            print(f"WOTD error: {e}")
        finally:
            self.vocab_service.remove_session()

    def get_current_phrase(self):
        """Get current word from temp file or memory."""
        temp_file = TEMP_PHRASE_FILE
        if os.path.exists(temp_file):
            with open(temp_file) as f:
                return f.read().strip()
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
        win = SettingsWindow(self.vocab_service, config_file=self.config_file)
        win.show_all()

    def on_word_browser(self, widget):
        """Show word browser window."""
        win = WordBrowserWindow(self.vocab_service)
        win.show_all()

    def on_quit(self, widget):
        """Quit application."""
        self.running = False
        self.vocab_service.close()
        Gtk.main_quit()


def main():
    """Main entry point - GUI only."""
    app = VocabTrayApp()
    Gtk.main()


if __name__ == "__main__":
    main()
