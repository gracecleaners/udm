# Delivery roadmap

Each phase ends with a usable, reviewable increment and its own acceptance checks before the next phase begins. The larger vision is intentionally staged so the first release has a coherent vertical slice. Phase 1 is complete; work is now inside Phase 2.

1. **Architecture and setup (complete):** architecture, domain model, roadmap, design tokens, Flutter and Django project skeletons, API contract and environment conventions.
2. **Core mobile experience (in progress):** onboarding, authentication/session, profile, server-backed home feed, navigation and accessible loading/error/empty states.
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

## Known deviations and deferred work

- **GetX package:** the `getx` meta-package no longer resolves on pub.dev, so the app depends on `get` 4.7.3, the maintained package by the same author. No API change was required.
- **Client session:** the JWT endpoints and rotating-refresh backend exist and are tested, but the mobile token store, refresh interceptor and auth-guarded routing are deliberately deferred to the rest of Phase 2. The app currently consumes public content only.
- **Local infrastructure:** local development uses a native PostgreSQL instance, which the team chose over a container toolchain. Docker/Compose returns with the staging/production work in Phase 8, so no half-configured container files are committed.
- **Admin privacy:** `UserContentProgress` is intentionally unregistered from Django Admin. Staff status does not imply a right to read a student's private discipleship record.

## Delivery rules

- Prefer a working end-to-end vertical slice over broad disconnected screens.
- Treat backend content and permissions as authoritative; do not ship decorative actions that do nothing.
- Add the feature's automated checks as part of its implementation and run the checks requested for that phase.
- Mark third-party credentials, licensing, and provider-dependent functions explicitly; never fake live integrations.
