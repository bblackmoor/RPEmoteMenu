# Settings Architecture

Status: the earlier structural refactor was implemented in its Phases 6–8;
in-game integration checks remain open. Phase 1 of the separate Details Framework
widget conversion is complete; see [the current conversion baseline and phases](details-framework-conversion.md).

## Goal

The settings source should be easy for a human to read and modify. When a developer opens the source for a settings tab and reads downward, the code should encounter substantially the same sections and controls, in the same order, that the user sees when looking downward at that tab in WoW.

The refactor must preserve behavior while making small layout changes safer and more localized.

## Ownership

The settings UI reflects three data scopes documented in `saved-data-model.md`:

- **Global** — account-wide application preferences.
- **Profile** — emote content and non-visual window/configuration state.
- **Theme** — visual appearance.

Presentation code should not obscure which scope a control edits.

## Preferred source hierarchy

Use a simple hierarchy rather than a large declarative UI framework:

```text
Tab
    Section
        Row/control
        Row/control
    Section
        Row/control
```

Likely organization:

```text
Settings.lua
    settings registration
    refresh orchestration

SettingsControls.lua
    common settings controls and row cursor

SettingsExchange.lua
    shared JSON transfer dialog

SettingsBehavior.lua
    global/startup preferences
    window behavior
    window layout

SettingsProfiles.lua
    profile selection
    theme assignment
    profile management
    profile transfer

SettingsThemes.lua
    theme selection/management
    typography
    colors
    selection
    opacity
    title bar
    minimized icon

SettingsEmotes.lua
    category selection
    category management
    emote list

SettingsTransfer.lua
    complete-data import/export
```

Physical file boundaries may be adjusted during implementation if a smaller split is clearer, but the tab -> section -> control hierarchy is required.

## Source order must match visual order

Do not construct controls far away from where they appear merely because another callback needs a reference.

A section that appears as:

```text
Window Behavior
Fade when inactive       [On]
Fade after               [5] seconds
Inactive opacity         [50] %
Minimize to              [Icon]
Minimized icon size      [32]
```

should be constructed in approximately that order.

Dependency/enable-state behavior should be separated from construction where practical, for example:

```text
CreateWindowBehaviorSection()
RefreshWindowBehaviorSection()
```

This lets a reader first understand what is on the screen, then how dependencies behave.

## Layout rules

Avoid maintaining the page primarily through hand-written absolute Y coordinates.

Use a small set of straightforward layout helpers, for example:

- `BeginSection`
- `AddSwitchRow`
- `AddNumberRow`
- `AddDropdownRow`
- `AddColorRow`
- `AddButtonRow`
- `AddNote`
- `AddGap`

The helper should normally own advancement to the next row. Explicit gaps and special-purpose layouts are allowed where they improve clarity.

Do not create a control at one position and immediately `ClearAllPoints()` and define its real layout elsewhere.

Special structures, such as the two-column Category Pane / Emote Pane typography layout, may use purpose-built helpers instead of forcing everything into a generic row abstraction.

## Standard row ordering

Where applicable, settings rows follow:

```text
[label] [control] [reset button, if any] [info link, if any]
```

Maintain consistent spacing between labels, controls, explanatory text, reset actions, and info links.

Use the established thumb-slider switches instead of checkbox controls.

Info controls use the established yellow/default-heading-color circled `i` treatment without a button background.

## Presentation versus subsystem behavior

Use vertical ownership rather than attempting an absolute separation of all UI and all logic.

A settings module may legitimately write its setting and request that a subsystem apply it:

```lua
settings.fadeEnabled = value
MainWindow.ApplyFadeSettings()
```

The settings module should not implement the fading subsystem itself.

Likewise, minimized-icon rendering/color application belongs in the minimized-icon subsystem, while the label, swatch, reset button, preview, and their settings-page layout belong in the Theme settings UI.

## Dialogs and lifecycle operations

Large dialog definitions and CRUD behavior should not interrupt the visual construction of a tab.

Profile and Theme constructors should read approximately as:

```text
Create panel
Create selection section
Create management section
Create transfer section
Install dialogs/behavior
Return panel
```

Dialogs may live in dedicated helpers or modules where that makes the panel source clearer.

## Dynamic Emotes UI

The Emotes tab is inherently more complex because it contains dynamic draggable categories/emotes. Keep its page structure separate from list mechanics.

Conceptual UI structure:

```text
Category selector
Category actions
Category description/name
Emote list
Add Emote
```

Mechanics such as `CreateEmoteRow`, refresh, drag start/end, duplicate, and delete should be separately named and kept out of the top-level layout flow.

## Registration and load order

Settings registration is a sensitive integration point. When files are split:

- update the `.toc` in dependency order;
- ensure every constructor exists before registration calls it;
- avoid circular module initialization;
- preserve About/top-level registration and all subcategories;
- verify slash commands that open About/Settings;
- verify refresh entry points used by MainWindow and Database.

A settings refactor is not complete merely because the files load; the addon must still appear correctly in WoW's AddOns settings hierarchy.

## Refactor timing

The structural settings refactor followed the new data model, runtime ownership,
serialization, and initial Profile/Theme UI conversion. Ordinary settings rows now
use a small cursor; the two-column Theme editor and dynamic Emote list keep their
own layouts. Manual in-game verification is still required.
