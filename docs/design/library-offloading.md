# Library offloading

This follow-up reduces custom presentation and scheduling work using the
libraries already embedded in RP Emote Menu. Preserve data ownership, validation,
dialog target guards, picker sessions and existing user behavior.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Behavior and Emotes scroll containers use Details Framework canvases | Implemented in 2.0.224; client acceptance pending |
| 2 | Remaining emote-editor and import/export dialog presentation uses Details Framework | Implemented in 2.0.225; client acceptance pending |
| 3 | Suitable refresh/timer bookkeeping uses Details Framework scheduling | Implemented in 2.0.226; client acceptance pending |

The optional CallbackHandler notification refactor is excluded by user decision.
No new library is planned. Profile/Theme normalization, JSON/transfer validation,
missing-font policy and specialized main-window geometry remain addon-owned.

## Phase 1 implementation

SettingsWidgets.CreateCanvasScrollBox centralizes DF canvas construction.
Behavior keeps its anchors and 700-by-670 content; the Emotes list keeps its
anchors, 590-unit content width and dynamic row/Add Emote sizing.

The adapter disables DF scrollbar reskinning, smoothing, acceleration, momentum
and canvas drag scrolling. It retains Blizzard scrollbar assets and native
template handlers. Behavior uses 40 units multiplied by wheel delta magnitude.
Emotes uses the native scrollbar's scrollStep or half its current height, one
step per nonzero wheel event. The inherited policy was checked against Blizzard's
SecureScrollTemplates.lua. The actual wheel movement uses DF's canvas handler.

Content/viewport size changes update the native scroll-child rectangle and clamp
the current offset. Range changes and showing the canvas also keep offsets valid.
The required-method check includes CreateCanvasScrollBox; the pinned shared
framework remains unchanged.

## Verification

All ten smoke suites pass. Real-framework adapter, Behavior and Emotes tests
cover API availability, disabled canvas animation/drag features, wheel magnitude
and zero delta, bounds, viewport resizing, shrinking/empty lists and emote row
reordering. Native scrollbar graphics and real frame-event/layout timing remain
client checks.

In-game acceptance: open both pages, resize settings, wheel/drag the scrollbar,
switch between empty/full categories and reorder emotes. Check that offsets
remain valid, Add Emote stays reachable, and wheel editing of numeric fields is
unchanged. Test standalone and alongside another Details Framework embedder.

## Phase 2 implementation

SettingsWidgets centralizes DF dialog panels, labels, buttons and draft text
entries. The emote editor and transfer dialog retain their dimensions and
addon-owned Save/Import callbacks, validation and captured-target/session guards.
DF supplies presentation; native OnClick remains the sole button action dispatch.

The panel disables DF's default mouse scripts and hidden title bar, uses the
existing left-button drag policy, DIALOG strata, screen clamping and a single
Escape registration. Draft fields bypass DF trimming and focus-loss/Enter commits.
Emote fields continue to validate 128-byte names and 4096-byte commands on Save,
without silently truncating rejected input. Transfer fields have no byte/letter
limit, use a multiline DF text entry and the Phase 1 canvas, and retain existing
content-height estimation and mode-specific actions.

All ten smoke suites pass, including exact whitespace/empty drafts, focus changes,
large transfer text, single action dispatch, stale targets and scroll clamping.
In-game acceptance: check both dialogs' labels, buttons and close control; drag
and press Escape; save with Enter; reject oversized commands without losing input;
paste/export large JSON, select/copy it and scroll to its end. Test standalone
and alongside another DF embedder. Phase 3 is described below.

## Phase 3 implementation

Scheduling.lua loads before FontMedia and resolves DF Schedules lazily so it
uses the current shared library. It requires NewTimer and RunNextTick. Its private
pending map uses addon-owned table/frame keys; it does not share named scheduler
IDs with other addons or alter DF global scheduling state.

NextTick preserves the first queued deadline and merges repeated requests for
scroll indicators, emote hover, font-provider changes, pin state and icon tint.
Each callback reads current state. Replace cancels superseded tooltip/font-retry
timers; Cancel removes the request before canceling its native timer. Dispatch
checks request identity and clears the entry before invoking the callback, so
reentrant requests and callback errors cannot strand or overwrite a new pass.
Defer preserves independent next-frame callbacks, including drag click-suppression
and revision-guarded settings text refreshes.

Tooltip zero-delay display remains immediate. Tooltip ownership/hover checks and
font-generation guards remain addon-owned. Font retries retain delays of 0.25,
0.75, 2, 5, 10 and 12 seconds and stop on success or supersession. Existing fade
timers, opacity animations, auto-hide transitions and per-frame drag tracking
remain unchanged. The optional CallbackHandler refactor remains excluded.

All eleven smoke suites pass. A new suite exercises real DF timers with controlled
native delivery, repeated requests, cancellation, forced stale callbacks,
reentrant callbacks, callback errors, independent deferrals, missing APIs and
actual tooltip cancellation. Existing font tests cover retry bounds and retirement.
In-game acceptance: hover rapidly between controls, change tooltip delay and
Themes/fonts, register a late font provider, scroll/resize and drag emotes, toggle
activation and check fade/minimize behavior. Test standalone and alongside another
DF embedder. All three source phases are complete; client acceptance remains open.
