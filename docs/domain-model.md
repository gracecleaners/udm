# UDM domain model

All records use UUID identifiers where they cross the API boundary and carry `created_at` / `updated_at`. Use soft deletion only for user-facing records that require recovery or audit; immutable progress/audit history is retained under the published retention policy. Relationships below are logical; implement them as Django foreign keys with constraints and indexes.

## Identity and campus

- **User**: email, password hash, active/staff flags, verification state. Custom Django user; email is the login identifier.
- **UserProfile** (one-to-one User): name, phone, photo, optional gender/church, country/city, course, year, preferred translation, interests, privacy preferences.
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

## Learning and publishing

- **Course** → **CourseModule** → **CourseLesson**: overview, objectives, prerequisites, typed lesson body/media/resources/order.
- **CourseEnrollment**: user/course/status; **LessonProgress**: user/lesson/status/score/completed_at.
- **Quiz** → **Question** → **AnswerOption**: ordered questions, answer key protected from learner responses; **QuizAttempt** stores user, responses, score, submission time.
- **ArticleCategory** → **Article**: author, rich body, featured image, references, publication metadata, status.
- **MediaContent**: provider/object key, type, duration, captions, license; **Playlist** orders media; **WatchHistory** stores user position and completion.

## Community, prayer, and activities

- **PrayerRequest**: owner, optional explicitly selected group, visibility/consent, status. **PrayerJournal**: owner, encrypted-at-rest private entry, date/category; never visible to admin or other users through normal APIs. **PrayerReminder**: owner and schedule.
- **Discussion** and **Comment**: group/topic, author, parent comment for replies, moderation state. **Report**: reporter, target, reason/status. Blocking and moderation actions are audited.
- **Event**: organizer/campus, schedule/timezone, location or online URL, capacity, publication status. **EventRegistration**: user/event/status; unique (user, event).
- **Notification** and **UserNotificationPreference**: recipient, type, delivery/read state and opt-in channel settings.

## Progress and governance

- **MemoryVerse**: verse, prompt and schedule; **UserMemoryVerseProgress**: user, verse, review state/schedule.
- **Achievement** and **UserAchievement**: definition and user award timestamp; unique pair.
- **AuditLog**: actor, action, target type/id, timestamp, safe metadata (exclude secrets and journal text).

## Data rules

Index feed status/publication time, campus/group scope, user-owned progress by user and date, and foreign keys used in list filters. Add uniqueness constraints for memberships, enrollments, registrations, progress, and canonical Bible ordering. Store timestamps in UTC and retain an explicit timezone for user/event schedules. Never treat client-supplied ownership, role, score, or campus scope as authoritative.
