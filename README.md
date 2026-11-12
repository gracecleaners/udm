# UDM — University Discipleship Mission

UDM equips university students to know Christ, grow in faith, live out biblical truth, and make disciples.

## Product pillars

- **Know Christ:** Scripture, devotionals, prayer, biblical study, and memory.
- **Grow in Christ:** Teaching recordings, mentors, accountability, fellowship, and spiritual disciplines.
- **Make disciples:** Evangelism, missions, outreach, leadership, and disciple making.

## Stack

Flutter (GetX, Dio, SharedPreferences-backed cache) against Django + DRF on PostgreSQL, with SimpleJWT, drf-spectacular, and a customised Django Admin. Staff curation also has a web console — React 18 + Vite + TanStack Query in `admin_ui/`, talking to the same `/api/v1/` API. Redis/Celery, object storage and FCM are introduced with the phases that need them — nothing is stubbed for them yet.

## What runs today

Phases 1 through 5 now run end to end against PostgreSQL:

- `GET /api/v1/home/` returns the greeting, the memory verse, today's devotional, the latest readings and the guides behind the home **Find resources on** list. Every value is read from the database; nothing is hardcoded in the client or the server.
- Devotional and article readers render real API content; each screen has loading, error, empty and offline states.
- The home feed is cached on device. When the network fails the last cached payload is shown and labelled **Offline copy** — never presented as fresh.
- Publishing is server-authoritative: drafts and future-scheduled items are invisible to the API until `publish_at` is reached; admins use Publish now / Schedule actions in Django Admin.
- **Accounts work on device.** Register, sign in, restore the session after a cold start, edit the profile and sign out. Access/refresh tokens live in the platform keystore (`flutter_secure_storage`); the Dio interceptor attaches them, refreshes a rotated pair once on 401, and shares one refresh between concurrent requests. An offline failure never signs anyone out — only the server rejecting the token does.
- **The Profile tab is the account.** It shows the server's copy of the student's details, edits them through `PATCH /api/v1/users/me/` (read-only fields such as email and photo are never echoed back), and holds the only sign-out path. An unverified email is labelled as a capability this build does not have.
- **Reading writes back.** "Mark as read" in both readers posts to `POST /api/v1/progress/`, which is owner-scoped and idempotent. Signed-out readers are offered sign-in instead of a silent no-op. The model is deliberately **not** registered in Django Admin: reading a student's private progress is not an operations task.
- Students browse everything without an account; sign-in is offered from the feed and the readers, never demanded (spec: public content stays open).
- Five tabs — Home, Devotions, Bible, Learn, Profile. **Devotions** is the reading library: published series as a grid of cover tiles, each opening as an ordered list — Introduction first, then Day 1, Day 2 and so on (`GET /api/v1/devotions/series/` and `/api/v1/devotions/series/{id}/`) — while readings filed under no series appear only as the daily reading on the home feed. Bible browses server-curated translation content, reading plans, private bookmarks and notes, and account-scoped progress. **Learn** is the ministry's shelves of teaching recordings, and the memory verse a student is keeping sits on home instead.

- **The Learn tab plays what the ministry publishes.** `GET /api/v1/media/` answers the shelves, `/api/v1/media/{id}/` the recordings on one shelf, and `/api/v1/media/items/{id}/` a single recording with its write-up. Staff paste a YouTube address in the console and the recording plays inside the app's own page (`youtube_player_iframe`); no video file is uploaded, downloaded or stored by UDM. A shelf with nothing published on it is not listed at all, so a tile never opens on an empty shelf.
  - Two things on that page belong to the student and to their account alone: the note they write on the recording (`PUT /api/v1/media/items/{id}/note/`) and the place they stopped (`PUT /api/v1/media/items/{id}/watch/`). Both are read back from the server when the page opens and are never written to the device cache, so a shared phone shows one student nothing about another. Blank text deletes the note; finishing a recording clears its resume point.
  - **Download appears only on a recording with a file the ministry hosts.** A YouTube recording may not be downloaded under its own terms, so the console's optional `download_url` is what makes that button real; a recording with only a video shows Share, the note and the resume, and no Download. Recording artwork is uploaded to the server (`UDM_MEDIA_ROOT`, default `udm_backend/media/`, served by the dev server only); with no artwork uploaded, a YouTube recording shows the thumbnail YouTube already publishes for it.

- **Guided reading is server-curated.** `GET /api/v1/resources/` answers the home **Find resources on** list with only the guides that have a readable step, `/api/v1/resources/{id}/` returns one guide in reading order — an unnumbered starting point first, then Step 1, Step 2 — and `/api/v1/resources/steps/{id}/` serves a single step. A step may carry a video link, which the app opens with **Watch**; a step without one renders no play control at all. Completing a step writes `POST /api/v1/progress/` under the `resource_step` kind, so a student's place in a guide belongs to the student and never appears in Django Admin.

- **Staff curate from a web console.** `admin_ui/` lists, searches, publishes and localizes the same records Django Admin holds, and answers the community prayer wall. It authenticates against a staff-only token route, keeps the refresh token in an `HttpOnly` cookie the page cannot read, and shows the API's field-level reason whenever a write is refused. Read-only where the API is read-only: the student roster has no write route, and Bible translation rows arrive from the licensed sync. See [admin console](docs/admin-console.md).
- **Two console roles, enforced by the API.** A ministry staff account (`is_staff`) adds and edits content and reads the campus directory; a platform admin (`is_superuser`) additionally decides which Bible editions students may read and is the only account Django Admin lets delete a user. The console asks the API which writes the signed-in role may make and renders no control it would refuse, so a limitation shows as a stated read-only screen rather than a button that fails after it is pressed.
- **A dashboard edit reaches students without a release.** Saving any tracked content row bumps one `ContentVersion` number. `GET /api/v1/content-version/` and the same number stamped inside the home, series and guide payloads let the app tell a response it already has from one that moved, and refetch only the screens that changed.

Not built yet: social sign-in, email/phone verification and password reset (no mail provider configured), profile photo upload, FCM, Celery, and Phase 6+ domains. The community module — directories, groups, events and the prayer wall — is not in the app's navigation in this build, while its endpoints and models remain in the backend and the console still answers the prayer queue. Bible text, the teaching videos themselves and community catalogs are not bundled; administrators curate material and confirm distribution rights before publishing. See [roadmap](docs/roadmap.md).

## Local development

The app interface is available in English and French. Choose the language from the translate icon during onboarding or in the Profile tab; the choice is saved on the device. The Bible catalog follows the selected language and lists the versions available to the configured YouVersion app key. For ministry content, admins can enter reviewed French copies in Django Admin; otherwise the backend translates English text on demand through Google Cloud Translation and caches the result. Set `UDM_TRANSLATION_API_KEY` in the backend environment to enable automatic translation. Without a key, the app uses reviewed French copies where available and falls back to the original text.

### 1. Database

Local development targets PostgreSQL only — there is no SQLite fallback, so the settings cannot silently drift from production.

PostgreSQL must be running on `127.0.0.1:5432`. Copy `.env.example` to `.env`, set `UDM_DB_PASSWORD` to a password for the local `udm` role, then create the role and database once with a superuser — the script reads the password from the command line so no credential is ever committed:

```
"C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -v udm_password="same-value-as-UDM_DB_PASSWORD" -f udm_backend\scripts\create_db.sql
```

The script is idempotent: re-running it updates the role instead of failing.

### 2. Backend

```
python -m venv venv && venv\Scripts\activate
pip install -r udm_backend\requirements.txt
cd udm_backend
python manage.py migrate
python manage.py seed_content                  # public-domain KJV only; --flush-existing to replace verses
python manage.py test                          # API, publish-visibility, JWT, privacy
python manage.py createsuperuser
python manage.py runserver
```

Interactive API docs: http://127.0.0.1:8000/api/v1/docs/ · console: `/admin/`.

### Bible catalog

Bible text is not bundled. The reader gets its translation catalog, books, and passages from the [YouVersion Platform API](https://developers.youversion.com/overview) through the UDM backend. Register the app in the [YouVersion Platform Portal](https://platform.youversion.com/), accept the relevant Bible licenses, and set the resulting app key as `YVP_APP_KEY` in the backend environment (see `.env.example`). The app key stays server-side. Only versions enabled for that app are returned. Catalog and book metadata are synchronized on demand; passages are requested by verse and saved as verse records for the existing bookmark and note features. YouVersion catalog entries default to `offline_allowed=false`; app caching remains disabled unless a translation's rights explicitly permit it. The API copyright and publisher link are shown with each translation. You can also add an independently authorized translation in Django Admin or import a reviewed JSON file with `python manage.py import_bible path\to\translation.json`. The file must include a `translation` object (`code`, `name`, `license_name`, `attribution`, optional `source_url`, `offline_allowed`, `is_active`) and a `books` list; each book includes `name`, canonical `order`, `testament` (`old` or `new`), and nested `chapters` and `verses` with positive numbers and verse `text`. The importer is idempotent for matching translation, book, chapter and verse keys, and never deletes catalog rows omitted from a later file. Verify the source's distribution terms before importing it.

Separately, `GET /api/v1/bible/passage/?reference=John+3:16&translation=kjv` resolves a passage on demand from whichever provider is entitled to serve it — public-domain KJV/WEB/ASV, ESV with your `ESV_API_KEY`, NLT with `NLT_API_KEY`, and restricted translations as authorized Bible Gateway / YouVersion deep links. Reference spelling is normalized (`1 Jn 3:16`, `1Jn3:16` and `First John 3:16` reach the same row), verified passages are cached, and when a keyed or upstream provider fails the request answers with public-domain text and the requested version's deep link rather than an error. `GET /api/v1/bible/sources/` reports which translations are currently servable and which are waiting on a key. Every provider key is optional and server-side; a missing key degrades to a deep link instead of an exception. The mobile Bible tab reads both: a reference search box with the server-driven version picker, the substitution notice with its authorized Bible Gateway / YouVersion buttons, and offline copies only where `offline_allowed` says so. See [Bible router](docs/bible-router.md).

`DJANGO_SETTINGS_MODULE` selects `udm_backend.settings.dev` (the default in `manage.py`) or `.prod`; production requires `UDM_SECRET_KEY` and `UDM_ALLOWED_HOSTS` and refuses to start without them.

### 3. Mobile

```
cd udm_frontend
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=UDM_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` reaches the host from an Android emulator; use the machine's LAN address on a physical device (`--dart-define=UDM_API_BASE_URL=http://192.168.x.x:8000/api/v1`). The debug manifest sets `usesCleartextTraffic` so a plain-http dev server is reachable; the release manifest does not, so a release build talks to https only. Tokens are held in the Android keystore / iOS keychain, never in SharedPreferences.

With the dev server running, `python scripts\phase2_smoke.py` from `udm_backend` walks every Phase 2 client contract against the live API — registration, profile patch, reading progress and its idempotency, the refused cases, refresh rotation and blacklisting, logout — and is the check to re-run after touching anything under `accounts/`. It registers a throwaway account, so point it at a development database.

### 4. Ministry console

```
cd admin_ui
npm install
npm run dev          # http://localhost:5173, proxies /api to 127.0.0.1:8000
```

Sign in with a staff account (`is_staff=True`; `python manage.py createsuperuser` makes one) — a student account is refused at the token endpoint rather than handed useless tokens. The console curates devotional series and their days, articles, memory verses, the resource guides and the steps inside them, plans, the Learn shelves and the recordings filed on them, and the campus directory, and moderates the community prayer wall. Publishing is a field write the API derives a state from, licensed translation and synced-scripture rules are enforced server-side, and French copies are stored as overrides. Recording artwork is uploaded from the console as a file, which is the one write that goes over `multipart/form-data` rather than JSON. A platform admin sees the licensing screen as writable; to a staff account it is read-only. See [admin console](docs/admin-console.md).

## Checks

| Area | Command |
| --- | --- |
| Backend models, config, URLs | `python manage.py check` |
| Backend behaviour | `python manage.py test` |
| Phase 2 contracts against a running API | `python scripts\phase2_smoke.py` |
| Bible router unit tests (no network) | `python manage.py test content.tests.test_bible_passages` |
| Bible router against the live providers | `python scripts\bible_passage_check.py` · add `--offline` to skip network |
| Bible router through the app's own API layer (opt-in, needs a running backend) | set `UDM_LIVE_API_URL`, then `flutter test test/data/live_bible_api_test.dart` |
| Mobile static analysis | `flutter analyze` |
| Mobile unit + widget tests | `flutter test` |
| Console types and bundle | `npx tsc --noEmit`, `npm run build` in `admin_ui` |
| Console lint | `npm run lint` in `admin_ui` |

## Ground rules

- **No placeholder functionality.** A control either performs a real operation or is not rendered.
- **Backend is authoritative.** Content, schedules and progress come from the API; dynamic content is never baked into the client.
- **Bible text is public domain or licensed.** A memory verse that stores its own text may only cite a translation listed in `UDM_MEMORY_VERSE_TRANSLATIONS` (`kjv,web,asv` today); one linked to a synced verse inherits that translation's licence. Full Bible translations require license and attribution metadata in the Bible catalog, and the app honors each translation's offline permission. Scraping copyrighted translations is prohibited.
- **Private stays private.** Prayer journals and personal notes are never exposed through public endpoints, admin listings, analytics or push payloads.
- **No secrets in git.** `.env`, `google-services.json` and `GoogleService-Info.plist` are ignored; commit `.env.example` changes instead.

## Documentation

[architecture](docs/architecture.md) · [domain model](docs/domain-model.md) · [roadmap](docs/roadmap.md) · [design system](docs/design-system.md) · [admin console](docs/admin-console.md) · [Bible router](docs/bible-router.md)

The OpenAPI schema generated from the code (`/api/v1/schema/`) is the API contract; it is not duplicated by hand in markdown.
