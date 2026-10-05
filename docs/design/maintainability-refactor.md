# Maintainability refactor

This is a separate six-phase plan following the completed library-offloading
work. Its goal is clearer responsibilities and explicit dependencies while
preserving behavior, saved data, transfer schema, geometry and dialog guards.

The base version is now 2.1. The final component continues the existing running
commit number: the first implementation commit is 2.1.229, following 2.0.228.
This version change does not imply a database or JSON schema change.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Separate MainWindow responsibilities: emote-editor presentation/actions/session lifecycle, independent geometry calculations, and fade/auto-hide/animation state | Implemented in 2.1.229; in-game acceptance pending |
| 2 | Separate transfer-dialog text layout/caret handling, import actions and dialog lifecycle into named components | Implemented in 2.1.230; in-game acceptance pending |
| 3 | Consolidate repeated transfer-mode opening/setup while keeping mode-specific captions, callbacks and replacement rules explicit | Implemented in 2.1.231; in-game acceptance pending |
| 4 | Centralize shared setting limits and enum definitions used by normalization, transfer validation and controls | Implemented in 2.1.232; in-game acceptance pending |
| 5 | Share visible-slot record reordering between categories and emotes; retain selection and drag behavior in callers | Implemented in 2.1.233; in-game acceptance pending |
| 6 | Reduce tests' dependence on private local names/upvalue replacement through explicit component contracts and integration boundaries | Implemented in 2.1.234; in-game acceptance pending |

Phase boundaries are intentional. Phase 2 keeps the opening methods' behavior
and structure; Phase 3 addresses their duplication. Phase 4 shares metadata,
not normalization/validation policy. Phase 5 does not redesign drag tracking.
Phase 6 addresses the remaining test suite broadly; each earlier phase still
adds or updates the regression checks necessary for its own implementation.

Small incidental improvements may accompany a phase when they are convenient
and do not consume another phase's scope: named options for long argument lists,
local state grouping, simple popup plumbing and unrelated dead-code removal.
The optional CallbackHandler notification refactor remains excluded. Preserve
addon-owned ownership guards, picker sessions, exact drafts and scheduling policy.

## Phase 1 implementation

MainWindow remains the coordinator and owns live frame bindings, settings
rebinding, rendering, drag operations and frame presentation. Three components
are loaded before it:

- EmoteEditor owns its lazy dialog, draft fields, Save validation and captured
  session target. Field construction, Save actions and session lifecycle are
  separate functions. MainWindow.OpenEmoteEditor remains the public forwarding
  entry point; successful saves refresh the menu and settings as before.
- WindowGeometry contains frame-size and position-clamping calculations with
  explicit dimensions/options. MainWindow still owns frame operations, saved
  anchors, persistence and column layout. Existing calculations and limits are
  preserved, including compact top/left title-bar and icon modes.
- WindowFade owns opacity animation, delayed fade/collapse generations and
  pending state. A small context supplies current frames, Profile/Theme bindings,
  minimized-mode predicates and the visibility callback. Existing public fade
  entry points remain. Delays, hover checks, animation durations and cancellation
  behavior are preserved.

MainWindow shrinks from 2,976 to 2,631 lines. The purpose is responsibility
boundaries rather than line count: future editor/fade changes no longer require
working among unrelated rendering and drag state. Rendering, tooltips and font
refresh remain in the coordinator in this phase.

The unused DestroyHumanity function was removed from Core as incidental cleanup.
No new library, saved-data migration, transfer-schema change or UI redesign is
included.

## Verification

All twelve smoke suites pass. Existing suites exercise editor Save/Enter,
whitespace, text limits, stale targets, activation, title-bar geometry, icon
anchoring, drag behavior, settings registration and fonts. A new component suite
uses explicit inputs/context to cover compact-size mode combinations, clamping,
fade/auto-hide cancellation, animation completion, hover rejection, opacity
restoration and settings replacement during delayed callbacks.

In-game acceptance remains open. Check editor opening/saving, activation,
Profile/Theme changes, top/left title bars, stationary icon placement, movement,
height persistence, all minimized modes and delayed fades. Test standalone and
alongside another DF embedder. Phases 2–6 require separate implementation commits.

## Phase 2 implementation

SettingsExchange is now a 300-line frame/mode coordinator, down from 538 lines.
Its eight opening methods remain byte-for-byte unchanged; Phase 3 owns their
repeated setup. Three components load immediately before the coordinator:

- SettingsExchangeText creates an independent layout controller from explicit
  edit box, viewport, scroll child and measurement inputs. It owns renderer
  measurement, cached caret bounds, resizing and reentrancy state. Refresh,
  ResetCaret and UpdateCaret are its small interface.
- SettingsExchangeActions installs status/action-state handling, import execution,
  the category replacement confirmation and button dispatch. Captured-target
  checks stay beside the mutations they protect. Import result/callback behavior
  and successful category-target rebinding are preserved.
- SettingsExchangeLifecycle wires native text, cursor, size, show, Escape and
  hide events to the components. It resets caret state before text measurement,
  clears status before action-state validation on user input, and retires the
  category target and focus when hidden.

The coordinator constructs all components before publishing the lazy singleton.
No saved-data, transfer-schema, UI layout, scheduling or mode-policy change is
included. The affected renderer test now uses the dialog's explicit measurement
frame rather than discovering private local functions by upvalue name. Broad
test-boundary cleanup remains Phase 6.

All thirteen smoke suites pass. The new component test exercises measurement,
caret resizing, failed/successful Profile imports, result callbacks, captured
category confirmations, stale confirmation rejection after hiding, status ordering
and Escape cleanup. Existing integration suites retain real database, serialization
and framework coverage for transfers, exact drafts, stale targets and all settings
routes. Native rendering/event timing and selection/copy remain in-game checks.

## Phase 3 implementation

InstallExchangeModes retains all eight named entry points and their original
mode-specific instructions. OpenSession takes named options and centralizes mode,
data type, category target/index, callback cleanup, captions, status reset, text,
scroll offset, action state, showing, focus and export selection. All session
fields are assigned before SetText can invoke native events. Unrelated Profile
and Theme callbacks and obsolete profileName fields are always cleared.

Exports produce and validate their payload before invoking OpenSession; failure
returns its error without changing the current draft, status, target/callbacks,
focus or scroll position. Category imports still capture a fresh content target
on opening. Replacement confirmation and import execution remain in the Phase 2
actions component, with their existing identity guards. Imports focus empty text;
exports reset the cursor and select the full prepared text. No saved-data/schema,
layout, import policy or library change is included.

All thirteen smoke suites pass. Integration tests exercise all 64 ordered mode
transitions, callback/target cleanup, fresh category targets, focus/selection,
button state and all four export failure paths preserving an active session.
Existing stale-confirmation and import-result tests remain intact. In-game focus,
selection/copy and native rendering checks remain pending. Phase 6 is planned.


## Phase 4 implementation

SettingDefinitions loads after Defaults and supplies named numeric ranges, name
lengths, color-field keys and enums with ordered values and membership tables.
Database normalization, transfer field validation, settings controls, runtime
height/tooltip/icon clamps and offscreen geometry use the shared metadata.
Dropdown labels remain local; order and range captions are preserved. Existing
minimized-icon constants remain available for compatibility.

Recovery and validation stay separate: saved numbers clamp/floor or default;
invalid individual transfer settings are discarded and defaulted by the existing
copy functions. Invalid document structure still fails its existing checks.
Opacity percentage conversion, tooltip milliseconds-to-seconds conversion and
native character versus database/transfer byte limits remain in their callers.
Transfer-only resource limits and unrelated UI layout measurements are unchanged.
No library, saved-data migration or transfer-schema change is included.

All thirteen smoke suites pass. Data-model tests now cover shared numeric
endpoints, out-of-range and fractional fields, nonfinite saved numbers, every
allowed enum, invalid-enum fallback and stable dropdown order. Existing widget,
geometry, transfer, dialog-ownership and component tests remain intact. Native
control and geometry acceptance remains pending in-game. Phase 6 remains separate work.


## Phase 5 implementation

VisibleSlotOrder.Move takes the records table, ordered visible slot indices, a
source position and an insertion gap in the original visible sequence. It moves
record references among those slots without compacting hidden slots, cloning
records or replacing the owning table. Invalid positions and adjacent no-op gaps
return false without mutation. The component loads before MainWindow.

MainWindow's two named reorder callers retain their visibility rules and supply
slot indices. The category caller captures the selected category object and
updates runtime/Profile selection to its new slot after a successful move. Drag
tracking, auto-scroll, indicators, ownership policy, deferred click suppression,
scroll restoration and settings refresh remain in the existing callers. The
settings emote list still compacts its populated records and is unchanged.
No library, saved-data migration or transfer-schema change is included.

All fourteen smoke suites pass. The new suite tests the component directly with
sparse slots, record identity, hidden records, empty/singleton lists, invalid
positions and all source/insertion-gap combinations. It also constructs the real
MainWindow with native frames stubbed and exercises every category/emote drag
combination, category-selection identity, incomplete hidden emotes, no-op refresh
policy and drag cleanup. Existing settings compaction and stale dialog tests
remain intact. In-game drag/scroll acceptance remains pending. Phase 6 is planned.



## Phase 6 implementation

The four remaining private-state-dependent suites no longer discover local
functions by name or mutate closure upvalues. No test uses debug.getupvalue or
debug.setupvalue. Runtime addon code is unchanged; the existing public methods
and the explicit component contracts from earlier phases provide the boundaries.

- Behavior constructs the real database and window before exercising settings
  controls. Public dispatch spies retain the existing action-count checks; the
  real geometry and Profile rebinding methods retain persistence, clamp, reset,
  centering and stale-input checks.
- Window geometry constructs real category/emote rows and observes native frame
  anchors, saved coordinates, icon sizes, gear visibility, borderless backdrops
  and activation. Top/left changes preserve the window corner under both saved
  anchor types. Same-orientation refresh preserves geometry. Existing explicit
  WindowFade tests retain timer, hover, animation and cancellation coverage.
- Scheduling triggers installed category hover/leave handlers on actual rows.
  It retains forced stale timer delivery and adds replacement-owner protection,
  hidden/nonhovered rejection and zero-delay presentation checks.
- Font media constructs the window and supplies only native font application and
  text measurement results. One category label failure checks pane-wide fallback
  on all real category labels/outlines; recovery checks the rendered frame width.
  Existing registration, overrides, transfer preservation and retry checks remain.

main-window-native.lua shares the minimal native coordinate/rendering support
used by these suites. It does not expose addon state or add production test hooks.
The real database, window coordinator and embedded libraries remain loaded.
Native drawing, security and client event timing remain outside the test doubles.

All fourteen smoke suites pass. All TOC Lua scripts compile and the real framework
XML loader is exercised by the integration suites. The six implementation phases
are complete; in-game acceptance remains open for editor, transfer, geometry,
fade/minimized modes, drag/scroll behavior, and standalone/shared-library loading.
No saved-data migration, transfer-schema change, library change or UI redesign
is included.


## Post-review fixes (2.1.235)

Appearance refresh now cancels pending collapse state when retiring an active
collapse animation, allowing a fresh auto-hide timer without requiring hover.
A timer that has not yet started its animation keeps its original deadline.
Component checks cover both minimized modes, hovered/nonhovered refreshes and
successful replacement collapse; the regression fails against the unfixed code.

The shared native window fixture dispatches main-window OnSizeChanged and
OnShow events on actual size/visibility transitions. Event dispatch is scoped
to the addon window so it does not impose synchronous callbacks on embedded
framework construction. Window integration checks cover user resize persistence,
automatic width correction, locked/programmatic resizing, saved expanded height
through both minimized modes and title-bar orientations, Active rejection during
Show and minimized icon restoration. These checks fail when the corresponding
native event dispatch is suppressed. All fourteen smoke suites pass; native
client drawing/event timing and in-game acceptance remain pending.


## Anchor restoration fixes (2.1.236)

RestoreWindowSize no longer treats saved signed anchor offsets as on-screen
TOPLEFT coordinates. Advanced negative x/y values survive Profile reapplication,
Profile switches and database reloads. User drag/resize and reset/center actions
retain their existing clamping/recovery policy.

WindowGeometry.GetAnchorOffsets converts an observed upper-left corner to the
saved point/relativePoint pair using the new frame dimensions and UIParent size.
Title-bar changes now use that conversion for every accepted anchor pair rather
than special-casing CENTER and interpreting all other anchors as TOPLEFT.
The native coordinate fixture independently models all nine anchor positions.

All fourteen smoke suites pass. Window integration checks exercise all 81
accepted anchor pairs with expanded, Icon and Title Bar modes, both orientation
changes, anchor identity and reapplication. Integer saved offsets retain the
existing rounding policy (up to one UI unit across the orientation round trip).
Signed offset checks also cover Profile switching and database reload. Saved-data
and transfer schema are unchanged; in-game acceptance remains pending.


## Height control anchor fix (2.1.237)

The Window height setter now applies geometry with preserveAnchor enabled,
matching the advanced position fields. It retains the saved point/relativePoint
and signed x/y offsets rather than interpreting those offsets as physical
TOPLEFT coordinates. Existing height limits and reset/drag behavior are unchanged.

The Behavior integration suite no longer expects a centered window's anchor to
change when editing height. It verifies centered presentation and drives the
actual Height field for all 81 accepted anchor pairs with signed offsets, typed
height changes and mouse-wheel changes. Center/bottom anchors retain their
natural vertical growth behavior. The corrected centered regression fails
against the old setter. All fourteen smoke suites pass; in-game acceptance
remains pending. Saved-data and transfer schema are unchanged.
