# Standard-emote picker

## Status and scope

Phase 0 (design) is complete in 2.1.256; phase 1 (catalog model) is complete in 2.1.257; phase 2 (editor interaction) is complete in 2.1.258. Version 2.1.259 fixes draft insertion for unverified entries; 2.1.260 replaces the insertion button with automatic filling and resets selection on manual edits. Version 2.1.262 moves the selector beside Emote Name and removes the heading and alias filter. The dropdown and reference previews now ship; native command verification remains pending. The four localization code phases are complete; native WoW layout/font acceptance remains pending. No additional translation is included.

The picker will help populate an existing emote-editor draft. It will use the supplied locale catalog, keep manual editing available, and leave saving, category limits, import/export schema and command execution under their existing owners. It will not execute an emote during selection.

## First-release interaction

Place the shortened **Emote Name** box, localized **or** label and standard-emote selector on one row. Keep the unselected caption **Choose a standard emote**. Show slash aliases (for example, `/wave`) in alphabetical order, with a bounded scrolling list. Do not show a separate heading or alias filter. Preserve separate alias variants initially rather than guessing synonym groups from similar preview text.

Selecting an entry immediately fills the draft and updates a read-only preview. Display the supplied untargeted and targeted descriptions with clear captions. They are reference wording, not guaranteed current client output. Keep `<target>` as a visible preview placeholder; do not convert it to `{target}`, a real unit name or executable text.

Selection applies the standard emote directly, without a separate button or overwrite confirmation. Field mapping:

| Field | Proposed result |
| --- | --- |
| Emote name | Remove the slash and capitalize the first letter, replacing the previous draft label. A small enUS exception table spaces compound names, such as `/badfeeling` → `Bad feeling`. |
| Default command | Set the exact selected slash alias, such as `/wave`. |
| Targeted command | Clear the targeted override so it cannot replace the selected default with an unrelated command. |
| Saved data | Change nothing until the editor's existing Save action succeeds. |

Editing any of the three emote fields resets the selector to **Choose a standard emote** and returns the reference preview to its initial state without changing the user's text. Programmatic auto-fill and editor initialization do not trigger this reset. Cancel, Escape or closing the editor discards applied draft changes through the existing unsaved-draft behavior.

This mapping is implemented in phase two. It deliberately uses a slash command instead of synthesizing a custom `/e` sentence from preview prose. Native target/no-target behavior must be verified before accepting the feature; if the chosen command requires a different routing contract, revise this plan and cover that change separately.

## Catalog and execution boundaries

The source is `addon.Localization.StandardEmotes[clientLocale]`. The supplied enUS catalog has 299 rows of alias, untargeted preview and targeted preview. Keep the source rows unchanged and build a separate picker model.

Interface text may fall back to English through `addon.L`. Command aliases must not silently fall back across locale boundaries: on a client without its own catalog, leave the manual fields available and explain that standard emotes are unavailable for that locale.

Validate row shape, nonempty aliases, permitted alias syntax and uniqueness before building choices. Sorting must not mutate the catalog. A choice's identity is its exact locale and alias, not its list position or translated preview. A sorted list must retain that identity through selection.

The catalog is user-supplied reference data, not proof that all aliases work in the current client. `Commands.ExecuteEmoteCommand` currently resolves a single slash alias through `addon.EmoteAliases`, then falls back to its uppercase token. Existing aliases and that fallback must remain intact. Catalog shape checks and the existing alias map do not establish native support. Phase 1 must define and document verification status for selectable entries; unsupported or unverified entries must not be advertised as validated commands.

The picker should initially be available only where a valid locale catalog exists. Do not introduce runtime API discovery based on an assumed Blizzard API. Review the actual available client interface before choosing any support-discovery mechanism.

## Integration ownership

| Component | Responsibility |
| --- | --- |
| New catalog model | Validate source rows; build sorted/filterable choices; retain alias/locale identity and support status. |
| `EmoteEditor.lua` | Selection, preview and automatic draft insertion; target/read-only checks; clearing selection on each Open/Hide. |
| `SettingsWidgets.lua` | Reuse the existing dropdown/button styling; bounded list and filter behavior as needed. |
| `Localization.lua` and locale files | Interface captions and locale-specific reference data. |
| `Database.lua` | Existing text limits, edit permission and captured-target validation. |
| `Commands.lua` | Existing execution routing; change only if independently required and verified. |
| `Serialization.lua` | Existing label/default/targeted strings; no catalog index or picker state in exports. |

Use the common editor opened by menu right-click or gear. Adding a separate inline picker to the settings emote list is outside the first release. In a read-only editor, previews may be browsed but insertion must be disabled. Recheck edit permission and captured target when selecting and saving.

Transient picker state belongs to the dialog. Clear selection, filter and preview on every new editor session; reopening must not inherit the previous emote's selection. Refresh the measured dialog layout after preview/filter/status changes. Keep the controls reachable at the intended UI scale; long previews must scroll rather than grow the dialog beyond the screen.

## Implementation sequence

| Phase | Work | Completion evidence |
| --- | --- | --- |
| 0 — Design | Inspect catalog, editor, locale and execution contracts; record proposed behavior and boundaries. | This document; no runtime behavior changes. |
| 1 — Catalog model (complete in 2.1.257) | Implement validation, stable choice identity, sorting/filtering and locale availability; define support verification policy. | Shape/error tests; unchanged source catalog; no mutation of saved data; documented verified/unverified alias status. |
| 2 — Editor interaction (complete in 2.1.258) | Add selector, previews and explicit insertion with overwrite confirmation, read-only and stale-session guards. | Real-editor tests for draft mapping, confirmation, Cancel, reopen, Save, filtering and translated layout; serialization remains unchanged. |
| 3 — Native acceptance | Verify representative aliases and variants, target/no-target/self-target behavior, list usability and layout in WoW. | Recorded native results; no claim of support for unchecked aliases or locales. |

## Acceptance cases

Automated coverage must include malformed rows, duplicate aliases, deterministic order, alias variants, empty lists, missing locale catalogs and stable identity after sorting. Confirm that catalog access and preview never call the execution module.

Editor integration must cover empty and existing drafts, automatic replacement of all three fields, selector reset after each manual field edit, read-only sessions, Profile changes, category/emote replacement, stale dropdown callbacks after hide/reopen, and translated/long previews. Save must continue rejecting over-limit fields without truncation, and Cancel must leave the database unchanged.

Command checks must retain literal percent signs and `{player}`/`{target}` behavior for manually authored commands. Round-trip exports must contain only the existing emote fields and preserve manual command bytes. Native tests must distinguish reference preview wording from actual game output and record the tested client locale and build.


## Phase-one model contract

`StandardEmoteCatalog.lua` loads after Defaults and locale registration. It exposes `addon.StandardEmoteCatalog` and does not create SavedVariables, UI frames, execute commands or alter the command module. `Build(locale, rows, options)` returns a snapshot or a developer diagnostic on invalid input. Catalogs and rows must be dense arrays, each row must contain exactly three strings, and aliases must be unique lowercase ASCII letters/digits beginning with a letter. This grammar covers the supplied enUS data; supporting locale aliases outside it requires a reviewed extension. Empty catalogs are valid but contain no choices.

Each choice contains `locale`, `alias`, `value` (`locale:alias`), `command`, resolved `token`, `defaultPreview`, `targetedPreview`, `supportStatus`, `selectable`, and optional `evidence`. Resolving the token mirrors the existing alias map plus uppercase fallback; this does not prove game support. `model:GetChoices(verifiedOnly)` returns copied entries sorted by alias, optionally restricted to verified entries. Alias text filtering was removed in 2.1.262. `model:Resolve(value)` returns a copied entry by exact stable identity. Mutating returned entries or later source/review data cannot change an existing snapshot.

`GetForClient({clientBuild = "..."})` builds from the current locale's catalog, existing execution alias map and `Catalog.Verification[locale]`. Its state is `available`, `unavailable` or `invalid`; invalid includes a developer diagnostic. Availability means reference data is present and valid, not that commands are verified. There is no cross-locale catalog fallback or automatic client API discovery. All 299 enUS entries are initially **unverified**, and `GetChoices(true)` therefore returns no verified entries until native evidence is recorded. Unverified entries remain selectable for draft insertion; `selectable` means insertion is permitted, not that native support is verified.

Verification records are developer-maintained runtime data, not user settings. `Catalog.Verification[locale][alias]` may contain `locale`, `clientBuild`, `token`, `status` (`verified` or `unsupported`), nonblank `evidence`, and `targetingChecked`. The locale, build and token must match the model. Verified entries additionally require `targetingChecked = true`, meaning native target/no-target/self-target checks were recorded. Unsupported entries remain unselectable. Missing, malformed or stale evidence produces unverified status. The caller supplies the actual native client build for verification status; missing build information leaves entries unverified and does not block draft insertion. No build is guessed. No verification records ship in this phase.

Phase two implements browsing, previews and insertion guards using this model. Unverified entries may be inserted into editable drafts. Entries recorded as unsupported for the current locale/build/token remain disabled; native review establishes support status rather than granting draft-editing permission. Native review may begin alongside UI implementation rather than waiting for the final acceptance stage. Shape tests, command-routing stubs and the presence of an alias in existing defaults are not native verification.


## Phase-two editor contract

`StandardEmotePicker.lua` loads before EmoteEditor and constructs controls through SettingsWidgets when the shared editor is first opened. The alias dropdown uses a 240-unit scrolling menu. Selection updates the reference preview and immediately fills the name with a capitalized, slash-free label and the default command with the exact selected slash alias, clearing the targeted override. Compound-name spacing uses a small enUS-only exception table; other locales retain their own aliases. No button or overwrite confirmation is required. SavedVariables and command execution remain unchanged until Save.

The picker rebuilds the current client catalog before filling fields, then checks edit permission and the captured content target. Unverified and verified entries may populate editable drafts; known unsupported entries cannot. Missing, invalid or empty catalogs retain manual fields. Read-only sessions can browse previews without changing fields. Profile/category/emote replacement and retired dropdown callbacks cannot fill a stale draft.

User text changes in any of the three emote fields clear selection, invalidate old menu callbacks and reset the preview and draft status. All field text remains intact. Native text-change hooks preserve framework callbacks and distinguish user edits from programmatic filling. Every Open resets selection; Close retires the picker session.

The preview has a fixed 72-unit scrollable viewport for available catalogs, including long or translated wording. The integration suite checks auto-fill, all three manual reset paths, stale callbacks, support/read-only/target guards, saved-data isolation, Save/Cancel and long preview scrolling. These fixtures do not establish native command support. The localization acceptance suite supplies a synthetic locale catalog to check the picker within the real editor layout.

Phase three is native acceptance: inspect the dropdown/filter/preview at the intended UI scale and record actual aliases, target/no-target/self-target behavior and client build before adding verification records. Native localization/font acceptance also remains pending. The editor still measures the overall dialog height; extremely long surrounding translation copy or a small effective screen can exceed it and must be addressed during native acceptance rather than certified by the synthetic measurements.


