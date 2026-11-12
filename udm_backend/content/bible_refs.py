"""Scripture reference parsing, text cleaning and authorized deep links.

The router in `bible_passages` speaks to several providers, each of which wants a
reference in a different shape: Bible-API.com takes a human string, Bolls.life
takes a 1-based book number plus a chapter, BibleGateway takes a query string and
YouVersion takes an OSIS book code with a dotted passage id. Everything the rest
of the module needs is derived once here from one canonical form, so a curator
typing "1jhn 3:16-18" and a student tapping a bookmark reach the same row.
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass
from urllib.parse import quote_plus

# (canonical name, book number in Protestant order, OSIS code, aliases).
#
# The numbers are not decorative: Bolls.life addresses books by them, and 1-based
# Protestant ordering is what its John=43 and Revelation=66 endpoints use.
_BOOKS: tuple[tuple[str, int, str, tuple[str, ...]], ...] = (
    ("Genesis", 1, "GEN", ("gen", "genesis")),
    ("Exodus", 2, "EXO", ("exo", "exod", "exodus")),
    ("Leviticus", 3, "LEV", ("lev", "le v", "leviticus")),
    ("Numbers", 4, "NUM", ("num", "nu", "numbers")),
    ("Deuteronomy", 5, "DEU", ("deut", "deu", "deuteronomy")),
    ("Joshua", 6, "JOS", ("josh", "jos", "joshua")),
    ("Judges", 7, "JDG", ("judg", "jdg", "judges")),
    ("Ruth", 8, "RUT", ("ruth", "rut")),
    ("1 Samuel", 9, "1SA", ("1sam", "1sa", "1 samuel", "i sam", "first samuel")),
    ("2 Samuel", 10, "2SA", ("2sam", "2sa", "2 samuel", "ii sam", "second samuel")),
    ("1 Kings", 11, "1KI", ("1kgs", "1ki", "1 kings", "i kings")),
    ("2 Kings", 12, "2KI", ("2kgs", "2ki", "2 kings", "ii kings")),
    ("1 Chronicles", 13, "1CH", ("1chr", "1ch", "1 chron", "1 chronicles")),
    ("2 Chronicles", 14, "2CH", ("2chr", "2ch", "2 chron", "2 chronicles")),
    ("Ezra", 15, "EZR", ("ezra", "ezr")),
    ("Nehemiah", 16, "NEH", ("neh", "nehem", "nehemiah")),
    ("Esther", 17, "EST", ("esth", "est", "esther")),
    ("Job", 18, "JOB", ("job",)),
    ("Psalms", 19, "PSA", ("ps", "psa", "psal", "psalm", "psalms")),
    ("Proverbs", 20, "PRO", ("prov", "pro", "prv", "proverbs")),
    ("Ecclesiastes", 21, "ECC", ("eccl", "ecc", "eccles", "ecclesiastes")),
    ("Song of Solomon", 22, "SNG", ("song", "sg", "sos", "ss", "song of solomon", "song of songs")),
    ("Isaiah", 23, "ISA", ("isa", "isaih", "isaiah")),
    ("Jeremiah", 24, "JER", ("jer", "jerem", "jeremiah")),
    ("Lamentations", 25, "LAO", ("lam", "lao", "lamentations")),
    ("Ezekiel", 26, "EZE", ("ezk", "eze", "ezek", "ezekiel")),
    ("Daniel", 27, "DAN", ("dan", "daniel")),
    ("Hosea", 28, "HOS", ("hos", "hosea")),
    ("Joel", 29, "JOL", ("jol", "joel")),
    ("Amos", 30, "AMO", ("amo", "amos")),
    ("Obadiah", 31, "OBA", ("obad", "oba", "obadiah")),
    ("Jonah", 32, "JON", ("jonah", "jon")),
    ("Micah", 33, "MIC", ("mic", "micha", "micah")),
    ("Nahum", 34, "NAB", ("nah", "nab", "nahum")),
    ("Habakkuk", 35, "HAB", ("hab", "habakkuk")),
    ("Zephaniah", 36, "ZEP", ("zep", "zeph", "zephaniah")),
    ("Haggai", 37, "HAG", ("hag", "haggai")),
    ("Zechariah", 38, "ZEC", ("zec", "zech", "zechariah")),
    ("Malachi", 39, "MAL", ("mal", "malachi")),
    ("Matthew", 40, "MAT", ("matt", "mat", "mt", "matthew")),
    ("Mark", 41, "MRK", ("mar", "mrk", "mk", "mark")),
    ("Luke", 42, "LUK", ("luk", "luke")),
    ("John", 43, "JHN", ("jn", "jhn", "joh", "john")),
    ("Acts", 44, "ACT", ("act", "acts")),
    ("Romans", 45, "ROM", ("rom", "roms", "romans")),
    ("1 Corinthians", 46, "1CO", ("1cor", "1co", "1 cor", "1 corinthians", "i cor")),
    ("2 Corinthians", 47, "2CO", ("2cor", "2co", "2 cor", "2 corinthians", "ii cor")),
    ("Galatians", 48, "GAL", ("gal", "galatians")),
    ("Ephesians", 49, "EPH", ("eph", "ephes", "ephesians")),
    ("Philippians", 50, "PHP", ("php", "phil", "phillipians", "philippians")),
    ("Colossians", 51, "COL", ("col", "colossians")),
    ("1 Thessalonians", 52, "1TH", ("1th", "1 thess", "1 thessalonians")),
    ("2 Thessalonians", 53, "2TH", ("2th", "2 thess", "2 thessalonians")),
    ("1 Timothy", 54, "1TI", ("1ti", "1 tim", "1 timothy", "i tim")),
    ("2 Timothy", 55, "2TI", ("2ti", "2 tim", "2 timothy", "ii tim")),
    ("Titus", 56, "TIT", ("tit", "titus")),
    ("Philemon", 57, "PHM", ("phm", "phlm", "philemon")),
    ("Hebrews", 58, "HEB", ("heb", "hebr", "hebrews")),
    ("James", 59, "JAS", ("jas", "jam", "james")),
    ("1 Peter", 60, "1PE", ("1pe", "1 pet", "1 peter", "i pet")),
    ("2 Peter", 61, "2PE", ("2pe", "2 pet", "2 peter", "ii pet")),
    ("1 John", 62, "1JN", ("1jn", "1jhn", "1joh", "1 jo", "1 john", "i joh")),
    ("2 John", 63, "2JN", ("2jn", "2jhn", "2joh", "2 jo", "2 john")),
    ("3 John", 64, "3JN", ("3jn", "3jhn", "3joh", "3 jo", "3 john")),
    ("Jude", 65, "JUD", ("jud", "jude")),
    ("Revelation", 66, "REV", ("rev", "revelation", "rev of john")),
)

_ROMAN = {"i": 1, "ii": 2, "iii": 3}
# Longest numeral first: alternation stops at the first branch that matches.
_ROMAN_PREFIX = re.compile(r"^(iii|ii|i)(?=[a-z])")
_ORDINAL_PREFIX = re.compile(r"^(\d+)(?:st|nd|rd|th)(?=[a-z])")
# Book, then chapter, then optional verse or verse range. The book part is lazy so
# the digits always land in the chapter group, which is what makes "1Jn3:16" and
# "1 John 3:16" parse the same way.
_PASSAGE = re.compile(
    r"^(?P<book>.*?)\s*"
    r"(?P<chapter>\d{1,3})"
    r"(?::\s*(?P<start>\d{1,3})(?:\s*(?:-|–|—)\s*(?P<end>\d{1,3}))?)?$"
)
_TAG = re.compile(r"<[^>]+>")
# Markup whose *content* is apparatus rather than text: Strong's concordence
# numbers (`<S>1161</S>`), KJV/CSB margin notes (`<sup>again: or, from
# above</sup>`) and footnote markers. Stripping only the tags would leave the
# numbers reading as part of the verse.
_APPARATUS = re.compile(
    r"<(S|sup|note|footnote)\b[^>]*>.*?</\1>", re.I | re.S
)
_WHITESPACE = re.compile(r"\s+")
_LOOSE_PUNCTUATION = re.compile(r"\s+([,.;:!?])")

BOOKS: dict[str, tuple[int, str]] = {name: (number, code) for name, number, code, _ in _BOOKS}


def _compact(value: str) -> str:
    """Fold a book name or alias to the one spelling every input reduces to.

    "I John", "1st John" and "1john" all have to reach the same row, so case,
    punctuation and inner spacing are removed first, then a leading book number is
    rewritten to the digit the canonical aliases use. The rewrite only sticks when
    the digit form is a real book: the "I" opening "Isaiah" is a letter of the
    name, not the number one.
    """
    squashed = re.sub(r"[^a-z0-9]+", "", str(value or "").lower())
    ordinal = _ORDINAL_PREFIX.sub(r"\1", squashed)
    if ordinal in _ALIASES:
        return ordinal
    match = _ROMAN_PREFIX.match(squashed)
    if match:
        numeral = f"{_ROMAN[match.group(1)]}{squashed[match.end() :]}"
        if numeral in _ALIASES:
            return numeral
    return squashed


_ALIASES: dict[str, str] = {}
for _name, _number, _code, _aliases in _BOOKS:
    for _alias in (_name, *_aliases):
        _ALIASES.setdefault(_compact(_alias), _name)


class InvalidReference(ValueError):
    """The text does not name a chapter of Scripture."""


@dataclass(frozen=True)
class PassageRef:
    book: str
    book_number: int
    book_code: str
    chapter: int
    verse_start: int | None = None
    verse_end: int | None = None

    @property
    def reference(self) -> str:
        """The canonical human form, which is also what providers echo back."""
        text = f"{self.book} {self.chapter}"
        if self.verse_start is None:
            return text
        if self.verse_end in (None, self.verse_start):
            return f"{text}:{self.verse_start}"
        return f"{text}:{self.verse_start}-{self.verse_end}"

    @property
    def is_single_chapter(self) -> bool:
        return self.verse_start is None

    @property
    def verse_count(self) -> int:
        if self.verse_start is None:
            return 0
        return (self.verse_end or self.verse_start) - self.verse_start + 1

    @property
    def youversion_passage(self) -> str:
        return f"{self.book_code}.{self.chapter}" + (
            f".{self.verse_start}" if self.verse_start is not None else ""
        )


def parse_reference(value: str) -> PassageRef:
    """Turn any reasonable spelling of a passage into a `PassageRef`.

    A chapter is required: "John" alone is a book, and book-sized requests would
    fetch sixty chapter payloads for no benefit to a reader.
    """
    text = " ".join(str(value or "").split())
    if not text:
        raise InvalidReference("A reference is required.")
    match = _PASSAGE.match(text)
    if match is None:
        named = _ALIASES.get(_compact(re.split(r"\d", text, maxsplit=1)[0]))
        if named is None:
            raise InvalidReference(f"“{text}” does not name a book of the Bible.")
        raise InvalidReference(f"“{text}” needs a chapter, for example “{named} 3:16”.")
    book_name = _ALIASES.get(_compact(match.group("book")))
    if book_name is None:
        raise InvalidReference(f"“{text}” does not name a book of the Bible.")
    chapter = int(match.group("chapter"))
    first = int(match.group("start")) if match.group("start") else None
    last = int(match.group("end")) if match.group("end") else None
    if chapter < 1 or chapter > 150 or (first is not None and first < 1) or (last is not None and last < first):
        raise InvalidReference(f"“{text}” is not a readable passage.")
    book_number, book_code = BOOKS[book_name]
    return PassageRef(book_name, book_number, book_code, chapter, first, last)


def clean_text(value: str) -> str:
    """Provider markup out, readable prose in.

    Bolls.life ships Strong's numbers inline (`<S>2532</S>`) and margin notes as
    `<sup>` content; ESV returns paragraph and verse-number markup. The apparatus
    elements go first so their numbers do not survive as verse text, then every
    remaining tag is dropped, entities decoded and whitespace collapsed, so the
    reader app never sees markup.
    """
    without_apparatus = _APPARATUS.sub("", str(value or ""))
    without_tags = _TAG.sub(" ", without_apparatus)
    decoded = html.unescape(without_tags)
    # Markup sat between a word and its punctuation (`world<S>2889</S>,`), so
    # removing it would otherwise leave the space behind.
    joined = _WHITESPACE.sub(" ", decoded).strip()
    return _LOOSE_PUNCTUATION.sub(r"\1", joined)


_VERSE_MARK = re.compile(r'<v[^>]*\bn(?:umber)?="(\d+)"[^>]*>', re.I)


def split_verses(markup: str, fallback_number: int = 1) -> list[dict]:
    """Verse-number markup to `[{verse, text}]`, or one entry when unmarked."""
    text = str(markup or "")
    marks = list(_VERSE_MARK.finditer(text))
    if not marks:
        cleaned = clean_text(text)
        return [{"verse": fallback_number, "text": cleaned}] if cleaned else []
    verses = []
    for position, mark in enumerate(marks):
        stop = marks[position + 1].start() if position + 1 < len(marks) else len(text)
        body = clean_text(text[mark.end():stop])
        if body:
            verses.append({"verse": int(mark.group(1)), "text": body})
    return verses


def bible_gateway_url(reference: str, version: str) -> str:
    return (
        "https://www.biblegateway.com/passage/"
        f"?search={quote_plus(reference)}&version={quote_plus(version)}"
    )


def youversion_url(reference: PassageRef, bible_id: int | str) -> str:
    """A bible.com passage link.

    The numeric Bible id comes from the routing matrix (it is the same id the
    YouVersion catalog stores in `BibleTranslation.code`), because bible.com
    addresses versions by that id rather than by an abbreviation.
    """
    return f"https://www.bible.com/bible/{bible_id}/{reference.youversion_passage}"
