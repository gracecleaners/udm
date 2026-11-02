# UDM — University Discipleship Mission

UDM equips university students to know Christ, grow in faith, live out biblical truth, and make disciples.

## Product pillars

- **Know Christ:** Scripture, devotionals, prayer, biblical study, and memory.
- **Grow in Christ:** Courses, mentors, accountability, fellowship, and spiritual disciplines.
- **Make disciples:** Evangelism, missions, outreach, leadership, and disciple making.

## Stack

Flutter (GetX, Dio, SharedPreferences-backed cache) against Django + DRF on PostgreSQL, with SimpleJWT, drf-spectacular, and a customised Django Admin. Redis/Celery, object storage and FCM are introduced with the phases that need them — nothing is stubbed for them yet.

## What runs today

Phase 1 is wired end to end, plus the first vertical slice of Phase 2:

- `GET /api/v1/home/` returns the greeting, verse of the day, today's devotional and latest articles. Every value is read from the database; nothing is hardcoded in the client or the server.
- Devotional and article readers render real API content; each screen has loading, error, empty and offline states.
- The home feed is cached on device. When the network fails the last cached payload is shown and labelled **Offline copy** — never presented as fresh.
- Publishing is server-authoritative: drafts and future-scheduled items are invisible to the API until `publish_at` is reached; admins use Publish now / Schedule actions in Django Admin.
- `POST /api/v1/progress/` is owner-scoped and idempotent. The model is deliberately **not** registered in Django Admin: reading a student's private progress is not an operations task.
- Four tabs (Pray, Grow, Community, More) show a status panel naming the phase that ships them. They contain no dead controls.

Not built yet: accounts/sign-up flows in the app, secure token storage and the refresh interceptor, FCM, Celery, and the Phase 3+ domain apps. See [roadmap](docs/roadmap.md).

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

`10.0.2.2` reaches the host from an Android emulator; use the machine's LAN address on a physical device.

## Checks

| Area | Command |
| --- | --- |
| Backend models, config, URLs | `python manage.py check` |
| Backend behaviour | `python manage.py test` |
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
