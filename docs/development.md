# Developer Documentation

## Design and Architecture

- [Settings conventions](design/settings-conventions.md): module contracts, deliberate differences from Simple Nameplates, regression coverage, and native acceptance checks.
- [Addon standardization](design/addon-standardization.md): the completed settings standardization work.
- [Saved-data model](design/saved-data-model.md): Profile and Theme storage.
- [Settings architecture](design/settings-architecture.md): settings modules and responsibilities.
- [Localization](design/localization.md): interface localization and native acceptance.
- [Standard-emote picker](design/standard-emote-picker.md): catalog, editor integration, and native verification.

## Running Tests

Run the smoke suites from the repository root with LuaTeX:

```sh
for test in tests/*-smoke.lua; do
    texlua "$test" || exit 1
done
git diff --check
```

Tests use bundled libraries and addon modules with UI fixtures. Command tests load the execution module and check routing, aliases, target selection, token replacement, and editable chat drafts using WoW API stubs. They do not establish native rendering or client frame restrictions. See the settings conventions for the optional actual-addon picker coexistence check and the in-game checklist.

## Editor and Catalog Behavior

Selecting a standard emote fills the display name and default command and clears the targeted override. Display names omit the slash, capitalize the first letter, and use an explicit table for English compound names. Manual changes to any of the three fields reset the selector without discarding the draft. Save applies the change.

Previews come from the reference catalog and do not guarantee current game output. Unverified entries can be inserted; entries recorded as unsupported for the current client build cannot. Catalog browsing currently requires enUS. An unselected picker has no reserved preview area. Dialog backgrounds consume clicks.

Category names and emote labels have a 128-byte limit; commands have a 4,096-byte limit. Editors reject longer values without saving or truncating them.

## Settings and Rendering Behavior

Profiles own categories, emotes, selected category, window position and height, locking, fade and minimization, and a Theme reference. Themes own fonts, colors, selection effects, opacity, title-bar placement, and minimized icon tint. Global Behavior settings own activation, tooltip delay, and gear visibility.

Creating or copying a Profile selects it; importing a Profile does not. The Theme editor selection and active Profile's Theme reference stay synchronized.

Activation shows the full window at normal opacity and starts the inactivity timer. Deactivation hides the window and minimized icon. The minimized icon remains at the upper-left corner when the title bar changes orientation.

Font selectors refresh when providers register fonts. An unavailable saved font falls back to Friz Quadrata without discarding the saved selection, including during transfers. Rendering retries are limited to failed attempts; widths update with the font.

## Data Compatibility

The saved-data model does not migrate v1 or obsolete v2 schemas; obsolete schemas initialize with defaults. Transfers accept version 2 JSON. Unknown or invalid Profile and Theme settings are ignored and defaulted. Other format versions and malformed categories or emotes are rejected without conversion.

Transfers exclude global preferences and character-to-Profile assignments. Name conflicts produce new names. A standalone Profile with an unavailable Theme uses Default Theme and reports the fallback.

## Release Documentation

The [changelog](../CHANGELOG.md) and [v2.0.209 release notes](releases/2.0.209.md) retain release history. User installation instructions are in the [README](../README.md).
