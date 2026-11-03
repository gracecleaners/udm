# UDM — University Discipleship Mission

UDM equips university students to know Christ, grow in faith, live out biblical truth, and make disciples.

## Product pillars

- **Know Christ:** Scripture, devotionals, prayer, biblical study, and memory.
- **Grow in Christ:** Courses, mentors, accountability, fellowship, and spiritual disciplines.
- **Make disciples:** Evangelism, missions, outreach, leadership, and disciple making.

## Stack

Flutter (GetX, Dio, SharedPreferences-backed cache) against Django + DRF on PostgreSQL, with SimpleJWT, drf-spectacular, and a customised Django Admin. Redis/Celery, object storage and FCM are introduced with the phases that need them — nothing is stubbed for them yet.

## What runs today

Phase 1 and the whole of Phase 2 are wired end to end against PostgreSQL:

- `GET /api/v1/home/` returns the greeting, verse of the day, today's devotional and latest articles. Every value is read from the database; nothing is hardcoded in the client or the server.
- Devotional and article readers render real API content; each screen has loading, error, empty and offline states.
- The home feed is cached on device. When the network fails the last cached payload is shown and labelled **Offline copy** — never presented as fresh.
- Publishing is server-authoritative: drafts and future-scheduled items are invisible to the API until `publish_at` is reached; admins use Publish now / Schedule actions in Django Admin.
- **Accounts work on device.** Register, sign in, restore the session after a cold start, edit the profile and sign out. Access/refresh tokens live in the platform keystore (`flutter_secure_storage`); the Dio interceptor attaches them, refreshes a rotated pair once on 401, and shares one refresh between concurrent requests. An offline failure never signs anyone out — only the server rejecting the token does.
- **The Profile tab is the account.** It shows the server's copy of the student's details, edits them through `PATCH /api/v1/users/me/` (read-only fields such as email and photo are never echoed back), and holds the only sign-out path. An unverified email is labelled as a capability this build does not have.
- **Reading writes back.** "Mark as read" in both readers posts to `POST /api/v1/progress/`, which is owner-scoped and idempotent. Signed-out readers are offered sign-in instead of a silent no-op. The model is deliberately **not** registered in Django Admin: reading a student's private progress is not an operations task.
- Students browse everything without an account; sign-in is offered from the feed and the readers, never demanded (spec: public content stays open).
- Five tabs — Home, Bible, Learn, Community, Profile. Home and Profile are live; Bible (Phase 3), Learn (Phase 4) and Community (Phase 5) show a status panel naming the phase that ships them and pointing at what already works today. They contain no dead controls.

Not built yet: social sign-in, email/phone verification and password reset (no mail provider configured), profile photo upload, FCM, Celery, and the Phase 3+ domain apps. See [roadmap](docs/roadmap.md).

## Local development

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

## Checks

| Area | Command |
| --- | --- |
| Backend models, config, URLs | `python manage.py check` |
| Backend behaviour | `python manage.py test` |
| Phase 2 contracts against a running API | `python scripts\phase2_smoke.py` |
| Mobile static analysis | `flutter analyze` |
| Mobile unit + widget tests | `flutter test` |

## Ground rules

- **No placeholder functionality.** A control either performs a real operation or is not rendered.
- **Backend is authoritative.** Content, schedules and progress come from the API; dynamic content is never baked into the client.
- **Bible text is public domain or licensed.** Only translations listed in `UDM_FEATURED_VERSE_TRANSLATIONS` (KJV today) can be saved; the check is enforced in `FeaturedVerse.clean()`, not by convention. Scraping copyrighted translations is prohibited.
- **Private stays private.** Prayer journals and personal notes are never exposed through public endpoints, admin listings, analytics or push payloads.
- **No secrets in git.** `.env`, `google-services.json` and `GoogleService-Info.plist` are ignored; commit `.env.example` changes instead.

## Documentation

[architecture](docs/architecture.md) · [domain model](docs/domain-model.md) · [roadmap](docs/roadmap.md) · [design system](docs/design-system.md)

The OpenAPI schema generated from the code (`/api/v1/schema/`) is the API contract; it is not duplicated by hand in markdown.
