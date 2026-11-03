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

Five tabs: **Home · Bible · Learn · Community · Profile**. Home leads with a personal greeting, verse of the day, and one clear “Read Scripture” action; next show today's devotion and continue reading; then a compact challenge and selected learning/community/event items. Use horizontally scrolling collections only when they add discovery, and keep sections content-driven. The sample Romans 12:2 copy in the brief is design illustration only; production verse text must come from the selected licensed/public-domain source.

## Interaction principles

Use calm transitions, preserve reading position, give immediate feedback on saved/completed actions, and show offline state when relevant. Every control must have a defined action and accessible label. Personal prayer/journal content must not leak into previews, notifications, analytics, or shared surfaces without explicit user choice.

## As built

`AppColors` carries the light tokens above plus their dark counterparts (`darkBackground`, `darkSurface`, `darkElevated`, `darkModeText`, `darkModeSecondaryText`, `darkLightBlue`); screens read `Theme.of(context).colorScheme` and `textTheme` rather than raw colors, and surfaces Material has no slot for (the scripture tint) come from the `AppSurfaces` theme extension. `AppSpacing` fixes the 8-point rhythm and the two corner radii.

Shared widgets today: `ContentCard`, `ScripturePanel`, `SectionHeader`, `StateView` (loading/error/empty/ready), `CenteredSlot`/`Centered`, `MessagePanel`, `UdmProgress`, `OfflineChip`, `NoticeBanner` + `NoticeTone` (`info`, `problem`), `UdmLogo` and `FeatureStatusView`. `NoticeBanner` renders nothing for an empty message, so a screen can bind it straight to an `RxString` without a conditional.

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
