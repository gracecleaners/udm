"""Server-side adapter for the YouVersion Platform Bible API."""

import json
import os
import re
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.core.cache import cache

BASE_URL = "https://api.youversion.com/v1"
TIMEOUT_SECONDS = 12
ID_PATTERN = re.compile(r"^[A-Za-z0-9_.-]{1,80}$")


class YouVersionError(Exception):
    """The YouVersion API could not return usable JSON."""


def fetch_json(path, *, params=None, cache_seconds=0):
    if not path.startswith("/") or ".." in path:
        raise YouVersionError("Invalid Bible provider path.")
    query = f"?{urlencode(params, doseq=True)}" if params else ""
    cache_key = f"youversion:{path}{query}"
    if cache_seconds:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached
    app_key = os.environ.get("YVP_APP_KEY", "").strip()
    if not app_key:
        raise YouVersionError(
            "YouVersion is not configured. Set YVP_APP_KEY after registering the app and accepting Bible licenses."
        )
    request = Request(
        f"{BASE_URL}{path}{query}",
        headers={"Accept": "application/json", "X-YVP-App-Key": app_key,
                 "User-Agent": "UDM/1.0 Bible reader"},
    )
    try:
        with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        if exc.code == 404:
            raise YouVersionError("That Bible version or passage is not available to this app.") from exc
        if exc.code in (401, 403):
            raise YouVersionError("YouVersion rejected the app key or the app lacks the required Bible license.") from exc
        if exc.code == 429:
            raise YouVersionError("YouVersion rate limited the request. Wait briefly, then retry.") from exc
        if exc.code >= 500:
            raise YouVersionError("YouVersion is temporarily unavailable. Retry in a few minutes.") from exc
        raise YouVersionError(f"YouVersion rejected the request (HTTP {exc.code}).") from exc
    except TimeoutError as exc:
        raise YouVersionError("The request to YouVersion timed out. Check the backend connection and retry.") from exc
    except URLError as exc:
        raise YouVersionError("The backend could not connect to api.youversion.com. Check outbound HTTPS access and retry.") from exc
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise YouVersionError("YouVersion returned an invalid or unreadable response.") from exc
    if not isinstance(payload, dict):
        raise YouVersionError("YouVersion returned an unexpected response.")
    if cache_seconds:
        cache.set(cache_key, payload, cache_seconds)
    return payload


def normalize_translation(row):
    identifier = row.get("id")
    if not isinstance(identifier, (str, int)) or not str(identifier).isdigit():
        return None
    code = str(identifier)
    title = str(row.get("localized_title") or row.get("title") or code)
    language_tag = str(row.get("language_tag") or "")
    language_name = "French" if language_tag.lower().startswith("fr") else (
        "English" if language_tag.lower().startswith("en") else language_tag or "Unknown language"
    )
    copyright_text = str(row.get("copyright") or "").strip()
    publisher_url = str(row.get("publisher_url") or row.get("youversion_deep_link") or "")
    return {
        "id": code, "code": code, "name": title, "language": language_name,
        "language_code": language_tag,
        "license_name": "See publisher copyright and license", 
        "attribution": copyright_text or title,
        "source_url": publisher_url, "offline_allowed": False,
        "source_provider": "youversion", "number_of_books": len(row.get("books") or []),
    }


def available_translations(language_range="en"):
    language_range = str(language_range).lower()
    if language_range not in ("en", "fr"):
        language_range = "en"
    results, token, seen = [], None, set()
    for _ in range(100):
        params = [("language_ranges[]", language_range), ("page_size", 99)]
        if token:
            params.append(("page_token", token))
        payload = fetch_json("/bibles", params=params, cache_seconds=60 * 60)
        rows = payload.get("data")
        if not isinstance(rows, list):
            raise YouVersionError("YouVersion returned an invalid Bible catalog.")
        results.extend(item for row in rows if isinstance(row, dict)
                       for item in [normalize_translation(row)] if item is not None)
        token = payload.get("next_page_token")
        if not token:
            return results
        if token in seen:
            break
        seen.add(token)
    raise YouVersionError("YouVersion Bible catalog pagination did not complete.")


def translation_books(code):
    if not str(code).isdigit():
        raise YouVersionError("Invalid YouVersion Bible identifier.")
    catalog_row = normalize_translation(fetch_json(f"/bibles/{code}", cache_seconds=6 * 60 * 60))
    if catalog_row is None:
        raise YouVersionError("That Bible version is not available to this app.")
    index = fetch_json(f"/bibles/{code}/index", cache_seconds=6 * 60 * 60)
    rows = index.get("books")
    if not isinstance(rows, list):
        raise YouVersionError("YouVersion returned an invalid Bible index.")
    books = []
    for row in rows:
        if not isinstance(row, dict) or not ID_PATTERN.fullmatch(str(row.get("id", ""))):
            continue
        canon = row.get("canon")
        if canon not in ("old_testament", "new_testament"):
            continue
        chapters = row.get("chapters") if isinstance(row.get("chapters"), list) else []
        books.append({"id": row["id"], "provider_id": row["id"],
                      "name": str(row.get("title") or row["id"]), "order": len(books) + 1,
                      "testament": "old" if canon == "old_testament" else "new",
                      "chapters": [chapter.get("id") for chapter in chapters
                                   if isinstance(chapter, dict) and isinstance(chapter.get("id"), int)]})
    return catalog_row, books


def translation_chapter(code, book, chapter):
    if not str(code).isdigit() or not ID_PATTERN.fullmatch(str(book)) or not isinstance(chapter, int) or chapter < 1:
        raise YouVersionError("Invalid Bible chapter reference.")
    index = fetch_json(f"/bibles/{code}/books/{book}", cache_seconds=6 * 60 * 60)
    chapter_rows = index.get("chapters")
    selected = next((row for row in chapter_rows or []
                     if isinstance(row, dict) and row.get("id") == chapter), None)
    verses = selected.get("verses") if selected else None
    if not isinstance(verses, list) or not verses:
        raise YouVersionError("YouVersion returned no verse index for that chapter.")

    def get_verse(row):
        passage_id = row.get("passage_id")
        if not isinstance(passage_id, str) or not ID_PATTERN.fullmatch(passage_id):
            return None
        payload = fetch_json(f"/bibles/{code}/passages/{passage_id}", params={"format": "text"}, cache_seconds=24 * 60 * 60)
        text = payload.get("content")
        number = row.get("id")
        return {"number": number, "text": text.strip()} if isinstance(number, int) and isinstance(text, str) and text.strip() else None

    with ThreadPoolExecutor(max_workers=8) as pool:
        parsed = list(pool.map(get_verse, verses))
    result = [row for row in parsed if row]
    if not result:
        raise YouVersionError("YouVersion returned no verse text for that chapter.")
    return {"book_id": book, "number": chapter, "verses": result}
