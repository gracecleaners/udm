# Bible passage router

`udm_backend/content/bible_passages.py` answers one question — *give me this
passage in this translation* — from whichever of four sources is allowed and
available, and never fails the request because a source was missing, rate
limited or unlicensed. It is a Python module rather than the TypeScript the
brief sketched, for two project reasons: the API keys must stay server-side
(same rule as `YVP_APP_KEY`), and the reader already gets all Scripture through
this backend. Its wire field is therefore `deep_link_url`, snake_case like every
other field the API returns, rather than the brief's `deepLinkUrl`.

Two modules:

| File | Responsibility |
| --- | --- |
| `content/bible_refs.py` | Reference parsing and normalization, provider markup removal, authorized deep-link builders. No network, no settings. |
| `content/bible_passages.py` | Routing matrix, the four providers, caching, quota counting, fallback, the unified passage. |

Endpoints (`content/views.py`, both `AllowAny` on the `content` throttle scope):

| Route | Purpose |
| --- | --- |
| `GET /api/v1/bible/passage/?reference=&translation=` | One passage. `translation` may be blank (deployment default), a code, an abbreviation or the version's own name. |
| `GET /api/v1/bible/sources/` | The routing matrix as this deployment is configured: which codes serve text, which are deep-link-only, which are missing a key. |

## The passage

Whatever answers, the response shape does not change:

```json
{
  "reference": "1 John 3:16",
  "translation": "kjv",
  "translation_name": "King James Version",
  "source": "bible_api",
  "text": "Hereby perceive we the love of God, because he laid down his life for us.",
  "verses": [{ "verse": 16, "text": "Hereby perceive we the love of God, …", "id": "6f1c…" }],
  "deep_link_url": "https://www.biblegateway.com/passage/?search=1+John+3%3A16&version=KJV",
  "alternate_link_url": "",
  "attribution": "King James Version (public domain).",
  "offline_allowed": true,
  "fallback": null,
  "cached": false
}
```

`text` is the joined prose with every trace of provider markup removed;
`verses[]` keeps the per-verse split so a reader can number them.
`offline_allowed` is what the app gates local caching on, and stays `false` for
anything under a licence. `fallback` is `null` unless the requested translation
could not be served, in which case the text came from the public-domain default
and `fallback` names what was asked for and why it was replaced.

`verses[].id` is added by `views.py`, not by a provider: it is the database id of
that verse when this deployment has already imported it, and `""` when it has
not. The app bookmarks and annotates against that id, so it offers a save action
only for verses that really have a row to save against — a verse served from
bible-api.com that was never imported is read and linked out, never offered as a
no-op bookmark. Provider text is never overridden by the local copy; the id
labels it, nothing more.

## Routing matrix

| Code | Provider | Key | Status |
| --- | --- | --- | --- |
| `kjv` `web` `asv` | bible-api.com | none | Verified live. Public domain, `offline_allowed=true`, cached 30 days. |
| `esv` | api.esv.org v3 | `ESV_API_KEY` | Endpoint and unauthenticated 403 verified live; a successful payload is parsed from the published contract, not from a captured response. Cached 1 day. |
| `nlt` | nlt.to | `NLT_API_KEY` | **Not working at the vendor.** Documented endpoint 404s; see *Verified against the live services*. Cached 1 day. |
| `niv` `nkjv` `csb` `nasb` `msg` `amp` | deep link only | none | No text source is enabled by default. See *Licensing gates*. |
| any code mapped in `UDM_BOLLS_TRANSLATIONS` | bolls.life | none | Chapter-level fetch, sliced to the requested span. Opt-in, because rights are the operator's to assert. |

Unknown codes answer 400 and list what exists; a reference naming no chapter is
a 400, never a silently substituted verse.

## Reference normalization

`parse_reference` folds spelling to one canonical form before anything is
fetched, so a bookmark, a search box and a reading plan agree:

- `1 John 3:16`, `1John 3:16`, `1Jn 3:16`, `i jhn 3:16`, `1st John 3:16`,
  `1 JOHN 3:16` and `1jn3:16` are the same passage and share one cache entry.
- A leading roman numeral is folded to a digit only when the digit form is a
  real book, which is why `Isaiah` is not read as “1 saiah”.
- Book aliases cover the common abbreviations of all 66 books, with bolls.life's
  1-based Protestant book numbers (John = 43) and OSIS codes (`JHN`) attached —
  both are what providers address books by.
- Refused: no book, no chapter, chapter zero, an end before a start, a chapter
  above 150, and a span wider than `UDM_BIBLE_MAX_VERSES` (checked before any
  request is made).

`clean_text` is the other half: it deletes apparatus whose *content* is not
Scripture (`<S>2889</S>` Strong's numbers, `<sup>` margin notes) before it drops
remaining tags, decodes entities, closes the gap markup left in front of a
comma, and collapses whitespace. Nothing downstream sees a tag or a concordance
number.

## Caching, quota and fallback

- Served passages live in `django.core.cache` under
  `bible:passage:{code}:{OSIS-ish key}` — no spaces, so memcached and Redis are
  both safe targets. Public domain 30 days, licensed text 1 day: a stale copy of
  a licensed text is worse than one extra request.
- ESV's free tier is 5,000 requests a day. `_consume_esv_quota` counts calls per
  UTC day in the cache and stops sending them once spent. The counter is
  advisory — two workers can both pass the check and Crossway still enforces
  the real limit — its job is to stop one runaway client burning the day.
- Any provider failure (`MissingCredential`, `RateLimited`,
  `UpstreamUnavailable`, `PassageNotFound`, `TranslationRefused`) falls back to
  `UDM_BIBLE_DEFAULT_TRANSLATION`, and the response keeps the deep link of the
  translation that was *asked for*, so the reader can finish the verse at an
  authorized site. When the fallback fails too, the original error is the one
  reported; when the default translation is itself the unavailable route, the
  error is raised rather than looping into itself.
- Failures are never fabricated into success: a 404 from the source is a 404
  from the API, and a bad reference is a 400 with the reason.

## Licensing gates

The brief asked for the NIV, NKJV, CSB, NASB, The Message and AMP "through
bolls.life, with a fallback helper that generates authorized Bible Gateway or
YouVersion deep-link URLs". The helper is there. The text route is deliberately
not enabled, because that is what the evidence says:

- `https://bolls.life/get-text/NIV/43/3/` answers HTTP 200 with a well-formed
  verse list whose text is Biblica's prohibition letter ("Biblica, Inc. has
  prohibited me from using the NIV translation…"). `_PROHIBITION` recognizes it
  against the whole chapter and raises `TranslationRefused`, so no slice of that
  letter can ever be quoted to a student as Scripture.
- `…/get-text/CSB/43/3/` and `…/get-text/BBE/…` return `[]`: an unpublished
  abbreviation is an empty list, not an error status.
- bolls.life's copies are scraped from an aggregator, which is not a grant of
  redistribution rights, and the repo ground rule is that copyrighted
  translations must not be scraped.

So a restricted code serves text only when an operator who holds the licence
maps it in `UDM_BOLLS_TRANSLATIONS` (`nkjv:NKJV,csb:CSB17`). Everything else
about those versions is honest: the response says why it substituted, names the
publisher, and links out.

Deep links use BibleGateway's own `version` abbreviations, checked against its
live passage pages on 2026-11-11 for all eleven routed versions — worth
recording because `version=NV` (the old NIV code) now renders an empty page
while `version=NIV` serves text. The bible.com link appears only when an
operator supplies numeric Bible ids in `UDM_BIBLE_YOUVERSION_IDS`: those ids are
per-app licence, and this app's own `YVP_APP_KEY` enables 11 English and 4
French Bibles, none of them NIV, NLT or ESV, so no id is guessed here.
Attribution strings must stay attached to any licensed text the app renders.

## In the mobile app

The Bible tab (`udm_frontend/lib/app/modules/bible/`) reads the router directly.
A reference lookup panel sits above the catalog browser and is always rendered:
it needs no synced rows, so it works in a deployment that has never run
`import_bible`.

- `BibleController.load()` fetches `/bible/sources/` **before** it checks the
  catalog, and the catalog check no longer gates the tab — with no translations
  synced, the browse pickers are replaced by a notice while lookup keeps working.
- The version picker is server-driven, one entry per routed code, labelled with
  the server's own version name and suffixed `· authorized link only` when
  `text_available` is false, `· needs a key` when `configured` is false. The
  app never hardcodes which translation is legally servable.
- `searchPassage()` calls `UdmApi.biblePassage(reference, translation:)`. The
  result is headed by the served version and reference, numbers each verse, and
  keeps the attribution line attached.
- Only a passage with `offline_allowed: true` is written to `LocalCache`
  (`bible.passage.{code}.{reference}` with non-alphanumerics folded out);
  licensed and fallback-served text is displayed and never persisted.
- A non-null `fallback` renders `"{requested version}: {reason}"` beside the
  public-domain text that replaced it, plus the authorized buttons — Bible
  Gateway whenever the response has a `deep_link_url`, YouVersion only when it
  also has an `alternate_link_url`. Both are labelled with the version that was
  *asked for*, not the one that was served.
- Bookmark and note actions appear only on verses whose `id` is non-empty, per
  the enrichment rule above.
- No provider key reaches the device. The app knows one URL (`UDM_API_BASE_URL`)
  and the endpoint answers the rest.

## Verified against the live services

On 2026-11-11, from this machine, against the real endpoints:

- `scripts/bible_passage_check.py` — **86 checks, 0 failures**, covering KJV,
  WEB and ASV fetched over the network, six restricted codes refused and
  fallen back with the requested version's link, ESV and NLT answering without
  a key, cache reuse across two spellings, and every normalization rule above.
- `bible-api.com`: keys are `reference`, `verses[{book_id, book_name, chapter,
  verse, text}]`, `text`, `translation_id`, `translation_name`,
  `translation_note`. **Its default translation is WEB, not KJV**, so the
  `translation` parameter is always sent, and the echoed `translation_id` is
  checked — a service answering a different version raises `PassageNotFound`
  rather than mislabeling text. A real 404 returns JSON `{"error":"not found"}`;
  an unknown *translation* returns an nginx HTML page, which is why a non-JSON
  body is handled as an upstream failure.
- bolls.life: chapter URLs work, `/get-text/KJV/43/3/16/` (per verse) 404s, so
  verses are sliced from the chapter here. Catalog lives in static JS modules,
  not a JSON endpoint, and exposes 156 abbreviations.
- ESV: `https://api.esv.org/v3/passage/text/?q=…` without a token is HTTP 403
  `{"detail": "Authentication credentials were not provided."}` — no
  `WWW-Authenticate`, no quota headers. **The successful payload shape is
  unverified**: `_from_esv` parses the published contract (`passages[].verses[]`
  with `chapter`/`verse`/`text`, and `paragraphs[]` as a fallback whose leading
  verse number is stripped) and cannot be exercised until a key is configured.
- NLT: `api.nlt.to/api/text` answers 404 (`{"Message":"No HTTP resource was
  found…"}`) for every parameter spelling, and `api.nlt.co` fails its TLS
  handshake. The route exists so a licensed key can be used the day the vendor
  documents a working URL (`UDM_NLT_API_URL`), and until then NLT is
  functionally deep-link-only. **It has never returned a verse.**
- Endpoint-level: 200 with the unified schema, 400 with
  `errors.reference`/`errors.translation` in the standard envelope, 404 for a
  passage no source holds, and `/bible/sources/` reporting `configured=false`
  for the keyless ESV and NLT.

## Checks

```
cd udm_backend
python manage.py test content.tests.test_bible_passages   # 51 tests, no network
../venv/Scripts/python.exe scripts/bible_passage_check.py          # live providers
../venv/Scripts/python.exe scripts/bible_passage_check.py --offline # parse + matrix only

cd ../udm_frontend
flutter test test/modules/bible_passage_test.dart        # 7 tests, captured payloads
flutter test test/core/translations_test.dart             # 5 tests, FR copy of the new strings
UDM_LIVE_API_URL=http://127.0.0.1:8000/api/v1 flutter test test/data/live_bible_api_test.dart
```

The unit tests replay provider payloads instead of calling out: fixtures marked
*captured live* above are byte-for-byte response bodies, and the ESV and NLT
fixtures come from the vendors' published contracts.

`live_bible_api_test.dart` is skipped unless `UDM_LIVE_API_URL` names a running
backend. Pointed at one, it drives the app's own `UdmApi` against the real
router — sources shape, `Jn 3:16` normalization, the NIV refusal carrying
`version=NIV`, a three-verse span, the `verses[].id` contract, and a 400 on a
reference that names no book. It passed 6/6 against this deployment on
2026-11-11.

## Known gaps

- **ESV success path is unverified.** No `ESV_API_KEY` exists in this
  development environment, so only its 403 and the fallback have been observed.
- **NLT has never served a verse.** The vendor endpoint is dead; the route is
  configurable, not working.
- **Only English codes are routed.** `bible-api.com` returned 404 for
  `french`, `ostervald` and `lrth` on 2026-11-11, so there is no verified
  public-domain French text source to route to yet. French readers keep the
  YouVersion browse endpoints, whose app key enables Segond 1910, Martin 1744,
  Darby and Ostervald; adding one here means a confirmed public-domain copy
  imported with `manage.py import_bible` or a new provider.
- **Chapter counts are not checked locally.** `John 40:1` reaches the provider
  and comes back 404, which costs a request; per-book chapter tables would move
  that to a local refusal.
- **The curation console has no router screen.** The matrix is env-driven by
  design, since it encodes licensing rather than editorial choice; an operator
  changes `UDM_BOLLS_TRANSLATIONS` and the app's picker follows.
- **The mobile flow is verified by tests, not by pixels.** No browser surface
  was available in this environment, so the Bible tab's lookup was checked with
  widget tests on captured payloads plus the live `UdmApi` test above. A pass on
  a device or an emulator screenshot is still worth taking once a translation is
  imported with `manage.py import_bible`, since that is what fills `verses[].id`
  and turns a searched verse into a bookmarkable one.
