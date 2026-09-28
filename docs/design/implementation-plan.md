# Profile/Theme Refactor Implementation Plan

Status: approved staged plan. This document is a living checklist. Preserve the phase boundaries so data-model changes and UI/readability changes can be debugged independently.

See also:

- `saved-data-model.md`
- `settings-architecture.md`

## Phase 0 — Document the architecture

- [x] Record Global/Profile/Theme ownership.
- [x] Record Character -> Profile -> Theme relationship.
- [x] Record Default Profile/Theme semantics.
- [x] Record bundled Theme semantics.
- [x] Record Theme deletion/fallback behavior.
- [x] Record import/export boundaries.
- [x] Record clean-break compatibility policy.
- [x] Record settings readability/layout rules.
- [x] Preserve this staged implementation plan.

Runtime Lua is intentionally unchanged in Phase 0.

## Phase 1 — Restructure definitions and saved-data schema

- [x] Split defaults into `DefaultGlobalSettings`, `DefaultProfileSettings`, and `DefaultThemeSettings`.
- [x] Split key ownership into Global/Profile/Theme key lists.
- [x] Move `selectedCategory` to Profile.
- [x] Move window geometry, lock, fade/minimize, and minimized-icon size/side from Global to Profile.
- [x] Keep only true application preferences Global.
- [x] Move the current visual Profile settings to Theme.
- [x] Convert bundled visual Profiles to bundled Themes (and rename definitions/files where appropriate).
- [x] Establish the new saved-variable shape and invariants.
- [x] Remove obsolete migration machinery rather than adapting it to the new clean-break schema.

Phase 1 keeps the merged `GetSettings()` view as a temporary runtime bridge; it routes each key to its new owner. The existing Profile exchange format still carries visual settings as an interim bridge and does not yet represent Profile-to-Theme sharing. Phase 4 replaces that format. The settings layout refactor remains in Phases 6–7.

## Phase 2 — Create explicit Database Profile and Theme APIs

- [x] Provide explicit Global, Profile, and Theme getters.
- [x] Implement Profile create/copy/rename/delete/restore operations.
- [x] Implement Theme create/copy/rename/delete/restore operations.
- [x] Implement bundled Theme restore/recreation.
- [x] Preserve per-character active Profile selection.
- [x] Add Profile -> Theme assignment operations.
- [x] Add queries for Profiles referencing a Theme.
- [x] On confirmed deletion of an in-use Theme, reassign referencing Profiles to Default Theme.
- [x] Normalize invalid Profile/Theme references to their Default fallbacks.
- [x] Reduce reliance on the current merged writable `GetSettings()` proxy; writes should make ownership apparent.

Phase 2 provides explicit access and lifecycle operations for Profiles and Themes. An in-use Theme deletion requires a confirmation flag; callers can query the affected Profiles before presenting the warning. The merged `GetSettings()` proxy remains for the existing runtime/settings consumers until Phases 3 and 5 convert those call sites.

## Phase 3 — Convert runtime consumers to the three scopes

- [x] Update MainWindow to obtain Global/Profile/Theme values from the correct owner.
- [x] Separate application of Profile state from application of Theme appearance where useful.
- [x] Update minimized-icon color behavior to read Theme state.
- [x] Ensure Profile switching applies categories, window state, and referenced Theme.
- [x] Ensure Theme changes update appearance without changing Profile content/state.
- [x] Ensure Global preference changes remain independent.
- [x] Verify character-specific Profile selection and Default fallback.

MainWindow and minimized-icon color now read their explicit scopes. Profile switching rebinds all three scopes and cancels pending fades; Theme changes refresh appearance without running the full Profile switch. A title-bar orientation change adjusts the active Profile's saved anchor only to keep the window's upper-left corner (and its minimized icon) stationary. Settings controls still use the temporary merged proxy until the UI phases. WoW frame geometry requires an in-game smoke test.

## Phase 4 — Redesign serialization

- [x] Bump the serialization format version.
- [x] Profile export: name, Profile settings, categories/emotes, Theme reference; do not embed Theme.
- [x] Profile import: preserve data; if referenced Theme is unavailable, assign Default Theme and report the fallback.
- [x] Theme export/import: appearance only.
- [x] Everything export/import: all Profiles, all Themes, and Profile -> Theme relationships.
- [x] Keep category-level import/export.
- [x] Do not accept obsolete Profile serialization merely for migration compatibility.

Format 3 separates Profile settings/content from Theme appearance. Everything import adds renamed copies of colliding Profiles and Themes and remaps references to preserve sharing; character assignments stay local. Standalone Profile import reports a missing Theme and falls back to Default. The Phase 5 settings dialog calls the dedicated Profile, Theme, and Everything APIs; temporary `ExportAllProfiles`/`ImportAllProfiles` aliases remain until the transitional API cleanup. Obsolete version 2 Profile documents are rejected.

## Phase 5 — Build the new Profile and Theme management UI

- [x] Make Profiles a genuine Profile-management panel.
- [x] Put Theme assignment on the Profile panel.
- [x] Support Default Profile edit/restore but not rename/delete.
- [x] Rename/rework Appearance into Theme management and Theme appearance editing.
- [x] Support Default Theme edit/restore but not rename/delete.
- [x] Present existing visual presets as bundled Themes.
- [x] Allow bundled Themes to be edited and restored/recreated.
- [x] When deleting an in-use Theme, warn and list referencing Profiles before confirmation.
- [x] Add separate Profile and Theme import/export actions.
- [x] Update complete-data import/export UI.

This phase establishes the final UI responsibilities before structural source cleanup.

The Themes tab edits a selected Theme independently of the character's assignment. Theme
assignment lives on Profiles. An in-use Theme deletion lists its referencing Profiles
and reassigns them to Default only after confirmation. Phase 6 moved Theme icon
controls out of MinimizedIconColor and into the Themes settings modules.

## Phase 6 — Perform the structural settings readability refactor

- [x] Organize settings code by tab -> section -> control.
- [x] Make source order substantially match visual order.
- [x] Split oversized settings code into appropriately scoped modules/functions.
- [x] Separate construction from dependency/refresh behavior where practical.
- [x] Move settings-page presentation out of unrelated subsystems such as minimized-icon color rendering.
- [x] Move Profile/Theme dialogs and lifecycle mechanics out of top-level visual construction flow.
- [x] Keep Emotes layout structure separate from dynamic list/drag mechanics.
- [x] Preserve existing behavior and the agreed UI standards.

This is a required project phase, not optional cleanup.

Settings.lua now registers the tabs and their refresh entry points. Controls, exchange
dialogs, and each tab's settings live in focused files in `.toc` visual order. Theme
appearance uses section constructors; the minimized icon renderer handles only the
live icon, while Theme settings own the swatch and preview. Profile and Theme prompts
have dedicated modules. Emote list layout, row construction, and row actions are
separated. Phase 7 advances ordinary settings rows with a small cursor while
retaining the Theme editor's two columns and the Emote list's scrolling layout.
The `tests/settings-smoke.lua` WoW UI stub checks settings registration, load order,
Theme editing and assignment, in-use deletion prompts, Emote drag ordering, and
exchange actions; the in-game integration matrix below still needs manual verification.

## Phase 7 — Replace manual vertical layout with small helpers

This may be implemented alongside Phase 6 but should remain a distinct review target.

- [x] Introduce a small, understandable section/row layout mechanism.
- [x] Use consistent row advancement instead of hand-maintained Y coordinates for ordinary rows.
- [x] Preserve explicit gaps where semantically useful.
- [x] Preserve purpose-built layouts for special cases such as two-column Theme controls.
- [x] Eliminate create-then-immediately-reanchor patterns where possible.
- [x] Keep standard row order: label, control, reset, info.

The shared row cursor only advances vertical positions and creates section headings.
Panels retain their own controls and special layouts. Smoke assertions cover key
Behavior, Theme, Profile, and Emote anchors; the in-game matrix remains outstanding.

## Phase 8 — Cleanup and verification

- [x] Remove transitional APIs and obsolete Profile/Appearance terminology.
- [x] Search for old `BuiltInProfiles`, old setting-key ownership, and stale Profile-appearance assumptions.
- [x] Update README/help/About text.
- [x] Verify `.toc` load order after any file split.
- [x] Verify Settings registration and slash-command opening.
- [x] Verify settings refresh entry points.
- [x] Review Lua function/upvalue complexity after the refactor.
- [x] Update version/changelog as appropriate.

The `.toc` paths exist and load the Settings dependencies before `Core.lua`.
The settings smoke test covers registration, refresh, About/Settings slash routes,
Theme editing and assignment, Emote drag, and JSON exchange. A data-model smoke test
covers per-character selection, shared Theme references, deletion, and reload.
All Lua modules compile;
the largest function has 33 upvalues (in `MainWindow.lua`). The integration matrix
below still needs a live WoW session and has not been marked complete.

### Integration test matrix

- [ ] Fresh install -> Default Profile -> Default Theme.
- [ ] Different characters independently select different Profiles.
- [ ] Two Profiles share one Theme; editing that Theme updates both.
- [ ] Profile switch changes categories/emotes, window state, and referenced Theme.
- [ ] Theme switch changes appearance only.
- [ ] Deleting an in-use Theme lists referencing Profiles.
- [ ] Cancel Theme deletion leaves everything unchanged.
- [ ] Confirm Theme deletion reassigns referencing Profiles to Default Theme.
- [ ] Default Profile is editable/restorable but cannot be renamed/deleted.
- [ ] Default Theme is editable/restorable but cannot be renamed/deleted.
- [ ] Bundled Themes are editable and restorable/re-creatable.
- [ ] Profile import/export works with Theme references.
- [ ] Theme import/export works independently.
- [ ] Everything import/export preserves Profile/Theme relationships.
- [ ] Category import/export still works.
- [ ] Reload UI preserves state.
- [ ] Logout/login preserves state.
- [ ] Character switching preserves per-character Profile selection.

## Commit discipline

Prefer a sequence of coherent commits rather than one large change. In particular, keep data-model/behavior changes distinct from the structural settings readability refactor so regressions can be localized.
