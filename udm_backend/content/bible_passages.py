"""Multi-source Bible passage router with licensing gates and KJV fallback.

One call, one shape, whichever provider answers::

    get_passage("1Jn 3:16", "esv") -> {reference, translation, text, verses,
                                       deep_link_url, attribution, ...}

Four sources are wired, each behind a `Route` in `routing_table()`:

* **bible_api** — KJV, WEB and ASV from bible-api.com. Public domain, no key.
* **esv** — api.esv.org v3, needs `ESV_API_KEY`, counted against its daily quota.
* **nlt** — nlt.to, needs `NLT_API_KEY`. See `_nlt` for why this one is off.
* **bolls_life** — chapter payloads; only reachable for a translation the
  operator has mapped in `UDM_BOLLS_TRANSLATIONS`, which is deliberately empty.

Any failure inside a route (missing key, rejected key, rate limit, timeout,
404, or a publisher that refuses redistribution) falls back to the
public-domain translation while keeping `deep_link_url` pointed at the
translation the caller actually asked for, so the reader can still finish the
verse at an authorized site. Reference spelling never matters: `bible_refs`
folds "1 John 3:16", "1John 3:16" and "1Jn 3:16" to the same request.
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.cache import cache

from .bible_refs import (
    PassageRef,
    bible_gateway_url,
    clean_text,
    parse_reference,
    youversion_url,
)

logger = logging.getLogger("udm.bible")

TIMEOUT_SECONDS = 12
USER_AGENT = "UDM/1.0 Bible reader"
BIBLE_API_BASE = "https://bible-api.com"
ESV_BASE = "https://api.esv.org/v3/passage/text/"
BOLLS_BASE = "https://bolls.life"
CACHE_PREFIX = "bible:passage"

DAY = 24 * 60 * 60
# Public-domain text cannot change, so it is worth holding for a month. Anything
# under a licence is held briefly: the wording is the publisher's, and a stale
# copy of a licensed text is a bigger problem than one extra request.
PUBLIC_DOMAIN_TTL = 30 * DAY
LICENSED_TTL = DAY

# bolls.life serves the NIV as a wall of text explaining that Biblica has
# prohibited its use, with HTTP 200 and a valid verse list, so it has to be
# recognised in the prose rather than in the status code. Verified live on
# 2026-11-11 against /get-text/NIV/43/3/.
_PROHIBITION = re.compile(r"prohibited me from using|may not be redistributed", re.I)


class PassageError(Exception):
    """A translation source could not deliver the requested passage.

    `translation` is filled in by `get_passage` so a view can name the version
    that failed without every raise site repeating it.
    """

    translation = ""


class UnknownTranslation(PassageError):
    """No route exists for that translation code."""


class MissingCredential(PassageError):
    """The route needs an API key that this deployment has not configured."""


class RateLimited(PassageError):
    """This deployment or the provider has run out of requests for now."""


class UpstreamUnavailable(PassageError):
    """The provider could not be reached, or answered with something unusable."""


class PassageNotFound(PassageError):
    """The provider has no text for that passage."""


class TranslationRefused(PassageError):
    """No licensed text source is wired for this translation; deep link only."""


class PassageTooLong(PassageError):
    """The span is wider than the API serves in one call."""


@dataclass(frozen=True)
class Route:
    """How one translation code is served."""

    code: str
    name: str
    provider: str
    provider_id: str
    link_version: str
    attribution: str
    cache_seconds: int = LICENSED_TTL
    offline_allowed: bool = False
    youversion_bible_id: str = ""

    @property
    def text_source_available(self) -> bool:
        return self.provider != "deep_link"


# Codes the reader may ask for, in lower case without punctuation. NIV, NKJV,
# CSB, NASB, MSG and AMP are listed as deep-link-only on purpose: their
# publishers sell licences for app text, bolls.life's copies are scraped, and
# Biblica blocks the NIV there outright. An operator that holds rights maps the
# code to a bolls abbreviation in UDM_BOLLS_TRANSLATIONS and it starts serving.
_BASE_ROUTES: tuple[Route, ...] = (
    Route("kjv", "King James Version", "bible_api", "kjv", "KJV",
          "King James Version (public domain).", PUBLIC_DOMAIN_TTL, True),
    Route("web", "World English Bible", "bible_api", "web", "WEB",
          "World English Bible (public domain).", PUBLIC_DOMAIN_TTL, True),
    Route("asv", "American Standard Version (1901)", "bible_api", "asv", "ASV",
          "American Standard Version (1901, public domain).", PUBLIC_DOMAIN_TTL, True),
    Route("esv", "English Standard Version", "esv", "esv", "ESV",
          "ESV® text © Crossway. Used under the ESV API terms, which limit how "
          "much may be quoted and require this notice to stay with the text."),
    Route("nlt", "New Living Translation", "nlt", "nlt", "NLT",
          "Holy Bible, New Living Translation®, © Tyndale House Foundation. "
          "Used under licence; not redistributable through this API."),
    Route("niv", "New International Version", "deep_link", "", "NIV",
          "NIV text is licensed by Biblica and may not be served from this app. "
          "Open it on an authorised site."),
    Route("nkjv", "New King James Version", "deep_link", "", "NKJV",
          "NKJV text is licensed by Thomas Nelson and may not be served from "
          "this app. Open it on an authorised site."),
    Route("csb", "Christian Standard Bible", "deep_link", "", "CSB",
          "CSB text is licensed by Holman Bible Publishers and may not be "
          "served from this app. Open it on an authorised site."),
    Route("nasb", "New American Standard Bible", "deep_link", "", "NASB",
          "NASB text is licensed by The Lockman Foundation and may not be "
          "served from this app. Open it on an authorised site."),
    Route("msg", "The Message", "deep_link", "", "MSG",
          "The Message is a copyrighted paraphrase (NavPress) and may not be "
          "served from this app. Open it on an authorised site."),
    Route("amp", "Amplified Bible", "deep_link", "", "AMP",
          "The Amplified Bible is licensed by Zondervan and may not be served "
          "from this app. Open it on an authorised site."),
)

# Spellings that are neither a code nor the route's own name.
_CODE_ALIASES = {
    "kingjames": "kjv", "kjv1611": "kjv", "asv1901": "asv",
    "englishstandard": "esv", "esvuk": "esv",
    "nltse": "nlt", "niv11": "niv", "nivuk": "niv",
    "csb17": "csb", "csbslim": "csb", "nasb1995": "nasb", "nasbu": "nasb",
    "message": "msg", "amplified": "amp", "ampclassic": "amp",
}


def normalize_code(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", str(value or "").lower())


def _pairs(raw: str) -> dict[str, str]:
    """Parse `niv:NIV,csb:CSB17` into {niv: NIV, csb: CSB17}."""
    result = {}
    for item in str(raw or "").split(","):
        key, _, value = item.partition(":")
        if key.strip() and value.strip():
            result[normalize_code(key)] = value.strip()
    return result


def routing_table() -> dict[str, Route]:
    """The configured routes, with operator mappings applied on top.

    Rebuilt per call so `override_settings` in tests and a changed `.env` take
    effect without a restart. Twelve entries — cheap, and it keeps this module
    free of import-order problems with Django settings.
    """
    bolls = _pairs(getattr(settings, "UDM_BOLLS_TRANSLATIONS", ""))
    youversion = _pairs(getattr(settings, "UDM_BIBLE_YOUVERSION_IDS", ""))
    routes: dict[str, Route] = {}
    for route in _BASE_ROUTES:
        abbr = bolls.get(route.code)
        if abbr:
            route = Route(
                route.code, route.name, "bolls_life", abbr, route.link_version,
                route.attribution, LICENSED_TTL, False, route.youversion_bible_id,
            )
        bible_id = youversion.get(route.code)
        if bible_id:
            route = Route(
                route.code, route.name, route.provider, route.provider_id,
                route.link_version, route.attribution, route.cache_seconds,
                route.offline_allowed, bible_id,
            )
        routes[route.code] = route
    return routes


def route_is_configured(route: Route) -> bool:
    """False when the route's provider needs a key this deployment lacks.

    A missing key is a supported state, not an error: the router still answers
    with public-domain text and an authorized link. The app uses this to label
    such a translation as unavailable rather than offering it and falling back
    on every request.
    """
    if route.provider == "deep_link":
        return False
    key_name = {"esv": "ESV_API_KEY", "nlt": "NLT_API_KEY"}.get(route.provider)
    return True if key_name is None else bool(str(getattr(settings, key_name, "") or "").strip())


def resolve_route(code: str) -> Route:
    """Look a translation code up, accepting the spellings readers type."""
    routes = routing_table()
    normalized = normalize_code(code) or normalize_code(
        getattr(settings, "UDM_BIBLE_DEFAULT_TRANSLATION", "kjv")
    )
    by_name = {normalize_code(route.name): route.code for route in routes.values()}
    resolved = routes.get(normalized) or routes.get(_CODE_ALIASES.get(normalized, "")) \
        or routes.get(by_name.get(normalized, ""))
    if resolved is None:
        raise UnknownTranslation(
            f"“{code}” is not a translation this app serves. Available: "
            f"{', '.join(sorted(routes))}."
        )
    return resolved


# HTTP ---------------------------------------------------------------------


def _fetch(url: str, *, headers: dict[str, str] | None = None, provider: str = "The provider", expect=list | dict):
    """GET a JSON payload, translating every transport failure into a `PassageError`.

    Nothing here raises to the caller: the router is expected to keep working
    with a key missing and one provider down, so an unhandled error at this
    layer would be the whole resilience story failing.
    """
    request = Request(url, headers={
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
        **(headers or {}),
    })
    try:
        with urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            raw = response.read().decode("utf-8", "replace")
    except HTTPError as exc:
        if exc.code == 404:
            raise PassageNotFound(f"{provider} has no text for that passage.") from exc
        if exc.code == 429:
            raise RateLimited(f"{provider} rate limited the request. Try again in a moment.") from exc
        if exc.code in (401, 403):
            raise MissingCredential(f"{provider} rejected the configured API key.") from exc
        if exc.code >= 500:
            raise UpstreamUnavailable(f"{provider} is temporarily unavailable.") from exc
        raise UpstreamUnavailable(f"{provider} returned HTTP {exc.code}.") from exc
    except (TimeoutError, URLError, OSError) as exc:
        raise UpstreamUnavailable(
            f"{provider} could not be reached. Check the backend connection and retry."
        ) from exc
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        # bible-api answers a bad translation with an nginx HTML page, so a
        # non-JSON body is a normal upstream failure rather than a bug here.
        raise UpstreamUnavailable(f"{provider} returned a response that is not JSON.") from exc
    if not isinstance(payload, expect):
        raise UpstreamUnavailable(f"{provider} returned an unexpected response.")
    return payload


def _verse_rows(ref: PassageRef, rows: list) -> list[dict]:
    """Keep the requested verses of provider rows shaped `{verse, text}`."""
    verses = [
        {"verse": row["verse"], "text": clean_text(row.get("text"))}
        for row in rows
        if isinstance(row, dict) and isinstance(row.get("verse"), int)
        and isinstance(row.get("text"), str) and clean_text(row.get("text"))
    ]
    if ref.verse_start is None:
        return verses
    last = ref.verse_end or ref.verse_start
    return [row for row in verses if ref.verse_start <= row["verse"] <= last]


def _links(ref: PassageRef, route: Route) -> dict:
    """Authorized sites where the requested translation can be read in full.

    BibleGateway's `version` abbreviations are what its own passage pages use
    (checked live for all routed versions on 2026-11-11 — note that NIV is
    “NIV”, not “NV”, which now renders an empty page). The bible.com link only
    appears when an operator names a numeric Bible id in
    `UDM_BIBLE_YOUVERSION_IDS`, because ids are per-app licence, not public.
    """
    return {
        "deep_link_url": bible_gateway_url(ref.reference, route.link_version),
        "alternate_link_url": (
            youversion_url(ref, route.youversion_bible_id) if route.youversion_bible_id else ""
        ),
    }


def _assemble(ref: PassageRef, route: Route, verses: list[dict], *, attribution: str = "") -> dict:
    """The unified passage every caller sees, whatever answered."""
    return {
        "reference": ref.reference,
        "translation": route.code,
        "translation_name": route.name,
        "source": route.provider,
        "text": " ".join(row["text"] for row in verses),
        "verses": verses,
        **_links(ref, route),
        "attribution": attribution or route.attribution,
        "offline_allowed": route.offline_allowed,
        "fallback": None,
    }


# Providers ----------------------------------------------------------------


def _from_bible_api(ref: PassageRef, route: Route) -> dict:
    # The service's own default is WEB, so an unrecognised `translation` must
    # never be mistaken for the version the caller asked for.
    payload = _fetch(
        f"{BIBLE_API_BASE}/{quote(ref.reference.replace(' ', '+'), safe=':+')}"
        f"?translation={quote(route.provider_id)}",
        provider=route.name, expect=dict,
    )
    echoed = str(payload.get("translation_id", "")).casefold()
    if echoed and echoed != route.provider_id:
        raise PassageNotFound(
            f"{route.name} is not available from bible-api.com (it answered with “{echoed}”)."
        )
    verses = _verse_rows(ref, payload.get("verses") or [])
    if not verses:
        raise PassageNotFound(f"{route.name} has no text for {ref.reference}.")
    note = str(payload.get("translation_note") or "").strip()
    name = str(payload.get("translation_name") or route.name).strip()
    return _assemble(ref, route, verses, attribution=f"{name} ({note or 'public domain'}).")


def _from_esv(ref: PassageRef, route: Route) -> dict:
    key = str(getattr(settings, "ESV_API_KEY", "") or "").strip()
    if not key:
        raise MissingCredential(
            "ESV needs ESV_API_KEY. Register at https://www.esv.org/services/ "
            "(free, 5,000 requests a day) and add it to the backend `.env`."
        )
    _consume_esv_quota(route)
    payload = _fetch(
        f"{ESV_BASE}?{urlencode({'q': ref.reference})}",
        headers={"Authorization": f"Token {key}"}, provider=route.name, expect=dict,
    )
    passages = payload.get("passages")
    first = passages[0] if isinstance(passages, list) and passages else {}
    verses = _verse_rows(ref, first.get("verses") or [])
    if not verses:
        # Older payloads carry only paragraphs, each with a verse range and the
        # number printed inside the text; take the range's first verse as the
        # label and drop that leading number from the prose.
        for block in first.get("paragraphs") or []:
            if not isinstance(block, dict):
                continue
            text = clean_text(block.get("text"))
            if not text:
                continue
            match = re.match(r"(\d+)", str(block.get("verses") or ""))
            number = int(match.group(1)) if match else len(verses) + 1
            text = re.sub(rf"^{number}\s*", "", text).strip()
            if text:
                verses.append({"verse": number, "text": text})
        verses = _verse_rows(ref, verses)
    if not verses:
        raise PassageNotFound(f"ESV returned no text for {ref.reference}.")
    return _assemble(ref, route, verses)


def _consume_esv_quota(route: Route) -> None:
    """Short-circuit at the documented 5,000/day before spending a request.

    The counter is advisory: two workers can both pass the check and Crossway's
    own limit still holds, so this exists to stop a runaway client burning the
    day's quota, not to be the authority on it.
    """
    quota = int(getattr(settings, "UDM_ESV_DAILY_QUOTA", 5000) or 0)
    if quota <= 0:
        return
    now = datetime.now(timezone.utc)
    key = f"bible:esv-quota:{now.date().isoformat()}"
    used = cache.get(key)
    used = used if isinstance(used, int) else 0
    if used >= quota:
        raise RateLimited(
            f"the ESV daily quota of {quota:,} requests is used up; it resets at midnight UTC."
        )
    reset = (datetime.combine(now.date() + timedelta(days=1), datetime.min.time(), timezone.utc) - now).seconds + 1
    cache.set(key, used + 1, reset)


def _from_nlt(ref: PassageRef, route: Route) -> dict:
    key = str(getattr(settings, "NLT_API_KEY", "") or "").strip()
    if not key:
        raise MissingCredential(
            "NLT needs NLT_API_KEY and a licensed text source for the New Living "
            "Translation."
        )
    # Verified live on 2026-11-11: the documented https://api.nlt.to/api/text
    # endpoint answers 404 ("No HTTP resource was found") for every parameter
    # spelling, and api.nlt.co fails its TLS handshake. The route therefore only
    # works against an endpoint the operator names in UDM_NLT_API_URL once they
    # hold a working key, and is otherwise unreachable — never assume it is on.
    base = str(getattr(settings, "UDM_NLT_API_URL", "https://api.nlt.to/api/text") or "").strip()
    reference = ref.youversion_passage + (f"-{ref.verse_end}" if ref.verse_end else "")
    payload = _fetch(f"{base}?{urlencode({'key': key, 'ref': reference})}", provider=route.name, expect=(dict, list))
    if isinstance(payload, list):
        rows = [{"verse": number + ref.verse_start if ref.verse_start else number + 1, "text": row}
                for number, row in enumerate(payload) if isinstance(row, str)]
    else:
        rows = payload.get("verses") or ([{"verse": ref.verse_start or 1, "text": payload.get("text")}]
                                         if isinstance(payload.get("text"), str) else [])
    verses = _verse_rows(ref, rows)
    if not verses:
        raise PassageNotFound(f"NLT returned no text for {reference}.")
    return _assemble(ref, route, verses)


def _from_bolls_life(ref: PassageRef, route: Route) -> dict:
    # Chapter-level only: /get-text/{abbr}/{book}/{chapter}/ works while the
    # per-verse URL 404s, so a verse span is sliced out of the chapter here.
    # `book_number` is bolls's 1-based Protestant ordering (John = 43).
    payload = _fetch(
        f"{BOLLS_BASE}/get-text/{quote(route.provider_id, safe='')}/{ref.book_number}/{ref.chapter}/",
        provider=route.name, expect=list,
    )
    if not payload:
        raise PassageNotFound(
            f"{route.name} is not published on bolls.life (the chapter came back empty)."
        )
    # Checked against the whole chapter, before slicing: a refusal arrives as the
    # text of every verse, so a one-verse request would otherwise quote a piece
    # of the publisher's protest letter back as Scripture.
    if _PROHIBITION.search(" ".join(str(row.get("text", "")) for row in payload if isinstance(row, dict))):
        raise TranslationRefused(
            f"{route.name} may not be redistributed by this source: the publisher "
            "blocks it on bolls.life. Use the authorised site link instead."
        )
    verses = _verse_rows(ref, payload)
    if not verses:
        raise PassageNotFound(f"bolls.life returned no readable text for {ref.reference}.")
    return _assemble(ref, route, verses)


_PROVIDERS = {
    "bible_api": _from_bible_api,
    "esv": _from_esv,
    "nlt": _from_nlt,
    "bolls_life": _from_bolls_life,
}


# Routing ------------------------------------------------------------------


def _cache_key(ref: PassageRef, route: Route) -> str:
    """A memcached-safe key: no spaces, and one per canonical passage."""
    span = f"{ref.verse_start or 0}-{ref.verse_end or 0}" if ref.verse_start else "ch"
    return f"{CACHE_PREFIX}:{route.code}:{ref.book_code}.{ref.chapter}.{span}"


def _served(ref: PassageRef, route: Route) -> dict:
    if route.provider == "deep_link":
        raise TranslationRefused(route.attribution)
    fetch = _PROVIDERS.get(route.provider)
    if fetch is None:  # pragma: no cover - routing_table only emits wired providers
        raise UnknownTranslation(f"No fetcher is wired for {route.name}.")
    key = _cache_key(ref, route)
    stored = cache.get(key)
    if isinstance(stored, dict) and stored.get("verses"):
        return {**stored, "cached": True}
    passage = fetch(ref, route)
    cache.set(key, passage, route.cache_seconds)
    return {**passage, "cached": False}


def get_passage(reference: str, translation: str = "") -> dict:
    """Fetch one passage, falling back to the default translation on any failure.

    `translation` may be blank (the deployment default), an abbreviation, or a
    longer name; a bad *reference* is the caller's error and is never papered
    over with another version's text.
    """
    ref = parse_reference(reference)
    route = resolve_route(translation)
    limit = int(getattr(settings, "UDM_BIBLE_MAX_VERSES", 200) or 200)
    if ref.verse_count > limit:
        raise PassageTooLong(
            f"{ref.reference} is {ref.verse_count} verses; this API serves at most "
            f"{limit} at a time. Ask for a shorter span."
        )
    try:
        return _served(ref, route)
    except PassageError as exc:
        fallback = resolve_route(getattr(settings, "UDM_BIBLE_DEFAULT_TRANSLATION", "kjv"))
        if fallback.code == route.code or not fallback.text_source_available:
            exc.translation = route.code
            raise
        try:
            passage = _served(ref, fallback)
        except PassageError:
            # The requested translation's failure is the informative one.
            exc.translation = route.code
            raise exc from None
        reason = str(exc)
        logger.info("bible fallback: %s %s -> %s (%s)", route.code, ref.reference, fallback.code, reason)
        return {
            **passage,
            **_links(ref, route),
            "attribution": f"{route.name}: {route.attribution} Shown in {fallback.name} because {reason}",
            "fallback": {"requested": route.code, "requested_name": route.name, "reason": reason},
        }
