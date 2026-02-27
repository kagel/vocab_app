#!/usr/bin/env python3
"""Translation providers."""

from abc import ABC, abstractmethod
import requests


class TranslationProvider(ABC):
    """Abstract base class for translation providers."""

    @abstractmethod
    def translate(self, text: str, target_lang: str = "ru") -> str:
        """Translate text to target language."""
        pass

    @abstractmethod
    def get_name(self) -> str:
        """Return provider display name."""
        pass


class GoogleTranslate(TranslationProvider):
    """Google Translate provider."""

    def __init__(self):
        self.base_url = "https://translate.googleapis.com/translate_a/single"

    def translate(self, text: str, target_lang: str = "ru") -> str:
        """Translate text using Google Translate."""
        try:
            response = requests.get(
                self.base_url,
                params={
                    "client": "gtx",
                    "sl": "en",
                    "tl": target_lang,
                    "dt": "t",
                    "q": text,
                },
                timeout=12,
            )
            response.raise_for_status()
            data = response.json()

            if data and data[0]:
                for item in data[0]:
                    if item[0]:
                        return item[0].strip()

            return ""
        except Exception as e:
            print(f"Translation error: {e}")
            return ""

    def get_name(self) -> str:
        return "Google Translate"


class ProviderRegistry:
    """Registry of translation providers."""

    _providers = {
        "google": GoogleTranslate,
    }

    @classmethod
    def get(cls, provider_name: str) -> TranslationProvider:
        """Get provider by name."""
        provider_class = cls._providers.get(provider_name)
        if provider_class:
            return provider_class()
        return GoogleTranslate()  # Default

    @classmethod
    def list_providers(cls) -> list:
        """List available providers."""
        return [
            (name, cls.get(name).get_name())
            for name in cls._providers.keys()
        ]
