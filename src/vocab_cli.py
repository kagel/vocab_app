#!/usr/bin/env python3
"""CLI module for vocab app."""

import argparse
import os
import sys

from constants import CONFIG_FILE, TEMP_PHRASE_FILE
from helpers import notify_cli, get_clipboard_text, init_vocab_service


def run_cli():
    """Handle CLI actions (for desktop hotkeys)."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--save", action="store_true", help="Save word from selection")
    parser.add_argument("--delete", action="store_true", help="Delete current word")
    parser.add_argument("--next", action="store_true", help="Show next word")
    args = parser.parse_args()
    
    if not (args.save or args.delete or args.next):
        return False
    
    vocab_service = init_vocab_service(CONFIG_FILE, must_exist=True)
    if not vocab_service:
        sys.exit(1)
    
    if args.save:
        try:
            result = get_clipboard_text()
            if not result:
                notify_cli("No text selected")
            else:
                phrase = result.strip().lower()
                if len(phrase) >= 1:
                    word = vocab_service.add_word(phrase, auto_translate=True)
                    
                    if word:
                        translation, trans_lang = vocab_service.get_translation_with_lang(word["id"])
                        if translation:
                            abbrev = vocab_service.get_language_abbreviation(trans_lang) if trans_lang else "—"
                            notify_cli(f"<b>{phrase[:20]}</b> → {translation} [{abbrev}]")
                        else:
                            notify_cli(f"Word saved: {phrase[:30]}")
                        
                        # Save to temp file for --delete hotkey
                        with open(TEMP_PHRASE_FILE, "w") as f:
                            f.write(phrase)
                else:
                    notify_cli("Word too short (min 1 char)")
        except Exception as e:
            notify_cli(f"Error: {e}")
    
    if args.delete:
        temp_file = TEMP_PHRASE_FILE
        if os.path.exists(temp_file):
            with open(temp_file) as f:
                phrase = f.read().strip()
            if phrase:
                vocab_service.delete_word(phrase)
                notify_cli(f"Word deleted: {phrase[:30]}")
                os.remove(temp_file)
    
    if args.next:
        body = vocab_service.get_next_word_notification()
        if body:
            notify_cli(body)
    
    vocab_service.close()
    return True


if __name__ == "__main__":
    run_cli()
