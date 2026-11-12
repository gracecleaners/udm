"""On-demand translation for backend-managed content."""

import hashlib
from html import unescape
import json
import logging
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger("udm.translation")
_CACHE_SECONDS = 60 * 60 * 24 * 30


def _cache_key(text, target_language):
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return f"udm.translation.v1.{target_language}.{digest}"


def _chunks(texts, max_count=50, max_bytes=24000):
    chunk = []
    byte_count = 0
    for text in texts:
        size = len(text.encode("utf-8"))
        if chunk and (len(chunk) >= max_count or byte_count + size > max_bytes):
            yield chunk
            chunk, byte_count = [], 0
        chunk.append(text)
        byte_count += size
    if chunk:
        yield chunk


def _request_translations(texts, target_language):
    api_key = getattr(settings, "UDM_TRANSLATION_API_KEY", "")
    if not api_key or not texts:
        return None

    url = getattr(settings, "UDM_TRANSLATION_API_URL", "")
    query = urlencode({"key": api_key})
    request = Request(
        f"{url}?{query}",
        data=json.dumps({
            "q": texts,
            "source": "en",
            "target": target_language,
            "format": "text",
        }).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=5) as response:
            payload = json.loads(response.read().decode("utf-8"))
        translations = payload["data"]["translations"]
        if len(translations) != len(texts):
            raise ValueError("Translation provider returned an unexpected result count")
        return [unescape(item["translatedText"]) for item in translations]
    except (HTTPError, URLError, TimeoutError, OSError, ValueError, KeyError, TypeError):
        # The source content remains available if translation is disabled or unavailable.
        logger.warning("Dynamic translation provider request failed; using source text.")
        return None


def translate_strings(texts, target_language="fr"):
    """Translate unique strings in batches, using the configured cache."""
    unique_texts = list(dict.fromkeys(
        text for text in texts if isinstance(text, str) and text.strip()
    ))
    if target_language != "fr" or not unique_texts:
        return {}

    keys = {text: _cache_key(text, target_language) for text in unique_texts}
    cached = cache.get_many(keys.values())
    result = {text: cached[key] for text, key in keys.items() if key in cached}
    missing = [text for text in unique_texts if text not in result]

    for batch in _chunks(missing):
        translated = _request_translations(batch, target_language)
        if translated is None:
            continue
        for source, target in zip(batch, translated):
            if isinstance(target, str) and target.strip():
                result[source] = target
                cache.set(keys[source], target, _CACHE_SECONDS)
    return result


def translate_value(value, target_language="fr"):
    """Translate string values recursively while retaining JSON shape and keys."""
    strings = []

    def collect(item):
        if isinstance(item, str):
            strings.append(item)
        elif isinstance(item, list):
            for child in item:
                collect(child)
        elif isinstance(item, dict):
            for child in item.values():
                collect(child)

    collect(value)
    translated = translate_strings(strings, target_language)

    def replace(item):
        if isinstance(item, str):
            return translated.get(item, item)
        if isinstance(item, list):
            return [replace(child) for child in item]
        if isinstance(item, dict):
            return {key: replace(child) for key, child in item.items()}
        return item

    return replace(value)
