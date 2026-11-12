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
(`is_staff`), and `python manage.py createsuperuser` (or setting `is_staff=True` on an existing user) is how a
new one is made.

| Route | Use |
| --- | --- |
| `POST /api/v1/auth/admin/token/` | Staff-gated pair; sets the refresh cookie |
| `POST /api/v1/auth/admin/token/refresh/` | Rotation, cookie-only |
| `POST /api/v1/auth/admin/token/logout/` | Blacklists the refresh token and clears the cookie |
| `GET /api/v1/auth/admin/me/` | Identity behind the account chip |

The access token is held in memory only; the refresh token lives in an `HttpOnly`, `SameSite=Lax` cookie scoped
to `Path=/api/v1/auth/admin`, so no script on the page can read it. `src/lib/api.ts` refreshes 45 seconds before
expiry, collapses concurrent refreshes into one request, retries a 401 once, and bumps a session epoch so work
in flight during sign-out cannot write into the next person's session.

## Two roles, one console

Both accounts sign in the same door; the API decides what each may write.

| Role | How the API marks it | What it does here |
| --- | --- | --- |
| Ministry staff | `is_staff=True` | Adds and edits every content record and the campus directory, monitors the roster and the prayer queue. |
| Platform admin | `is_superuser=True` | The above, plus the Bible licensing toggle — the one write that changes what students may read and cannot be undone by putting the flag back — and deletions in Django Admin. |

Every curation endpoint is staff-*readable*, because monitoring is part of the job, so the split is not a matter of
which pages a role can open. `ResourceConfig.writableBy` records which role the endpoint takes writes from, and
`ResourceScreen` gates it control by control: on a `"superuser"` resource a staff account sees the list, the search
box and a note saying why there are no buttons, and no create, edit, delete or state control is rendered at all.
That is the console's share of the ground rule that a control either performs a real operation or does not appear —
the refused-403 path exists server-side, it just is not offered as something to click.

A staff account cannot delete a *user* anywhere: Django Admin's `PlatformOwnerDeletesOnly` gate takes the delete
button and the `user:delete` permission away from staff while leaving change rights, and the console has no user
write route at all.

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
| ↳ shelf artwork | the same row, as `multipart/form-data` | `image` is the one file field in the console; it uploads on its own write after the text |
| Media recordings | `admin/media-items/` | full CRUD, filtered by shelf, dated publishing; a YouTube address is pasted, never uploaded, and only a ministry-hosted `download_url` makes the app offer Download |
| Memory verses | `admin/memory-verses/` | full CRUD — one row does both jobs: the home feed's verse of the day (its date window) and the verse a student commits to memory (synced scripture, or a stored copy in a licensed translation) |
| Universities | `admin/universities/` | full CRUD |
| Campuses | `admin/campuses/` | full CRUD, filtered by university |
| Fellowships, Groups, Events | `admin/fellowships/`, `admin/groups/`, `admin/events/` | full CRUD, filtered by campus |
| Students | `admin/students/` | read-only roster |
| Prayer queue | `prayers/moderation/` | `moderation_state` approve/decline |
| Account | `auth/admin/me/`, `users/me/` | own name only (`full_name`) |

Content screens are config-driven: each page under `src/pages/` is a `ResourceConfig` descriptor consumed by
`src/components/curation/ResourceScreen.tsx`, which owns paging, search, parent filters, the form dialog and nested
child dialogs. Adding a screen means writing a descriptor, not a component. The Devotions and Media recordings
screens use the descriptor's parent filter (`admin/devotion-series/`, `admin/media-collections/`), so staff can narrow
the table to one parent and work through its rows in the order the app lists them.

An `image` field is the descriptor's only file type, and it is deliberately two writes rather than one: the text of the
row goes as JSON, then a chosen file goes as `multipart/form-data` to the same detail route. A form that mixed the two
would have to encode one inside the other, and a refused upload would take the wording with it. With nothing chosen the
field sends nothing at all, so opening a form never re-uploads a cover.

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
  what Django Admin does: HTTPS media, end-after-start events, IANA event time zones, unique campus+name
  fellowships, one reading per plan day, one memory verse per verse row, one recording position per shelf, and a
  YouTube field that either stays empty or holds an address the app can actually play.
- **The reason a write failed is shown, not swallowed.** The shared envelope carries `detail`, `code`, `status` and
  `errors`; `extractApiError` prefers `errors` because `detail` is generic whenever a field carries the message.

## Privacy boundaries

The roster has no create, update or delete route, so the console renders no such button on it. It carries identity,
the staff flag and two counts of work the app already shows publicly — never what a student reads, bookmarks,
notes or prays. `UserContentProgress` is not exposed by any console route, matching its exclusion from Django
Admin. The prayer queue only ever lists requests their owner submitted to the community wall with explicit
consent; private and group requests stay out of reach of every console route, and approving one is a
`moderation_state` write with no free-text reply field.

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
- **`admin_ui/` is not committed yet.** Until it lands in a commit, nothing in it is recoverable, so removals
  there have been archived rather than deleted.
- **The prayer queue has not been exercised with a row.** `GET /api/v1/prayers/moderation/` returns `[]` in this
  database because no student has consented to a public request, so approve and decline are wired to the route and
  its `moderation_state` contract but have not been clicked against real data. Submitting one from the app with
  *Community prayer wall* visibility is the way to see it.
- **On a database with no imported scripture the memory-verse picker has nothing to offer.** It can only propose
  `BibleVerse` rows a sync or `import_bible` produced, so until one runs it says so rather than listing verses.
