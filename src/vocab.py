#!/usr/bin/env python3
"""Vocabulary service with SM-2 algorithm."""

import os
import time
from typing import Optional
from db import Database
from translate import ProviderRegistry


class VocabService:
    """Vocabulary service with spaced repetition."""

    def __init__(self, db: Database):
        self.db = db

    def get_settings(self) -> dict:
        """Get app settings."""
        return {
            "review_interval": int(self.db.get_setting("review_interval", "3600")),
            "target_lang": self.db.get_setting("target_lang", "ru"),
            "translation_provider": self.db.get_setting("translation_provider", "google"),
        }

    def get_languages(self) -> list:
        """Get all available languages."""
        return self.db.get_all_languages()

    def save_settings(self, settings: dict):
        """Save app settings."""
        for key, value in settings.items():
            self.set_setting(key, str(value))
        
        if "autostart" in settings:
            self._set_autostart(settings["autostart"] == "true")

    def set_setting(self, key: str, value: str):
        """Set a single setting."""
        self.db.set_setting(key, value)

    def get_setting(self, key: str, default: str = None) -> str:
        """Get a single setting."""
        return self.db.get_setting(key, default)

    def _set_autostart(self, enable: bool):
        """Enable or disable autostart."""
        autostart_dir = os.path.expanduser("~/.config/autostart")
        desktop_file = os.path.join(autostart_dir, "vocab_app.desktop")
        
        if enable:
            os.makedirs(autostart_dir, exist_ok=True)
            script_path = os.path.dirname(os.path.abspath(__file__))
            # venv is in project root, not in src/
            venv_python = os.path.join(os.path.dirname(script_path), "venv", "bin", "python3")
            exec_path = os.path.join(script_path, "vocab_gui.py")
            
            if os.path.exists(venv_python):
                python_exec = venv_python
            else:
                python_exec = "python3"
            
            desktop_content = f"""[Desktop Entry]
Type=Application
Name=Vocab App
Exec={python_exec} {exec_path}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
"""
            with open(desktop_file, "w") as f:
                f.write(desktop_content)
        else:
            if os.path.exists(desktop_file):
                os.remove(desktop_file)

    def add_word(self, phrase: str, translation: str = None, auto_translate: bool = False) -> dict:
        """Add a new word or add translation to existing word.
        
        Args:
            phrase: The word/phrase to add
            translation: Optional manual translation
            auto_translate: If True, auto-translate when no translation provided
            
        Returns:
            dict with word info (id, phrase)
        """
        phrase = phrase.strip().lower()

        existing = self.db.get_word_by_phrase(phrase)
        
        if existing:
            # Word exists - add/update translation if provided or auto_translate
            target_lang = self.db.get_setting("target_lang", "ru") or "ru"
            
            if translation:
                self.db.add_translation(existing["id"], translation, target_lang)
            elif auto_translate:
                provider = ProviderRegistry.get(
                    self.db.get_setting("translation_provider", "google") or "google"
                )
                trans = provider.translate(phrase, target_lang)
                if trans:
                    self.db.add_translation(existing["id"], trans, target_lang)
            return existing
        
        # New word
        word_id = self.db.add_word(phrase)

        if translation:
            target_lang = self.db.get_setting("target_lang", "ru") or "ru"
            self.db.add_translation(word_id, translation, target_lang)
        elif auto_translate:
            provider = ProviderRegistry.get(
                self.db.get_setting("translation_provider", "google") or "google"
            )
            target_lang = self.db.get_setting("target_lang", "ru") or "ru"
            trans = provider.translate(phrase, target_lang)
            if trans:
                self.db.add_translation(word_id, trans, target_lang)

        return self.db.get_word_by_phrase(phrase)

    def get_next_word(self) -> Optional[dict]:
        """Get next word due for review with translation in current target language."""
        target_lang = self.db.get_setting("target_lang", "ru") or "ru"
        words = self.db.get_due_words(limit=10, target_lang=target_lang)
        return words[0] if words else None

    def review_word(self, word_id: int, quality: int = 3):
        """Review a word with SM-2 quality rating (0-5).

        Quality values:
        0 - complete blackout
        1 - incorrect response, correct one remembered
        2 - incorrect response, correct one seemed easy
        3 - correct response with serious difficulty
        4 - correct response after hesitation
        5 - perfect response
        """
        stats = self.db.get_word_stats(word_id)

        if stats:
            interval = stats["interval_days"]
            ease = stats["ease_factor"]
            due = stats.get("due_date", 0)
        else:
            interval = 1
            ease = 2.5
            due = 0

        now = int(time.time())

        # SM-2 algorithm
        if quality < 3:
            # Failed - reset interval
            new_interval = 1
            new_ease = max(1.3, ease - 0.2)
        else:
            # Passed - increase interval
            new_ease = ease + 0.1 - (quality - 3) * 0.08
            new_ease = max(1.3, new_ease)

            if due == 0 or now >= due:
                new_interval = int(interval * new_ease * 0.5)
                new_interval = max(1, new_interval)
            else:
                # Normal progression
                new_interval = int(interval * new_ease)
                new_interval = min(new_interval, 180)  # Max 180 days

        new_due = now + new_interval * 86400

        self.db.update_word_stats(word_id, new_interval, new_due, new_ease)
        self.db.record_review(word_id)

    def skip_word(self, word_id: int):
        """Skip word - move to end of queue by updating due date."""
        self.db.record_review(word_id)
        
        # Update due date to push to end of queue (small interval)
        stats = self.db.get_word_stats(word_id)
        if stats:
            current_interval = stats.get("interval_days", 1)
        else:
            current_interval = 1
        
        # Move due date forward by a small amount (10 minutes) to deprioritize
        new_due = int(time.time()) + 600  # 10 minutes from now
        
        self.db.update_word_stats(word_id, current_interval, new_due, stats.get("ease_factor", 2.5) if stats else 2.5)

    def delete_word(self, phrase: str):
        """Delete a word."""
        self.db.delete_word(phrase)

    def get_translation(self, word_id: int) -> Optional[str]:
        """Get translation for a word."""
        target_lang = self.db.get_setting("target_lang", "ru") or "ru"
        return self.db.get_translation(word_id, target_lang)

    def get_translation_with_lang(self, word_id: int) -> tuple[Optional[str], Optional[str]]:
        """Get translation and its language code."""
        target_lang = self.db.get_setting("target_lang", "ru") or "ru"
        translation = self.db.get_translation(word_id, target_lang)
        return translation, target_lang

    def get_stats(self) -> dict:
        """Get statistics."""
        stats = self.db.get_stats()
        stats["streak"] = self.db.get_streak()
        return stats

    def test_translation_api(self) -> bool:
        """Test if translation API works."""
        try:
            provider = ProviderRegistry.get(
                self.db.get_setting("translation_provider", "google")
            )
            result = provider.translate("hello", self.db.get_setting("target_lang", "ru"))
            return bool(result)
        except:
            return False

    def export_csv(self, filepath: str):
        """Export words to CSV."""
        self.db.export_csv(filepath)
