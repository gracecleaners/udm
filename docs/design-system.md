# UDM mobile design system — initial direction

## Product identity

**UDM — University Discipleship Mission**. Tagline: **Know Christ. Grow in Christ. Make Disciples.** The interface should feel calm, clear, welcoming, and suitable for everyday campus life. Scripture is prominent without crowding the home screen; community actions remain intentional rather than feed-driven.

## Color tokens

| Token | Value | Use |
|---|---|---|
| Primary blue | `#1769AA` | Main actions, active navigation, links |
| Deep blue | `#123B63` | Strong emphasis, headers |
| Light blue | `#EAF4FC` | Scripture and selected surfaces |
| White | `#FFFFFF` | Cards and reading surfaces |
| Background | `#F7F9FC` | Main light canvas |
| Dark text | `#182B3A` | Primary text |
| Secondary text | `#718096` | Supporting text |
| Success | `#269B72` | Completion state |
| Warning | `#E6A23C` | Caution and reminders |
| Danger | `#C0392B` | Rejected input, session problems |

Use semantic tokens rather than raw colors in features. Define a dark palette with equivalent contrast before shipping dark mode. Avoid using color alone to convey status.

## Type, layout, and components

Use a readable sans-serif family with distinct display, title, body, and caption styles. Establish an 8-point spacing rhythm; use generous insets, rounded cards, restrained elevation, and clear focus/pressed/disabled states. Shared components: primary/quiet buttons, text fields, content cards, Scripture reference, progress indicator, section header, avatar, empty/error/loading panels, and accessible bottom sheets. Support dynamic text scaling, screen readers, large tap targets, and responsive tablet layouts.

## Navigation and home hierarchy

Five tabs: **Home · Devotions · Bible · Learn · Profile**. Home leads with a personal greeting, verse of the day, and one clear “Read Scripture” action; next show today's devotion and continue reading; then a compact challenge and selected learning items. Use horizontally scrolling collections only when they add discovery, and keep sections content-driven. The sample Romans 12:2 copy in the brief is design illustration only; production verse text must come from the selected licensed/public-domain source.

**Devotions** is the reading library, in the shape the ministry brief shows: a two-column grid of series covers, each tile the ministry's own art or — when a series has none — the brand-gradient tile bearing the series' initials, never a broken box. A tile opens on that series' days in reading order (Introduction first, then Day 1, Day 2 …), one row per reading with its thumbnail, title and a chevron. Readings filed under no series do not appear in the grid; they are the daily reading on the home feed.

**Learn** is the watching library, and it is the same idea in a different shape: a column of shelf rows (SOMA, Uliza, Podcast — whatever staff name them), each one the ministry's own artwork or the brand-gradient monogram tile when a shelf has none, over the shelf's title, description and a count pill. A shelf opens on its recordings in order, each row on the same 72dp artwork square (`AppSpacing.shelfArt`) — the recording's own picture, or the brand-gradient play mark when staff uploaded none — with its title, author, length and the mark of whether the student has already watched it. A recording page is the player at 16:9, the title in the display style, a wrapped row of author/length/date pills, a gold rule, then the four actions the ministry asked for — Download, Take a note, Share, and the resume state — above the write-up. Artwork is only ever absent because the ministry has not uploaded one, so a missing picture is a designed state, not a broken one.

## Interaction principles

Use calm transitions, preserve reading position, give immediate feedback on saved/completed actions, and show offline state when relevant. Every control must have a defined action and accessible label. Personal prayer/journal content must not leak into previews, notifications, analytics, or shared surfaces without explicit user choice.

## As built

`AppColors` carries the light tokens above plus their dark counterparts (`darkBackground`, `darkSurface`, `darkElevated`, `darkModeText`, `darkModeSecondaryText`, `darkLightBlue`); screens read `Theme.of(context).colorScheme` and `textTheme` rather than raw colors, and surfaces Material has no slot for (the scripture tint) come from the `AppSurfaces` theme extension. `AppSpacing` fixes the 8-point rhythm and the two corner radii.

**Type.** Two bundled families, declared once in `AppFonts` and never named in a screen: `AppFonts.ui` = *Plus Jakarta Sans* for chrome, and `AppFonts.scripture` = *Newsreader* for anything quoted from the Bible. `AppTypography` adds the styles ThemeData has no slot for — `scriptureBody`, `scriptureVerse`, `scriptureReference` and `eyebrow` — so a verse always reads as a verse. Both are under the SIL Open Font License; the texts live in `assets/fonts/licenses/` and are shipped with the app rather than fetched.

**Depth.** Colour alone does not carry hierarchy. `AppGradients.hero` / `.scripture` / `.sheen` / `.goldRule` / `.veil()` paint the brand surfaces, `AppShadows.card` / `.float` / `.glow` lift them, and `Mark` (the concentric-arc motif from the logo) repeats behind hero panels at low alpha so a dark card never looks like a flat rectangle.

Shared widgets today: `ContentCard`, `ScripturePanel`, `SectionHeader`, `StateView` (loading/error/empty/ready), `CenteredSlot`/`Centered`, `MessagePanel`, `UdmProgress`, `OfflineChip`, `NoticeBanner` + `NoticeTone` (`info`, `problem`), `UdmLogo` and `FeatureStatusView`. `NoticeBanner` renders nothing for an empty message, so a screen can bind it straight to an `RxString` without a conditional. The brand kit adds `IconBadge`, `MetaPill`, `Panel`, `PressableScale`, `GoldRule`, `Eyebrow`, `UdmAvatar`, `FadeIn`, `HeroPanel`, `GhostButton`, `SkeletonBox`/`SkeletonCard` and `BrandBackdrop`.

The shell's bottom bar is a widget of ours, not a `NavigationBar`: five tabs, the selected one sitting in an `AppGradients.hero` pill with the label beneath it, so the active tab is legible without relying on colour alone. `GhostButton(label, icon, onTap)` takes `onTap` as required precisely because a control that does nothing must not be rendered.


Phase 2 added three interaction patterns:

- **Reading progress** (`modules/reader/reading_progress.dart`): `TracksReadingProgress` is a `GetxController` mixin holding `markedRead`/`savingProgress`/`progressMessage` and `markRead()`, so both readers share one write-back and one vocabulary. `ProgressFooter` is its view: a disabled **Marked as read** once recorded, a **Sign in to keep this in your reading history** message for anonymous readers, and the API's own words on failure.
- **Edit sheets** (`modules/profile/profile_view.dart`): `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with a `Column` whose `Flexible(SingleChildScrollView)` scrolls the form while the action row stays pinned above the keyboard. A save that fails validation states the reason next to the button, because the offending field can be off-screen.
- **Feedback that survives a screen change**: session notices (`error`, `notice`) are re-rendered on the signed-out profile screen rather than dropped with the route, so a sign-out the server never heard about is still visible where the student can act on it.

Two rules learned while wiring Phase 1 are worth keeping:

- **A tappable card owns its Material.** `InkWell` sits *inside* `Card`/`Ink`, so the ripple paints on the card surface and the widget renders correctly outside a `Scaffold`. Wrapping a card from the outside leaves the splash hidden behind the card's own surface and needs a Material ancestor.
- **Offline is stated, not implied.** Cached content shows the `OfflineChip` in the verse header; a tab whose feature has not shipped shows `FeatureStatusView` naming its phase and what works today. No control is rendered that does nothing.

Two more came out of Phase 2, both from real overflow or dead-end bugs:

- **Centred content stays scrollable.** `CenteredSlot` centres via `LayoutBuilder` + `ConstrainedBox(minHeight:)` inside a `SingleChildScrollView`, so a long server message on a small phone can be read instead of clipped.
- **Full width before it wraps.** Dropdowns that carry real values (`American Standard Version`, `Year 4`) are stacked at full width; half-row dropdowns overflow at 320dp. Form fields are addressed by `Key` (`udm.field.<name>`), which is what lets the widget tests drive them without depending on labels.

The design pass added four more, every one of them found by photographing a real screen against the live API rather than by reading code:

- **A backdrop is a Stack that fills.** `Positioned.fill(BrandBackdrop())` inside a default `Stack` sizes the Stack to its *content*, so the gradient stopped at the foot of the form and left a hard seam across the screen. Auth screens use `Stack(fit: StackFit.expand)`, and their app bar is transparent with `extendBodyBehindAppBar: true` — a solid bar would have cut the same backdrop in half at the top.
- **Ellipsize the byline, never the title.** Putting a reading-time pill on the title row made "How to Study a Chapter in Twenty Minutes" read as "…in Twenty M…". The title owns the full width and wraps to two lines; only the author line shares a row with the pill, and it is the one allowed to truncate.
- **A choice that is clipped is a choice that is missing.** Section filters use `Wrap`, not a horizontal scroller — four short chips fit on screen, and a scroller would hide that the list is finite. A `SegmentedButton` whose labels cannot all fit ("Prefer not to say") scrolls horizontally instead of truncating, because half a label is worse than a scroll.
- **Dropdowns state the value, not the value plus its metadata.** The translation picker keeps `name · language` in the open list and only the name in the closed field (`selectedItemBuilder`); at 320dp the combined string truncated to "King James Versi…".

The Learn tab added three, all of them the same ground rule met on new ground:

- **A player is rendered only where it can run.** `inlinePlaybackSupported` is web, Android, Fuchsia, iOS and macOS — the platforms with a WebView (or the frame itself) behind `youtube_player_iframe`. On a Windows or Linux build the recording page shows no black rectangle: it names the platform limit and hands the student the recording's own YouTube address. An embedded refusal gets its own panel in the same terms ("the owner of this recording does not allow it to play inside other apps"), because a bare *video unavailable* tells the student nothing about whose problem it is.
- **An action that would do nothing is not rendered.** **Download** appears only on a recording where staff attached a file the ministry distributes itself; a YouTube-only row shows Share, note and resume and no download control at all. The same rule keeps the note editor and the resume banner out of a signed-out student's way until they sign in.
- **Truncation belongs to the byline, never the shelf.** Shelf and recording titles wrap to two lines; the author line and the length pill are the row's truncating elements. This repeats the reading-library rule rather than inventing a second one, so a title is never the thing that gets cut.

## Console (web) adaptation

`admin_ui/` is staff-facing, so it keeps the same identity but not the same kit: Tailwind HSL tokens plus one hand-written stylesheet (`src/design-system.css`), on the brand blues `#1769AA` / `#123B63` and `#EAF4FC` the table above records.

- **The fonts are bundled, not fetched.** *Plus Jakarta Sans* for chrome and *Newsreader* for prose are `@font-face`d from `src/fonts/` with their OFL texts beside them, mirroring the mobile decision and keeping a campus network from needing a CDN. Newsreader is reserved for what a person wrote and what the ministry sets over it — the login headline and a prayer request's body — which is the same rule the app applies to Scripture.
- **Console rules qualify their selectors.** `design-system.css` is `@import`ed *before* `@tailwind`, so at equal specificity a Tailwind utility wins. Every console rule therefore names its element or stacks its class (`div.console-toolbar label.console-search`, `.console-panel thead th`), and the table variant is an explicit `console-panel-table` modifier rather than a `:has()` query.
- **Density over delight.** A curator reads hundreds of rows, so list panels carry the row state control inline, secondary values drop to `.console-cell-sub` under the thing that identifies the record, and dialogs say what cannot be edited before the form does.
