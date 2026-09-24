# Changelog

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
