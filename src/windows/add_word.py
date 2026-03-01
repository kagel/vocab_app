#!/usr/bin/env python3
"""Add word dialog."""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

from constants import TEMP_PHRASE_FILE


class AddWordDialog(Gtk.Window):
    """Add word dialog."""

    def __init__(self, vocab_service, on_add=None):
        super().__init__(title="Add New Word")
        self.vocab_service = vocab_service
        self.on_add = on_add
        self.set_default_size(400, 280)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.build_ui()

    def build_ui(self):
        """Build the UI."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_left(20)
        box.set_margin_right(20)
        self.add(box)

        # Get current target language
        settings = self.vocab_service.get_settings()
        target_lang = settings.get("target_lang", "ru")
        
        # Find language object
        languages = self.vocab_service.get_languages()
        current_language = None
        for lang in languages:
            if lang.code == target_lang:
                current_language = lang
                break
        
        lang_name = current_language.name if current_language else target_lang
        lang_abbrev = current_language.abbreviation if current_language else target_lang.upper()

        # Language info label
        lang_label = Gtk.Label(f"Translation target: {lang_name} ({lang_abbrev})")
        lang_label.set_xalign(0)
        box.pack_start(lang_label, False, False, 0)

        # Word entry
        box.pack_start(Gtk.Label("Word/Phrase:"), False, False, 0)
        self.word_entry = Gtk.Entry()
        self.word_entry.set_placeholder_text("Enter word or phrase")
        box.pack_start(self.word_entry, False, False, 0)

        # Translation entry
        box.pack_start(Gtk.Label(f"Translation ({lang_abbrev}):"), False, False, 0)
        self.translation_entry = Gtk.Entry()
        self.translation_entry.set_placeholder_text("Leave empty to auto-translate")
        box.pack_start(self.translation_entry, False, False, 0)

        # Buttons
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btn_box.set_homogeneous(True)

        cancel_btn = Gtk.Button(label="Cancel")
        cancel_btn.connect("clicked", lambda _: self.destroy())
        btn_box.pack_start(cancel_btn, True, True, 0)

        add_btn = Gtk.Button(label="Add")
        add_btn.connect("clicked", self.on_add_clicked)
        btn_box.pack_start(add_btn, True, True, 0)

        translate_btn = Gtk.Button(label="Add & Translate")
        translate_btn.connect("clicked", self.on_add_translate)
        btn_box.pack_start(translate_btn, True, True, 0)

        box.pack_start(btn_box, False, False, 10)

    def on_add_clicked(self, widget):
        """Add word with manual translation (no auto-translate)."""
        word = self.word_entry.get_text().strip()
        if not word:
            return

        translation = self.translation_entry.get_text().strip() or None
        self.vocab_service.add_word(word, translation, auto_translate=False)

        # Save to temp file for --delete hotkey
        with open(TEMP_PHRASE_FILE, "w") as f:
            f.write(word)

        if self.on_add:
            self.on_add(word)
        self.destroy()

    def on_add_translate(self, widget):
        """Add word and auto-translate."""
        word = self.word_entry.get_text().strip()
        if not word:
            return

        self.vocab_service.add_word(word, None, auto_translate=True)

        # Save to temp file for --delete hotkey
        with open(TEMP_PHRASE_FILE, "w") as f:
            f.write(word)

        if self.on_add:
            self.on_add(word)
        self.destroy()
