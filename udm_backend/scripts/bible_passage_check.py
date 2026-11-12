"""Live check of the Bible passage router against the real providers.

Fetches across every routed translation — public-domain KJV/WEB/ASV, the keyed
ESV and NLT, and the restricted NIV/NKJV/CSB/NASB/MSG/AMP — and proves the
invariants the app depends on: one unified schema, an authorized deep link on
every response, markup never reaching the reader, equivalent references sharing
one request, and a fallback instead of a failure when a source is unavailable.

    cd udm_backend && ../venv/Scripts/python.exe scripts/bible_passage_check.py

It talks to the internet and needs no server and no database. Keys come from the
repository `.env`; missing keys are a checked state, not a crash. Add
`--offline` to verify only the reference normalizer and the routing matrix.
"""

import os
import re
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = BACKEND_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "udm_backend.settings.dev")

import django  # noqa: E402

django.setup()

from django.core.cache import cache  # noqa: E402

from content.bible_passages import (  # noqa: E402
    PassageError,
    get_passage,
    resolve_route,
    route_is_configured,
    routing_table,
)
from content.bible_refs import InvalidReference, parse_reference  # noqa: E402

PASSAGE_KEYS = {
    "reference", "translation", "translation_name", "source", "text", "verses",
    "deep_link_url", "alternate_link_url", "attribution", "offline_allowed",
    "fallback", "cached",
}
FAILURES: list[str] = []
CHECKS = 0


def report(label: str, ok: bool, detail: str = "") -> None:
    global CHECKS
    CHECKS += 1
    print(f"  {'ok  ' if ok else 'FAIL'} {label}{f' — {detail}' if detail else ''}")
    if not ok:
        FAILURES.append(label)


def fetch(label: str, reference: str, translation: str, *, expect_served: str | None = None) -> dict | None:
    """Fetch one passage and assert the schema; returns None if the source failed."""
    try:
        passage = get_passage(reference, translation)
    except PassageError as exc:
        report(f"{label} answers instead of failing", False, f"{type(exc).__name__}: {exc}")
        return None
    report(f"{label} schema", set(passage) == PASSAGE_KEYS, ", ".join(sorted(set(passage) ^ PASSAGE_KEYS)))
    report(f"{label} has verses", bool(passage["verses"]),
           f"{len(passage['verses'])} verse(s)")
    report(f"{label} carries an authorized link", bool(passage["deep_link_url"]), passage["deep_link_url"])
    report(f"{label} text is markup-free", not re.search(r"<[A-Za-z/]", passage["text"]))
    if expect_served:
        report(f"{label} served by {expect_served}", passage["translation"] == expect_served, passage["translation"])
    return passage


def check_references() -> None:
    print("\nreference normalization")
    expected = parse_reference("1 John 3:16")
    for spelling in ("1John 3:16", "1Jn 3:16", "i jhn 3:16", "1st John 3:16", "1 JOHN 3:16", "1jn3:16"):
        report(f"“{spelling}” = 1 John 3:16", parse_reference(spelling) == expected)
    report("“Isaiah 53:5” is not read as “1 saiah”", parse_reference("Isaiah 53:5").book == "Isaiah")
    report("“John 3” is a whole chapter", parse_reference("John 3").is_single_chapter)
    for junk in ("", "Frogs 1:1", "John", "3:16", "John 0:5", "1 John 400"):
        try:
            parse_reference(junk)
            report(f"“{junk}” is refused", False)
        except InvalidReference:
            report(f"“{junk}” is refused", True)


def check_matrix() -> None:
    print("\nrouting matrix")
    routes = routing_table()
    report("every code resolves", all(resolve_route(code).code == code for code in routes), ", ".join(sorted(routes)))
    for code in ("niv", "nkjv", "csb", "nasb", "msg", "amp"):
        report(f"{code} only ever serves text through an explicit rights mapping",
               routes[code].provider in ("deep_link", "bolls_life"), routes[code].provider)
    for code in ("kjv", "web", "asv"):
        report(f"{code} serves text without a key", routes[code].text_source_available and route_is_configured(routes[code]))
    for code in ("esv", "nlt"):
        print(f"       {code}: configured={route_is_configured(routes[code])} "
              f"({'key present' if route_is_configured(routes[code]) else 'no key — fallback path is what runs'})")


def check_live() -> None:
    print("\npublic-domain fetches (bible-api.com)")
    for code, reference in (("kjv", "John 3:16"), ("web", "1 Cor 15:3-4"), ("asv", "Psalm 23")):
        fetch(f"{code} {reference}", reference, code, expect_served=code)

    print("\nequivalent references share one request")
    cache_key_probe = get_passage("1 John 3:16", "kjv")
    again = get_passage("1Jn 3:16", "King James Version")
    report("second spelling is served from cache", bool(again["cached"]) and not again["fallback"],
           f"first cached={cache_key_probe['cached']} second cached={again['cached']}")

    print("\nrestricted translations")
    for code in ("niv", "nkjv", "csb", "nasb", "msg", "amp"):
        passage = fetch(f"{code} refused-then-fallback", "John 3:16", code)
        if passage:
            report(f"{code} links the asked-for version, not the served one",
                   f"version={resolve_route(code).link_version}" in passage["deep_link_url"],
                   passage["deep_link_url"])
            report(f"{code} explains the substitution", bool(passage["fallback"]),
                   (passage["fallback"] or {}).get("reason", "")[:80])

    print("\nkeyed providers")
    for code, reference in (("esv", "John 3:16"), ("nlt", "John 3:16")):
        configured = route_is_configured(resolve_route(code))
        passage = fetch(f"{code} {reference}", reference, code)
        if passage and configured and not passage["fallback"]:
            report(f"{code} returned its own text", passage["translation"] == code)
        elif passage and not configured:
            report(f"{code} without a key falls back to {passage['translation']}",
                   passage["translation"] == "kjv" and bool(passage["fallback"]))

    if route_is_configured(resolve_route("esv")):
        print("\nESV quote etiquette")
        print("       Keep attribution with the text and stay inside the publisher's")
        print("       quoting limits; the counter caps this deployment at the daily quota.")


def main() -> int:
    offline = "--offline" in sys.argv
    print(f"Bible passage router check ({'offline' if offline else 'live providers'})")
    check_references()
    check_matrix()
    if not offline:
        check_live()
    print(f"\n{CHECKS} checks, {len(FAILURES)} failure(s)")
    for label in FAILURES:
        print(f"  failed: {label}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    raise SystemExit(main())
