# RP Emote Menu / Simple Nameplates standardization

Use common conventions where the purpose is the same; preserve addon-specific behavior and practical control layouts. Keep the embedded libraries and each addon's scroll backend.

## Phase 1 — About and visual conventions (implemented)

Both About pages use a large About heading, muted description, Version/Author/Category/License metadata, a copyable Source link, Commands, and addon-specific reference sections. RP Emote Menu's page is extracted to SettingsAbout.lua and uses its existing Details Framework canvas adapter. Paragraphs and the source link reflow on resize and show; content grows and shrinks with wrapped text. Simple Nameplates now documents the profiling command. Settings headings use the same font and supporting descriptions the same muted color; adjacent info links use a 12-unit gap. Existing control widths, setters, reset scope and page registration remain in place.

Validation: both complete smoke suites pass, including responsive About expansion/contraction and source-copy behavior. Verify final appearance and native scrolling in WoW at narrow and normal Settings widths.

## Phase 2 — Naming and page registration (implemented)

Settings modules now use addon, UI and Widgets for equivalent locals. Both addons publish page factories through SettingsPanels and use RegisterSettingsPanels with explicit pageOrder, rootCategory, categories and panels. Registration checks all required APIs and factories before constructing pages and ignores repeated calls. Visible page order and slash routes are preserved.

Ordinary editable pages expose panel.Refresh; RP Emote Menu retains RefreshEditors, category selection and font refresh, and Simple Nameplates retains its OnHide edit-cancellation behavior. Equivalent layout fields use LayoutFullWidth/ LayoutText and the info helper is CreateInfoLink. Runtime namespace structure, database contracts and embedded libraries remain addon-specific.

Validation: complete smoke suites, registration preflight/retry/idempotence/order/routing, silent construction and control refresh, profile switching, picker cancellation and editor-target tests. Native appearance verification in WoW remains pending.

## Phase 3 — Database, dialog and picker contracts

Compare ownership boundaries, dialog lifecycle, captured targets and color-picker cancellation. Standardize equivalent contracts while preserving each addon's saved-data schema and runtime behavior.

## Phase 4 — Shared regression checks and documentation

Document the agreed conventions and strengthen comparable regression checks. Review load order, registration, refresh, responsive layout and disabled-control behavior across both addons. Avoid a shared runtime dependency unless it has a clear maintenance benefit.
