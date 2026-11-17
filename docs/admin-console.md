# Ministry console (`admin_ui/`)

The staff-facing web console for UDM content and the campus directory. It replaces nothing on the mobile app and
does not duplicate Django Admin: the console is the day-to-day curation surface (lists, search, publishing,
French copies, the prayer queue), while Django Admin keeps the records with structural collateral — deleting a
Bible translation and everything hanging off its verses, users, or migrations.

React 18 + Vite 5 + TypeScript, TanStack Query for server state, axios for the session, Radix/shadcn primitives
plus one console stylesheet (`src/design-system.css`). Every screen reads the same `/api/v1/admin/` API the
mobile app's contracts were verified against; there is no mock data anywhere in this folder.

## Running it

```
cd admin_ui
npm install
npm run dev            # http://localhost:5173, proxies /api -> http://127.0.0.1:8000
```

Start the Django server first (`python manage.py runserver` in `udm_backend`). The dev proxy exists so the
refresh cookie is same-origin — `VITE_API_BASE_URL` overrides `/api/v1` when the console is deployed behind the
same host as the API.

Checks: `npm run lint`, `npx tsc --noEmit`, `npm run build`.

## Who gets in

Sign-in posts to `POST /api/v1/auth/admin/token/`, which refuses a student account with the message the login
form shows: a student is turned away rather than handed tokens it could not use. Console sessions are staff-only
(`is_staff`). The platform owner opens those accounts on the **Staff accounts** screen;
`python manage.py createsuperuser` is still the only way to make an owner, and no route here can make a second one.

| Route | Use |
| --- | --- |
| `POST /api/v1/auth/admin/token/` | Staff-gated pair; sets the refresh cookie |
| `POST /api/v1/auth/admin/token/refresh/` | Rotation, cookie-only |
| `POST /api/v1/auth/admin/token/logout/` | Blacklists the refresh token and clears the cookie |
| `GET /api/v1/auth/admin/me/` | Identity, role and capability list behind the account chip |

The access token is held in memory only; the refresh token lives in an `HttpOnly`, `SameSite=Lax` cookie scoped
to `Path=/api/v1/auth/admin`, so no script on the page can read it. `src/lib/api.ts` refreshes 45 seconds before
expiry, collapses concurrent refreshes into one request, retries a 401 once, and bumps a session epoch so work
in flight during sign-out cannot write into the next person's session.

## Two roles, one console

Both accounts sign in the same door; the API decides what each may write.

| Role | How the API marks it | What it does here |
| --- | --- | --- |
| Ministry staff | `is_staff=True` | Adds and edits every content record and the campus directory, monitors the roster and the prayer queue. |
| Platform admin | `is_superuser=True` | The above, plus the three acts another account cannot take back: the Bible licensing toggle, deleting a student account, and opening, suspending or closing the staff accounts below them. |

Every curation endpoint is staff-*readable*, because monitoring is part of the job, so the split is not a matter of
which pages a role can open. `ResourceConfig.writableBy` records which role the endpoint takes writes from, and
`ResourceScreen` gates it control by control: on a `"superuser"` resource a staff account sees the list, the search
box and a note saying why there are no buttons, and no create, edit, delete or state control is rendered at all.
That is the console's share of the ground rule that a control either performs a real operation or does not appear —
the refused-403 path exists server-side, it just is not offered as something to click.

`GET /api/v1/auth/admin/me/` answers with `role` and a `capabilities` list read from the same
`CONSOLE_CAPABILITIES` table the permission classes use, so the menu is built from what the server already decided
rather than a second copy of the rules written in TypeScript. One page is missing from that list for staff rather
than merely button-free: `admin/accounts/` refuses to even list for them, so `/staff-accounts` is behind
`ProtectedRoute capability="accounts"` and its sidebar entry is filtered out — staff are not told who else holds a
console account, and a link that would only render a table of refusals is not offered.

A staff account cannot delete a *user* anywhere: Django Admin's `PlatformOwnerDeletesOnly` gate takes the delete
button and the `user:delete` permission away from staff while leaving change rights, and the student roster route has
no write verb at all. The staff accounts route writes only staff accounts: `is_superuser` and `is_staff` are both
read-only there, so no HTTP call — including one made through a hijacked session — can mint a second owner or demote
an account out of the only list that can find it again. The owner's own row is not in that queryset, which is why no
route on this page can hide or close the last admin account.

## Screens and endpoints

| Screen | Endpoint | Writes |
| --- | --- | --- |
| Overview | `GET /api/v1/health/` | none — it is the same probe a deploy checks |
| Devotional series | `admin/devotion-series/` | full CRUD, dated publishing; this list *is* the grid the app's Devotions tab opens on |
| Devotions | `admin/devotions/` | full CRUD, filtered by series, dated publishing |
| Articles | `admin/articles/` | full CRUD, dated publishing |
| Reading plans | `admin/reading-plans/` | full CRUD |
| ↳ Readings | `admin/reading-plans/{id}/assignments/` | nested dialog, one passage per day |
| Translations | `admin/translations/` | `is_active` only, and only for a platform admin — no form, no delete |
| Media shelves | `admin/media-collections/` | full CRUD, dated publishing; this list *is* the Learn tab, in `order`, and a shelf with nothing published on it is hidden from students |
| ↳ artwork | the same row, as `multipart/form-data` or as a pasted link | `image` is the console's only file type, on five resources: shelves, recordings, devotions, articles and memory verses. Each of them pairs it with `image_link` for a picture that already lives on another host; an upload wins when both are set |
| Media recordings | `admin/media-items/` | full CRUD, filtered by shelf, dated publishing; a YouTube address is pasted, never uploaded, and only a ministry-hosted `download_url` makes the app offer Download |
| Memory verses | `admin/memory-verses/` | full CRUD — one row does both jobs: the home feed's verse of the day (its date window) and the verse a student commits to memory (synced scripture, or a stored copy in a licensed translation) |
| Universities | `admin/universities/` | full CRUD |
| Campuses | `admin/campuses/` | full CRUD, filtered by university |
| Fellowships, Groups, Events | `admin/fellowships/`, `admin/groups/`, `admin/events/` | full CRUD, filtered by campus |
| Students | `admin/students/` | read-only roster |
| Staff accounts | `admin/accounts/`, `admin/accounts/{id}/` | platform admin only, and only for staff: open an account with an email, a name and a password; rename, suspend or close one. Nothing here writes a role flag, and the owner's own account is not listed |
| Prayer queue | `prayers/moderation/` | `moderation_state` approve/decline, plus a wall choice (`category`) corrected on the same PATCH while the row is still pending |
| Account | `auth/admin/me/`, `users/me/` | own name only (`full_name`); the page also repeats the capability list the API sent |

Content screens are config-driven: each page under `src/pages/` is a `ResourceConfig` descriptor consumed by
`src/components/curation/ResourceScreen.tsx`, which owns paging, search, parent filters, the form dialog and nested
child dialogs. Adding a screen means writing a descriptor, not a component. The Devotions and Media recordings
screens use the descriptor's parent filter (`admin/devotion-series/`, `admin/media-collections/`), so staff can narrow
the table to one parent and work through its rows in the order the app lists them.

An `image` field is the descriptor's only file type, and it is deliberately two writes rather than one: the text of the
row goes as JSON, then a chosen file goes as `multipart/form-data` to the same detail route. A form that mixed the two
would have to encode one inside the other, and a refused upload would take the wording with it. With nothing chosen the
field sends nothing at all, so opening a form never re-uploads a cover. Five resources carry one — a shelf, a recording,
a devotion, an article, a memory verse — and every one of them is optional, because the app paints the ministry's brand
tile wherever staff have not uploaded a picture yet. Empty artwork is a state on this screen, not an error.

Each of those five also carries `image_link`, for a picture that already lives on another host: the ministry CDN, a
parish photo album, anywhere. `content.services.artwork_url` is the single resolver the app reads through, and it
prefers the uploaded file whenever both are set, so a link is never a way to lose a picture somebody chose. The model's
`clean()` refuses a link without a scheme, which `full_clean()` on every admin write turns into a field message instead
of a URL the device cannot load. Video is never uploaded: a recording's play link is YouTube only, and a ministry-hosted
file is reached through `download_url`. That is the whole of the app's media policy — the phone ships artwork for the
splash and the three onboarding slides and takes every other picture from this console.

## Rules the console inherits rather than re-implements

- **Publishing is a field write.** `publish_state` is read-only and derived from `is_published` + `publish_at`, so
  the row control PATCHes those fields — there is no publish action to get out of sync. Records that only carry
  `is_published` (plans and memory verses) never show a *Scheduled* option: `simplePublishState` drops it
  rather than offering a state the row cannot hold.
- **Licensing is the server's.** The memory-verse translation list is read back from `allowed_translation_codes` on
  an existing row, which comes from `UDM_MEMORY_VERSE_TRANSLATIONS` (`kjv`, `web`, `asv`); with no rows yet the field
  falls back to free text and the API still refuses an unlicensed code. That list is the *stored copy* path — a verse
  the ministry types in and attributes itself. The other path links the row to synced scripture, and the picker
  searches `admin/verses/` by translation, book/words and chapter, so it can only point at scripture the sync
  already stored with its attribution. Neither path lets a verse be typed into existence unlicensed.
- **A day belongs to a series, or to none.** Both are optional on a devotion: an unfiled row is the one-off daily
  reading on the home feed, while two days numbered alike inside one series are refused. DRF reads the model's
  *conditional* unique constraint as a required-together rule and would reject any create that omits a series, so
  `ConditionalUniqueValidator` drops the implied requirement and keeps the duplicate check.
- **Saving here reaches a phone without a release.** Every write lands on a tracked model, whose signal moves the
  single `ContentVersion` number the app polls at `GET /api/v1/content-version/` and that is stamped into the home
  and series payloads. No console screen has to tell anyone to refresh.
- **French is an override, never a replacement.** The localized panel writes `translations.fr` for the fields each
  resource declares; a blank box leaves that field reading the English text, and saving preserves locales the form
  cannot see. List-shaped fields (a devotion's reflection questions, a reading's reference) go back as arrays, prose as text.
- **Validation lives in `Model.clean()`.** Every admin write runs `full_clean()`, so the console enforces exactly
  what Django Admin does: HTTPS media, an artwork link that is a full `http(s)` address or empty, end-after-start
  events, IANA event time zones, unique campus+name fellowships, one reading per plan day, one memory verse per verse
  row, one recording position per shelf, and a YouTube field that either stays empty or holds an address the app can
  actually play.
- **The reason a write failed is shown, not swallowed.** The shared envelope carries `detail`, `code`, `status` and
  `errors`; `extractApiError` prefers `errors` because `detail` is generic whenever a field carries the message.

## Privacy boundaries

The roster has no create, update or delete route, so the console renders no such button on it. It carries identity,
the staff flag and two counts of work the app already shows publicly — never what a student reads, bookmarks,
notes or prays. `UserContentProgress` is not exposed by any console route, matching its exclusion from Django
Admin. The prayer queue only ever lists requests their owner submitted to the community wall with explicit
consent, and only the ones still waiting: a group's pending requests are moderated by that group's own leader inside
the student app, and nothing a student kept private is reachable from any console route. Approving one is a
`moderation_state` write with no free-text reply field. What a wall request collects afterwards — the promises people
made under it and the words they wrote — belongs to the students, and no console route lists either; a queue row that
showed those counts would be counting nothing anyway, since a pending request is visible only to its own author.

## What was verified against the running API

On 2026-11-11, against the dev PostgreSQL database with the console served by Vite and Django on
`127.0.0.1:8000`:

- Every screen listed against the live API with nothing but two react-router v7 future-flag warnings in the
  browser console — seeded content where the database has it
  (devotional readings, articles, the verse rows that have since become memory verses, one course with its module
  and lesson, one quiz, 143 synced verses, 11
  translations, the roster), and the honest empty state where it does not. The verification rows written below were
  deleted afterwards, so a fresh look at this database shows the directory with one university and one campus and
  no fellowships, groups, events or plans. Memory verses are no longer in that list: `seed_content` now publishes
  ten of them for the home feed and the Learn tab's reviews.
- Writes proven end to end: university → campus (foreign-key dropdown populated in the same visit), fellowship,
  group with a student leader, event, reading plan → reading, course → module → lesson, quiz → question,
  memory verse chosen from `admin/verses/`, French overrides on a text field and on a list field, row state
  Active ⇄ Hidden, publish/draft through `is_published`, and `publish_state` reading `scheduled` for a future
  `publish_at`.
- Refusals proven: unlicensed `translation_code`, duplicate campus+name, duplicate plan day, non-HTTPS lesson
  media, event ending before it starts, unknown IANA time zone, blank quiz choice, `translations.fr` value that
  is neither text nor a list of strings — each surfaced as its field message.
- `npm run build`, `npx tsc --noEmit` and `npm run lint` pass (lint reports only `react-refresh/only-export-components`
  warnings from shadcn primitives and the `useAuth` export), and `python manage.py test` is green at 59 tests.

Later the same day, on the Devotions, licensing and memory-verse changes, with the same two servers:

- The Overview, `/series`, `/devotions`, `/memory-verses` and `/translations` screens all listed the seeded
  database — one series ("Foundations for Campus Life", 3 days), three devotions with their series and day in the
  new *Reading order* column, and 10 memory verses showing source (`kjv` / "King James Version (public domain)") and
  window (`any → any` where the row is undated).
- Writes proven: **New series**, and **New devotion** with the series left on *Choose…*, which is the one-off reading
  path that DRF's required-together reading of the model's conditional constraint had been refusing with
  `{"series": ["This field is required."]}`. That row was created and edited through the console and deleted again
  afterwards, as were the two temporary accounts the role check needed; the database is back to seeded content only.
- Both roles signed in against the same running API. As a platform admin the Translations screen shows the
  Active ⇄ Hidden control; as ministry staff the same screen lists and searches the same 11 rows with no state
  control, no New, no Edit, no delete, and the note explaining that a platform admin changes them. The staff
  Account page states the same split in one sentence, and the roster stays button-free for both.
- `npm run build` and `npx tsc --noEmit` pass again; `python manage.py test` is green at 145 tests, including the
  regression test for the unfiled-devotion create and one that a console write moves the version stamp.

On 2026-11-12, on the Learn shelves and recordings, with Django on `127.0.0.1:8000` and the console on Vite:

- The Overview and the sidebar's **Learn** group list Media shelves, Media recordings and Memory verses, and no
  Courses or Quizzes anywhere. The two screens those pages replaced are gone from the console with them: migration
  `0014` dropped the course, lesson, enrolment, quiz and attempt tables, so the course → module → lesson and
  quiz → question writes proven in the 11 November entry above describe records this build no longer has.
- `/media-shelves` listed the three seeded shelves with their recording counts (`2 recordings`, `1 recording`),
  position, artwork state, Live control and search. `/media-recordings` listed the four recordings with shelf and
  position, the length as the app prints it (`15:40`, `43:00`), and a source column that said *No video attached*
  and *No download file* — which is exactly what the app is allowed to offer on those rows.
- **The artwork upload is the console's one multipart write and it was proven as one.** Choosing a picture on a
  shelf produced two requests in order — the JSON PATCH the row's text needs, then a `multipart/form-data` PATCH
  carrying only the file — the file landed under `MEDIA_ROOT`, and the public `/api/v1/media/` payload came back
  with that `image_url`. The first attempt at this failed with `Image: The submitted data was not a file`, because
  the shared client's default `Content-Type: application/json` makes axios convert a `FormData` into JSON before it
  leaves the page; `uploadFiles` now takes that header off the request so the browser sets it, boundary included.
- Writes proven on a recording: a YouTube watch link (accepted, and the row then reports YouTube's own thumbnail as
  its artwork), a ministry-hosted `https` file (accepted, and the source column changes to *Also a ministry file*,
  which is the only condition under which the app shows Download), and a French title override, which the public
  API serves at `?language=fr` while English keeps reading the stored text.
- Refusals proven, each surfaced as its own field message: `https://vimeo.com/1234` → *Youtube url: That is not a
  YouTube link the app can play. Paste the video's watch or youtu.be address.*, and a plain `http://` ministry file
  → *Download url: Media must be served over a secure HTTPS URL.*
- The shelf dropdown above the recordings table renders with the seeded shelves and their counts; the query
  parameter it sends is the parent-filter mechanism the Devotions screen already uses, so it was not re-proven here.
- Everything written for this check was undone afterwards: the shelf picture, the links and the French override are
  back to the seeded state, the uploaded file is gone from `MEDIA_ROOT`, and the two temporary accounts the check
  needed are deleted. `npx tsc --noEmit`, `npm run lint` (0 errors, the same 10 `react-refresh` warnings) and
  `npm run build` pass.

On 2026-11-14, on the community wall and the last three artwork fields, **no browser pass was run**. What follows is
what the code and the two suites prove; nothing here is a claim about how a screen looks:

- Devotions, articles and memory verses gained the `image` control the shelves and recordings already had, through the
  descriptor's one file type and the same `uploadFiles` two-write flow proven against the running API on 12 November.
  The server half is now held by `CurationImageWriteApiTests`, which posts each of the three with a real file and
  reads the picture back off the student API — including a memory verse in an unlicensed translation *with* a file
  attached, which must still be a 400 and not a crash.
- The prayer queue learned the wall. Each row has a `WALLS` selector, and the choice travels as `category` on the
  *same* PATCH as the approve/decline decision, because `prayers/moderation/<id>/` answers only while the row is
  pending — a second write would target a row the queue no longer returns.
- Parity was then checked in the direction the mobile app does not cover: what the backend has gained that this
  console has not. Nothing is missing. Affirmations and comment threads are student-to-student and reach nobody else,
  and `GET /progress/summary/` and `GET /media/resume/` are `IsAuthenticated` reads of *the requesting account* — a
  staff token there returns the admin's own streak and the admin's own half-watched videos. A staff dashboard number
  built on either would be a lie about a student, so neither has UI here. That is the correct state, not a gap.
- `npx tsc --noEmit` and `npm run build` pass. `npx eslint .` reports the same 10 `react-refresh` warnings plus one
  error that predates this work and is in a file this pass never opened: `tailwind.config.ts:98` uses a `require()`,
  which the console's flat config forbids. `python manage.py test content accounts` is green at 220 tests.

On 2026-11-17, on artwork links and staff accounts, again **no browser pass was run** — the same pinned browser
surface as before, and nothing below claims how a screen looks:

- Five resources gained `image_link` beside `image`, resolved by one `artwork_url()` that prefers the uploaded file,
  and the console pairs the two in each form. `CurationArtworkLinkApiTests` covers the four cases that matter: the link
  reaching the student API verbatim, an upload beating a link, a scheme-less link refused, and clearing the file
  leaving the link serving.
- `admin/accounts/` and `admin/accounts/{id}/` opened behind `IsPlatformAdmin`, with `StaffAccountSerializer` forcing
  `is_staff` and the email-verified flag on create and both role flags read-only on every write. Nine tests in
  `StaffAccountOpeningTests` walk the whole path, including the new account signing in at the console's own token
  endpoint and then being refused `admin/accounts/` with its own token, a suspension that keeps the password and stops
  the sign-in, and a deletion that leaves the group it led with a null leader.
- `/api/v1/auth/admin/me/` now also answers `role` and `capabilities`, and the console builds its sidebar from that
  list instead of a copy of the rules. A server old enough to omit the list falls back to the two rows the
  TypeScript knows, because an absent list would otherwise hide every page from everybody.
- `npx tsc --noEmit` and `npm run build` pass; `npx eslint .` still reports only the ten `react-refresh` warnings and
  the pre-existing `tailwind.config.ts` error. `python manage.py test` is green at 233 tests. The new
  `image_link` columns arrive in migration `0016`, which has run against the test database but **not** yet against
  the dev or the AWS database.

## Known gaps

- **Desktop width is unverified visually.** The available browser surface is pinned to 638×616, so the 258px
  sidebar and two-column form layout have only been checked by reading the CSS, not by looking at them. The
  mobile drawer and the 900px/760px breakpoints are what was exercised. During the 12 November media check the
  surface went hidden part-way, after which the pass was structural — accessibility snapshots, the live DOM and the
  API log — so nothing about the media screens above is a claim about how they *look*.
- **Unused npm packages remain.** `recharts`, `embla-carousel-react`, `cmdk`, `react-day-picker`, `vaul` and the
  Radix packages behind them came with the dashboard this folder was copied from and are no longer imported.
  Removal needs a dependency change, so it is left for explicit approval.
- **The FoGo/food-delivery code it started from is moved aside, not deleted**, at
  `C:/Users/okumu/AppData/Local/Temp/udm_admin_ui_fudz_legacy` (unused shadcn primitives, two feedback helpers and
  their styles). It is a scratch copy, not a supported part of the repo.
- **The console is served by Vite only.** No static build is wired into Django or any host, and `public/.htaccess`
  (Apache SPA fallback) and `vercel.json` are both still in the folder from the template it came from — Phase 8
  should keep whichever one matches the host actually chosen.
- **Three lockfiles are present**: `package-lock.json` (what is installed and verified here, with npm) plus
  `bun.lock` and `bun.lockb` from the template. Two package managers resolving this folder would drift, so keep
  the one the team uses and drop the others.
- **The prayer queue has not been exercised with a row.** `GET /api/v1/prayers/moderation/` returns `[]` in this
  database because no student has consented to a public request, so approve, decline and the wall correction are
  wired to the route and its `moderation_state`/`category` contract — and covered by Django's own wall tests — but
  have never been clicked against real data. Submitting one from the app with *Community prayer wall* visibility is
  the way to see it.
- **Four dropdowns copy the server's choices instead of reading them.** `WALLS` on the prayer queue, `eventState` on
  events, and `PUBLISH_OPTIONS` behind every publish control are hand-written mirrors of Django `TextChoices`. The API
  refuses a value it does not recognise, so drift surfaces as a refused save rather than as bad data — but adding a
  fourth wall, event state or publish state means editing this folder as well, and nothing fails until someone tries.
- **The console never asks for published-only rows.** `?published=true` is answered by the curation list endpoints and
  is not used here; staff see the whole table and narrow it with search and the state control.
- **On a database with no imported scripture the memory-verse picker has nothing to offer.** It can only propose
  `BibleVerse` rows a sync or `import_bible` produced, so until one runs it says so rather than listing verses.
