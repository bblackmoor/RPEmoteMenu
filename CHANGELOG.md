# Changelog

## 2.1.255

- Complete automated phase-four localization acceptance: audit all 288 interface keys and test expanded Unicode text without shipping an unreviewed translation.
- Reject unknown translation keys, changed formatting arguments and lost command tokens; retain English fallback and expose rejection diagnostics.
- Reflow emote-editor labels above their fields and measure dialog help, status text and action captions; preserve a usable import/export text viewport.
- Add translation-contract and dialog-layout regression coverage. Native WoW rendering and non-Latin font acceptance remain pending.

## 2.1.254

- Complete phase three of interface localization: menu titles, empty states, tooltips, lock/settings hints, and emote-editor labels, help and status messages.
- Measure the localized Add Category caption when calculating empty-sidebar width, matching the visible button.
- Add translated menu/editor coverage for width measurement, literal user text and tokens, command dispatch, validation and stale editor targets.

## 2.1.253

- Complete phase two of interface localization: remaining settings pages, dialogs, tooltips, result messages, validation, framework diagnostics and bundled-theme descriptions.
- Use complete translation templates for messages containing names, counts and validation limits; preserve stored enum values, names, generated copy/import names, command text and schema version 2.
- Add synthetic-translation regression coverage for dropdown values, validation, theme identity and byte-for-byte identical exports.

## 2.1.252

- Begin interface localization with an English fallback table, client-locale selection, settings navigation and About-page strings.
- Preserve the supplied 299-entry standard-emote reference catalog in the English locale file for a future dropdown.
- Document the remaining conversion phases and add locale fallback/navigation regression coverage.

## 2.1.251

- Refresh menu fonts after display-size and UI-scale changes, including Alt-Tab window resizing; defer refresh until WoW applies the new scale.
- Invalidate cached title, category, outline, emote and empty-state glyphs and remeasure automatic column widths without changing saved font sizes or window geometry.
- Add display-scale regression coverage for hidden menus in both title-bar orientations and all three minimize modes. All seventeen smoke suites pass; in-game acceptance remains pending.

## 2.1.250

- Treat native dragging and resizing as activity; block new inactivity requests, pending timers and automatic collapse completion while a gesture is active.
- Cancel inactivity on resize start, retire gestures before manual minimize changes or collapse, and restart normal inactivity after release when the pointer is already outside.
- Cover both gestures in both title-bar orientations and all three minimize modes, plus timer and animation completion guards. All seventeen smoke suites and Lua syntax checks pass; in-game acceptance remains pending.

## 2.1.249

- Finish active drag/resize gestures before Center Window, Reset Window and exact geometry changes, allowing the requested layout to supersede the gesture.
- Preserve center anchors, reset defaults and signed advanced offsets against delayed release callbacks and unrelated size events.
- Cover all three actions during dragging and resizing in both title-bar orientations. All seventeen smoke suites and Lua syntax checks pass; in-game acceptance remains pending.

## 2.1.248

- Finish active move/resize gestures before hiding, Profile rebinding, locking or Theme application.
- Save interrupted gestures to their original Profile and clear interaction state before native stop callbacks, preventing stale releases and later layout changes from overwriting saved geometry.
- Add integration coverage for Profile changes in both title-bar orientations, hidden resizes, late release callbacks, locking and Theme application. All seventeen smoke suites pass; in-game acceptance remains pending.

## 2.1.247

- Use native WoW window dragging instead of polling the cursor and resetting the anchor every frame.
- Preserve the upper-left corner when dragging begins, save and clamp the position on release, and stop movement when the menu is hidden.
- Verify both title-bar orientations, drag handles, movement locking and saved-position restoration; in-game responsiveness still requires acceptance.

## 2.1.234

- Complete maintainability Phase 6: replace private-upvalue inspection and mutation in the remaining behavior, geometry, scheduling and font suites with real window/widget integration.
- Preserve geometry, Profile rebinding, pane-wide font fallback and retry coverage; exercise tooltip ownership through native hover events, including stale owners, hidden rows and immediate presentation.
- Share minimal native window test support without adding production test hooks or changing addon behavior, saved data or transfer schema.
- All fourteen smoke suites pass; all six implementation phases are complete, with in-game acceptance still pending.

## 2.1.231

- Complete maintainability Phase 3: consolidate transfer-session setup, captions, text, scrolling, action state, focus and selection in one named helper.
- Retain eight explicit opening methods with their original instructions, export preparation and mode-specific callbacks; consistently clear unrelated session targets and callbacks.
- Preserve active sessions when export preparation fails, and retain category-target capture and stale-confirmation rejection.
- Add coverage for all 64 mode transitions, focus/selection, callback cleanup and all four export failure paths. All thirteen smoke suites pass; in-game acceptance remains pending.

## 2.1.230

- Complete maintainability Phase 2: separate transfer text layout/caret state, import actions and native lifecycle wiring into dedicated components.
- Keep SettingsExchange as the frame/mode coordinator and preserve all eight mode-opening methods unchanged for Phase 3.
- Preserve exact drafts, rendered wrapping, caret resizing, category replacement guards, confirmation snapshots, import callbacks and result messages.
- Replace the affected text-layout test's private-upvalue lookup with explicit measurement input and add focused component/lifecycle coverage. All thirteen smoke suites pass; in-game acceptance remains pending.

## 2.1.229

- Begin the six-phase maintainability refactor and change the base version to 2.1 while continuing the running commit number.
- Complete Phase 1: extract the emote editor, independent geometry calculations and fade/auto-hide/animation controller from MainWindow behind explicit component boundaries.
- Preserve MainWindow entry points, captured editor targets, saved geometry, activation, fade timing and minimized-mode behavior. Saved data and transfer schema are unchanged.
- Record non-overlapping scopes for Phases 2–6; remove unused Core joke code as incidental cleanup.
- Add explicit geometry/fade component tests and update module loading. All twelve smoke suites pass; in-game acceptance remains pending.

## 2.0.228

- Retain transfer-editor caret bounds and recheck visibility after viewport/editor size changes, including height-only resizing without a new cursor event.
- Invalidate cached bounds on text replacement, dialog hiding and width changes so prior drafts and wrapping cannot redirect scrolling.
- Add stationary-caret resize and stale-bound regression checks. All eleven smoke suites pass; in-game acceptance remains pending.

## 2.0.227

- Measure transfer-editor content with font-rendered word and non-space wrapping instead of byte-count estimates; remeasure on text, viewport, editor-size and show changes.
- Keep empty and trailing-newline rows visible, preserve full draft text, and synchronize edit/scroll-child dimensions with the viewport.
- Follow the transfer caret in both directions with padding and bounded scroll offsets, including cursor events that precede layout updates.
- Add regression coverage for proportional glyph widths, Unicode, resizing, caret visibility, empty/shrinking content and reentrant size callbacks. All eleven smoke suites pass; native text rendering remains an in-game check.

## 2.0.226

- Complete library-offloading Phase 3 with an addon scheduling adapter backed by Details Framework timers.
- Coalesce repeated scroll-indicator, emote-hover, font-provider, pin and minimized-icon refreshes; preserve independent next-frame callbacks and settings field revision guards.
- Cancel superseded tooltip and font-retry timers while retaining ownership/generation checks, existing delays and bounded retries. Fade animation and drag tracking remain unchanged.
- Clear queue entries before callback dispatch so reentrant refreshes survive; add real-framework tests for cancellation, stale delivery, coalescing, callback errors and tooltip ownership. All eleven smoke suites pass; in-game acceptance remains pending.

## 2.0.225

- Complete library-offloading Phase 2: use Details Framework panels, labels, buttons and draft text entries for the emote editor and import/export dialogs.
- Use the canvas adapter for transfer scrolling; preserve exact text, unlimited transfer input, existing Save/Import actions, validation and captured-target guards.
- Keep dialog dimensions, dragging and Escape behavior; disable DF default text commits and panel click-to-move/right-click-close behavior.
- Add real-framework tests for draft focus, empty/whitespace text, large transfer input, action dispatch and scroll clamping. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.224

- Complete library-offloading Phase 1: use Details Framework canvas scroll containers for Behavior and the Emotes list, preserving anchors, content sizing and native scrollbar appearance.
- Preserve Behavior's 40-unit delta-scaled wheel and Emotes' native scrollbar step; disable canvas drag scrolling, momentum and smoothing so emote drag ordering remains independent.
- Clamp offsets after viewport/content changes and add real-framework tests for wheel limits, zero delta, resizing, shrinking/empty lists, API availability and row reordering.
- Record the three-phase plan with the optional CallbackHandler refactor excluded. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.223

- Include Default Theme in Restore Bundled Themes, along with all five bundled presets; preserve custom Themes and Profile assignments.
- Include Default in captured-target and name-conflict validation before any bulk mutation, and refresh the active appearance when Default is restored.
- Update confirmation text, restored count and README; add coverage for Default restoration and stale-confirmation rejection. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.222

- Replace show-at-login with a global Active switch and Active/Inactive status, following Simple Nameplates; /rpem toggles activation and settings commands remain available while inactive.
- Activation shows the full window at normal opacity before normal fade/minimize timers resume; deactivation hides the window and minimized icon. Preserve false boolean settings across reload.
- Share byte limits between editors and transfers: 128 for category names/emote labels and 4,096 for commands. Reject overlong edits without partial saves or truncation, and keep generated duplicate category names within the limit.
- Add activation, reload, native editing, multibyte text and transfer-boundary regressions. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.221

- Reject factory Theme recreation/restoration when a differently capitalized Theme already uses that name; preserve its settings and Profile assignments and explain how to resolve the conflict.
- Check all bundled Theme names before bulk restoration to prevent partial resets or duplicate names that break Everything export/import.
- Correct Theme import instructions to state that the imported Theme is assigned to the active Profile.
- Add regression coverage for native recreation, atomic bulk rejection, conflict resolution and export/import validity. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.220

- Bind Theme deletion warnings to the displayed affected Profile names and objects; reject acceptance if Profiles join, leave, are renamed or are replaced while the dialog is open.
- Require reopening to review the current list before deleting the Theme and assigning affected Profiles to Default.
- Add regression coverage for changed Profile sets, same-name replacements, initially unused Themes and successful fresh confirmations. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.219

- Bind Profile and Theme Copy, Rename, Delete and factory-restore dialogs to their original objects; reject pending actions after deletion, name reuse or same-name replacement.
- Validate every bundled Theme target before a bulk restore, including missing presets, so a stale confirmation cannot partially reset or overwrite replacement Themes.
- Add native-dialog regression coverage for name reuse, deletion/recreation and restore replacements. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.218

- Close open dropdown menus when disabled and guard native pooled option clicks before Details Framework changes selection; disabled, closed and retired entries leave saved values and displayed selection unchanged.
- Preserve canonical selection and label caches after callback refresh/rejection; leave the pinned shared framework unchanged.
- Hide missing-font tooltips on refresh, mouse leave and control hiding only when owned by that selector; preserve other controls’ tooltips.
- Exercise native option clicks across adapter, Behavior, Profile, Theme and Emotes suites, including row reuse and rejection. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.217

- Bind native emote Save, Delete, category restore and category import operations to their captured Profile/category/emote identities; reject stale targets after selection, reorder or replacement.
- Retire category-import confirmations when the shared dialog closes or opens another session, preserve pasted JSON on rejection, and require reopening before retrying a changed target.
- Expand Emotes regression coverage for the reproduced data-loss cases and valid operations; remove obsolete native-control comments and replace a vacuous Behavior assertion. All ten smoke suites pass; in-game acceptance remains pending.

## 2.0.216

- Complete Phase 6: convert Emotes selectors, category-name editing and ordinary action buttons to Details Framework; retain custom rows, scrolling, native dialogs and JSON editor.
- Guard pending category-name edits, preserve exact/empty values and deferred show refresh, and retire active list drags before rows are refreshed or the page is hidden.
- Remove unused native widget helpers and add real-framework Emotes integration coverage; all ten smoke suites pass, with final in-game acceptance pending.

## 2.0.215

- Convert Theme management, fonts, numeric fields, RGB swatches, effects, opacity, title-bar selection and icon actions to Details Framework while preserving layout and native dialogs/preview.
- Retain FontMedia missing/late/shared-font handling and the existing picker manager; preserve shared Theme edits, captured restore targets, Recreate actions and reset scopes.
- Add Theme integration coverage for fonts, ownership, hidden fields, picker lifecycle, tint, CRUD and transfers; all nine smoke suites pass, with in-game checks pending.

## 2.0.214

- Convert Profiles selectors/actions, About's source link and the Everything transfer buttons to Details Framework; preserve layout, native popups and the JSON editor.
- Refresh Profile/Theme menu choices after CRUD and imports, close invalidated menus and retire stale option callbacks while preserving selected labels and Theme synchronization.
- Add real-framework/database/serialization integration checks for dialog targets, Default protection, reset scope, transfer routes and long scrolling menus; all eight smoke suites pass, with in-game checks pending.

## 2.0.213

- Convert the Behavior page's switches, numeric fields, minimize selector and action buttons to Details Framework while preserving layout, ownership and runtime calls.
- Guard pending Global/Profile edits across selection and resets; cancel edits when fields are disabled or the page is hidden, and keep refreshes silent.
- Add real-framework/database Behavior integration tests covering dependencies, input limits, signed coordinates, reset scopes, geometry and scrolling; in-game checks remain pending.

## 2.0.212

- Complete settings conversion Phase 2: embed pinned Details Framework and isolated switch, dropdown, button, RGB swatch, text and integer adapters; settings pages retain their current controls.
- Preserve exact/empty text, edit cancellation, owner guards, silent refresh, disabled controls and signed numeric editing; reuse the existing color-picker manager and font policy.
- Add real-framework integration checks alongside the five existing smoke suites.

- Complete settings conversion Phase 1: document current behavior, ownership, input contracts, the six-phase Details Framework plan, and verification gates; no runtime or addon-version change.

## 2.0.211

- Bundle shared-font dependencies and isolate font lookup without changing saved Theme names or JSON format.
- Refresh font choices and selected text when providers register fonts or change shared-font overrides; preserve missing selections and fallback rendering.
- Replace unconditional thirty-second font refreshes with bounded retries after rendering failures, and keep automatic widths in sync.

## 2.0.210

- Bind all Theme color pickers, including the minimized icon, to their opening Theme and retire stale callbacks.
- Cancel previews before Profile/Theme changes, factory restores, swatch hiding, or opening another picker; preserve accepted colors and protect other addons’ pickers.

## 2.0.209

- Publish the current state as release 2.0.209; see [Changes from v1 to v2](docs/releases/2.0.209.md) for the major-version summary and upgrade compatibility.
- Remove border color and style from Themes and their editor.
- Render the menu without an outer border or sidebar divider, regardless of old saved or imported border values.

## 2.0.208

- Combine the title bar and emote gear visibility options into one global toggle.
- Keep hidden emote gears hidden on hover, while retaining right-click editing.

## 2.0.207

- Use import/export format version 2, rejecting other versions without migration.
- Silently ignore invalid or unknown Profile and Theme settings while retaining valid settings and strict category and emote validation.

## 2.0.206

- Anchor the minimized icon to the upper-left corner for both title-bar orientations.
- Let the category and emote lists move with the title bar while keeping the window corner fixed.
- Make both title bars 32 pixels thick and remove the obsolete Icon side setting.
- Continue accepting older version 3 Profile exports containing Icon side.

## 2.0.205

- Center the minimized icon on the left title bar's pin, regardless of icon size.
- Keep the category and emote lists in place when switching title bar orientation.
- Apply the Icon side preference only when the title bar is on top.

## 2.0.204

- Reduced the gap between Theme management and the Theme editor.
- Matched the left title bar's width to the top title bar's thickness.
- Set the default inactive opacity for new and restored Profiles to 50%.

## 2.0.203

- Completed the Profile and Theme settings refactor, with small row layout helpers and clearer module boundaries.
- Updated the documentation for shared Themes, per-character Profile selection, and Profile-owned window settings.
- Expanded settings smoke checks for row placement and slash-command routing.

## 2.0.202

- Stack the pin and settings controls above the text in the left title bar.

## 2.0.201

- Replaced settings checkboxes with sliding on/off switches and standardized control spacing.
- Reorganized profile controls around selection, restore, create, copy, rename, and delete; added a confirmation dialog to restore Default.

## 2.0.198

- Keep the first category, first emote, and minimized icon at nearly the same screen height when changing title bar orientation.

## 2.0.197

- Applied one visible-menu opacity to adjoining category and emote backgrounds, removing the darker overlap.
- Removed the separate background opacity control; opacity now affects the whole visible menu.

## 2.0.185

- Separated global app behavior and preferences from per-profile appearance.
- Reorganized settings into Behavior and Appearance sections with independent resets.
- Profile imports ignore unknown or invalid appearance settings while retaining valid categories, emotes, and appearance values.

## 2.0.184

- Added a 0-1000 ms delay for main-window tooltips, defaulting to 350 ms.
- Pending tooltips are cancelled when the cursor leaves or moves to another control.

## 2.0.183

- Added right-click category editing from the main menu.

## 2.0.182

- Added drag-and-drop category sorting with the same insertion indicator and edge scrolling used for emotes.

## 2.0.181

- Added a default-off option to hide each emote's edit gear and edit emotes by right-clicking their menu rows.

## 2.0.180

- Added 90-day development ZIP artifacts for every commit to `main`, identified by addon version and short commit SHA.
- Reserved permanent, cleanly named GitHub Releases for matching version tags.
- Added tag-to-TOC version validation before publishing a permanent release.




