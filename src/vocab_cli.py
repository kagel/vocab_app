#!/usr/bin/env python3
"""CLI module for vocab app."""

import argparse
import os
import sys

from config import read_config
from db import Database
from helpers import notify_cli, get_clipboard_text
from vocab import VocabService


def run_cli():
    """Handle CLI actions (for desktop hotkeys)."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--save", action="store_true", help="Save word from selection")
    parser.add_argument("--delete", action="store_true", help="Delete current word")
    parser.add_argument("--next", action="store_true", help="Show next word")
    args = parser.parse_args()
    
    if not (args.save or args.delete or args.next):
        return False
    
    # Config file path
    config_file = os.path.expanduser("~/.config/vocab_app/settings")
    config = read_config(config_file)
    custom_data_dir = config.get("data_dir")
    
    # Determine DB path
    default_db_path = os.path.join(os.path.expanduser("~/.local/share/vocab_app"), "vocab.db")
    
    if custom_data_dir:
        custom_db_path = os.path.join(os.path.expanduser(custom_data_dir), "vocab.db")
        if os.path.exists(custom_db_path):
            db_path = custom_db_path
        else:
            db_path = default_db_path
    else:
        db_path = default_db_path
    
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        print("Please run the GUI app first to initialize the database.")
        sys.exit(1)
    
    db = Database(db_path)
    db.connect()
    db.init_languages()
    
    vocab_service = VocabService(db)
    
    def get_lang_abbrev(code):
        lang = db.get_language_by_code(code)
        return lang.abbreviation if lang else code.upper()

    if args.save:
        try:
            result = get_clipboard_text()
            if not result:
                notify_cli("No text selected")
            else:
                phrase = result.strip().lower()
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


if __name__ == "__main__":
    run_cli()
