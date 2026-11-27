# RP Emote Menu

<img width="400" height="400" alt="icon-400" src="https://github.com/user-attachments/assets/7c69aa7a-7754-4143-9212-34ceb5317f29" />

**RP Emote Menu** keeps your character’s gestures, habits, and favorite lines a click away in Retail World of Warcraft. Put the standard emotes you use alongside your own dialogue and gestures, group them by category, and give each character their own selection. It’s for roleplayers who want their usual lines handy and different wording when they have someone targeted.

## What’s new in 2.3.0

- Choose **Send** separately for default and targeted commands. Send immediately or open an editable chat draft.
- Fixed Send-enabled chat commands that stayed in the chat box.
- New Profiles fade after three seconds of inactivity. Existing Profiles keep their saved delay.
- Hiding or collapsing the menu cancels a drag in progress.

## Features

- Organize up to 100 standard and custom emotes in 10 categories per Profile.
- Use different wording when someone is targeted and insert either character’s name.
- Edit, duplicate, and drag categories and emotes into order.
- Choose a Profile for each character and share Themes across Profiles.
- Customize fonts, colors, opacity, and title-bar placement with six editable Themes.
- Hide the category pane or let the menu fade or minimize when idle.
- Import and export categories, Profiles, and Themes.

## Screenshots

<a href="https://github.com/user-attachments/assets/260f5f13-25a7-406b-89a7-cbe5badd6b20"><img width="300" alt="profile-default" src="https://github.com/user-attachments/assets/260f5f13-25a7-406b-89a7-cbe5badd6b20" /></a>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="https://github.com/user-attachments/assets/5ee10f14-0dc5-403c-b8bb-674fdc1f31ff"><img width="300" alt="profile-crimson-night" src="https://github.com/user-attachments/assets/5ee10f14-0dc5-403c-b8bb-674fdc1f31ff" /></a>

<a href="https://github.com/user-attachments/assets/1850751f-3cdc-4eac-ace0-3c2e02639cdd"><img width="300" alt="profile-gilded-shadow" src="https://github.com/user-attachments/assets/1850751f-3cdc-4eac-ace0-3c2e02639cdd" /></a>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="https://github.com/user-attachments/assets/cc218880-1687-40bf-9e43-d7b6584673b5"><img width="300" alt="profile-high-contrast" src="https://github.com/user-attachments/assets/cc218880-1687-40bf-9e43-d7b6584673b5" /></a>

<a href="https://github.com/user-attachments/assets/c6fb2f8a-eab9-454c-96cf-9317634a7937"><img width="300" alt="profile-moonlight" src="https://github.com/user-attachments/assets/c6fb2f8a-eab9-454c-96cf-9317634a7937" /></a>&nbsp;&nbsp;&nbsp;&nbsp;
<a href="https://github.com/user-attachments/assets/9e6700a5-99ff-4209-a76f-9a3e1bd60bee"><img width="300" alt="profile-teal" src="https://github.com/user-attachments/assets/9e6700a5-99ff-4209-a76f-9a3e1bd60bee" /></a>

[Watch the video](https://youtu.be/Ouv6zsLms58?si=ChO1rj_9D4x2NkAr)

## Installation

Install from [CurseForge](https://www.curseforge.com/wow/addons/rp-emote-menu), or download the installable ZIP from [GitHub Releases](https://github.com/bblackmoor/RPEmoteMenu/releases) and extract the `RPEmoteMenu` folder to:

```text
World of Warcraft/_retail_/Interface/AddOns/RPEmoteMenu/
```

Enable the addon at character selection. The package includes its libraries.

## Using RP Emote Menu

Hover over a category, then click an emote to use it. Right-click a category or emote to edit it. The chevron hides or shows the category pane. Open settings with `/rpem config` or the title-bar gear.

| Page | What you can change |
| --- | --- |
| Behavior | Activation, tooltip delay, and gear visibility |
| Profiles | Character selection, window position, and idle behavior |
| Themes | Fonts, colors, opacity, and title-bar placement |
| Emotes | Categories, default and targeted commands, and Send switches |
| Import & Export | Back up or share Profiles and Themes |

### Emotes and chat commands

Choose a standard emote such as `/wave` in the editor, or enter your own command such as `/e watches quietly.` Add an optional targeted command such as `/e watches {target} quietly.` to use when you target someone else. Use `{target}` and `{player}` to insert names without realm names.

Each command remembers its own **Send** switch. On sends immediately. Off opens the chat box for editing. Existing emotes keep their previous behavior when the switches are first filled in.

### Profiles and Themes

A Profile holds your emotes and window behavior. Each character selects a Profile. Several Profiles can share one Theme. The Default Profile and Default Theme can be edited and restored, and deleting a Theme in use assigns Default Theme to the affected Profiles. SharedMedia font packs can add more fonts.

### Sharing and backups

Export a category from **Emotes**, an individual Profile or Theme from its settings page, or all Profiles and Themes from **Import & Export**. Import adds Profiles and Themes under unique names. Importing a category replaces the selected category.

## Known limitations

The standard-emote picker supports English (enUS) clients. You can enter commands manually on other clients. Import accepts the current version 2 format. Saved settings from v1 or obsolete v2 layouts may reset to defaults.

## Commands

| Command | Action |
| --- | --- |
| `/rpem` | Show or hide the menu |
| `/rpem config`, `/rpem options`, `/rpem settings` | Open settings |
| `/rpem about` | Open About |

## Development

See the [developer documentation](docs/development.md) for implementation and testing notes and the [changelog](CHANGELOG.md) for release history.

---

**AI disclaimer:** AI-assisted tools were used in development. The author reviewed and approved the code and documentation and remains responsible for the project.

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)

Licensed under [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)

Source: [bblackmoor/RPEmoteMenu](https://github.com/bblackmoor/RPEmoteMenu)
