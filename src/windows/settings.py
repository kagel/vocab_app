#!/usr/bin/env python3
"""Settings window."""

import os

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

from translate import ProviderRegistry


class SettingsWindow(Gtk.Window):
    """Settings window."""

    def __init__(self, vocab_service, on_save=None):
        super().__init__(title="Settings")
        self.vocab_service = vocab_service
        self.on_save = on_save
        self.set_default_size(550, 840)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.recording_key = None

        self.build_ui()

    def build_ui(self):
        """Build the UI."""
        scroll = Gtk.ScrolledWindow()
        self.add(scroll)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_left(20)
        box.set_margin_right(20)
        scroll.add(box)

        # Review settings
        section = self._make_section("REVIEW")
        box.pack_start(section, False, False, 0)

        # Interval
        interval_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        interval_box.pack_start(Gtk.Label("Review Interval:"), False, False, 0)
        self.interval_combo = Gtk.ComboBoxText()
        intervals = [
            ("1800", "30 minutes"),
            ("3600", "1 hour"),
            ("7200", "2 hours"),
            ("14400", "4 hours"),
            ("28800", "8 hours"),
        ]
        for value, label in intervals:
            self.interval_combo.append(value, label)
        current_interval = str(self.vocab_service.get_settings().get("review_interval", "3600"))
        self.interval_combo.set_active_id(current_interval)
        interval_box.pack_end(self.interval_combo, False, False, 0)
        box.pack_start(interval_box, False, False, 0)

        # Translation settings
        section = self._make_section("TRANSLATION")
        box.pack_start(section, False, False, 0)

        # Provider
        provider_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        provider_box.pack_start(Gtk.Label("Dictionary/API:"), False, False, 0)
        self.provider_combo = Gtk.ComboBoxText()
        for provider, name in ProviderRegistry.list_providers():
            self.provider_combo.append(provider, name)
        current_provider = self.vocab_service.get_settings().get("translation_provider", "google")
        self.provider_combo.set_active_id(current_provider)
        provider_box.pack_end(self.provider_combo, False, False, 0)
        box.pack_start(provider_box, False, False, 0)

        # Target language
        lang_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lang_box.pack_start(Gtk.Label("Target Language:"), False, False, 0)
        self.lang_combo = Gtk.ComboBoxText()
        for lang in self.vocab_service.get_languages():
            self.lang_combo.append(lang.code, lang.name)
        current_lang = self.vocab_service.get_settings().get("target_lang", "ru")
        self.lang_combo.set_active_id(current_lang)
        lang_box.pack_end(self.lang_combo, False, False, 0)
        box.pack_start(lang_box, False, False, 0)

        # Test API button
        test_btn = Gtk.Button(label="Test API")
        test_btn.connect("clicked", self.on_test_api)
        box.pack_start(test_btn, False, False, 0)

        # Keyboard shortcuts
        section = self._make_section("KEYBOARD SHORTCUTS")
        box.pack_start(section, False, False, 0)

        # Info label
        info_label = Gtk.Label("Hotkeys work best when configured in XFCE:\nSettings → Keyboard → Application Shortcuts.\n\nCommands:")
        info_label.set_xalign(0)
        info_label.set_line_wrap(True)
        box.pack_start(info_label, False, False, 0)

        # Commands info
        gui_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "vocab_gui.py")
        cmds_label = Gtk.Label(f"Save selected:   python3 {gui_path} --save\nDelete current: python3 {gui_path} --delete\nShow next:      python3 {gui_path} --next")
        cmds_label.set_xalign(0)
        cmds_label.set_line_wrap(True)
        cmds_label.set_selectable(True)
        box.pack_start(cmds_label, False, False, 0)

        # Startup settings
        section = self._make_section("STARTUP")
        box.pack_start(section, False, False, 0)

        self.autostart_check = Gtk.CheckButton(label="Start with system login")
        # Check both DB setting and actual file existence
        desktop_file = os.path.expanduser("~/.config/autostart/vocab_app.desktop")
        autostart = os.path.exists(desktop_file)
        self.autostart_check.set_active(autostart)
        box.pack_start(self.autostart_check, False, False, 0)

        # Data directory
        section = self._make_section("DATA")
        box.pack_start(section, False, False, 0)

        hint_label = Gtk.Label("Leave empty to use default: ~/.local/share/vocab_app")
        hint_label.set_xalign(0)
        hint_label.set_line_wrap(True)
        box.pack_start(hint_label, False, False, 0)

        data_dir = self.vocab_service.get_settings().get("data_dir", "")
        dir_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        dir_box.pack_start(Gtk.Label("Custom Path:"), False, False, 0)
        self.data_dir_entry = Gtk.Entry()
        self.data_dir_entry.set_text(data_dir)
        dir_box.pack_end(self.data_dir_entry, True, True, 0)
        box.pack_start(dir_box, False, False, 0)

        # Buttons
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        cancel_btn = Gtk.Button(label="Cancel")
        cancel_btn.connect("clicked", lambda _: self.destroy())
        btn_box.pack_start(cancel_btn, True, True, 0)

        save_btn = Gtk.Button(label="Save Settings")
        save_btn.connect("clicked", self.on_save_settings)
        btn_box.pack_start(save_btn, True, True, 0)

        box.pack_start(btn_box, False, False, 10)

    def _make_section(self, title: str) -> Gtk.Label:
        """Make a section header."""
        label = Gtk.Label()
        label.set_markup(f"<b>{title}</b>")
        label.set_xalign(0)
        return label

    def on_test_api(self, widget):
        """Test translation API."""
        self.vocab_service.db.set_setting("translation_provider", self.provider_combo.get_active_id())
        self.vocab_service.db.set_setting("target_lang", self.lang_combo.get_active_id())

        success = self.vocab_service.test_translation_api()

        msg = Gtk.MessageDialog(
            self,
            Gtk.DialogFlags.DESTROY_WITH_PARENT,
            Gtk.MessageType.INFO if success else Gtk.MessageType.ERROR,
            Gtk.ButtonsType.OK,
            "API Test Successful!" if success else "API Test Failed!"
        )
        msg.run()
        msg.destroy()

    def on_save_settings(self, widget):
        """Save settings."""
        settings = {
            "review_interval": self.interval_combo.get_active_id(),
            "translation_provider": self.provider_combo.get_active_id(),
            "target_lang": self.lang_combo.get_active_id(),
            "autostart": "true" if self.autostart_check.get_active() else "false",
            "data_dir": self.data_dir_entry.get_text(),
        }

        self.vocab_service.save_settings(settings)

        if self.on_save:
            self.on_save(settings)

        # Show confirmation
        msg = Gtk.MessageDialog(
            self,
            Gtk.DialogFlags.DESTROY_WITH_PARENT,
            Gtk.MessageType.INFO,
            Gtk.ButtonsType.OK,
            "Settings saved successfully!"
        )
        msg.run()
        msg.destroy()
