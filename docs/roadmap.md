# Delivery roadmap

Each phase ends with a usable, reviewable increment and its own acceptance checks before the next phase begins. The larger vision is intentionally staged so the first release has a coherent vertical slice. Phases 1 through 5 are complete; the next increment is Phase 6. Phase 7's staff console was pulled forward, because every phase above it needs content someone has to curate — see **Staff console** below.

1. **Architecture and setup (complete):** architecture, domain model, roadmap, design tokens, Flutter and Django project skeletons, API contract and environment conventions.
2. **Core mobile experience (complete):** onboarding, authentication/session, profile, server-backed home feed, navigation and accessible loading/error/empty states.
3. **Spiritual content:** devotional series and their days, licensed Bible reading, plans, bookmarks, notes, progress, offline reading and sync.
4. **Teaching media and memory:** the ministry's shelves of recorded teaching, inline playback, private notes and resume points, and memory verses.
5. **Community and campus (complete):** directory, fellowship discovery, scoped groups, events, prayer sharing with consent and moderation.
6. **Mission and growth:** evangelism resources, goals, achievements, mentoring/accountability flows and recommendations.
7. **Administration (partly complete — console):** web curation console with a staff-only session, ministry-staff and platform-admin write scopes, a moderation queue and read-only operational views. Scheduling, role-scoped campus management and operational analytics remain.
8. **Production readiness:** privacy/security review, observability, backups/restore, performance, offline conflict handling, deployment and release process.

## Phase 1 acceptance

- Architecture and system boundaries are documented.
- Domain entities and privacy/ownership rules are mapped.
- Mobile design tokens and component direction are recorded.
- API versioning, authentication and offline behavior are defined.
- Initial Flutter/Django skeletons can be added without committing secrets or copyrighted Bible text.

All five are met in code, not only on paper:

- Django runs from a settings package (dev/prod), PostgreSQL only, with DRF, SimpleJWT (rotation + blacklist), CORS, drf-spectacular and a shared error envelope. Default permission is `IsAuthenticated`; public content endpoints opt into `AllowAny`.
- `accounts` ships a custom email user; `content` ships devotional series, devotional, article and memory-verse models plus owner-scoped progress, with publish-window querysets, license checks in `Model.clean()` (a stored memory-verse copy must cite a translation listed in `UDM_MEMORY_VERSE_TRANSLATIONS`), admin curation actions and an idempotent seed command.
- Flutter is a GetX feature-first app: themed light/dark tokens, named routes with bindings, Dio client with typed failure mapping, cached home payload with honest offline labelling. `flutter analyze` is clean and `flutter test` passes.
- Phase 2's first vertical slice (server-backed home feed, devotion and article readers, shell navigation) was pulled forward to prove the contract end to end rather than shipping disconnected screens.

## Phase 2 acceptance

- A student can register, sign in, restore the session after a cold start, edit their profile and sign out on device.
- Sessions are held and refreshed securely; an expired access token is renewed without the user noticing, and a rejected refresh is the only thing that ends the session.
- The profile the API returns is the profile the app shows; the app can only change fields the API lets it change.
- Public content stays browsable without an account (spec: exploration before registration).
- Reading activity is written back per student, privately, and never surfaces to another user.
- Onboarding, home feed, shell navigation and every loading/error/empty/offline state are reachable and honest.

All six are met in code and verified:

- `accounts` exposes `POST /auth/register/`, `/auth/token/`, `/auth/token/refresh/`, `/auth/token/logout/` and `GET|PATCH /users/me/`; the token, register and logout endpoints are throttled under the `auth` scope; `udm_backend/accounts/tests/test_auth.py` covers registration, the password minimum length, owner scoping, read-only fields, rotation and blacklisting. `python manage.py test` is green.
- On device, `SecureTokenStore` keeps the pair in the keystore/Keychain and `AuthInterceptor` attaches it, refreshes once on a 401 and shares a single in-flight refresh between concurrent requests. `SessionController` restores the session at startup and is the only writer of auth state; a profile it cannot re-fetch offline is shown as **last downloaded**, never as live. The auth screens and Profile tab go through it. `scripts/phase2_smoke.py` re-checks those contracts against a running server.
- `UserProfile.patchPayload()` sends only editable fields, so email and photo can never be echoed back and silently overwritten; an unverified email is labelled as a capability this build does not have rather than being presented as a broken button.
- Sign-in is offered from the feed and from both readers; no route demands it. `content`'s publish-visibility rules still govern what an anonymous and a signed-in student see, and the two are the same for public content.
- Registering replaces the navigation stack with the shell, so a new account lands in the app instead of back on the sign-in form it may have arrived from; the session is already live the moment the server answers.
- `TracksReadingProgress` (a mixin over `GetxController`) is shared by the devotion and article readers and posts to the idempotent `POST /progress/`, so re-reading an item updates one row instead of appending history. The model stays out of Django Admin.
- `flutter analyze` is clean and `flutter test` passes with no layout overflows, including on a 320dp-wide phone.

## Phase 3 acceptance

- Bible content is managed on the server as translation, book, chapter, and verse records with license and attribution metadata; the API serves active translations and chapter text without bundling copyrighted text in the app.
- The Bible tab browses translation/book/chapter content, shows attribution, reads chapters cached for offline use only when the translation permits it, and retries private offline bookmark/note writes per account. It also looks up any reference through the passage router, with the server-driven version list, the licensing notice and authorized deep-link buttons where a version may not be printed.
- Students can save private bookmarks and notes, browse published reading plans, and record owner-scoped assignment completion. These records have database uniqueness constraints and private API querysets.
- Django Admin supports licensed translation, Scripture hierarchy, and reading-plan curation. Automated API checks cover public reading, private data isolation, idempotency, and plan progress.

All four are implemented. Reading translations are served through the YouVersion Platform API adapter: the translation catalog and book metadata update on demand, while fetched verse records support the existing private bookmark and note flows. Every translation carries publisher attribution; offline caching stays disabled unless the translation rights explicitly allow it. Reading plans remain an independent catalog that staff curate. Secure per-account sync queues retry bookmark, note, deletion and plan-progress changes on refresh or session restoration. A user can inspect, edit and remove their saved items in the tab.

## Phase 4 acceptance

- Students browse the Learn tab's shelves and the recordings on each one; a shelf with nothing published on it is not listed, so a tile never opens on an empty shelf.
- A recording plays inside the app from the ministry's own YouTube address. Playback needs no account, and a recording with no link at all is presented as what it is — the write-up, with no play control offered.
- A student's note on a recording and the place they stopped in it are written to and read from their account only. Neither is cached on the device, neither appears in a staff route, and deleting one takes it off every device the account reaches.
- Download is offered only where staff attached a file the ministry distributes itself, because a recording hosted by someone else may not be downloadable through this app.
- Memory verses come from active translations with recorded license metadata; review progress is private to the student.
- Django Admin and the staff console curate shelves, recordings and memory verses, and API checks cover note and watch privacy, shelf and item ordering, HTTPS and YouTube-link rules, and review privacy.

All six are implemented. The shelves, recordings and memory verses start empty until staff curate them. Video and audio stay with the ministry's YouTube channel; this backend stores addresses, write-ups and uploaded artwork, not media files.

## Phase 5 acceptance

- Students can browse active university, campus, fellowship, group and upcoming event catalogs; group visibility follows campus and membership scope.
- Students can request group membership; group leaders can approve or decline requests, with capacity enforced on the server.
- Event registration is idempotent and capacity-bounded. Online meeting links are returned only to registered students.
- Prayer sharing requires explicit consent. Private requests are owner-only, group requests are limited to approved members, and public requests appear only after staff moderation.
- Group leaders can moderate only consented group prayer requests for their group; the public moderation queue never includes private or group requests.
- API tests cover directory visibility, membership, capacity, event registration, prayer consent and visibility, and moderation permissions.

All six are implemented. The directory and events catalog start empty for staff curation. Prayer requests are intentionally excluded from Django Admin; moderation is exposed through permission-scoped APIs so staff cannot browse private or group prayer text.

## Staff console (pulled forward from Phase 7)

`admin_ui/` is the web console ministry staff use to curate what students read and watch: devotional series and their days, articles, reading plans and their days, the Learn tab's shelves and the recordings filed on them, memory verses, the university/campus/fellowship/group/event directory, the student roster and the community prayer queue. It is documented in [admin-console.md](admin-console.md).

- Console auth is a separate, staff-gated route family (`/api/v1/auth/admin/…`): a student account is refused at the token endpoint instead of being issued tokens it cannot use. The access token stays in memory and the refresh token in an `HttpOnly`, `SameSite=Lax` cookie scoped to that route, so no script on the page can read it; logout blacklists it server-side.
- `/api/v1/admin/…` mirrors the curation rules Django Admin already enforces — every write runs `Model.full_clean()`, so licensing, HTTPS media, capacity, unique-together and one-per-day rules reject the same rows in both places. Publishing remains a write of `is_published`/`publish_at`; `publish_state` is derived and read-only, and resources without a date field never offer a *Scheduled* state.
- French copies are written as `translations.fr` overrides that preserve locales the form cannot see, and scripture can only be chosen from `BibleVerse` rows the licensed sync produced — the console cannot invent a verse.
- Read-only is rendered as read-only: the roster has no write route, so it has no buttons, and translation records can only be shown or hidden, with deletion left to Django Admin, which lists the collateral first.
- **Two roles, decided by the API and mirrored by the console.** A ministry staff account (`is_staff`) curates content and reads the directory; a platform admin (`is_superuser`) additionally owns Bible licensing — the one write whose effect cannot be undone by switching the flag back — and is the only account Django Admin lets delete a user. Because every curation endpoint is staff-readable, the split is enforced control by control (`ResourceConfig.writableBy`), not by hiding pages: a staff account on a licensing screen sees the same list and search with no button the API would refuse.
- **A console edit reaches a student with no release.** Saving a tracked content row bumps one `ContentVersion` number, served at `GET /api/v1/content-version/` and stamped inside the home and series payloads. The mobile app polls it, adopts the newer reading first and refetches only the screens whose stamp moved, so the cached copy is never shown as fresh when it is stale.
- Verified against the running API on 2026-11-11: every screen listed against the live API with no console errors, the writes above proven end to end, and each refusal surfacing the API's field-level reason. Both roles were signed in against the same server to confirm the licensing screen changes shape between them. `npm run build`, `tsc --noEmit` and `npm run lint` pass; `python manage.py test` is green.
- Still open in this area: the console is only served by Vite (hosting is Phase 8), its desktop-width layout has not been visually confirmed on a real wide viewport, unused dashboard dependencies are still installed, and Phase 7's scheduling, role-scoped campus permissions and analytics have not started.

## Known deviations and deferred work

- **GetX package:** the `getx` meta-package no longer resolves on pub.dev, so the app depends on `get` 4.7.3, the maintained package by the same author. No API change was required.
- **No auth-guarded routing:** deliberately, because the spec asks students to explore public content before registering. Screens that need a session prompt for one in place instead of redirecting, and the shell never blocks.
- **Community is complete but not in the app's navigation.** The ministry asked for Devotions in that slot, so the shell's five tabs are Home, Devotions, Bible, Learn and Profile. Phase 5's directories, groups, events and consent-scoped prayer sharing stay served by the API, and the console still answers the prayer queue; the mobile community screens were unmounted rather than deleted, so the surface can come back without a rebuild.
- **Social sign-in, email and phone verification, password reset:** all need a third-party credential (OAuth app, SMS account, outbound mail provider) that does not exist yet, so they are absent rather than stubbed. The Profile tab labels the email field as unverified and offers no verify button.
- **Profile photo upload:** no object storage is configured; `photo` is server-owned and read-only in the client until Phase 8 brings media storage.
- **Read state is not prefetched:** `/progress/` has no server-side filter by kind, so a reader cannot ask "have I read this?" without pulling the student's whole history. Each reader therefore starts unmarked and marks on demand.
- **Offline sign-out can't revoke:** signing out with no network clears the device tokens but leaves the refresh token valid for its 14-day lifetime, because revocation is a server call. Signing out while online calls `/auth/token/logout/` and blacklists it.
- **Bundle id:** `applicationId` is still `com.example.udm_frontend`. It must be replaced before any store upload, since it cannot be changed afterwards.
- **Local infrastructure:** local development uses a native PostgreSQL instance, which the team chose over a container toolchain. Docker/Compose returns with the staging/production work in Phase 8, so no half-configured container files are committed. Redis, Celery and FCM arrive with the phases that need them.
- **Admin privacy:** `UserContentProgress` is intentionally unregistered from Django Admin. Staff status does not imply a right to read a student's private discipleship record.
- **Local dev dataset:** `seed_content` publishes one series of three devotional readings, two articles, ten memory verses and three Learn shelves holding four recordings — enough for the Devotions grid, the home feed and the Learn tab to be exercised on a fresh database. The seeded recordings carry teaching text and no link, so the app opens them as readable pages with no play control until staff paste the ministry's YouTube address in the console. Bible books exist without chapter rows, and the campus, group and event catalogs are empty, so on a fresh database those tabs correctly show their empty states and the chapter picker is disabled. Filling them is curation work — the staff console is the intended surface for it, and Django Admin remains for records with structural collateral.

## Delivery rules

- Prefer a working end-to-end vertical slice over broad disconnected screens.
- Treat backend content and permissions as authoritative; do not ship decorative actions that do nothing.
- Add the feature's automated checks as part of its implementation and run the checks requested for that phase.
- Mark third-party credentials, licensing, and provider-dependent functions explicitly; never fake live integrations.
