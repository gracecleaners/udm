"""Server adapter for the HelloAO Free Use Bible API.

The app consumes the ministry's stable Bible endpoints. This module translates
HelloAO's catalog and chapter JSON into the database-friendly shapes those
endpoints already use, while only exposing English-language translations.
"""

from __future__ import annotations

import json
import re
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from django.core.cache import cache

BASE_URL = "https://bible.helloao.org/api"
TIMEOUT_SECONDS = 18
USER_AGENT = "UDM Bible reader (HelloAO Free Use Bible API)"
_IDENTIFIER = re.compile(r"^[A-Za-z0-9_.-]{1,40}$")


class HelloAOError(Exception):
    """The HelloAO API could not return usable Bible data."""


def _fetch_json(path: str, *, cache_seconds: int) -> dict:
    if not path.startswith("/") or ".." in path:
        raise HelloAOError("Invalid HelloAO Bible API path.")
    key = f"helloao:{path}"
    cached = cache.get(key)
    if cached is not None:
        return cached
    request = Request(
        f"{BASE_URL}{path}",
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
    )
    try:
        with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        if exc.code == 404:
            raise HelloAOError("That English translation or Bible chapter is unavailable.") from exc
        raise HelloAOError(f"HelloAO returned HTTP {exc.code}.") from exc
    except (TimeoutError, URLError, OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise HelloAOError("HelloAO is temporarily unavailable. Please retry shortly.") from exc
    if not isinstance(payload, dict):
        raise HelloAOError("HelloAO returned an unexpected JSON response.")
    cache.set(key, payload, cache_seconds)
    return payload


def _normalize_translation(row: dict) -> dict | None:
    identifier = row.get("id")
    language = str(row.get("language", "")).strip().lower()
    if not isinstance(identifier, str) or not _IDENTIFIER.fullmatch(identifier):
        return None
    # HelloAO documents `language` as an ISO 639-3 code. `eng` is English;
    # filtering here prevents other languages from ever being offered in UDM.
    if language != "eng" or "json" not in (row.get("availableFormats") or []):
        return None
    name = str(row.get("englishName") or row.get("name") or identifier)
    license_url = str(row.get("licenseUrl") or row.get("website") or "")
    notice = str(row.get("licenseNotice") or "").strip()
    notes = str(row.get("licenseNotes") or "").strip()
    license_data = row.get("license") if isinstance(row.get("license"), dict) else {}
    if license_data.get("publicDomain"):
        license_name = "Public domain"
    elif license_data:
        license_name = "See translation license"
    else:
        license_name = "See publisher license"
    attribution = notice or name
    if notes:
        attribution = f"{attribution} {notes}"
    return {
        # Lowercase stable codes keep existing KJV selections/bookmark lookups
        # compatible; the API adapter restores the provider ID when fetching.
        "code": identifier.lower(),
        "provider_id": identifier,
        "name": name,
        "language": "English",
        "license_name": license_name,
        "attribution": attribution,
        "source_url": license_url,
        "offline_allowed": True,
        "source_provider": "helloao",
        "language_code": "eng",
    }


def available_translations() -> list[dict]:
    payload = _fetch_json("/available_translations.json", cache_seconds=60 * 60)
    rows = payload.get("translations")
    if not isinstance(rows, list):
        raise HelloAOError("HelloAO returned an invalid translation catalog.")
    translations = [
        normalized
        for row in rows
        if isinstance(row, dict)
        if (normalized := _normalize_translation(row)) is not None
    ]
    translations.sort(key=lambda row: (row["name"].casefold(), row["code"]))
    return translations


def _provider_translation_id(code: str) -> str:
    wanted = str(code).casefold()
    if not _IDENTIFIER.fullmatch(wanted):
        raise HelloAOError("Invalid HelloAO translation identifier.")
    row = next((item for item in available_translations() if item["code"] == wanted), None)
    if row is None:
        raise HelloAOError("Only English HelloAO translations are available.")
    return row["provider_id"]


def translation_books(code: str, *, provider_id: str = "") -> tuple[dict, list[dict]]:
    if not _IDENTIFIER.fullmatch(code):
        raise HelloAOError("Invalid HelloAO translation identifier.")
    api_id = quote(provider_id or _provider_translation_id(code), safe="")
    payload = _fetch_json(f"/{api_id}/books.json", cache_seconds=6 * 60 * 60)
    metadata = _normalize_translation(payload.get("translation", {}))
    rows = payload.get("books")
    if metadata is None or metadata["code"] != code.casefold() or not isinstance(rows, list):
        raise HelloAOError("HelloAO returned an invalid English Bible index.")
    cleaned = []
    for row in rows:
        if not isinstance(row, dict) or not _IDENTIFIER.fullmatch(str(row.get("id", ""))):
            continue
        start = row.get("firstChapterNumber")
        end = row.get("lastChapterNumber")
        if not isinstance(start, int) or not isinstance(end, int) or end < start:
            continue
        cleaned.append({
            "id": str(row["id"]),
            "name": str(row.get("commonName") or row.get("name") or row["id"]),
            "order": int(row.get("order") or len(cleaned) + 1),
            "testament": "old",
            "chapters": list(range(start, end + 1)),
        })
    cleaned.sort(key=lambda row: row["order"])
    matthew = next((row["order"] for row in cleaned if row["id"].upper() == "MAT"), None)
    if matthew is not None:
        for row in cleaned:
            row["testament"] = "new" if row["order"] >= matthew else "old"
    return metadata, cleaned


def _verse_text(content) -> str:
    pieces = []
    for piece in content if isinstance(content, list) else []:
        if isinstance(piece, str):
            pieces.append(piece)
        elif isinstance(piece, dict):
            text = piece.get("text")
            if isinstance(text, str):
                pieces.append(text)
            heading = piece.get("heading")
            if isinstance(heading, str):
                pieces.append(heading)
            if piece.get("lineBreak"):
                pieces.append("\n")
    return "".join(pieces).strip()


def translation_chapter(
    code: str, book: str, chapter: int, *, provider_id: str = ""
) -> dict:
    if not _IDENTIFIER.fullmatch(code) or not _IDENTIFIER.fullmatch(book) or chapter < 1:
        raise HelloAOError("Invalid HelloAO chapter reference.")
    translation_id = quote(provider_id or _provider_translation_id(code), safe="")
    book_id = quote(book, safe="")
    payload = _fetch_json(
        f"/{translation_id}/{book_id}/{chapter}.json", cache_seconds=24 * 60 * 60
    )
    metadata = _normalize_translation(payload.get("translation", {}))
    if metadata is None or metadata["code"] != code.casefold():
        raise HelloAOError("Only English HelloAO translations are available.")
    book_data = payload.get("book") if isinstance(payload.get("book"), dict) else {}
    chapter_data = payload.get("chapter") if isinstance(payload.get("chapter"), dict) else {}
    content = chapter_data.get("content")
    if not isinstance(content, list):
        raise HelloAOError("HelloAO returned an invalid chapter.")
    verses = []
    for row in content:
        if not isinstance(row, dict) or row.get("type") != "verse":
            continue
        number = row.get("number")
        text = _verse_text(row.get("content"))
        if isinstance(number, int) and text:
            verses.append({"number": number, "text": text})
    if not verses:
        raise HelloAOError("HelloAO returned no verse text for that chapter.")
    return {
        "book_id": book,
        "book_name": str(book_data.get("commonName") or book_data.get("name") or book),
        "number": int(chapter_data.get("number") or chapter),
        "verses": verses,
    }
