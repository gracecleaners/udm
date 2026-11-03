# Delivery roadmap

Each phase ends with a usable, reviewable increment and its own acceptance checks before the next phase begins. The larger vision is intentionally staged so the first release has a coherent vertical slice. Phases 1 and 2 are complete; the next increment is Phase 3.

1. **Architecture and setup (complete):** architecture, domain model, roadmap, design tokens, Flutter and Django project skeletons, API contract and environment conventions.
2. **Core mobile experience (complete):** onboarding, authentication/session, profile, server-backed home feed, navigation and accessible loading/error/empty states.
3. **Spiritual content:** devotionals, licensed Bible reading, plans, bookmarks, notes, progress, offline reading and sync.
4. **Discipleship learning:** courses, lesson progress, quizzes, media playback and memory verses.
5. **Community and campus:** directory, fellowship discovery, scoped groups, events, prayer sharing with consent and moderation.
6. **Mission and growth:** evangelism resources, goals, achievements, mentoring/accountability flows and recommendations.
7. **Administration:** Django Admin curation, scheduling, role-scoped campus management, moderation and operational analytics.
8. **Production readiness:** privacy/security review, observability, backups/restore, performance, offline conflict handling, deployment and release process.

## Phase 1 acceptance

- Architecture and system boundaries are documented.
- Domain entities and privacy/ownership rules are mapped.
- Mobile design tokens and component direction are recorded.
- API versioning, authentication and offline behavior are defined.
- Initial Flutter/Django skeletons can be added without committing secrets or copyrighted Bible text.

All five are met in code, not only on paper:

- Django runs from a settings package (dev/prod), PostgreSQL only, with DRF, SimpleJWT (rotation + blacklist), CORS, drf-spectacular and a shared error envelope. Default permission is `IsAuthenticated`; public content endpoints opt into `AllowAny`.
- `accounts` ships a custom email user; `content` ships devotional, article, featured-verse and owner-scoped progress models with publish-window querysets, KJV-only licensing in `Model.clean()`, admin curation actions and an idempotent seed command.
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
- `TracksReadingProgress` (a mixin over `GetxController`) is shared by the devotion and article readers and posts to the idempotent `POST /progress/`, so re-reading an item updates one row instead of appending history. The model stays out of Django Admin.
- `flutter analyze` is clean and `flutter test` passes with no layout overflows, including on a 320dp-wide phone.

## Known deviations and deferred work

- **GetX package:** the `getx` meta-package no longer resolves on pub.dev, so the app depends on `get` 4.7.3, the maintained package by the same author. No API change was required.
- **No auth-guarded routing:** deliberately, because the spec asks students to explore public content before registering. Screens that need a session prompt for one in place instead of redirecting, and the shell never blocks.
- **Social sign-in, email and phone verification, password reset:** all need a third-party credential (OAuth app, SMS account, outbound mail provider) that does not exist yet, so they are absent rather than stubbed. The Profile tab labels the email field as unverified and offers no verify button.
- **Profile photo upload:** no object storage is configured; `photo` is server-owned and read-only in the client until Phase 8 brings media storage.
- **Read state is not prefetched:** `/progress/` has no server-side filter by kind, so a reader cannot ask "have I read this?" without pulling the student's whole history. Each reader therefore starts unmarked and marks on demand.
- **Translation picker is client-side:** the Profile sheet's Bible version choices mirror `UDM_FEATURED_VERSE_TRANSLATIONS`, the same server setting `FeaturedVerse.clean()` validates against. A server-driven list endpoint replaces this when one exists.
- **Offline sign-out can't revoke:** signing out with no network clears the device tokens but leaves the refresh token valid for its 14-day lifetime, because revocation is a server call. Signing out while online calls `/auth/token/logout/` and blacklists it.
- **Bundle id:** `applicationId` is still `com.example.udm_frontend`. It must be replaced before any store upload, since it cannot be changed afterwards.
- **Local infrastructure:** local development uses a native PostgreSQL instance, which the team chose over a container toolchain. Docker/Compose returns with the staging/production work in Phase 8, so no half-configured container files are committed. Redis, Celery and FCM arrive with the phases that need them.
- **Admin privacy:** `UserContentProgress` is intentionally unregistered from Django Admin. Staff status does not imply a right to read a student's private discipleship record.

## Delivery rules

- Prefer a working end-to-end vertical slice over broad disconnected screens.
- Treat backend content and permissions as authoritative; do not ship decorative actions that do nothing.
- Add the feature's automated checks as part of its implementation and run the checks requested for that phase.
- Mark third-party credentials, licensing, and provider-dependent functions explicitly; never fake live integrations.
