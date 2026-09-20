# RP Emote Menu

## The Short Version

RP Emote Menu is a customizable emote menu that keeps frequently used character actions organized and readily available for **World of Warcraft** roleplayers.

- **Emotes:** The addon organizes up to 100 emotes across 10 categories, with optional targeted commands.
- **Easy organization:** Emotes can be edited from the menu, dragged into order, and duplicated along with complete categories.
- **Flexible window:** The window remains visible by default; optional inactivity fading can hide it or replace it with a configurable minimized icon.
- **Profiles and sharing:** Profiles provide distinct character setups, while categories and complete profiles can be imported or exported.
- **Appearance:** Per-profile settings control fonts, colors, selection effects, borders, opacity, and fading.
- **Commands:** `/rpem` toggles the menu, while `/rpem config` opens its settings.

## What's New In Version 2

- **Easier editing:** Version 2 adds row-level emote editing, streamlined settings, emote and category duplication, and direct editing links in empty menus.
- **Drag-and-drop sorting:** Visible emotes can be reordered directly in the menu with a clear insertion marker.
- **Optional minimize to icon:** The hidden title bar can be replaced by a transparent icon with a configurable size, corner, color tint, and live preview.
- **Refined pinning and hiding:** The menu can remain pinned or fade and collapse when not in use, then reappear when hovered.
- **Smarter layout:** Column widths automatically fit their labels, while height, position, and lock state remain persistent.
- **Improved profiles:** Six bundled visual themes—including a high-contrast, colorblind-friendly option—accompany clearer tools for creating, copying, restoring, importing, and exporting profiles. Existing Version 1 profiles and character assignments migrate automatically.

## Screenshots

<img width="468" height="230" alt="profile-default" src="https://github.com/user-attachments/assets/48876569-9339-4db2-8648-fec3e13dec61" />  

<img width="347" height="228" alt="profile-crimson-night" src="https://github.com/user-attachments/assets/6d6c148f-9cc8-4f53-97f8-c3f1366be179" />  

<img width="502" height="228" alt="profile-gilded-shadow" src="https://github.com/user-attachments/assets/eec845e8-c6be-414f-a034-d34de229d7ea" />  

<img width="427" height="306" alt="profile-joker" src="https://github.com/user-attachments/assets/a6a09b49-f258-48de-957c-6e5be95bf0de" />  

<img width="533" height="277" alt="profile-moonlight" src="https://github.com/user-attachments/assets/75d067e6-f571-41db-8b06-9e410f0761df" />  

<img width="407" height="308" alt="profile-teal" src="https://github.com/user-attachments/assets/d7c48279-da8d-46b8-98e4-2d645e31ace2" />  


https://github.com/user-attachments/assets/b5bad169-6a50-4085-a0c7-5366533300af

## Installation

The `RPEmoteMenu` folder should be placed in the World of Warcraft addons directory:

```text
World of Warcraft/_retail_/Interface/AddOns/RPEmoteMenu/
```

If necessary, **RP Emote Menu** can be enabled from the character-selection screen's AddOns list.

## Getting Started

1. The `/rpem` command shows or hides the menu.
2. Hovering over a category displays its emotes, and selecting an emote performs it.
   The small icon at the right edge of each row opens that emote's name and command editor.
   Hovering over an emote displays its default and targeted commands.
   Emote labels can be dragged into a new order; an insertion line marks the destination.
   When inactivity fading is enabled and the menu is unpinned, it hides after use or after the configured delay. The title bar—or the addon icon when **Minimize to icon** is enabled—reveals it when hovered.
3. The gear icon, a right-click on the title bar, and the `/rpem config` command open the addon settings.
4. Profiles with customizable categories and emotes can be created or copied under **Profiles**.
5. Category names and their emote commands can be edited under **Emotes**.

The built-in **Default** profile is always available. Its categories and emotes are protected, but its window and appearance settings can be customized.

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

The **Emotes** screen can restore the selected category or every category in the current custom profile to the built-in set.

## Profiles

A profile contains its categories, emotes, window layout, and appearance. Profiles are available to all characters, while an active profile is selected independently for each character.

The **Default** profile has protected categories and is local only. It cannot be imported, exported, renamed, or deleted. Its window and appearance settings remain customizable and persistent.

The **Profiles** settings screen includes:

- **Create Profile:** Creates a profile with the built-in categories and the current profile's settings.
- **Copy Profile:** Duplicates the current profile, including its categories, emotes, layout, and appearance.
- **Rename Profile:** Renames the current custom profile.
- **Delete Profile:** Deletes the current custom profile after confirmation.
- **Export Profile:** Copies the current custom profile as JSON.
- **Import Profile:** Adds a profile from exported JSON.
- **Restore Bundled Profiles:** Resets the six bundled profiles and recreates any that were deleted.

Imported profiles do not replace or activate existing profiles. If an imported name is already in use, the addon assigns the new profile a unique name. Deleting a profile returns characters using it to **Default**.

Profile names cannot be blank, exceed 64 characters, duplicate another name regardless of case, or use the reserved name **Default**.

The addon includes six editable starter profiles: **Gilded Shadow**, **Crimson Night**, **Teal**, **High Contrast**, **Joker**, and **Moonlight**. They use the built-in emote categories with different visual designs. **High Contrast** is colorblind-friendly: it combines bright neutral text, dark opaque backgrounds, and a bold yellow selection outline so selection does not depend on red–green color differences alone. It uses Teal's fonts and font sizes. Bundled profiles can be edited, renamed, exported, or deleted like any custom profile. Restoring bundled profiles resets profiles still using those names and recreates missing ones; renamed profiles are left unchanged.

Bundled profile names are marked **(Bundled)** in the profile selector. Each also displays a short description of its visual theme.

## Import and Export

The **Emotes** screen can export the selected category or replace that category in the current custom profile with an imported one.

The **Profiles** screen can import or export one custom profile. The separate **Import & Export** screen can import or export all custom profiles at once.

Profile exports include sharable window settings, appearance, categories, and emotes. They do not include the local **Default** profile, character names, realms, character assignments, or the last selected category.

All transfers use JSON text. Imports are validated before any existing category is replaced or any new profiles are added. Bulk imports skip **Default**, preserve existing profiles, and automatically rename conflicts.

## Appearance

The **Appearance** settings screen provides these options for the current profile:

- Separate fonts and font sizes for category names and emote labels.
- Category text, selected text, emote text, selection, background, and border colors.
- Selection effects: **Background**, **Outline**, **Separator**, **Underline**, or **Drop shadow**.
- Border styles: **None**, **Thin**, or **Blizzard**.
- Background opacity and active window opacity.

The font menus include WoW's built-in fonts and fonts made available by LibSharedMedia-3.0 (if any). A custom font may take 10 to 30 seconds to appear the first time it is selected.

If a saved custom font is unavailable, the font selector marks it in red and the menu temporarily displays Friz Quadrata instead.

Changes appear immediately. **Restore Defaults** resets the current profile's appearance, window height, and window position.

## Window Settings

The **General** settings screen controls the current profile's window behavior and layout:

- The window position and height can be locked.
- The settings gear icon can be hidden; right-clicking the title bar still opens the settings.
- The addon can be shown or hidden at login.
- Inactivity fading can be enabled with a configurable delay and inactive opacity. It is disabled by default, so the menu remains visible.
- The auto-hidden title bar can be replaced by a square addon icon sized from 16 to 64 pixels, independently of the main window dimensions.
- The minimized icon can occupy the upper-left or upper-right corner of the main window and can use a custom color tint.
- The window can be dragged or centered, with exact coordinates available as an advanced option.
- The window height can be set manually, while its width automatically fits every category and emote label in the profile.
- The default position and size can be restored.

The window can also be moved and resized vertically while it is unlocked. Changing the height does not change the minimized icon, and changing the icon size does not resize the window. The category pane scrolls when necessary, and the pushpin controls whether the body automatically hides.

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

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under the GNU General Public License v3.0 (GPL-3.0):  
https://www.gnu.org/licenses/gpl-3.0.en.html  
Source: https://github.com/bblackmoor/rpemotemenu
