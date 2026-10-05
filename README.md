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

[![Watch the video]([https://youtube.com](https://youtu.be/Ouv6zsLms58?si=ChO1rj_9D4x2NkAr))](https://youtu.be/Ouv6zsLms58?si=ChO1rj_9D4x2NkAr)

<img width="268" height="225" alt="profile-default" src="https://github.com/user-attachments/assets/260f5f13-25a7-406b-89a7-cbe5badd6b20" />&nbsp;&nbsp;&nbsp;&nbsp;
<img width="512" height="250" alt="profile-crimson-night" src="https://github.com/user-attachments/assets/5ee10f14-0dc5-403c-b8bb-674fdc1f31ff" />    

<img width="510" height="276" alt="profile-gilded-shadow" src="https://github.com/user-attachments/assets/1850751f-3cdc-4eac-ace0-3c2e02639cdd" />&nbsp;&nbsp;&nbsp;&nbsp;
<img width="346" height="306" alt="profile-high-contrast" src="https://github.com/user-attachments/assets/cc218880-1687-40bf-9e43-d7b6584673b5" />    

<img width="339" height="246" alt="profile-moonlight" src="https://github.com/user-attachments/assets/c6fb2f8a-eab9-454c-96cf-9317634a7937" />&nbsp;&nbsp;&nbsp;&nbsp;
<img width="534" height="246" alt="profile-teal" src="https://github.com/user-attachments/assets/9e6700a5-99ff-4209-a76f-9a3e1bd60bee" />    

## Installation

Automatic release packaging is disabled for now. Download the repository using **Code → Download ZIP**, extract it, and copy the inner `RPEmoteMenu` folder (the one containing `RPEmoteMenu.toc`) to:

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

Themes contain fonts, colors, selection effects, menu opacity, title-bar position, and minimized icon tint. The menu has no border. Multiple Profiles can share one Theme, and edits to a Theme affect all of them. Selecting a Theme in the **Themes** editor also assigns it to the current Profile; the two selections stay synchronized.

Default Theme can be edited and restored, but cannot be renamed or deleted. The six editable bundled Themes are **Crimson Night**, **Gilded Shadow**, **High Contrast**, **Moonlight**, and **Teal**. Restore individual bundled Themes or all six from their factory definitions. Deleting a Theme used by Profiles requires confirmation and assigns those Profiles Default Theme.

The **Behavior** screen holds global show-at-login, tooltip-delay, and gear-visibility preferences. Window position, height, lock, fade, and minimization belong to the selected Profile. With fade enabled, the menu can dim in place or minimize to its title bar or icon when inactive; hovering restores it. The icon size is adjustable. The minimized icon stays at the window's upper-left corner when the title bar moves between the top and left edges.

Shared font support is included; extra fonts come from SharedMedia or other font-providing addons. The font selectors update when providers register fonts. If a saved font is unavailable, the menu uses Friz Quadrata while preserving the selection, including in imports and exports. It resumes using that font when its provider loads. Rendering retries are limited to failed attempts, and menu widths update with the font.

## Importing and Exporting

**Emotes** exports a category or replaces the selected category with an import. **Profiles** and **Themes** transfer one of each; **Import & Export** transfers Everything (all Profiles, Themes, and their links). Transfers use version 2 JSON. Global preferences and character-to-Profile assignments are excluded.

Imports add Profiles and Themes without overwriting existing ones; name conflicts are resolved with new names. A standalone Profile whose Theme is unavailable uses Default Theme and reports the fallback. Invalid or unknown Profile and Theme settings are silently ignored and defaulted. Malformed categories, emotes, and other format versions are rejected without conversion.

## Commands

| Command | Action |
| --- | --- |
| `/rpem` | Show or hide the menu |
| `/rpem about` | Open the About page |
| `/rpem config`, `/rpem options`, `/rpem settings` | Open settings |

## Changes from v1 to v2

- Separate Profiles and Themes: Profiles hold categories, emotes, window position and height, selected category, locking, and fade/minimize behavior. Shared Themes hold appearance, so one Theme can style several Profiles.
- Editable defaults and visual presets: Default Profile now allows category and emote editing and can be restored. Default Theme and five additional bundled Themes are editable and restorable; visual presets no longer create separate content Profiles.
- Clearer settings ownership: Show-at-login, tooltip delay, and gear visibility are global preferences. Each character still chooses its own account-wide Profile; new characters start with Default Profile and Default Theme.
- Easier editing: Right-click categories and emotes to edit them, drag categories into order, and duplicate categories or emotes. One switch hides all settings gears, including emote gears on hover, while preserving right-click editing.
- Cleaner settings screens: Dedicated Behavior, Profiles, Themes, Emotes, and Import & Export screens use sliding on/off switches, circled information links, consistent spacing, and clearer restore and deletion confirmations. The About page is also available through /rpem about.
- More flexible presentation: Place the title bar above or beside the menu, with controls above the text on the left title bar. The minimized icon stays at the window's upper-left corner when orientation changes. Visible-menu opacity applies uniformly, and the menu always renders without borders.
- Improved sharing: Export and import categories, individual Profiles, individual Themes, or all Profiles and Themes with their relationships. Imports preserve existing entries, rename conflicts, and use Default Theme when a standalone Profile references an unavailable Theme.
- More predictable controls: Configure tooltip delay from 0 to 1,000 milliseconds, use clearer window locking and centering controls, and receive confirmations before destructive category and emote actions.

**Upgrade compatibility**

The current saved-data model intentionally does not migrate v1 or earlier v2 layouts. Obsolete saved-data schemas initialize with fresh defaults. Transfers accept only version 2 JSON; other format versions and malformed categories or emotes are rejected. Unknown or invalid Profile and Theme settings are silently ignored and replaced with defaults. Global preferences and character-to-Profile selections are not exported.

The existing 10-category, 100-emote limit, default and targeted commands, character-name tokens, emote dragging, and per-character Profile selection remain available.

-----

**AI disclaimer:** AI-assisted tools were used in development. The author reviewed and approved the code and documentation and remains responsible for the project.

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under GPL-3.0 [https://www.gnu.org/licenses/gpl-3.0.en.html](https://www.gnu.org/licenses/gpl-3.0.en.html)  
Release history: [CHANGELOG.md](CHANGELOG.md)  
Source: [https://github.com/bblackmoor/RPEmoteMenu](https://github.com/bblackmoor/RPEmoteMenu)
