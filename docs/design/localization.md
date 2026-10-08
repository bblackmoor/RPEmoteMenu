# Interface localization

## Scope and sequence

1. **Foundation and navigation — complete in 2.1.252.** Add a lightweight locale registry, English fallback, translated settings navigation and About text. Store the supplied standard-emote reference catalog in the English locale file.
2. **Settings pages and shared messages — complete in 2.1.253.** Convert Behavior, Profiles, Themes, Emotes and Import/Export interface strings, including dialogs, tooltips, validation messages and framework diagnostics. Keep complete sentences and formatting templates together.
3. **Menu and editor.** Convert MainWindow and the emote editor's labels, help text, empty states and messages. Preserve player-authored content and command execution.
4. **Translation and layout acceptance.** Audit remaining interface literals, test longer translated strings and fonts for supported scripts, and add reviewed translations as available. English alone is shipped initially.

## Locale contract

`Localization.lua` loads before `Locales/enUS.lua`, which always loads before addon consumers. Add future locale files immediately after English in the .toc. They call `addon.Localization.Register("deDE", strings)` using stable symbolic keys from the English file. Only the current client's translation is applied; omitted keys fall back to English. No locale selector is required for this conversion.

Consumers use `local L = addon.L`. Saved-variable keys, profile/theme identities, factory data, slash commands, serialization fields and schema version remain language-independent. User-authored category names, labels and emote commands are never translated. Blizzard-owned button captions can continue using Blizzard's localized globals.

Translate entire sentences or formatting templates rather than concatenated fragments. Preserve `%s` placeholders and literal command tokens such as `{target}` and `{player}`. Unknown interface keys render their symbolic name so omissions are visible.

## Standard-emote reference catalog

`Locales/enUS.lua` also registers the 299 rows supplied by the user as `addon.Localization.StandardEmotes.enUS`. Each row contains an English slash alias, an untargeted preview and a targeted preview. The submitted wording, alias variants and `<target>` placeholders are preserved verbatim. This is supplied reference data, not a verified list of commands supported by every current game client.

The catalog is held separately from interface strings and SavedVariables. It does not change existing command aliases, starter emotes or execution. A future dropdown can consume the reference data once its behavior is decided; selection, insertion, alias grouping and preview policy are outside this conversion. Non-English catalogs must be registered separately because command aliases can differ by locale.

## Validation

The localization smoke suite checks client selection, partial-translation fallback, stable table identity, translated navigation and catalog shape/isolation. Existing settings tests load the new startup dependency and continue checking English behavior. Native WoW layout and non-Latin font acceptance remain pending.

Phase two also converts user-facing Database and Serialization messages and bundled-theme descriptions. Stored enum tokens, reserved and bundled names, generated copy/import names, font identifiers and exported fields remain unchanged. Parser diagnostics embedded inside the translated Invalid JSON message retain the parser's technical wording. Standard units and coordinate labels remain unchanged. The settings localization suite uses a synthetic translation to check real dropdown behavior, validation, theme identities and identical exported documents. No additional language is shipped yet.
