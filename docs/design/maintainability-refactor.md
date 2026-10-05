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
| 2 | Separate transfer-dialog text layout/caret handling, import actions and dialog lifecycle into named components | Planned |
| 3 | Consolidate repeated transfer-mode opening/setup while keeping mode-specific captions, callbacks and replacement rules explicit | Planned |
| 4 | Centralize shared setting limits and enum definitions used by normalization, transfer validation and controls | Planned |
| 5 | Share visible-slot record reordering between categories and emotes; retain selection and drag behavior in callers | Planned |
| 6 | Reduce tests' dependence on private local names/upvalue replacement through explicit component contracts and integration boundaries | Planned |

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
