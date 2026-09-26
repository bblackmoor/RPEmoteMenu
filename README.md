# RP Emote Menu

## The Short Version

RP Emote Menu is a customizable emote menu that keeps frequently used character actions organized and readily available for **World of Warcraft** roleplayers.

- **Emotes:** The addon organizes up to 100 emotes across 10 categories, with optional targeted commands.
- **Easy organization:** Emotes can be edited from the menu, dragged into order, and duplicated along with complete categories.
- **Flexible window:** The window remains visible by default; optional inactivity fading can dim it or minimize it to the title bar or a configurable icon.
- **Profiles and sharing:** Profiles provide distinct character setups, while categories and complete profiles can be imported or exported.
- **Appearance:** Per-profile settings control fonts, colors, selection effects, borders, and opacity.
- **Commands:** `/rpem` toggles the menu, while `/rpem config` opens its settings.

## What's New In Version 2

- **Easier editing:** Version 2 adds row-level emote editing, streamlined settings, emote and category duplication, and direct editing links in empty menus.
- **Drag-and-drop sorting:** Visible emotes can be reordered directly in the menu with a clear insertion marker.
- **Flexible minimization:** Inactive menus can remain full-size, minimize to the title bar, or minimize to a transparent icon with configurable size, side, color tint, and live preview.
- **Synchronized locking:** The title-bar pin and **Lock Window Position and Height** setting control the same state.
- **Smarter layout:** Column widths automatically fit their labels, while height, position, title-bar placement, and lock state remain persistent.
- **Improved profiles:** Default is editable and restorable while remaining the reserved fallback. Six bundled themes include a high-contrast, colorblind-friendly option. Existing Version 1 profiles and character assignments migrate automatically.

## Screenshots

<img width="468" height="230" alt="profile-default" src="https://github.com/user-attachments/assets/48876569-9339-4db2-8648-fec3e13dec61" />  

<img width="347" height="228" alt="profile-crimson-night" src="https://github.com/user-attachments/assets/6d6c148f-9cc8-4f53-97f8-c3f1366be179" />  

<img width="502" height="228" alt="profile-gilded-shadow" src="https://github.com/user-attachments/assets/eec845e8-c6be-414f-a034-d34de229d7ea" />  

<img width="427" height="306" alt="profile-joker" src="https://github.com/user-attachments/assets/a6a09b49-f258-48de-957c-6e5be95bf0de" />  

<img width="533" height="277" alt="profile-moonlight" src="https://github.com/user-attachments/assets/75d067e6-f571-41db-8b06-9e410f0761df" />  

<img width="407" height="308" alt="profile-teal" src="https://github.com/user-attachments/assets/d7c48279-da8d-46b8-98e4-2d645e31ace2" />  


https://github.com/user-attachments/assets/b5bad169-6a50-4085-a0c7-5366533300af

## Download

Permanent, ready-to-install ZIP files are available from the [GitHub Releases](https://github.com/bblackmoor/RPEmoteMenu/releases) page. Each release contains a `RPEmoteMenu-<version>.zip` archive.

Every commit to `main` also creates a development build under [GitHub Actions](https://github.com/bblackmoor/RPEmoteMenu/actions/workflows/release.yml). Development archives are named `RPEmoteMenu-<version>-dev-<commit>.zip` and retained for 90 days. Downloading an Actions artifact requires signing in to GitHub. A version tag such as `v2.0.180` publishes the corresponding permanent release.

## Installation

The `RPEmoteMenu` folder should be placed in the World of Warcraft addons directory:

```text
World of Warcraft/_retail_/Interface/AddOns/RPEmoteMenu/
```

If necessary, **RP Emote Menu** can be enabled from the character-selection screen's AddOns list.

## Getting Started

1. The `/rpem` command shows or hides the menu.
2. Hovering over a category displays its emotes, and selecting an emote performs it.
   The small icon at the right edge of each row opens that emote's name and command editor. Emotes can also be right-clicked to edit them.
   Hovering over an emote displays its default and targeted commands.
   Category and emote labels can be dragged into a new order; an insertion line marks the destination.
   Right-clicking a category opens that category in the Emotes settings editor.
   When inactivity fading is enabled, the complete menu fades or minimizes to its title bar or addon icon after the configured delay. Hovering restores it.
3. The gear icon, a right-click on the title bar, and the `/rpem config` command open the addon settings.
4. Profiles with customizable categories and emotes can be created or copied under **Profiles**.
5. Category names and their emote commands can be edited under **Emotes**.

The built-in **Default** profile is editable and always available. Its reserved name cannot be renamed or deleted.

## Categories and Emotes

Each profile supports **10 categories** with up to **10 emotes** each. The **Emotes** settings screen provides a category dropdown for editing them.

Each emote includes:

- **Emote Label:** The text shown in the menu.
- **Default Command:** The command used when no other unit is targeted.
- **Targeted Command:** An optional command used when targeting another unit.

Commands can use built-in emotes such as `/wave` or custom `/e` commands.

```text
Emote Label: Watches quietly
Default Command: /e watches quietly.
Targeted Command: /e watches {target} quietly.
```

An emote appears only when it has both a label and a default command. A category appears only when it has a name.

The **Emotes** screen can restore the selected category or every category in the current profile to the built-in set.

## Profiles

A profile contains its categories, emotes, and appearance. Profiles are available to all characters, while an active profile is selected independently for each character. App behavior, user preferences, and window layout are global.

The **Default** profile can be edited, imported into, exported, and restored. Importing a profile named **Default** creates a uniquely named copy.

The **Profiles** settings screen includes:

- **Restore Default:** Resets Default's categories, emotes, and appearance, including when another profile is selected.
- **Create:** Prompts for a name, then creates a profile with the built-in categories and the current profile's appearance.
- **Copy:** Prompts for a name, then duplicates the current profile, including its categories, emotes, and appearance.
- **Rename:** Renames the current profile, except for **Default**.
- **Delete:** Deletes the current profile after confirmation, except for **Default**.
- **Export Profile:** Copies the current profile as JSON.
- **Import Profile:** Adds a profile from exported JSON.
- **Restore Bundled Profiles:** Resets the six bundled profiles' categories and appearance and recreates any that were deleted.

Imported profiles do not replace or activate existing profiles. If an imported name is already in use, the addon assigns the new profile a unique name. Deleting a profile returns characters using it to **Default**.

Profile names cannot be blank, exceed 64 characters, duplicate another name regardless of case, or use the reserved name **Default**.

The six bundled profiles are **Gilded Shadow**, **Crimson Night**, **Teal**, **High Contrast**, **Joker**, and **Moonlight**. **High Contrast** uses bright neutral text, dark backgrounds, and a yellow selection background that does not rely on red–green differences.

Bundled profiles can be edited, renamed, exported, or deleted. **Restore Bundled Profiles** resets categories and appearance for profiles still using bundled names and recreates missing profiles. Renamed profiles are unchanged.

Bundled profile names are marked **(Bundled)** in the profile selector. Each also displays a short description of its visual theme.

## Import and Export

The **Emotes** screen can export the selected category or replace that category in the current profile with an imported one.

The **Profiles** screen can import or export one profile. The separate **Import & Export** screen can import or export all profiles at once.

Profile exports include appearance, categories, and emotes. They do not include global behavior, preferences, window layout, character names, realms, character assignments, or the last selected category.

All transfers use JSON text. Categories and emotes are validated before any existing category is replaced or any new profiles are added. Unknown or invalid profile setting fields are ignored. Bulk imports preserve existing profiles and automatically rename conflicts, including an imported **Default** profile.

## Appearance

The **Appearance** settings screen provides these options for the current profile:

- Separate fonts and font sizes for category names and emote labels.
- Category text, selected text, emote text, selection, background, and border colors.
- Selection effects: **Background**, **Outline**, **Separator**, **Underline**, or **Drop shadow**.
- Border styles: **None**, **Thin**, or **Blizzard**.
- Visible menu opacity, applied to the entire menu.
- Minimized icon color.

The font menus include WoW's built-in fonts and fonts made available by LibSharedMedia-3.0 (if any). A custom font may take 10 to 30 seconds to appear the first time it is selected.

If a saved custom font is unavailable, the font selector marks it in red and the menu temporarily displays Friz Quadrata instead.

Changes appear immediately. **Restore Defaults** resets the current profile's appearance.

## Window Settings

The **Behavior** settings screen controls global app behavior, user preferences, and window layout:

- The window position and height can be locked.
- **Reset Window Height & Position** restores the global window geometry without changing other preferences.
- The title bar can run across the top or down the left edge. In left-edge mode, its text rotates counterclockwise while the pin and settings icons remain upright.
- The settings gear icon can be hidden; right-clicking the title bar still opens the settings.
- Emote-row edit gear icons can be hidden; right-clicking an emote still opens its editor. This option is disabled by default.
- Main-window tooltips have a global delay from 0 to 1000 milliseconds. The default is 350 milliseconds; 0 displays them immediately.
- The addon can be shown or hidden at login.
- Inactivity fading can be enabled with a configurable delay and inactive opacity. **Minimize to** selects **None**, **Title Bar**, or **Icon**. Fading is disabled by default.
- The minimized square addon icon can be sized from 16 to 64 pixels independently of the main window dimensions.
- The minimized icon can occupy the left or right edge of the main window, centered alongside the first category and emote. Its profile-specific color tint is set under **Appearance**, and its black antialiased outline remains visible against light backgrounds.
- The window can be dragged or centered, with exact coordinates available as an advanced option.
- The window height can be set manually, while its width automatically fits every category and emote label in the profile.
- The default position and size can be restored.
- **Restore Global Defaults** resets all behavior, preferences, and window layout.

The window can also be moved and resized vertically while it is unlocked. Changing the height does not change the minimized icon, and changing the icon size does not resize the window. The category pane and longer settings tabs scroll when necessary. The pushpin toggles the window position and height lock.

## Slash Commands

| Command          | Description                    |
| :--------------- | :----------------------------- |
| `/rpem`          | Shows or hides RP Emote Menu   |
| `/rpem config`   | Opens the addon settings       |
| `/rpem options`  | Opens the addon settings       |
| `/rpem settings` | Opens the addon settings       |

## Target Tokens

These tokens insert character names into either command:

| Token      | Description                             |
| :--------- | :-------------------------------------- |
| `{target}` | Target's name without the realm         |
| `{player}` | Current character's name without the realm |

The **Targeted Command** is used only when another unit is targeted. Without a target, or when the character targets itself, the **Default Command** is used instead.

---

**AI Disclaimer:** AI-assisted tools were used during the development of this project. The author reviewed and approved the resulting code and documentation and remains responsible for the project.

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under the GNU General Public License v3.0 (GPL-3.0):  
https://www.gnu.org/licenses/gpl-3.0.en.html  
Release history: [CHANGELOG.md](CHANGELOG.md)  
Source: https://github.com/bblackmoor/rpemotemenu
