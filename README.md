# RP Emote Menu

## The Short Version

RP Emote Menu is a customizable emote menu that keeps frequently used character actions organized and readily available for **World of Warcraft** roleplayers.

- **Emotes:** The addon organizes up to 100 emotes across 10 categories, with optional targeted commands.
- **Easy organization:** Emotes can be edited from the menu, dragged into order, and duplicated along with complete categories.
- **Flexible window:** The window remains visible by default; optional inactivity fading can dim it or minimize it to the title bar or a configurable icon.
- **Profiles and sharing:** Each character selects an account-wide Profile with its own emotes, window state, and Theme assignment; categories and Profiles can be shared as JSON.
- **Themes:** Shared Themes control fonts, colors, selection effects, and opacity.
- **Commands:** `/rpem` toggles the menu, while `/rpem config` opens its settings.

## What's New In Version 2

- **Easier editing:** Version 2 adds row-level emote editing, streamlined settings, emote and category duplication, and direct editing links in empty menus.
- **Drag-and-drop sorting:** Visible emotes can be reordered directly in the menu with a clear insertion marker.
- **Flexible minimization:** Inactive menus can remain full-size, minimize to the title bar, or minimize to a transparent icon with configurable size, side, color tint, and live preview.
- **Synchronized locking:** The title-bar pin and **Lock Window Position and Height** setting control the same state.
- **Smarter layout:** Column widths automatically fit their labels, while height, position, title-bar placement, and lock state remain persistent.
- **Improved profiles:** Default is editable and restorable while remaining the reserved fallback. Six editable bundled Themes include a high-contrast option. Default is the only built-in Profile; this version starts a new saved-data schema.

## Screenshots

These images illustrate the bundled color presets. The presets now live under **Themes**.

<img width="468" height="230" alt="theme-default" src="https://github.com/user-attachments/assets/48876569-9339-4db2-8648-fec3e13dec61" />  

<img width="347" height="228" alt="theme-crimson-night" src="https://github.com/user-attachments/assets/6d6c148f-9cc8-4f53-97f8-c3f1366be179" />  

<img width="502" height="228" alt="theme-gilded-shadow" src="https://github.com/user-attachments/assets/eec845e8-c6be-414f-a034-d34de229d7ea" />  

<img width="427" height="306" alt="theme-joker" src="https://github.com/user-attachments/assets/a6a09b49-f258-48de-957c-6e5be95bf0de" />  

<img width="533" height="277" alt="theme-moonlight" src="https://github.com/user-attachments/assets/75d067e6-f571-41db-8b06-9e410f0761df" />  

<img width="407" height="308" alt="theme-teal" src="https://github.com/user-attachments/assets/d7c48279-da8d-46b8-98e4-2d645e31ace2" />  


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

Profiles are shared account-wide, and each character independently selects one. A Profile contains categories, emotes, the selected category, window position and height, fade/minimize behavior, title-bar and edit-gear preferences, and a reference to one Theme. A new character uses Default Profile with Default Theme. The Default Profile is editable and restorable, but cannot be renamed or deleted.

The **Profiles** screen selects the current character's Profile and assigns a Theme to it. It also offers:

- **Restore Default:** Restores Default's categories, emotes, window state, and Default Theme assignment. The Default Theme's appearance is unchanged.
- **Create:** Adds a Profile with built-in categories, current Profile window settings, and the current Theme assignment, then selects it for this character.
- **Copy:** Duplicates the selected Profile's categories, emotes, window settings, and Theme reference, then selects the copy for this character.
- **Rename** and **Delete:** Manage custom Profiles; deletion returns characters using that Profile to Default.
- **Export Profile** and **Import Profile:** Share a Profile's categories, settings, and Theme name. Imports create a new uniquely named Profile and do not select it.

There are no bundled Profiles other than Default. If a Profile import references an unavailable Theme, it uses Default Theme and reports the fallback.

## Import and Export

The **Emotes** screen can export the selected category or replace it with an imported one. The **Profiles** and **Themes** screens import or export a single Profile or Theme. **Import & Export** transfers Everything: all Profiles and Themes and their relationships.

Transfers use version 2 JSON text. A Profile export contains its settings, categories, emotes, and assigned Theme name; a Theme export contains its visual settings. Neither includes global preferences or character-to-Profile assignments. Imports add uniquely named Profiles and Themes without overwriting existing ones. Invalid or unknown Profile and Theme settings are silently ignored and use defaults; invalid category and emote data is rejected. Other format versions are rejected without conversion. A missing Theme reference in an imported Profile falls back to Default Theme and is reported.

## Themes

The **Themes** screen edits a Theme independently of the character's assigned Profile. Several Profiles can share one Theme; edits to it affect every Profile using it. Selecting a Theme for editing does not assign it to a Profile; make that assignment on the **Profiles** screen.

Theme settings include separate category and emote fonts and sizes, text and background colors, selection effects, visible menu opacity, title-bar placement, and minimized icon tint. The menu has no border. Font menus include WoW's built-in fonts and available LibSharedMedia fonts. An unavailable saved font temporarily displays in Friz Quadrata; a newly selected custom font may take 10 to 30 seconds to appear.

Default Theme is editable and restorable, but cannot be renamed or deleted. The six bundled Themes are **Gilded Shadow**, **Crimson Night**, **Teal**, **High Contrast**, **Joker**, and **Moonlight**. Bundled Themes can be edited, renamed, or deleted; their original names can be restored or recreated from factory definitions. **Restore Bundled Themes** restores all six. Deleting a Theme used by Profiles first lists those Profiles and asks for confirmation; on confirmation, they are assigned Default Theme.

## Behavior and Window Settings

The **Behavior** screen contains global startup preferences (including show at login and the 0–1000 ms tooltip delay). Its window, fade, minimization, position, height, and lock controls edit the selected Profile. The minimized icon's tint and the title-bar orientation are on **Themes**.

The window can be dragged or centered and resized vertically while unlocked. Its width fits category and emote labels automatically. **Reset Window** resets the active Profile's position and height; **Restore Global Defaults** resets only global startup and interaction preferences.

The minimized icon is centered on the window's upper-left corner: the left edge of a top title bar or the upper edge of a left title bar. Switching the title bar orientation moves the category and emote lists with the window layout while leaving the minimized icon in place.

## Slash Commands

| Command          | Description                    |
| :--------------- | :----------------------------- |
| `/rpem`          | Shows or hides RP Emote Menu   |
| `/rpem about`    | Opens the About page           |
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
