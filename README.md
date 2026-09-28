# RP Emote Menu

RP Emote Menu organizes roleplay commands in a movable World of Warcraft menu. Each account-wide Profile holds up to 10 categories with 10 emotes each; each character chooses its own Profile. Shared Themes control the menu's appearance.

## Features

- Organize up to 100 emotes in 10 categories per Profile.
- Give emotes separate default and targeted commands with character-name tokens.
- Edit, duplicate, and drag categories and emotes into order.
- Let each character select an account-wide Profile independently.
- Share customizable Themes across Profiles, with six bundled presets.
- Choose fonts, colors, selection effects, opacity, and top or left title-bar placement.
- Fade the menu when inactive or minimize it to a title bar or icon.
- Hide gear icons while keeping right-click editing available.
- Import and export categories, Profiles, Themes, or all Profiles and Themes together.

## Screenshots

## Installation

Download an installable ZIP from [GitHub Releases](https://github.com/bblackmoor/RPEmoteMenu/releases). Development builds are available as artifacts from [GitHub Actions](https://github.com/bblackmoor/RPEmoteMenu/actions/workflows/release.yml). Extract the `RPEmoteMenu` folder to:

```text
World of Warcraft/_retail_/Interface/AddOns/RPEmoteMenu/
```

Enable the addon at character selection if needed.

## Using the Menu

- `/rpem` shows or hides the menu; `/rpem config` opens settings. You can also open settings with the title-bar gear or by right-clicking the title bar.
- Hover over a category to see its emotes. Click an emote to run its command. Drag categories or emotes to reorder them.
- Right-click a category to edit it, or right-click an emote to edit its label and commands. The emote gear opens the same editor. **Hide setting gear icons** hides both the title-bar and emote gears without removing right-click editing.
- An emote appears when it has a label and a default command. Categories with no name are hidden.

Each emote has a **Default Command** and an optional **Targeted Command** used when another unit is targeted. Commands may contain `{target}` (target's name) or `{player}` (your character's name), without realm names. With no target or when targeting yourself, the default command is used.

For example, an emote labeled “Watches quietly” could use `/e watches quietly.` by default and `/e watches {target} quietly.` when targeting someone else. Built-in emotes such as `/wave` also work.

## Profiles and Themes

Profiles contain categories, emotes, the selected category, window position and height, lock state, fade and minimize settings, and a Theme reference. Each character selects a Profile independently. A new character uses **Default Profile**, which starts with **Default Theme**. Default Profile can be edited and restored, but cannot be renamed or deleted. Create and Copy select the resulting Profile for the current character; imported Profiles are added without selecting them.

Themes contain fonts, colors, selection effects, menu opacity, title-bar position, and minimized icon tint. The menu has no border. Multiple Profiles can share one Theme, and edits to a Theme affect all of them. Selecting a Theme in the **Themes** editor does not assign it; assign it on **Profiles**.

Default Theme can be edited and restored, but cannot be renamed or deleted. The six editable bundled Themes are **Gilded Shadow**, **Crimson Night**, **Teal**, **High Contrast**, **Joker**, and **Moonlight**. Restore individual bundled Themes or all six from their factory definitions. Deleting a Theme used by Profiles requires confirmation and assigns those Profiles Default Theme.

The **Behavior** screen holds global show-at-login, tooltip-delay, and gear-visibility preferences. Window position, height, lock, fade, and minimization belong to the selected Profile. With fade enabled, the menu can dim in place or minimize to its title bar or icon when inactive; hovering restores it. The icon size is adjustable. The minimized icon stays at the window's upper-left corner when the title bar moves between the top and left edges.

## Importing and Exporting

**Emotes** exports a category or replaces the selected category with an import. **Profiles** and **Themes** transfer one of each; **Import & Export** transfers Everything (all Profiles, Themes, and their links). Transfers use version 2 JSON. Global preferences and character-to-Profile assignments are excluded.

Imports add Profiles and Themes without overwriting existing ones; name conflicts are resolved with new names. A standalone Profile whose Theme is unavailable uses Default Theme and reports the fallback. Invalid or unknown Profile and Theme settings are silently ignored and defaulted. Malformed categories, emotes, and other format versions are rejected without conversion.

## Commands

| Command | Action |
| --- | --- |
| `/rpem` | Show or hide the menu |
| `/rpem about` | Open the About page |
| `/rpem config`, `/rpem options`, `/rpem settings` | Open settings |

**AI disclaimer:** AI-assisted tools were used in development. The author reviewed and approved the code and documentation and remains responsible for the project.

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)  
[Release history](CHANGELOG.md)  
[Source](https://github.com/bblackmoor/RPEmoteMenu)
