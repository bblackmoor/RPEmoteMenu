# Saved Data Model

Status: approved design specification for the Profile/Theme refactor.

## Core relationship

RP Emote Menu uses this ownership chain:

```text
Character -> Profile -> Theme
```

Profiles and Themes are account-wide. Each WoW character independently remembers its selected Profile. A character with no saved selection uses **Default Profile**, which references **Default Theme**.

## Global preferences

Global preferences are account-wide and are not part of a Profile or Theme:

- Show at login (`showAtLogin`)
- Tooltip delay (`tooltipDelayMs`)
- Hide settings gear (`hideSettingsGear`)
- Hide emote edit gears (`hideEmoteEditGears`)

## Profiles

A Profile owns content and non-visual configuration:

- Theme reference
- Categories and emotes
- Selected category
- Window position and anchor information
- Window height
- Lock window
- Fade/minimize behavior
- Minimized icon size
- Minimized icon side/corner

The expected Profile settings include:

- `locked`
- `minimizeMode`
- `minimizedIconSize`
- `minimizedIconCorner`
- `selectedCategory`
- `point`
- `relativePoint`
- `x`
- `y`
- `height`
- `fadeEnabled`
- `fadeDelay`
- `inactiveOpacity`

### Default Profile

**Default Profile**:

- always exists;
- can be edited;
- can be restored to factory defaults;
- cannot be renamed;
- cannot be deleted;
- is the fallback for a character whose selected Profile no longer exists;
- references Default Theme on a fresh install or after a factory restore.

There are initially no bundled Profiles other than Default Profile.

## Themes

A Theme owns visual appearance only:

- Title-bar position (top/left)
- Minimized icon color
- Category and emote fonts
- Category and emote font sizes
- Text colors
- Category selection appearance
- Category/emote background colors
- Border color/style
- Window opacity

The expected Theme settings include:

- `titleBarPosition`
- `minimizedIconColor`
- `categoryFont`
- `emoteFont`
- `categoryFontSize`
- `emoteFontSize`
- `categoryTextColor`
- `selectedCategoryTextColor`
- `emoteTextColor`
- `categoryHighlightColor`
- `categoryHighlightEffect`
- `categoryHighlightThickness`
- `categoryBackgroundColor`
- `emoteBackgroundColor`
- `borderColor`
- `borderStyle`
- `windowOpacity`

Profiles reference Themes; Themes are not copied into Profiles. Multiple Profiles may reference the same Theme. Editing a Theme therefore changes the appearance of every Profile that references it.

### Default Theme

**Default Theme**:

- always exists;
- can be edited;
- can be restored to factory defaults;
- cannot be renamed;
- cannot be deleted;
- is the fallback whenever a Theme reference is invalid or a referenced Theme is deleted.

### Bundled Themes

The existing visual presets become bundled Themes:

- Gilded Shadow
- Crimson Night
- Teal
- High Contrast
- Joker
- Moonlight

Bundled Themes are editable. They can be restored/recreated from their factory definitions.

## Deleting Themes

When the user requests deletion of a Theme that is referenced by one or more Profiles:

1. Warn that the Theme is in use.
2. List the Profiles that reference it.
3. Allow cancellation with no changes.
4. If deletion is confirmed, delete the Theme and change every referencing Profile to **Default Theme**.

Default Theme cannot be deleted, guaranteeing that a fallback always exists.

## Proposed saved-variable shape

```text
RPEmoteMenuDB
├── schemaVersion
├── globalSettings
├── profiles
│   └── <profile name>
│       ├── theme
│       ├── categories
│       └── settings
├── themes
│   └── <theme name>
│       └── settings
└── activeProfiles
    └── <Character-Realm> = <profile name>
```

The database must maintain these invariants:

- Default Profile always exists.
- Default Theme always exists.
- Every Profile references an existing Theme.
- Every valid character assignment references an existing Profile.
- Invalid Profile assignments fall back to Default Profile.
- Invalid Theme references fall back to Default Theme.

## Import and export

### Profile

Profile export includes:

- Profile name
- Profile settings
- Categories/emotes
- The name/reference of the selected Theme

It does **not** contain a copy of that Theme.

If an imported Profile references a Theme that is unavailable locally, retain the Profile but assign Default Theme and report that fallback to the user.

### Theme

Theme export contains the Theme name and appearance settings only.

### Everything

Export/Import Everything contains:

- all Profiles;
- all Themes;
- Profile-to-Theme relationships.

Character-to-Profile selections are local character choices and are not part of a Profile or Theme definition.

Category-level import/export remains supported independently.

## Compatibility policy

This redesign intentionally treats the previous saved-data structure as obsolete.

Do not add one-off migration code for the old Global/Profile hybrid model. Initialize the new schema cleanly using the new defaults and invariants. Obsolete serialization formats likewise do not need to be imported by the new format.
