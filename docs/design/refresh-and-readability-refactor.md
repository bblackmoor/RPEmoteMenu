# Refresh and readability refactor

This six-phase plan follows the earlier maintainability refactor. Keep behavior,
saved data, transfer schemas, dialog ownership guards and library boundaries intact.
Each phase receives a separate commit and review. Incidental cleanup must not
consume another phase's scope.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Consolidate refresh flow; distinguish content, typography, colors and geometry | Implemented; automated checks pass, in-game acceptance pending |
| 2 | Extract typography, fallback/retries and measurement from MainWindow | Implemented; automated checks pass, in-game acceptance pending |
| 3 | Extract category/emote rendering; install stable handlers reading current row bindings | Planned |
| 4 | Share drag cursor conversion, edge scrolling, hit testing and drop indicators | Planned |
| 5 | Extract database normalization/copying, use explicit settings ownership and separate presentation coordination | Planned |
| 6 | Simplify repeated settings-control construction with small helpers and named options | Planned |

## Baseline repair

The disabled fade-control test assumed the former five-second default. It now
captures the saved delay before interacting with the disabled control and verifies
that the value remains unchanged. The three-second default and saved values are
untouched. All existing Lua smoke suites and 28 Python tests passed after repair.

## Phase 1

Theme editor callbacks identify the setting they changed. ApplyThemeSettings uses
that key to choose a narrow update; absent or unknown keys apply the whole Theme.

- Colors and selection effects update existing rows, backgrounds, hover colors
  and scroll indicators. They retain scroll offsets, handlers, font state and
  inactivity deadlines.
- Opacity uses the existing fade controller without rebuilding rows or fonts.
- Typography builds rows once, applies fonts to every row, then measures column
  widths once. A successful immediate pass retires old font retries; failed
  rendering retains bounded retries. Display/provider events retain deferred,
  coalesced refresh behavior.
- Title-bar edits apply geometry and visibility without rebuilding menu content
  or refreshing displayed fonts. Geometry still measures widths when required.
- Full Theme/Profile changes defer intermediate visibility-driven menu rebuilds
  and perform one final content/typography pass. Profile initialization cancels
  previous fade work and retains existing saved-geometry rules.

The public no-argument refresh entry points remain available. This phase does not
add persistent measurement caching or move rendering into new modules; those
changes would obscure the refresh-flow change and belong to later work.

## Verification

The new window-refresh smoke suite observes native font/measurement calls, public
menu refreshes, row handlers and scroll offsets. It verifies zero content/font
work for colors and opacity, one measurement pass for typography, one menu rebuild
per full Theme/Profile application, and stable geometry-only transitions across
all four title-bar edges. Theme-control tests verify the changed-setting dispatch.
Existing suites cover font fallback/retries, drag/drop, hidden slots, geometry,
minimization, fades, dialogs, Send choices and transfer behavior.

In-game acceptance remains required: preview and cancel colors while scrolled;
change fonts and display scale; switch Profiles/Themes; move the title bar to all
four edges; and exercise fade/minimize behavior, selected categories and both Send
choices. Runtime rendering and timing cannot be established by native UI stubs.

## Phase 2

WindowTypography now owns text measurement, column-width calculations, row-height
policy, font application, whole-pane fallback, template-font cache invalidation
and bounded retry queues. MainWindow supplies current categories, Theme settings,
row references, selection and measurement text explicitly. The component does not
read the database or construct frames.

MainWindow retains content creation and update order, window geometry, colors,
settings-panel refreshes and display-event wiring. Its existing RefreshFont,
RefreshFontDisplays and ScheduleFontRefreshes entry points remain available.
Each retry queue owns its key and generation, and its callback resolves the
current rendering operation when dispatched. Existing cancellation, retry delays,
font flags, glyph invalidation and fallback policy are preserved.

MainWindow is reduced from 2,763 to 2,534 lines. The new component is loaded before
MainWindow in both the addon manifest and integration test fixtures. No saved-data
or transfer-schema changes, persistent measurement cache, or Phase 3 rendering
extraction are included.

Verification adds a direct component suite for measurement fallback, preserved
text/font flags, width bounds and independent retry queues with stale callback
rejection. Existing font-media, window-refresh, localization and geometry suites
continue to exercise the real integration. In-game checks remain outstanding:
change fonts, register a late font provider, switch Themes/Profiles during retries,
and change display size/UI scale with the menu expanded and minimized.
