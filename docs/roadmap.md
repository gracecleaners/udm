# Delivery roadmap

Each phase ends with a usable, reviewable increment and its own acceptance checks before the next phase begins. The repository starts at Phase 1; the larger vision is intentionally staged so the first release has a coherent vertical slice.

1. **Architecture and setup (current):** architecture, domain model, roadmap, design tokens, Flutter and Django project skeletons, API contract and environment conventions.
2. **Core mobile experience:** onboarding, authentication/session, profile, server-backed home feed, navigation and accessible loading/error/empty states.
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

## Delivery rules

- Prefer a working end-to-end vertical slice over broad disconnected screens.
- Treat backend content and permissions as authoritative; do not ship decorative actions that do nothing.
- Add the feature's automated checks as part of its implementation and run the checks requested for that phase.
- Mark third-party credentials, licensing, and provider-dependent functions explicitly; never fake live integrations.
