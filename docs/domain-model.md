# UDM domain model

All records use UUID identifiers where they cross the API boundary and carry `created_at` / `updated_at`. Use soft deletion only for user-facing records that require recovery or audit; immutable progress/audit history is retained under the published retention policy. Relationships below are logical; implement them as Django foreign keys with constraints and indexes.

## Identity and campus

- **User**: email, password hash, active/staff flags, verification state. Custom Django user; email is the login identifier.
- **UserProfile** (one-to-one User): name, phone, photo, optional gender/church, country/city, course of study and year (the student's academic programme, unrelated to teaching media), preferred translation, interests, privacy preferences.
- **University**: name, country, city, website, active status.
- **Campus**: University, name, location, status.
- **Fellowship**: Campus, name, description, meeting schedule, leaders, visibility.
- **DiscipleshipGroup**: optional Campus, name, description, group type, leader, capacity, visibility.
- **GroupMembership**: User, group, role, status, requested/approved timestamps; unique (user, group).

## Content and Scripture

- **DevotionalSeries** → **Devotional**: author, title/body, scripture references, reflection/application/prayer, memory verse, estimated minutes, publish window/status.
- **DevotionalPlan**: ordered devotional assignments; **DevotionalProgress**: user, devotional, status/completion time, private note; unique (user, devotional).
- **BibleTranslation**: code, name, license/attribution, source, offline permission.
- **BibleBook**: translation, canonical order, name/testament; **BibleChapter** and **BibleVerse**: canonical chapter/verse order and licensed text. Unique order constraints per parent.
- **BibleBookmark**, **BibleHighlight**, **BibleNote**: user-owned verse reference, selection/color or private note, timestamps. Unique bookmark per user/verse; never public by default.
- **BibleReadingPlan** and ordered assignments; **BibleReadingProgress**: user, assignment, status and completion.

## Teaching media and publishing

- **MediaCollection** → **MediaItem**: a shelf of teaching recordings (title, description, artwork, list position, publish window/status) and the recordings on it (title, author, excerpt, write-up, the ministry's YouTube address, an optional link to a file the ministry hosts itself, length in seconds, position within the shelf). A recording with no shelf cannot be reached, so deleting a shelf takes its recordings with it.
- **MediaNote**: user, recording, text; one per pair. Owner-scoped and absent from every staff listing, admin view, analytic and push payload.
- **MediaWatch**: user, recording, position in seconds, completion; unique pair, owner-scoped. This is the resume point and the "watched" mark, and it is the reason a shared device shows one student nothing about another.
- **ArticleCategory** → **Article**: author, rich body, featured image, references, publication metadata, status.
- Video and audio files are not held here. The ministry publishes them on YouTube and the row stores the address the app plays; the only uploads that land on this server are the artwork files, under `MEDIA_ROOT`. Courses, lessons, enrolments and quizzes were removed in migration `0014`, which dropped those tables and created the media models in their place.

## Community, prayer, and activities

- **PrayerRequest**: owner, optional explicitly selected group, visibility/consent, status. **PrayerJournal**: owner, encrypted-at-rest private entry, date/category; never visible to admin or other users through normal APIs. **PrayerReminder**: owner and schedule.
- **Discussion** and **Comment**: group/topic, author, parent comment for replies, moderation state. **Report**: reporter, target, reason/status. Blocking and moderation actions are audited.
- **Event**: organizer/campus, schedule/timezone, location or online URL, capacity, publication status. **EventRegistration**: user/event/status; unique (user, event).
- **Notification** and **UserNotificationPreference**: recipient, type, delivery/read state and opt-in channel settings.

## Progress and governance

- **MemoryVerse**: one row does both jobs — the home feed's verse of the day for its date window, and the verse a student commits to memory. It either points at a synced `BibleVerse` or stores its own text, in which case the translation must be one `UDM_MEMORY_VERSE_TRANSLATIONS` licenses. **UserMemoryVerseProgress**: user, verse, review state/schedule.
- **ContentVersion**: a single row holding one integer, moved by a signal on every content model the app renders. It is how a device tells a fresh response from its own stale cache.
- **Achievement** and **UserAchievement**: definition and user award timestamp; unique pair.
- **AuditLog**: actor, action, target type/id, timestamp, safe metadata (exclude secrets and journal text).

## Data rules

Index feed status/publication time, campus/group scope, user-owned progress by user and date, and foreign keys used in list filters. Add uniqueness constraints for memberships, registrations, progress, one note and one watch position per student per recording, and canonical Bible ordering. Store timestamps in UTC and retain an explicit timezone for user/event schedules. Never treat client-supplied ownership, role, or campus scope as authoritative.

## Implemented today

The entities above are the target model. Migrated and reachable through `/api/v1/` so far: **User**, **UserProfile**, **DevotionalSeries**, **Devotional**, **Article**, **UserContentProgress**, **BibleTranslation**, **BibleBook**, **BibleChapter**, **BibleVerse**, **BibleBookmark**, **BibleNote**, **BibleReadingPlan**, **BibleReadingAssignment**, **BibleReadingProgress**, **MediaCollection**, **MediaItem**, **MediaNote**, **MediaWatch**, **ResourceTopic**, **ResourceStep**, **MemoryVerse**, **UserMemoryVerseProgress**, **University**, **Campus**, **Fellowship**, **DiscipleshipGroup**, **GroupMembership**, **Event**, **EventRegistration** and **PrayerRequest**. FeaturedVerse no longer exists as its own table: migrations 0011 and 0012 moved every row into **MemoryVerse** and dropped it, so the home screen's verse of the day and the verses a student memorises are one license-checked record. Migration 0014 dropped the course, lesson, enrolment, quiz and attempt tables the earlier build had, in the same step as creating the media models — the Learn tab is recordings now, and nothing in the API still answers a lesson or a quiz. Bible translation metadata, attribution and offline permission govern Scripture browsing and caching. Translation and book records may identify an external provider and its stable book ID; the UDM API retrieves YouVersion passages and stores verse rows for existing private bookmark and note relations. The passage router can also serve a verse that has no local row; its response labels each verse with its database id only where one exists, so the app offers save actions on stored verses and reads or links out the rest. A student's note on a recording and their place in it are read and written only by their own account, and neither is ever serialized into a public list or a staff view. Community scopes, event registration, prayer consent, visibility and moderation are enforced server-side. Scripture, teaching media and community models currently live in the `content` Django app; later extraction into the separately described domain apps can happen as operations complexity grows.
