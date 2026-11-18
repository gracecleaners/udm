# UDM mobile design system

## Product identity

**UDM — University Discipleship Mission**. Tagline: **Know Christ. Grow in Christ. Make Disciples.** The interface should feel calm, clear, welcoming, and suitable for everyday campus life. Scripture is prominent without crowding the home screen; community actions remain intentional rather than feed-driven.

The look the ministry asked for is premium, modern and youthful — the reading warmth of YouVersion, the confident surface work of a current fintech app — never a generic Material demo. Every screen is built from the tokens and widgets in this file; a screen that hand-styles its own blue is a bug.

## Color tokens

`AppColors` (`lib/app/core/theme/app_colors.dart`) is the only place a hex value is written.

| Token | Value | Use |
|---|---|---|
| `primaryBlue` | `#2563EB` | Main actions, active navigation, links, selected pills |
| `deepBlue` / `ink` | `#101B3D` | Gradient foot, headers, shadow tint |
| `royalBlue` | `#3B82F6` | The lit corner of `AppGradients.hero` only |
| `lightBlue` | `#EFF6FF` | Scripture and selected surfaces |
| `white` | `#FFFFFF` | Cards and reading surfaces |
| `background` | `#F8FAFC` | Main light canvas |
| `darkText` | `#172033` | Primary text |
| `secondaryText` | `#64748B` | Supporting text |
| `success` | `#269B72` | Completion state |
| `warning` | `#E6A23C` | Caution and reminders |
| `danger` | `#C0392B` | Rejected input, session problems |
| `gold` | `#F5B942` | Decoration only — the verse rule, the streak flame. Never a status colour, because `warning` already owns amber |

Dark mode keeps the same hues and lifts the surfaces: `darkBackground` `#0B1020`, `darkSurface` `#111A2E`, `darkElevated` `#18243B`, `darkModeText` `#F1F5F9`, `darkModeSecondaryText` `#9AAAC1`, `darkLightBlue` `#1D3563`. Hairlines, the field wash and the brand tints (`hairline`, `hairlineStrong`, `field`, `primaryTint`, `successTint`, `goldTint`, `mist`, `scrim`) exist so a card edge or a highlighted row is a token rather than an opinion.

Screens never read `AppColors` for a foreground: they read `Theme.of(context).colorScheme` and `textTheme`. The two brightnesses are tuned in one place, and `AppSurfaces` (a `ThemeExtension`) supplies what Material has no slot for — the scripture tint, the hairline pair, the field wash, the shadow tint and the three gradients — through `card()`, `inset()` and `pill()`.

`lib/main.dart` builds on `themeMode: Get.find<AppearanceController>().mode.value` inside an `Obx`, so a change made in
Settings repaints the app where the student is standing rather than restarting it. The default is **Follow the phone**:
a student who never opened Settings still gets the operating system's schedule, and pinning Light or Dark for the
device is the one place the app is allowed to argue with the OS. `AppearanceController` keeps the answer in the device
cache rather than on the account — a shared family phone can be dark for one student and light for the next. The same
controller owns the reading size and writes it into `AppTypography.readingScale`, the one number every prose style in
the reading face multiplies by, so the choice reaches devotion, article, guided step, recording and Scripture bodies
without a reading screen having to ask for the preference — a reader that pulls in the settings controller would not
render at all in the tests that judge it. `scriptureVerse` is deliberately outside that rule: it sets monograms, card
titles and pulled quotes inside artwork that was proofed at a fixed size, and a card is glanced at rather than read
through. The two surfaces that do own the controller — the Bible chapter and the full-screen verse — pass
`scaled()` and so change on the frame the choice is made; the rest of the library takes the size as it is opened.

## Type

Two bundled families, declared once in `AppFonts` and never named in a screen: `AppFonts.ui` = **Brand Sans** (*Plus Jakarta Sans*) for chrome, `AppFonts.scripture` = **Scripture Serif** (*Newsreader*) for anything quoted from the Bible or written by a person. They are `@font-face`d from `assets/fonts/` with their OFL texts beside them and shipped with the app rather than fetched, so a student in a campus basement with no signal gets the same typography. Both are under the SIL Open Font License.

`AppTypography` adds the styles `ThemeData` has no slot for — `scriptureBody`, `scriptureVerse`, `scriptureReference`, `eyebrow`, `editorialTitle`, `editorialTitleOnArt`, `statValue`, `verseNumber` — so a verse always reads as a verse and a screen title always reads as a title (23–34pt, weight 700–800, negative tracking). Dynamic type is supported by scaling these rather than hardcoding sizes in features.

## Space, depth and motion

`AppSpacing` is the 8-point rhythm: `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`, with `screen 20` as the page inset, and the radii a card can have — `radiusCard 22`, `radiusSheet 28`, `radiusField 16`, `radiusTile 14`, `radiusArt 18`, `radiusPill`. It also fixes the art sizes, so a cover is the same square wherever it appears: `iconTile 46`, `shelfArt 72`, `railArt 148`, `railCard 172`, `featureArtHeight 188`.

Colour alone does not carry hierarchy. `AppGradients.hero` / `.scripture` / `.sheen` / `.goldRule` / `.scrim` / `.scrimSide` / `.veil()` / `.tint()` paint the brand surfaces, each with a `…Dark` sibling where a light-only gradient would blind a dark screen. `AppShadows.card` / `.float` / `.glow` / `.soft` / `.raised` lift them, all tinted with the shadow colour from `AppSurfaces` — grey shadows on a blue brand look dirty at low opacity. `Mark` (the concentric-arc motif from the logo) repeats behind hero panels at low alpha so a dark card never looks like a flat rectangle.

`AppMotion` names the four durations the app uses — `tap 110`, `quick 220`, `base 320`, `enter 420` — and the three curves (`standard`, `emphasized`, `springy`). Route transitions are `AppPages.transitionDuration`; a press is `PressableScale`, which scales rather than ripples, so a tap reads on a gradient where an `InkWell` would be invisible.

The opening screen is the one place the app waits rather than races: `SplashController.brandPause` holds the ministry's own picture for two full seconds before the first route decision, so the brand is seen instead of flashed. It is a fixed dwell, not a load timeout — the two seconds are paid up front and the onboarding flag is read when they are done, so what the student waits for is the brand, never a spinner.

## Icon dialect

`AppIcons` (`lib/app/core/widgets/app_kit.dart`) is the only source of glyphs in a feature screen. Every member is a `…_rounded` Material icon, so the set reads as one hand-drawn family — Lucide-style, 24dp grid, rounded terminals — and a screen cannot accidentally mix a sharp and a rounded icon on the same row. The base kit (`udm_widgets.dart`, `state_view.dart`) references raw `Icons.*` because `app_kit` depends on them; their glyphs are already the dialect.

One glyph, one meaning: `bookOpen` for reading, `bible` for the Bible tab, `learn` for teaching, `verify` for a completion the server accepted, `checkCircle` for a local state, `clock` for length, `external` for anything that leaves the app, `offline` for a cached copy, `heart` for standing with somebody in prayer, `comment` for the word left underneath a prayer on the wall, `quote` for a testimony rather than a petition. `BusyMark` is the waiting state inside a button: the label already says what is happening, so the mark only has to keep moving while the request is open.

## Shared components

**Base kit** (`udm_widgets.dart`): `UdmLogo`, `Mark` (+ `Mark.backdrop`), `IconBadge` (+ `IconBadgeTone`), `MetaPill`, `Panel`, `BrandBackdrop`, `PressableScale`, `GoldRule`, `Eyebrow`, `UdmAvatar`, `SectionHeader`, `FadeIn`, `HeroPanel`, `GhostButton`, `SkeletonBox`, `SkeletonCard`.

**State kit** (`state_view.dart`): `StateView` (loading/error/empty/ready, one widget so no screen invents its own spinner), `CenteredSlot`/`Centered`, `MessagePanel`, `UdmProgress`, `OfflineChip`, `NoticeBanner` + `NoticeTone` (`info`, `problem`). `NoticeBanner` renders nothing for an empty message, so a screen can bind it straight to an `RxString` without a conditional.

**Content** (`content_card.dart`, `feature_status_view.dart`): `ContentCard`, `ScripturePanel`, `FeatureStatusView`.

**Discovery kit** (`app_kit.dart`), which is what makes the app look designed rather than assembled:
- `CoverArt` — a server picture, or a designed fallback (monogram, icon, initials) on the brand gradient. Exactly one `Image` is ever requested, and only when the API supplied a URL, so a missing upload is a state, never a broken box.
- `UdmAvatar` (`udm_widgets.dart`) is the same rule for a person rather than a cover: the student's own picture where the server gave an address, the brand initials underneath it everywhere else — no file, a file that fails to load mid-scroll, or a wall entry its writer left unnamed. A screen never decides for itself whether somebody looks faceless; it passes the URL the API answered with and the widget holds the design.
- `BackdropArt` — a bundled ministry picture painted edge to edge. Four files are all the build carries (`AppArt`, `assets/images/`): the opening screen and the three onboarding slides, which paint before any request comes back, so the first thing a fresh device shows cannot depend on the network. Everything a student reaches afterwards takes its picture from the ministry console. It asks the decoder for the box's width in device pixels (`decodedWidthFor`) instead of the file's, so a small Android phone never holds a flagship-sized bitmap. The number is a budget, not a guarantee — a JPEG is only stepped down in halves — which is why asking is safe: it costs nothing in sharpness where the box genuinely needs the pixels.
- `FeatureCard` (the wide featured tile) and `RailCard` (the 148dp discovery card) — art, scrim, title and byline composed once.
- `DiscoveryRail` — the horizontal shelf. It is a `SingleChildScrollView`, deliberately not a `ListView`, so a rail of three items cannot be confused with the vertical feed by a scroll gesture or a widget test.
- `QuickActionGrid` + `QuickAction` — the home shortcuts, sized by the grid rather than by fixed widths.
- `PillSelector` — a `Wrap` of `AppSurfaces.pill()` choices: selected means brand gradient and glow, unselected means a hairline.
- `RailHeader` — eyebrow, title and the one action a shelf owns.
- `AppIconButton` — the 42dp round control in three tones (`quiet`, `brand`, `onDark`), the last of which is the only one allowed to sit on a gradient.
- `ProgressRing` — a read-through indicator drawn once, `_RingPainter`, so a streak and a percentage share a visual language.
- `UdmProgressBar` — the thin brand bar for resume state, never a `LinearProgressIndicator` with default styling.
- `SkeletonRail` / `SkeletonFeature` — loading that has the shape of the content that will replace it.
- `NavRow` — the account list row Profile and Settings both draw: an unfilled `IconBadge`, a title, an optional subtitle, a chevron, and one hairline that the last row of a group omits. `destructive: true` is the row that takes something away — the warning colour, no chevron — because signing out is not the same kind of thing as opening bookmarks.

The shell's bottom bar is a widget of ours, not a `NavigationBar`: five tabs — **Home · Devotions · Bible · Learn · Profile** — the selected one sitting in an `AppGradients.hero` pill that slides between labels, so the active tab is legible without relying on colour alone and the bar still reads at 320dp.

`GhostButton(label, icon, onTap)` takes `onTap` as required precisely because a control that does nothing must not be rendered.

## Navigation and home hierarchy

Home leads with a personal greeting from the API and the bell whose badge is the server's own `unread_count`, then the day's memory verse — its verse set in the large scripture face over the picture staff published, the reference under it marked with the book glyph the reference design uses — then **Today's reading**: the passage the ministry authored for the daily plan, the verse itself, and the two lines that say what it says and what to learn, under a progress line whose every number is the server's `completed` against its `total`. The card appears only when a published daily plan exists, so a student with no plan open in front of them is shown the next thing rather than an empty frame. **Today's activities** follows as the list they can finish. Each row leads with the item's own published picture cut to a round, or the brand tile when staff uploaded none, and a row the account says is finished carries the green ground and the solid white-on-green tick — the state is drawn, not only coloured. The quick actions under it are the three the ministry named — Courses, Articles, New Believer — with no Media tile. Horizontally scrolling collections are used only where they add discovery, and sections stay content-driven. Every *See all* in the app — `SectionHeader`, `RailHeader` and the two headers on home — is the same word in brand blue followed by the same short arrow, so the door out of a section looks like one control wherever it appears. Tapping the reading card opens the day as the four parts it was authored in: the passage, with an **Open** control that moves to the Bible tab rather than a browser because the translation already lives there, then *The verse*, *What it says* and *What to learn*. Each part renders only when the server sent text for it, so a day written in two sections shows two and never an empty heading. The sample Romans 12:2 copy in the brief is design illustration only; production verse text must come from the selected licensed/public-domain source.

**Devotions** is the reading library, in the shape the ministry brief shows: a two-column grid of series covers, each tile the ministry's own art or — when a series has none — the brand-gradient tile bearing the series' initials, never a broken box. A tile opens on that series' days in reading order (Introduction first, then Day 1, Day 2 …), one row per reading with its thumbnail, title and a chevron. Readings filed under no series do not appear in the grid; they are the daily reading on the home feed.

**Learn** is the watching library, and it is the same idea in a different shape: a column of shelf rows (SOMA, Uliza, Podcast — whatever staff name them), each one the ministry's own artwork or the brand-gradient monogram tile when a shelf has none, over the shelf's title, description and a count pill. A shelf opens on its recordings in order, each row on the same 72dp artwork square (`AppSpacing.shelfArt`) — the recording's own picture, or the brand-gradient play mark when staff uploaded none — with its title, author, length and the mark of whether the student has already watched it. A recording page is the player at 16:9, the title in the editorial style, a wrapped row of author/length/date pills, a gold rule, then the four actions the ministry asked for — Download, Take a note, Share, and the resume state — above the write-up. Artwork is only ever absent because the ministry has not uploaded one, so a missing picture is a designed state, not a broken one.

**Profile** carries the identity card (avatar, name, the email the session knows, verification state), the answers the student gave in onboarding as rows rather than as a form, interests as pills, and a single sign-out control that is unmistakably destructive. Editing opens `ProfileEditorSheet`, which groups the same fields under eyebrows — *Who you are*, *Where you study*, *Where you gather* — instead of presenting eleven unrelated inputs. The walk is three tiles (a day streak and two counts the server adds up at `progress/summary/`, with a plural the number decides: `1 guide finished` against `3 guides finished`), and everything the student can open is a `NavRow` — bookmarks, reading history, guides, settings — while sign-out is the same row with `destructive: true`: warning colour, no chevron, because it leads nowhere.

**Community** is four sections under one pill row — *Campus · Groups · Events · Prayer* — and the last is the wall: the requests a student offered to the ministry. A second `PillSelector` inside it (`Key: wall-tabs`, because both rows carry the word "Prayer" and a test must not confuse them) filters by which wall a request sits on — All, Prayer, Testimonies, Encouragement, which are the server's own three categories plus the whole feed. A card is the writer's initials and name, the day in the device's own calendar words, their text in the *reading* face rather than the UI face because it is something a person wrote, and a wrapped row of pills for wall, sharing scope and whether staff have approved it. Two responses sit underneath, neither of them borrowed from social media: a heart that means *I am praying for this*, and a one-level thread of encouragement. Each control's number doubles as its verb — an untouched card says **Pray for this** / **Encourage**, a used one says how many — and tapping it changes the card in place rather than refetching the wall.

**Settings** groups what belongs to the phone rather than the account under eyebrows — *Appearance*, *Reading*, *About UDM*, *Help* — every choice a `NavRow` and the selected one carrying a check instead of a filled radio. None of it reaches a server, which is deliberate: a shared family device can be dark for one student and light for the next. The showcase drew a Notifications switch and a Data Usage panel on this screen; notices are a real inbox reached from the home feed's bell rather than a switch that only promises them, and the app caches nothing a student can measure, so neither is rendered.

**Reading history** is the profile's number explained: completions grouped by the day the server recorded them, one dated eyebrow per group, read from the account and never from a second local copy. **Courses** is the ministry's guided reading — topics in a list, split into *Pick up where you stopped* and *Other guides*, each row carrying the server's own step count — and a `ResourceStep` page that reads like a chapter rather than like a recording, which is how the app keeps a guide distinct from the Learn tab it no longer is.

## Responsiveness

The floor is a 320dp Android phone, and the ceiling is a 430dp modern device; both are asserted in `test/modules/layout_smoke_test.dart`, which walks every tab, every reader, a guide, a shelf, both auth forms and onboarding at both sizes under both brightnesses, scrolling each surface to its end first. A layout that overflows there fails the suite. A surface with a control that opens more content inside a row proves it there too rather than in the shared suite: `test/modules/community_wall_test.dart` pumps the prayer wall with a thread open at both sizes and both brightnesses, because a comment composer and a keyboard are not the same layout as a card. That file is the machine-readable half of this section: `test/` remains the functional contract, and this is the part of the contract a screenshot cannot enforce.

The rules that fell out of it:

- **A non-flex child of a `Row` is measured with unlimited width.** A wordmark or a pill followed by a `Spacer` therefore gets its natural size and runs off the screen instead of ellipsizing; it needs `Expanded`, and `UdmLogo` and `GhostButton` are built to wrap or truncate once bounded.
- **An eyebrow names what is below it, so it wraps instead of truncating.** Titles own the full width and wrap to two lines; only a byline is allowed to be cut.
- **A screen whose copy can outgrow the viewport scrolls.** An onboarding slide sizes its artwork from the available height and lets the words scroll under it, rather than letting a long sentence clip at the fold.
- **Centred content stays scrollable.** `CenteredSlot` centres via `LayoutBuilder` + `ConstrainedBox(minHeight:)` inside a `SingleChildScrollView`, so a long server message on a small phone can be read instead of clipped.
- **Full width before it wraps.** Dropdowns that carry real values (`American Standard Version`, `Year 4`) are stacked at full width; half-row dropdowns overflow at 320dp. Form fields are addressed by `Key` (`udm.field.<name>`), which is what lets the widget tests drive them without depending on labels.
- **Status bars and notches are handled by the framework, not by magic numbers**: `SafeArea` at the surfaces, `MediaQuery` padding above the keyboard, and no fixed height on a text block.

## Interaction principles

Use calm transitions, preserve reading position, give immediate feedback on saved/completed actions, and show offline state when relevant. Every control must have a defined action and an accessible label. Personal prayer/journal content must not leak into previews, notifications, analytics, or shared surfaces without explicit user choice.

A tappable card owns its Material: `InkWell` sits *inside* `Card`/`Ink`, so the ripple paints on the card surface and the widget renders correctly outside a `Scaffold`. Wrapping a card from the outside leaves the splash hidden behind the card's own surface and needs a Material ancestor.

Offline is stated, not implied. Cached content shows the `OfflineChip` in the verse header; a tab whose feature has not shipped shows `FeatureStatusView` naming its phase and what works today. No control is rendered that does nothing.

Server content is never restyled into app copy. `AppText` localises app-owned strings and leaves a ministry title, summary or verse exactly as the API sent it — which is why a card can be redesigned without touching a single word a student reads.

Phase 2 added three patterns that still hold:

- **Reading progress** (`modules/reader/reading_progress.dart`): `TracksReadingProgress` is a `GetxController` mixin holding `markedRead`/`savingProgress`/`progressMessage` and `markRead()`, so both readers share one write-back and one vocabulary. `ProgressFooter` is its view: a disabled **Marked as read** once recorded, a **Sign in to keep this in your reading history** message for anonymous readers, and the API's own words on failure.
- **Edit sheets**: `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with a `Column` whose `Flexible(SingleChildScrollView)` scrolls the form while the action row stays pinned above the keyboard. A save that fails validation states the reason next to the button, because the offending field can be off-screen.
- **Feedback that survives a screen change**: session notices (`error`, `notice`) are re-rendered on the signed-out profile screen rather than dropped with the route, so a sign-out the server never heard about is still visible where the student can act on it.

The Learn tab added three, all of them the same ground rule met on new ground:

- **A player is rendered only where it can run.** `inlinePlaybackSupported` is web, Android, Fuchsia, iOS and macOS — the platforms with a WebView (or the frame itself) behind `youtube_player_iframe`. On a Windows or Linux build the recording page shows no black rectangle: it names the platform limit and hands the student the recording's own YouTube address. An embedded refusal gets its own panel in the same terms ("the owner of this recording does not allow it to play inside other apps"), because a bare *video unavailable* tells the student nothing about whose problem it is. For the same reason the layout suite serves a recording with no embed id: a widget test has no platform WebView.
- **An action that would do nothing is not rendered.** **Download** appears only on a recording where staff attached a file the ministry distributes itself; a YouTube-only row shows Share, note and resume and no download control at all. The same rule keeps the note editor and the resume banner out of a signed-out student's way until they sign in.
- **Truncation belongs to the byline, never the shelf.** Shelf and recording titles wrap to two lines; the author line and the length pill are the row's truncating elements. This repeats the reading-library rule rather than inventing a second one, so a title is never the thing that gets cut.

The community wall met the same rule on ground the Learn tab had not covered:

- **No control without an endpoint.** The showcase drew a *Discussion* tab beside Prayer; the service has no forum — only the words people leave under a request — so the wall has threads and no Discussion tab, and its pills are the API's own three categories rather than a fourth the screen invented. The rule that hid Download from a recording with no file also hides the delete on somebody else's comment: the write endpoint would answer 403, so the list carries `is_owner` and the app never offers the button.
- **A card answers for itself.** Affirming a request and opening its thread change that one card and refetch nothing — the wall was already asked for once, and the response the API returns (`{affirmed, count}`) is the whole truth about that number. A screen that re-reads its own list to paint one heart is a screen that scrolls.
- **Reactive state is only tracked where it is read.** GetX registers a dependency while the `Obx` closure builds, so an `Rx` touched only inside a child widget's `build` belongs to no reaction at all. A wall card's open state and its loaded thread are therefore read in the feed's own builder and handed down as constructor props. Wrapping each card in its own `Obx` was tried first and rebuilt nothing; hoisting the reads also keeps one card from repainting because a neighbour's thread arrived.

## Working rules for a redesign

1. Screens are redesigned, never replaced. Endpoints, models, GetX bindings and route names are the app's function; the kit is its surface. A redesign that changes what a control does has broken the contract the widget tests hold.
2. Reuse before style. If a screen needs a card that does not exist, the card goes into `app_kit.dart` and every screen adopts it — a token added in one file, not a padding value invented in nine.
3. No new dependency for a visual effect. Gradients, rings, rails and skeletons are painted from the existing kit.
4. The widget test is the specification. When a redesign needs a test changed, the change is to markup (a header, a pill, a wrap), never to a string a student reads or an endpoint the app calls.
5. Verify at the floor, in both brightnesses, before calling a screen finished — `flutter analyze lib` and `flutter test` are the last two steps of every pass, not the first.

## Console (web) adaptation

`admin_ui/` is staff-facing, so it keeps the same identity but not the same kit: Tailwind HSL tokens plus one hand-written stylesheet (`src/design-system.css`), still on the earlier brand blues `#1769AA` / `#123B63` and `#EAF4FC`. The mobile palette above is the current brand of record; the console carries the previous one, and aligning it is a separate pass that the 2026 UI modernization explicitly left out of scope.

- **The fonts are bundled, not fetched.** *Plus Jakarta Sans* for chrome and *Newsreader* for prose are `@font-face`d from `src/fonts/` with their OFL texts beside them, mirroring the mobile decision and keeping a campus network from needing a CDN. Newsreader is reserved for what a person wrote and what the ministry sets over it — the login headline and a prayer request's body — which is the same rule the app applies to Scripture.
- **Console rules qualify their selectors.** `design-system.css` is `@import`ed *before* `@tailwind`, so at equal specificity a Tailwind utility wins. Every console rule therefore names its element or stacks its class (`div.console-toolbar label.console-search`, `.console-panel thead th`), and the table variant is an explicit `console-panel-table` modifier rather than a `:has()` query.
- **Density over delight.** A curator reads hundreds of rows, so list panels carry the row state control inline, secondary values drop to `.console-cell-sub` under the thing that identifies the record, and dialogs say what cannot be edited before the form does.
- **Artwork is a control, not a text field.** Six resources take an `image` — shelf, recording, devotion, article, memory verse and guided course — and the descriptor renders it as a file picker that says whether a picture is already set and offers to replace or clear it. The file leaves on its own `multipart/form-data` PATCH after the JSON one, so a refused upload never takes the wording with it; the shared client's default `Content-Type` comes off that request, or axios serialises the `FormData` as JSON and Django answers *not a file*.
- **A queue row's wall is a correction, not a label.** The category a student chose is editable on the prayer queue, on the same single PATCH as the approve/decline decision, and the API only accepts it while the row is still pending — an approved request has already left the queue, so a follow-up write would target a row that endpoint no longer returns.
