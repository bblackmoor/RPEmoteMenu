# Settings conversion to Details Framework

## Status and scope

Phase 1 (baseline) completed on 2026-10-05 against RP Emote Menu 2.0.211,
commit `6c1835d735d7234c97633cbe2ac5b60f68ff7984`. This phase changes documentation
only. The addon version, controls, runtime, saved-data schema and JSON format
remain unchanged.

Phase 2 (foundation) completed on 2026-10-05 in 2.0.212. The pinned framework
and addon-owned adapters are embedded and tested; all existing settings pages
still constructed native controls at that checkpoint.

Phase 3 (Behavior) implemented on 2026-10-05 in 2.0.213. Its ordinary controls
now use the adapters, with ownership, dependency, reset and geometry regression
checks. The in-game checkpoint remains pending.

Phase 4 (Profiles and utility pages) implemented on 2026-10-05 in 2.0.214.
Profiles, About's source link and the transfer-page buttons use the adapters;
name/confirmation popups, the circled information link and JSON dialog stay
native. Its in-game checkpoint remains pending; Phases 5–6 remain planned.

This document governs the new widget conversion. The older
[settings architecture](settings-architecture.md) remains the guide to readable
source organization; its Phases 6–8 refer to the earlier data-model refactor.
Do not confuse the two phase sequences or restore historical controls.

Adopt Details Framework through an addon-owned `SettingsWidgets.lua` adapter.
Preserve the current page layout, behavior and Global/Profile/Theme ownership.
Keep the database and serialization implementations; do not adopt AceDB or the
framework's addon/profile scaffold. MainWindow's menu rendering, fading,
geometry, drag mechanics and command execution are outside the conversion.
Numeric controls remain compact text fields, not sliders.

For each requested phase, read current source and repository instructions,
implement that phase only, verify its scope, update its status here and relevant
documentation, then commit/push through the configured GitHub plugin. Preserve
the removal of automatic ZIP workflows. No AGENTS.md was found in the reviewed
repository tree. Existing open client checks do not constitute observed success.

## Module inventory and boundaries

| Module | Current responsibility | Conversion treatment |
| --- | --- | --- |
| Settings.lua | About, page registration, refresh orchestration, slash destinations | Native category registration/IDs preserved; About link converted in Phase 4 |
| SettingsControls.lua | Row cursor, switches, info links, numeric/content editors, swatches, font selectors | Retain rows and labels; delegate widgets to an isolated adapter |
| SettingsBehavior.lua | Startup/interaction, fade/minimize dependencies, window geometry | Converted in Phase 3; ownership and ranges preserved |
| SettingsProfiles.lua / SettingsProfileDialogs.lua | Character selection, Theme assignment, CRUD, Default restore, transfer | Profiles widgets converted in Phase 4; native confirmation/name dialogs retained |
| SettingsThemes.lua / SettingsThemeDialogs.lua | Theme selection/CRUD, two-column typography, effects, opacity, title bar | Convert widgets; preserve shared Theme assignment and native dialogs |
| SettingsThemeIcon.lua | Icon swatch, Restore Yellow, preview | Adapt swatch/button; retain icon preview and reset scope |
| SettingsColorPicker.lua | Native RGB session ownership, preview/cancel, stale callbacks | Reuse as the sole picker lifecycle; do not copy the SNP picker manager |
| FontMedia.lua | Built-in/shared names, lookup, late-provider notifications | Reuse as the sole font policy; do not embed this policy in DF controls |
| SettingsEmotes.lua / SettingsEmoteList.lua | Category selector/actions/editor and pooled draggable emote rows | Convert ordinary widgets; retain custom rows, scrolling and drag mechanics |
| SettingsExchange.lua / SettingsTransfer.lua | Native multiline JSON dialog and transfer-page actions | JSON editor/dialog retained; transfer-page buttons converted in Phase 4 |
| Database.lua / Serialization.lua | Validation, scope, references, persistence and format 2 | Preserve schema, names, reset semantics and import/export behavior |

Visible order is About (the top-level RP Emote Menu category), Behavior,
Profiles, Themes, Emotes, Import & Export. `/rpem` toggles the menu;
`/rpem about` opens About; config/options/settings open settings. Preserve these
routes, the gear/right-click routes, and all refresh entry points used by the
runtime/database. Construct all pages before registration as the current code
does; keep constructors available before Core initializes the addon.

## Ownership and control baseline

| Group | Scope and factory values | Behavior to preserve |
| --- | --- | --- |
| Startup/interaction | Global: showAtLogin true, tooltipDelayMs 350, hideSettingsGear false | Tooltip field 0–1000 ms; one gear switch controls title/emote gears, preserving right-click editing |
| Fade | Profile: fadeEnabled false, fadeDelay 5, inactiveOpacity 0.5 | Delay 0–60 seconds; opacity displayed as 10–100%; dependent controls disabled/dimmed when fade is off |
| Minimize | Profile: minimizeMode NONE, minimizedIconSize 32 | NONE/TITLE_BAR/ICON; icon size 16–64 px, enabled only with fade on and ICON selected |
| Layout | Profile: locked false, height 250, CENTER anchor, x/y 0 | Signed X/Y coordinates; advanced placement can be offscreen; height 150–630; automatic width remains runtime-owned |
| Selected category | Profile: selectedCategory 1 | Sidebar and settings category selection remain wired to the selected Profile |
| Profile selection | Character assignment to account-wide Profiles; Default initially | Selecting/creating/copying updates this character, while rename/delete update affected assignments |
| Theme selection | Profile reference; Default initially | Profiles assignment and Themes' Theme to edit always name the active Profile's Theme |
| Typography | Theme: categoryFont/emoteFont Friz Quadrata, both sizes 12 | Two independent font selectors; sizes 8–24; preserve names, unavailable labels, fallback and late providers |
| Text/background colors | Theme | Preserve category, selected category, emote text, category/emote backgrounds and selection RGB values from DefaultThemeSettings/BuiltInThemes |
| Selection effect | Theme: background, thickness 2 | Background, Outline, Separator, Underline, Drop shadow; thickness 1–6, visible only for outline/underline/separator |
| Visible opacity | Theme: windowOpacity 1.0 | Display 10–100%; runtime retains uniform visible-menu transparency |
| Title bar | Theme: TOP | TOP/LEFT; preserve window-corner, moving content and stationary minimized-icon behavior |
| Icon tint | Theme: yellow RGB (1, 0.82, 0) | RGB swatch, desaturated preview, Restore Yellow; actual renderer remains in MinimizedIconColor |
| Emote content | Profile | Up to 10 categories/10 emotes each; preserve empty slots, exact strings, default/targeted commands and drag/duplicate/delete behavior |

Use the source definitions for individual preset colors, rather than duplicating
all RGB values in a plan. Default Profile and Default Theme are editable and
restorable, but cannot be renamed/deleted. Five additional bundled Themes are
editable/restorable. There are no additional bundled Profiles. Creating a
Profile uses built-in content and the current Theme; copying creates independent
content/settings with the same Theme reference. Import adds data without
activating it. Theme edits remain shared by every referencing Profile.

| Action | Scope/acceptance behavior |
| --- | --- |
| Restore Global Defaults (Behavior) | Global preferences only; runtime reapplies settings without resetting Profile/Theme values |
| Center Window / Reset Window | Selected Profile geometry through existing MainWindow methods; preserve unrelated settings |
| Restore Default (Profiles) | Confirmation; Default's categories, emotes, window settings and Default Theme assignment; does not restore Theme appearance |
| Restore Theme / Restore Bundled Themes | Confirmation; factory appearance of the named Theme or bundled definitions, preserving custom Themes and Profile data |
| Restore Yellow | Selected Theme's icon tint only; cancel the live picker before applying factory yellow |
| Delete Theme in use | Warn with referencing Profiles; confirmed deletion assigns those Profiles Default Theme |
| Restore category / all categories | Confirmation; selected Profile content via existing database methods; retain current target wiring |
| Import/export | Version 2; preserve validation/defaulting, conflicts, missing-Theme fallback, links and exclusions of globals/character assignments |

## Input, picker and font contracts

Text/content editors track user edits, commit on Enter/focus loss, restore saved
text on Escape, and refresh after page show/database changes. Empty strings can
clear fields; preserve leading/trailing spaces in stored emote strings. Numeric
editors parse/clamp through existing setters, support wheel adjustment, and
restore on invalid input/Escape. Signed coordinate fields accept a minus sign.
A refresh must not become a user commit or redirect pending edits into another
Profile/Theme. Characterize owner changes, hiding and disabled fields with tests
before swapping their underlying control.

DF's reviewed textentry.lua trims default Enter/focus-loss input and does not
invoke the default empty-value callback in all paths. Its default Escape handler
clears focus rather than restoring the saved value. SNP's adapter does not
supply a general text-entry adapter. Phase 2 must explicitly adapt these paths;
do not assume replacing CreateFrame preserves semantics. Keep native JSON and
StaticPopup editors; these specialized controls need no widget replacement.

DF wrappers are not Blizzard frames. Expose a native frame accessor and unwrap
parents/anchors; provide explicit enable state and silent value/label setters.
Existing pages mix Enable/Disable/SetEnabled, ClearFocus, Label/SuffixLabel and
RefreshValue calls; retain these capabilities or adapt call sites deliberately.
Suppress callbacks during creation/refresh, and reject disabled user actions.

Route ordinary and icon swatches through SettingsColorPicker. Cancel restores
the captured RGB only for the current session; Okay/hide commits the preview.
Selection changes, restores, owner hiding and replacement editors retire old
callbacks. Never close or restore another addon's global picker. Keep native
picker ownership separate from the DF swatch wrapper.

Font dropdowns obtain choices/labels/paths from FontMedia. Preserve selected
unavailable names in menus and exports. Refresh labels cheaply; build menus on
opening and handle long lists/scrolling. A programmatic label refresh must not
assign a font, rebuild the menu body or change the active Theme. Keep bounded
rendering-failure retries and automatic-width updates in MainWindow.

## Layout and framework foundation

Retain source order matching visible section order, shared row cursors and
specialized two-column Themes/dynamic Emotes layouts. Labels precede controls,
then related reset/info actions. Keep yellow circled-i text links without a
button background. Preserve row spacing, wrapping and comfortable field gaps.
Reference measurements: FIELD_GAP 12, switches 44×20, numeric fields generally
70×24 (coordinate/height fields 80 wide; typography fields 52 wide), swatches
52×24, Behavior control column 255, Profile selectors 250 wide, font selectors
190 wide. Respect narrower specialized controls instead of imposing DF defaults.

Use the same pinned upstream Details Framework version reviewed for SNP:
[Tercioo/Details-Framework commit 653af57120e1287be784d468324590a9c150ae98](https://github.com/Tercioo/Details-Framework/tree/653af57120e1287be784d468324590a9c150ae98),
LibStub major DetailsFramework-1.0, minor 762, LGPL 2.1. Preserve its license,
source provenance and complete load.xml dependency chain. Current RP Emote Menu
already embeds LibStub, CallbackHandler and LibSharedMedia; reuse them before
loading DF, rather than adding duplicate copies or unrelated optional libraries.

Load SettingsWidgets after Settings.lua has created SettingsUI and before page
constructors execute. Do not overwrite SettingsUI or register pages from the
adapter. Verify required methods when constructing widgets, because an external
compatible library copy can win LibStub arbitration. Use supplied Blizzard
assets for used controls: SNP found default references to Details image files,
including nested dropdown scrollbars. Details/Plater must not be required.

## Preserved phase sequence

| Phase | Deliverable | Completion gate | Status |
| --- | --- | --- | --- |
| 1 — Baseline | This inventory, contracts, scope and phase plan | Review source; run existing suites; no runtime/control edits | Complete |
| 2 — Foundation | Embed pinned DF; isolated switch/menu/button/swatch/text-entry adapters | Real-library tests for load order, frames, enable state, silent refresh, exact/empty text, Enter/Escape/focus loss, signed numbers and assets; pages remain native | Complete |
| 3 — Behavior | Convert its switches, menus, buttons and numeric fields | Ownership, resets, fade/minimize dependencies, coordinate/height/wheel validation, geometry regressions; client checkpoint | Implemented; client pending |
| 4 — Profiles and utility pages | Profiles, About, transfer-page buttons | CRUD, captured dialog targets, Default protection, Theme synchronization, transfer routes, native dialogs/editor, long menus; client checkpoint | Implemented; client pending |
| 5 — Themes | Typography, RGB, effects, opacity, layout and icon widgets | Picker regressions, missing/late fonts, shared edits, factory reset scopes, conditional thickness, two-column layout, native geometry; client checkpoint | Planned |
| 6 — Emotes and cleanup | Ordinary Emotes widgets; retire unused helpers; update docs | Exact/empty text, category/emote edit/drag/duplicate/delete, limits, preserved custom rows/JSON editor, registration/refresh; final client checkpoint | Planned |

Keep the custom scroll canvases, category/emote drag rows, icon preview, native
information links, confirmations and JSON editor where they remain appropriate.
Conversion completeness means a coherent adapter for ordinary settings widgets,
not replacing every native frame with a library object. Do not advance to the
next phase without the user's instruction.

## Phase 2 implementation

`SettingsWidgets.lua` exports isolated switch, dropdown, button, link, RGB swatch,
text-entry and integer-entry factories. Handles expose `GetFrame`, explicit
native-frame parenting/anchors, enable state, sizing and script hooks. Silent
setters and per-handle refresh guards keep refreshes from becoming user actions;
failed framework setters restore the guard before propagating their error.
Dropdowns cache caller-provided options, support explicit invalidation, and can
update a supplied selected label without rebuilding choices. FontMedia remains
the font policy; pages will provide its choices and labels during conversion.

Text entries replace only their own native editing handlers, preserving exact
whitespace and empty strings. User edits commit once on Enter/focus loss and
cancel on Escape/hide/disable. `getOwner` bindings reject pending commits after
Profile/Theme/content identity changes; pages must supply that identity and
refresh after database changes. Page show reapplies saved text. Integer entries
retain compact fields, optional limits, signed-coordinate validation and wheel
increments. Callers still own database setters and runtime updates. Label,
suffix and row composition remain page/helper responsibilities during conversion.

Swatches reuse SettingsColorPicker with native owner frames; the adapter does
not create a second session manager. Used control assets come from Blizzard,
including the dropdown thumb. The bundle preserves the upstream license and
provenance in `Libs/DetailsFramework/UPSTREAM.json`; dependencies precede its
recursive manifest, and adapters load after SettingsColorPicker and before pages.

The new real-library smoke suite loads 52 scripts through nine XML manifests
without Details/Plater, constructs every adapter, checks exact/empty text and
editing events, guards owner changes, tests signed numbers/wheel/limits,
exercises swatches through the real database/session manager, checks used assets,
and verifies compatible newer LibStub copies are retained. Native UI stand-ins
cover API calls and callbacks, not rendering/security or client event ordering.
All six smoke suites pass. No page conversion or saved-data migration is included.

## Phase 3 implementation

The Behavior page now uses four DF switches, seven compact integer entries, the
minimize dropdown and three action buttons. Behavior-local composition retains
native headings/labels, the row cursor and scroll canvas; the shared SettingsUI
factories remain native for later-phase pages. Native labels anchor to unwrapped
frames. Existing control positions, widths, row spacing and disabled alpha remain
unchanged; native rendering still requires the client checkpoint.

Tooltip editing captures `Database.GetGlobalSettings()`; window fields capture
`Database.GetProfileSettings()`. These identities guard pending input across
selection or replacement, unlike the stable merged settings proxy. Global restore
still changes only global preferences. Center/reset actions and coordinates still
use MainWindow's existing geometry policy, preserving signed/offscreen advanced
placement, height limits, automatic width and anchor behavior. Numeric setters
retain their original runtime update calls and bounds.

Fade/minimize dependencies cancel edits before disabling fields rather than
clearing focus first. Page hide cancels pending numeric edits; page show and
runtime/database refreshes update values silently. The minimize menu's selected
value and label refresh together, without invoking its action.

`tests/behavior-smoke.lua` constructs the real DF controls before PLAYER_LOGIN,
uses the real database and geometry functions, and checks ownership transitions,
disabled/cancelled/invalid editing, limits/wheel input, reset scopes, refresh
reentrancy, exact positions/widths/native anchors and scroll bounds. Only native
UI and unrelated renderer operations/measurements are stubbed. The existing
settings suite now loads real DF alongside still-native later-phase pages,
retaining registration, cross-page, Emote drag and slash-route checks. All seven
smoke suites pass. The new Behavior controls need in-game verification before
recording the Phase 3 client checkpoint as passed.

## Phase 4 implementation

Profiles now uses two 250-wide DF selectors and seven action buttons. About's
source link resolves SettingsWidgets at constructor time, because Settings.lua
loads before the adapter. The two Everything buttons use DF while routing to
the existing exchange methods. Native labels retain their positions; handle
anchors unwrap native frames. The yellow circled information link remains native,
as do all name/confirmation popups and the multiline JSON exchange dialog.

Profile/Theme menu providers read the existing database lists. Refresh invalidates
choices and silently sets both selected values and labels, preserving Theme
assignment/editor synchronization. Invalidation closes open menus and retires
callbacks from their previous option generation, so CRUD/import updates cannot
leave stale choices actionable. Database rejection restores the page's selection.
Default's Rename/Delete actions remain disabled and guarded. Copy/Rename/Delete
continue passing captured source names to the existing native dialogs; factory
restore still targets Default without restoring Theme appearance. Database and
serialization schemas, import activation/conflict rules, character assignments,
and runtime implementations are unchanged.

The new `tests/profile-utility-smoke.lua` constructs all six pages in actual
settings-module order with the real framework, database, media and serialization.
It covers captured dialog targets across selection changes, a deleted Copy
source, Default protection, CRUD/menu freshness, Theme synchronization, factory
restore scope, native information/source popups, Profile/Everything transfers,
import conflicts/non-activation, invalid input, long scrolling menus, stale-menu
retirement, selected labels, native anchors and used assets. Native UI/rendering
and runtime appearance updates are stubbed. The existing settings suite now
inspects the converted Profile selector while keeping its Theme/Emote/route
checks. All eight smoke suites pass; visual layout, native popup/input timing,
scrolling and coexistence/security observations remain pending in-game.

## Verification baseline and acceptance checklist

All five existing suites passed during Phase 1 with:

```sh
for test in tests/*-smoke.lua; do
    luatex --luaonly "$test" || exit 1
done
```

The suites are color-picker, data-model, font-media, settings and window-geometry.
Settings tests currently inspect native templates, coordinates and scripts;
adapt their widget inspections during conversion while preserving behavior
assertions. Add real-DF integration tests instead of treating native-stub success
as proof of framework behavior. Preserve tests using the real database, media
libraries, picker callbacks, serialization and geometry. Compile all referenced
Lua and validate the recursive XML manifest when DF is embedded.

All client observations below remain **pending**. At each checkpoint record
client build, addon version, other DF embedders present/absent and actual results:

- Startup and all six registered settings pages; slash/gear/right-click routes.
- Page alignment, readable/wrapped labels, scrolling, two-column layout and menus.
- Mouse/keyboard editing: blank/exact text, Enter, Escape, focus loss, wheel,
  signed coordinates, dependent controls, hidden editors and Profile changes.
- Picker preview/Cancel/Okay, ownership, resets and selection changes.
- Missing/returning/shared fonts, menu label updates and automatic menu widths.
- Profile/Theme CRUD, shared references, factory restores and all transfer modes.
- Category/emote drag/reorder, duplicate/delete and empty/full capacity.
- Window lock/position/height, fade/minimize, title-bar geometry and icon position.
- Startup without Details/Plater, then coexistence with another DF embedder;
  control assets present and no observed Lua/security/taint errors in/out of combat.

Phases 1–4 report source/test readiness only. Neither these tests nor SNP's still
open client checklist establish native rendering or security acceptance.
