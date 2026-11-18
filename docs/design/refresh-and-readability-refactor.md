# Refresh and readability refactor

This six-phase plan follows the earlier maintainability refactor. Keep behavior,
saved data, transfer schemas, dialog ownership guards and library boundaries intact.
Each phase receives a separate commit and review. Incidental cleanup must not
consume another phase's scope.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Consolidate refresh flow; distinguish content, typography, colors and geometry | Implemented; automated checks pass, in-game acceptance pending |
| 2 | Extract typography, fallback/retries and measurement from MainWindow | Implemented; automated checks pass, in-game acceptance pending |
| 3 | Extract category/emote rendering; install stable handlers reading current row bindings | Implemented; automated checks pass, in-game acceptance pending |
| 4 | Share drag cursor conversion, edge scrolling, hit testing and drop indicators | Implemented; automated checks pass, in-game acceptance pending |
| 5 | Extract database normalization/copying, use explicit settings ownership and separate presentation coordination | Implemented; automated checks pass, in-game acceptance pending |
| 6 | Simplify repeated settings-control construction with small helpers and named options | Implemented; automated checks pass, in-game acceptance pending |

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


## Phase 3

MenuRenderer owns category/emote row construction, selection and hover effects,
empty-category presentation, row bindings and pooled emote rendering. MainWindow
retains pane creation, geometry, refresh ordering, tooltip scheduling and drag
state. Explicit live getters supply current settings and selection; pane references
and row pools are shared with typography and layout. Public window methods remain
available, including ApplyCategoryHighlight and UpdateMenu.

Click, edit and drag handlers are installed when an emote button is created.
Refreshes replace its current category, slot, commands and both Send flags without
replacing those handlers. Retired rows clear all bindings and ignore click/edit
callbacks. Drag click suppression survives the refresh until its existing deferred
cleanup, preserving post-drop behavior. No saved-data or transfer changes are made.

The menu-renderer integration suite covers record replacement, sparse category
selection, independent Send flags, gear visibility, retired rows, suppression and
Profile replacement using real database/window modules. Existing suites continue
to cover reorder, tooltip ownership, font changes, geometry and selective refresh.
In-game acceptance remains pending for category hover, editing, both Send choices,
drag/drop, gear visibility and switching Profiles/Themes.


## Phase 4

MenuDrag shares cursor conversion, edge scrolling, row hit testing and lazy drop
indicator rendering between the category and emote panes. Each pane has its own
controller and indicator; the row pools remain live references and a color getter
reads the current Theme. Scrolling runs before hit testing, preserving the existing
140-pixel-per-second speed, 14-pixel edge zones, inclusive row boundaries and
midpoint insertion rule.

MainWindow still owns drag start/stop, permission checks, drag state, selected
category identity, visible-slot reorder policy, scroll restoration, editor refresh
and post-drop click suppression. Settings list ordering retains its distinct
compacting policy. No saved-data, transfer or gesture behavior changes are intended.

The direct component suite verifies scaled coordinates, row edges and midpoint,
hidden/unbound rows, missing geometry, scroll thresholds and clamping, geometry
after scrolling, current colors and independent reusable indicators. Existing
integration tests exercise every source/gap pair for both window panes, hidden
record preservation, selection and refresh behavior. In-game acceptance remains
pending: drag through both edges of short panes, reorder at different UI scales,
switch Profiles during a drag, and verify the drop indicator and suppressed click.


## Phase 5

DatabaseNormalization owns saved-value repair and copying, including shared emote
and category copiers. Saved category normalization still repairs records in place
so pending dialog identity guards remain meaningful. Copies allocate independent
records and colors, preserving explicit false Send flags and missing-flag defaults.
Database retains schema initialization, live record access, validation, CRUD and
mutation ordering. Schema 15 and transfer format 2 remain unchanged; strict import
validation remains in Serialization before normalized copies are made.

DatabasePresentation owns preview cancellation and Profile, Theme, activation,
settings and category refresh routing. Database calls it at the original mutation
boundaries; it resolves views when dispatched so headless operations and late view
registration work. Category imports use the same category refresh path. Resetting
all categories explicitly resets the Profile's selected category, then synchronizes
the menu selection. Batch imports still refresh once without selecting imports.

Behavior callbacks read the current Global or Profile owner explicitly, including
after Profile changes and global reset. Settings registration and the Emotes panel
use Profile settings for selected category. The mixed GetSettings proxy remains
as a compatibility entry point, with no internal production callers.

The database component suite covers copy isolation, identity preservation, Send
flags, settings ownership, headless resets, cancellation/mutation/refresh order,
failed mutations, inactive Theme changes, batched imports and fallback view hooks.
Existing data, serialization, Behavior, Theme, Profile and dialog suites continue
to validate integration. In-game acceptance remains pending for Profile/Theme
switches during edits or color previews, global resets, imports and category resets.


## Phase 6

SettingsControls now composes labeled integer, switch and color controls using
small helpers over SettingsWidgets. Behavior and Theme call sites use named layout,
bounds, getter/setter, suffix and owner options. Panel callbacks still own unit
conversion, persistence, dependencies and runtime refresh decisions. Font controls
retain their specialized provider and tooltip logic in Themes, with named options
for their layout and binding.

Coordinates, widths, row heights, suffix spacing, signed-position input and numeric
bounds remain unchanged. A relative controlOffsetY allows a row cursor to advance
only once per control. Integer editing, cancellation and owner validation remain
in SettingsWidgets; color sessions remain in SettingsColorPicker. No new widget
framework, saved settings, defaults or transfer changes are introduced.

The settings-controls suite checks named placement, single row advancement, silent
construction/refresh, bounds, signed values, owner changes and disabled drafts with
real widget adapters. Existing Behavior and Theme suites verify control positions,
dependencies, Profile/Theme changes, provider refreshes and color picker lifecycle.
All six phases are implemented. In-game acceptance remains pending for the earlier
checklists and the Behavior/Theme controls, especially focus loss, Escape, disabling
controls during edits, font menus and color preview/cancel.
