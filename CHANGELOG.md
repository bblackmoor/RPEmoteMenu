# Changelog

## 2.0.210

- Bind all Theme color pickers, including the minimized icon, to their opening Theme and retire stale callbacks.
- Cancel previews before Profile/Theme changes, factory restores, swatch hiding, or opening another picker; preserve accepted colors and protect other addons’ pickers.

## 2.0.209

- Publish the current state as release 2.0.209; see [Changes from v1 to v2](docs/releases/2.0.209.md) for the major-version summary and upgrade compatibility.
- Remove border color and style from Themes and their editor.
- Render the menu without an outer border or sidebar divider, regardless of old saved or imported border values.

## 2.0.208

- Combine the title bar and emote gear visibility options into one global toggle.
- Keep hidden emote gears hidden on hover, while retaining right-click editing.

## 2.0.207

- Use import/export format version 2, rejecting other versions without migration.
- Silently ignore invalid or unknown Profile and Theme settings while retaining valid settings and strict category and emote validation.

## 2.0.206

- Anchor the minimized icon to the upper-left corner for both title-bar orientations.
- Let the category and emote lists move with the title bar while keeping the window corner fixed.
- Make both title bars 32 pixels thick and remove the obsolete Icon side setting.
- Continue accepting older version 3 Profile exports containing Icon side.

## 2.0.205

- Center the minimized icon on the left title bar's pin, regardless of icon size.
- Keep the category and emote lists in place when switching title bar orientation.
- Apply the Icon side preference only when the title bar is on top.

## 2.0.204

- Reduced the gap between Theme management and the Theme editor.
- Matched the left title bar's width to the top title bar's thickness.
- Set the default inactive opacity for new and restored Profiles to 50%.

## 2.0.203

- Completed the Profile and Theme settings refactor, with small row layout helpers and clearer module boundaries.
- Updated the documentation for shared Themes, per-character Profile selection, and Profile-owned window settings.
- Expanded settings smoke checks for row placement and slash-command routing.

## 2.0.202

- Stack the pin and settings controls above the text in the left title bar.

## 2.0.201

- Replaced settings checkboxes with sliding on/off switches and standardized control spacing.
- Reorganized profile controls around selection, restore, create, copy, rename, and delete; added a confirmation dialog to restore Default.

## 2.0.198

- Keep the first category, first emote, and minimized icon at nearly the same screen height when changing title bar orientation.

## 2.0.197

- Applied one visible-menu opacity to adjoining category and emote backgrounds, removing the darker overlap.
- Removed the separate background opacity control; opacity now affects the whole visible menu.

## 2.0.185

- Separated global app behavior and preferences from per-profile appearance.
- Reorganized settings into Behavior and Appearance sections with independent resets.
- Profile imports ignore unknown or invalid appearance settings while retaining valid categories, emotes, and appearance values.

## 2.0.184

- Added a 0-1000 ms delay for main-window tooltips, defaulting to 350 ms.
- Pending tooltips are cancelled when the cursor leaves or moves to another control.

## 2.0.183

- Added right-click category editing from the main menu.

## 2.0.182

- Added drag-and-drop category sorting with the same insertion indicator and edge scrolling used for emotes.

## 2.0.181

- Added a default-off option to hide each emote's edit gear and edit emotes by right-clicking their menu rows.

## 2.0.180

- Added 90-day development ZIP artifacts for every commit to `main`, identified by addon version and short commit SHA.
- Reserved permanent, cleanly named GitHub Releases for matching version tags.
- Added tag-to-TOC version validation before publishing a permanent release.

