"""The passage router: normalization, provider parsing, licensing gates, fallback.

No test here reaches the network. Each provider payload is either copied from a
response captured live against the real service (bible-api.com, bolls.life) or
written from the vendor's published contract (ESV, NLT); `docs/bible-router.md`
records which is which and when it was captured.
"""

import io
import json
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from django.core.cache import cache
from django.test import SimpleTestCase, override_settings

from content.bible_passages import (
    PassageNotFound,
    PassageTooLong,
    TranslationRefused,
    UnknownTranslation,
    UpstreamUnavailable,
    get_passage,
    resolve_route,
    route_is_configured,
    routing_table,
)
from content.bible_refs import InvalidReference, clean_text, parse_reference
from content.models import BibleBook, BibleChapter, BibleTranslation, BibleVerse
from core.testing import UdmAPITestCase

# Captured live from https://bible-api.com/1+John+3:16?translation=kjv
BIBLE_API_KJV = {
    "reference": "1 John 3:16",
    "verses": [{"book_id": "JHN", "book_name": "1 John", "chapter": 3, "verse": 16,
                "text": "Hereby perceive we the love of God, because he laid down his life for us.\n"}],
    "text": "Hereby perceive we the love of God, because he laid down his life for us.\n",
    "translation_id": "kjv",
    "translation_name": "King James Version",
    "translation_note": "Public Domain",
}
# Captured live from https://bible-api.com/john+3:16 — its default version is
# WEB, which is why every request names the translation explicitly.
BIBLE_API_WEB = {
    "reference": "John 3:16",
    "verses": [{"book_id": "JHN", "book_name": "John", "chapter": 3, "verse": 16,
                "text": "For God so loved the world, that he gave his only begotten Son.\n"}],
    "text": "For God so loved the world, that he gave his only begotten Son.\n",
    "translation_id": "web",
    "translation_name": "World English Bible",
    "translation_note": "Public Domain",
}
# Same service, a three-verse span, used where a fallback must answer a
# request whose verse is not 16.
BIBLE_API_JOHN3 = {
    "reference": "John 3:16-18",
    "verses": [{"book_id": "JHN", "book_name": "John", "chapter": 3, "verse": number,
                "text": f"Verse {number} of John three."} for number in (16, 17, 18)],
    "text": "Verse 16 of John three. Verse 17 of John three. Verse 18 of John three.",
    "translation_id": "kjv", "translation_name": "King James Version", "translation_note": "Public Domain",
}
# ESV's published response contract (https://www.esv.org/services/), API v3.
ESV_PASSAGE = {
    "query": "John 3:16",
    "passages": [{
        "passage_ref": "John 3:16",
        "canonical_ranges": ["John 3:16"],
        "verses": [{"chapter": "John 3", "verse": 16,
                    "text": "For God so loved the world, that he gave his only Son."},
                   {"chapter": "John 3", "verse": 17, "text": "God did not send his Son to condemn the world."},
                   {"chapter": "John 3", "verse": 18, "text": "Whoever believes in him is not condemned."}],
        "paragraphs": [],
    }],
    "errors": [],
}
ESV_PARAGRAPHS_ONLY = {
    "query": "John 3:16",
    "passages": [{
        "passage_ref": "John 3:16",
        "verses": [],
        "paragraphs": [{"verses": "16", "text": "<p>16&nbsp;For God so loved the world.</p>"}],
    }],
}
# Shape captured live from https://bolls.life/get-text/ASV/43/3/ (book 43 is
# John there, and only whole chapters are published).
BOLLS_CHAPTER = [
    {"pk": 39301, "chapter": 3, "verse": 15, "text": "But if<S>3756</S> ye shall neglect<S>1951</S>,"},
    {"pk": 39302, "chapter": 3, "verse": 16, "text": "For God so loved the world<S>2889</S>, that he gave<S>1325</S> his"
     "<sup>  begotten: or, beloved</sup> Son<S>3439</S>,"},
    {"pk": 39303, "chapter": 3, "verse": 17, "text": "For<S>1063</S> God sent<S>3992</S> not<S>3756</S> his Son into the world<S>2889</S>."},
    {"pk": 39304, "chapter": 3, "verse": 18, "text": "Every one that feareth<S>5380</S> him."},
]
# What bolls.life returns for /get-text/NIV/43/3/: HTTP 200 and a well-formed
# verse list whose text is the publisher's refusal.
BOLLS_NIV_PROTEST = [
    {"pk": 1, "chapter": 3, "verse": 16, "text": "Biblica, Inc. has prohibited me from using the NIV "
     "translation; I am not allowed to share it. <i>\"For God so loved the world\"</i>."}
]


def _http_error(code: int, body: bytes = b"<html>error</html>") -> HTTPError:
    return HTTPError("https://provider.invalid", code, "error", hdrs={}, fp=io.BytesIO(body))


class _Recorder:
    """A stand-in for `urlopen`: replays outcomes, records every request."""

    def __init__(self, *outcomes):
        self.outcomes = list(outcomes)
        self.requests = []

    @property
    def calls(self):
        return [request.full_url for request in self.requests]

    def __call__(self, request, timeout=None):
        self.requests.append(request)
        if len(self.requests) > len(self.outcomes):
            raise AssertionError(f"unexpected request #{len(self.requests)}: {request.full_url}")
        outcome = self.outcomes[len(self.requests) - 1]
        if isinstance(outcome, Exception):
            raise outcome
        body = outcome if isinstance(outcome, bytes) else json.dumps(outcome).encode()

        class Response:
            def read(self):
                return body

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

        return Response()


class RouterTestCase(SimpleTestCase):
    """Base: cache isolated per test, and `urlopen` replaced by a replay."""

    def setUp(self):
        cache.clear()
        patcher = patch("content.bible_passages.urlopen")
        self.urlopen = patcher.start()
        self.addCleanup(patcher.stop)

    def serve(self, *outcomes):
        recorder = _Recorder(*outcomes)
        self.urlopen.side_effect = recorder
        return recorder


class ReferenceTests(SimpleTestCase):
    def test_every_spelling_of_a_numbered_book_reaches_the_same_passage(self):
        expected = parse_reference("1 John 3:16")
        for spelling in ("1John 3:16", "1Jn 3:16", "i jhn 3:16", "1st John 3:16", "1 JOHN 3:16", "1jn3:16"):
            self.assertEqual(parse_reference(spelling), expected, spelling)

    def test_roman_folding_leaves_books_whose_names_begin_with_a_numeral_letter(self):
        self.assertEqual(parse_reference("Isaiah 53:5").book, "Isaiah")
        self.assertEqual(parse_reference("Job 2:1").book, "Job")
        self.assertEqual(parse_reference("i cor 15:3").book, "1 Corinthians")
        self.assertEqual(parse_reference("II Sam 7:12").book, "2 Samuel")

    def test_a_span_keeps_both_ends_and_counts_itself(self):
        ref = parse_reference("1 cor 15:3-4")
        self.assertEqual((ref.verse_start, ref.verse_end, ref.verse_count), (3, 4, 2))
        self.assertEqual(ref.reference, "1 Corinthians 15:3-4")

    def test_a_chapter_without_verses_is_a_whole_chapter(self):
        ref = parse_reference("John 3")
        self.assertTrue(ref.is_single_chapter)
        self.assertEqual(ref.verse_count, 0)

    def test_junk_is_refused_instead_of_guessed(self):
        for value in ("", "Frogs 1:1", "John", "3:16", "John 0:5", "Luke 1:9-2", "1 John 400"):
            with self.subTest(value=value):
                with self.assertRaises(InvalidReference):
                    parse_reference(value)

    def test_markup_and_strongs_numbers_never_survive_cleaning(self):
        cleaned = clean_text('For God so loved the world<S>2889</S> , <sup>or, beloved</sup> Son&nbsp; &amp; gave.')
        self.assertEqual(cleaned, "For God so loved the world, Son & gave.")


class RoutingTableTests(SimpleTestCase):
    def test_licensed_versions_are_deep_link_only_until_rights_are_configured(self):
        routes = routing_table()
        for code in ("niv", "nkjv", "csb", "nasb", "msg", "amp"):
            self.assertEqual(routes[code].provider, "deep_link", code)
            self.assertFalse(route_is_configured(routes[code]), code)

    def test_rights_mapping_switches_a_code_to_bolls_life(self):
        with override_settings(UDM_BOLLS_TRANSLATIONS="nkjv:NKJV, csb:CSB17"):
            routes = routing_table()
            self.assertEqual((routes["nkjv"].provider, routes["nkjv"].provider_id), ("bolls_life", "NKJV"))
            self.assertEqual(routes["csb"].provider_id, "CSB17")
            self.assertEqual(routes["niv"].provider, "deep_link")

    def test_a_name_or_an_abbreviation_resolves_to_the_same_route(self):
        for value in ("esv", "ESV", "english standard version", " English-Standard ", "English Standard Version"):
            self.assertEqual(resolve_route(value).code, "esv", value)

    def test_a_routes_own_name_is_always_acceptable_as_a_code(self):
        for code, route in routing_table().items():
            self.assertEqual(resolve_route(route.name).code, code, route.name)

    def test_blank_translation_uses_the_deployment_default(self):
        with override_settings(UDM_BIBLE_DEFAULT_TRANSLATION="web"):
            self.assertEqual(resolve_route("").code, "web")

    def test_an_unknown_code_names_the_available_ones(self):
        with self.assertRaises(UnknownTranslation) as caught:
            resolve_route("niv1984x")
        self.assertIn("kjv", str(caught.exception))

    def test_keyed_providers_report_unconfigured_without_a_key(self):
        with override_settings(ESV_API_KEY="", NLT_API_KEY="abc"):
            self.assertFalse(route_is_configured(resolve_route("esv")))
            self.assertTrue(route_is_configured(resolve_route("nlt")))
        self.assertTrue(route_is_configured(resolve_route("web")))


class PublicDomainTests(RouterTestCase):
    def test_passage_carries_the_unified_schema(self):
        recorder = self.serve(BIBLE_API_KJV)
        passage = get_passage("1Jn 3:16", "kjv")
        self.assertEqual(
            set(passage), {
                "reference", "translation", "translation_name", "source", "text", "verses",
                "deep_link_url", "alternate_link_url", "attribution", "offline_allowed",
                "fallback", "cached",
            }
        )
        self.assertEqual(passage["reference"], "1 John 3:16")
        self.assertEqual(passage["verses"], [{"verse": 16,
                                             "text": "Hereby perceive we the love of God, because he laid down his life for us."}])
        self.assertNotIn("\n", passage["text"])
        self.assertIn("version=KJV", passage["deep_link_url"])
        self.assertTrue(passage["offline_allowed"])
        self.assertIn("Public Domain", passage["attribution"])
        self.assertIsNone(passage["fallback"])
        self.assertEqual(recorder.calls, ["https://bible-api.com/1+John+3:16?translation=kjv"])

    def test_the_translation_is_named_explicitly_because_the_default_is_web(self):
        recorder = self.serve(BIBLE_API_WEB)
        passage = get_passage("John 3:16", "web")
        self.assertEqual(passage["translation"], "web")
        self.assertIn("?translation=web", recorder.calls[0])

    def test_a_service_answering_a_different_version_is_not_mislabeled(self):
        self.serve(BIBLE_API_WEB)
        with self.assertRaises(PassageNotFound):
            get_passage("John 3:16", "kjv")

    def test_a_second_request_is_served_from_cache_without_the_network(self):
        recorder = self.serve(BIBLE_API_KJV)
        first = get_passage("1 John 3:16", "kjv")
        second = get_passage("1 John 3:16", "kjv")
        self.assertFalse(first["cached"])
        self.assertTrue(second["cached"])
        self.assertEqual(len(recorder.calls), 1)

    def test_equivalent_spellings_share_one_cache_entry(self):
        recorder = self.serve(BIBLE_API_KJV)
        get_passage("1 John 3:16", "kjv")
        again = get_passage("1Jn 3:16", "King James")
        self.assertTrue(again["cached"])
        self.assertEqual(len(recorder.calls), 1)

    def test_a_404_from_the_source_is_reported_not_fabricated(self):
        self.serve(_http_error(404))
        with self.assertRaises(PassageNotFound):
            get_passage("John 40:1", "kjv")

    def test_a_wide_span_is_refused_before_any_request(self):
        recorder = self.serve()
        with self.assertRaises(PassageTooLong):
            get_passage("Exodus 15:1-250", "kjv")
        self.assertEqual(recorder.calls, [])


class FallbackTests(RouterTestCase):
    def test_unlicensed_translation_falls_back_with_the_requested_deep_link(self):
        recorder = self.serve(BIBLE_API_KJV)
        passage = get_passage("John 3:16", "niv")
        self.assertEqual(passage["translation"], "kjv")
        self.assertIn("version=NIV", passage["deep_link_url"])
        self.assertEqual(passage["fallback"]["requested"], "niv")
        self.assertEqual(passage["fallback"]["requested_name"], "New International Version")
        self.assertIn("Biblica", passage["fallback"]["reason"])
        self.assertEqual(len(recorder.calls), 1)

    def test_missing_key_falls_back_without_raising(self):
        recorder = self.serve(BIBLE_API_KJV)
        with override_settings(ESV_API_KEY=""):
            passage = get_passage("John 3:16", "esv")
        self.assertEqual(len(recorder.calls), 1)
        self.assertEqual(passage["translation"], "kjv")
        self.assertIn("ESV_API_KEY", passage["fallback"]["reason"])
        self.assertIn("version=ESV", passage["deep_link_url"])

    def test_a_keyless_provider_asks_for_nothing_but_the_fallback_text(self):
        recorder = self.serve(BIBLE_API_KJV)
        with override_settings(ESV_API_KEY=""):
            get_passage("John 3:16", "esv")
        self.assertEqual(len(recorder.calls), 1)
        self.assertIn("bible-api.com", recorder.calls[0])

    def test_rate_limit_timeout_and_server_errors_all_fall_back(self):
        for outcome in (_http_error(429), _http_error(503), URLError("no route to host")):
            with self.subTest(outcome=type(outcome).__name__):
                cache.clear()
                self.serve(outcome, BIBLE_API_KJV)
                with override_settings(ESV_API_KEY="k"):
                    passage = get_passage("John 3:16", "esv")
                self.assertEqual(passage["translation"], "kjv")
                self.assertIn("English Standard Version", passage["fallback"]["reason"])

    def test_a_non_json_body_is_an_upstream_failure_not_a_crash(self):
        self.serve(b"<html>nginx 404</html>", BIBLE_API_KJV)
        with override_settings(ESV_API_KEY="k"):
            passage = get_passage("John 3:16", "esv")
        self.assertEqual(passage["translation"], "kjv")
        self.assertIn("not JSON", passage["fallback"]["reason"])

    def test_when_the_fallback_fails_too_the_requested_failure_is_reported(self):
        with override_settings(ESV_API_KEY="k"):
            self.serve(_http_error(503), _http_error(503))
            with self.assertRaises(UpstreamUnavailable) as caught:
                get_passage("John 3:16", "esv")
        self.assertIn("English Standard Version", str(caught.exception))

    def test_a_deep_link_only_default_raises_rather_than_looping(self):
        with override_settings(UDM_BIBLE_DEFAULT_TRANSLATION="niv"):
            with self.assertRaises(TranslationRefused):
                get_passage("John 3:16", "niv")


class ESVTests(RouterTestCase):
    def setUp(self):
        super().setUp()
        patcher = override_settings(ESV_API_KEY="test-token")
        patcher.enable()
        self.addCleanup(patcher.disable)

    def test_verses_come_from_the_documented_payload(self):
        recorder = self.serve(ESV_PASSAGE)
        passage = get_passage("John 3:16", "esv")
        self.assertEqual(passage["translation"], "esv")
        self.assertEqual(passage["verses"][0]["text"], "For God so loved the world, that he gave his only Son.")
        self.assertIn("q=John+3%3A16", recorder.calls[0])

    def test_the_token_is_sent_as_the_documented_authorization_header(self):
        self.serve(ESV_PASSAGE)
        get_passage("John 3:16", "esv")
        self.assertEqual(self.urlopen.side_effect.requests[0].get_header("Authorization"), "Token test-token")

    def test_paragraph_only_payloads_lose_their_leading_verse_number(self):
        self.serve(ESV_PARAGRAPHS_ONLY)
        passage = get_passage("John 3:16", "esv")
        self.assertEqual(passage["verses"], [{"verse": 16, "text": "For God so loved the world."}])

    def test_a_rejected_key_falls_back_instead_of_leaking_an_http_error(self):
        self.serve(_http_error(403), BIBLE_API_KJV)
        passage = get_passage("John 3:16", "esv")
        self.assertEqual(passage["translation"], "kjv")
        self.assertIn("rejected the configured API key", passage["fallback"]["reason"])

    def test_the_daily_quota_stops_calling_once_it_is_spent(self):
        with override_settings(UDM_ESV_DAILY_QUOTA=2):
            recorder = self.serve(ESV_PASSAGE, ESV_PASSAGE, BIBLE_API_JOHN3)
            self.assertEqual(get_passage("John 3:16", "esv")["translation"], "esv")
            self.assertEqual(get_passage("John 3:17", "esv")["translation"], "esv")
            third = get_passage("John 3:18", "esv")
        self.assertEqual(third["translation"], "kjv")
        self.assertIn("daily quota", third["fallback"]["reason"])
        self.assertEqual(len(recorder.calls), 3)

    def test_the_counter_is_keyed_to_the_utc_day_it_resets_on(self):
        with override_settings(UDM_ESV_DAILY_QUOTA=1):
            self.serve(ESV_PASSAGE)
            self.assertEqual(get_passage("John 3:16", "esv")["translation"], "esv")
            key = f"bible:esv-quota:{datetime.now(timezone.utc).date().isoformat()}"
            self.assertEqual(cache.get(key), 1)
            tomorrow = (datetime.now(timezone.utc) + timedelta(days=1)).date().isoformat()
            self.assertIsNone(cache.get(f"bible:esv-quota:{tomorrow}"))


class BollsLifeTests(RouterTestCase):
    def setUp(self):
        super().setUp()
        patcher = override_settings(UDM_BOLLS_TRANSLATIONS="asv:ASV,niv:NIV")
        patcher.enable()
        self.addCleanup(patcher.disable)

    def test_the_chapter_is_fetched_once_and_sliced_to_the_span(self):
        recorder = self.serve(BOLLS_CHAPTER)
        passage = get_passage("john 3:16-17", "asv")
        self.assertEqual([row["verse"] for row in passage["verses"]], [16, 17])
        self.assertEqual(recorder.calls, ["https://bolls.life/get-text/ASV/43/3/"])

    def test_strongs_tags_and_margin_notes_are_stripped_from_the_text(self):
        self.serve(BOLLS_CHAPTER)
        text = get_passage("John 3:16", "asv")["text"]
        self.assertNotIn("<", text)
        self.assertNotIn("2889", text)
        self.assertNotIn("begotten: or, beloved", text)
        self.assertEqual(text, "For God so loved the world, that he gave his Son,")

    def test_a_whole_chapter_request_returns_every_verse(self):
        self.serve(BOLLS_CHAPTER)
        self.assertEqual(len(get_passage("John 3", "asv")["verses"]), 4)

    def test_a_publisher_refusal_at_the_source_becomes_fallback_not_prose(self):
        self.serve(BOLLS_NIV_PROTEST, BIBLE_API_KJV)
        passage = get_passage("John 3:16", "niv")
        self.assertEqual(passage["translation"], "kjv")
        self.assertNotIn("prohibited", passage["text"])
        self.assertIn("may not be redistributed", passage["fallback"]["reason"])

    def test_an_unpublished_abbreviation_falls_back(self):
        self.serve([], BIBLE_API_KJV)
        passage = get_passage("John 3:16", "asv")
        self.assertEqual(passage["translation"], "kjv")
        self.assertIn("bolls.life", passage["fallback"]["reason"])


class DeepLinkTests(RouterTestCase):
    def test_a_configured_youversion_id_adds_the_second_authorized_link(self):
        with override_settings(UDM_BIBLE_YOUVERSION_IDS="asv:12"):
            self.serve({**BIBLE_API_WEB, "translation_id": "asv", "translation_name": "American Standard Version"})
            passage = get_passage("John 3:16", "asv")
        self.assertEqual(passage["alternate_link_url"], "https://www.bible.com/bible/12/JHN.3.16")

    def test_no_youversion_link_is_invented_when_the_id_is_not_configured(self):
        self.serve(BIBLE_API_WEB)
        self.assertEqual(get_passage("John 3:16", "web")["alternate_link_url"], "")


class PassageApiTests(UdmAPITestCase):
    """The HTTP contract students read through, with the network replayed."""

    def setUp(self):
        patcher = patch("content.bible_passages.urlopen")
        self.urlopen = patcher.start()
        self.addCleanup(patcher.stop)

    def serve(self, *outcomes):
        recorder = _Recorder(*outcomes)
        self.urlopen.side_effect = recorder
        return recorder

    def test_a_reference_returns_the_unified_passage(self):
        self.serve(BIBLE_API_KJV)
        response = self.client.get("/api/v1/bible/passage/", {"reference": "1Jn 3:16"})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["translation"], "kjv")
        self.assertEqual(body["verses"][0]["verse"], 16)
        self.assertIn("biblegateway.com", body["deep_link_url"])

    def test_a_refused_translation_still_answers_200_with_a_link(self):
        self.serve(BIBLE_API_KJV)
        body = self.client.get("/api/v1/bible/passage/", {"reference": "John 3:16", "translation": "niv"}).json()
        self.assertEqual(body["fallback"]["requested"], "niv")
        self.assertIn("version=NIV", body["deep_link_url"])

    def test_a_bad_reference_is_a_client_error_in_the_standard_envelope(self):
        response = self.client.get("/api/v1/bible/passage/", {"reference": "Frogs 1:1"})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["code"], "invalid")
        self.assertIn("reference", response.json()["errors"])

    def test_an_unknown_translation_lists_what_exists(self):
        response = self.client.get("/api/v1/bible/passage/", {"reference": "John 3:16", "translation": "zzz"})
        self.assertEqual(response.status_code, 400)
        self.assertIn("kjv", response.json()["errors"]["translation"][0])

    def test_a_missing_reference_is_refused(self):
        response = self.client.get("/api/v1/bible/passage/", {"translation": "kjv"})
        self.assertEqual(response.status_code, 400)

    def test_a_passage_no_source_has_is_404(self):
        self.serve(_http_error(404))
        response = self.client.get("/api/v1/bible/passage/", {"reference": "John 40:1"})
        self.assertEqual(response.status_code, 404)

    def test_the_source_listing_labels_what_this_deployment_can_serve(self):
        with override_settings(ESV_API_KEY="", NLT_API_KEY="esv-key"):
            body = self.client.get("/api/v1/bible/sources/").json()
        rows = {row["code"]: row for row in body["results"]}
        self.assertTrue(rows["kjv"]["text_available"], rows["kjv"])
        self.assertTrue(rows["kjv"]["configured"])
        self.assertFalse(rows["niv"]["text_available"])
        self.assertFalse(rows["esv"]["configured"])
        self.assertTrue(rows["nlt"]["configured"])
        self.assertEqual(body["count"], len(body["results"]))


class StoredVerseIdentityTests(UdmAPITestCase):
    """A searched passage has to be as savable as a browsed one.

    Bookmarks and notes hang off a `BibleVerse` row, so the passage endpoint
    carries that row's id whenever the served translation is also stored here.
    """

    def setUp(self):
        patcher = patch("content.bible_passages.urlopen")
        self.urlopen = patcher.start()
        self.addCleanup(patcher.stop)
        translation = BibleTranslation.objects.create(
            code="kjv", name="King James Version", license_name="Public domain",
            attribution="Public domain", offline_allowed=True,
        )
        book = BibleBook.objects.create(translation=translation, name="1 John", order=62, testament="new")
        self.chapter = BibleChapter.objects.create(book=book, number=3)
        self.verse = BibleVerse.objects.create(
            chapter=self.chapter, number=16,
            text="Hereby perceive we the love of God, because he laid down his life for us.",
        )

    def serve(self, *outcomes):
        self.urlopen.side_effect = _Recorder(*outcomes)

    def test_a_stored_verse_returns_the_id_the_bookmark_needs(self):
        self.serve(BIBLE_API_KJV)
        body = self.client.get("/api/v1/bible/passage/", {"reference": "1Jn 3:16"}).json()
        self.assertEqual(body["verses"][0]["id"], str(self.verse.id))

    def test_an_unstored_verse_returns_an_empty_id_rather_than_a_broken_save(self):
        self.serve(BIBLE_API_KJV)
        BibleVerse.objects.update(number=17)
        body = self.client.get("/api/v1/bible/passage/", {"reference": "1 John 3:16"}).json()
        self.assertEqual(body["verses"][0]["id"], "")

    def test_the_stored_copy_never_overrides_what_the_provider_served(self):
        self.serve(BIBLE_API_KJV)
        self.verse.text = "Different wording in this edition."
        self.verse.save()
        body = self.client.get("/api/v1/bible/passage/", {"reference": "1Jn 3:16"}).json()
        self.assertIn("Hereby perceive we the love of God", body["verses"][0]["text"])

    def test_a_translation_row_that_is_inactive_supplies_no_id(self):
        self.serve(BIBLE_API_KJV)
        BibleTranslation.objects.filter(code="kjv").update(is_active=False)
        body = self.client.get("/api/v1/bible/passage/", {"reference": "1Jn 3:16"}).json()
        self.assertEqual(body["verses"][0]["id"], "")
