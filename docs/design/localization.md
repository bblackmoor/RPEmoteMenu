# Interface localization

## Scope and sequence

1. **Foundation and navigation — complete in 2.1.252.** Add a lightweight locale registry, English fallback, translated settings navigation and About text. Store the supplied standard-emote reference catalog in the English locale file.
2. **Settings pages and shared messages — complete in 2.1.253.** Convert Behavior, Profiles, Themes, Emotes and Import/Export interface strings, including dialogs, tooltips, validation messages and framework diagnostics. Keep complete sentences and formatting templates together.
3. **Menu and editor — complete in 2.1.254.** Convert MainWindow and the emote editor's labels, help text, empty states and messages. Preserve player-authored content and command execution.
4. **Translation and layout acceptance — automated checks complete in 2.1.255; native acceptance pending.** Audit remaining interface literals, test longer translated strings and fonts for supported scripts, and add reviewed translations as available. English alone is shipped initially.

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

Phase three localizes MainWindow and EmoteEditor interface text, reusing shared keys where English wording matches. The empty-sidebar fallback measures the same translated Add Category text shown on its button. A synthetic-translation suite exercises real width calculation, tooltips, editor validation/save and stale-target rejection, while preserving player-authored labels and commands (including percent signs and character tokens). Long translations and non-Latin native rendering remain phase-four acceptance work.


## Phase-four acceptance

The literal audit found no remaining addon-owned English captions in direct text/tooltip calls. Coordinate letters X/Y, the information glyphs O/i, the close glyph X, standard units, internal assertions and parser diagnostics are intentional exceptions. Stored identifiers, font names, built-in content and third-party library text remain outside the interface conversion. All 288 English keys are unique and every symbolic consumer reference resolves.

Locale registration checks every supplied translation, including inactive locales, against the English key and ordered Lua format argument types. Unknown keys, malformed formatted sentences and changed `{player}`/`{target}` counts are rejected; active rejected entries use English fallback. `addon.Localization.RejectedStrings[localeCode][key]` holds a developer diagnostic. A subsequent valid registration clears that key's diagnostic. Preserve argument order even where translated grammar would prefer a different ordering. Literal percent signs in formatting templates must be doubled (`%%`); ordinary unformatted percentage labels remain ordinary text. English must load before translations.

The emote editor now places each full-width label above its draft field. Help, labels, validation/status messages and dialog action captions are measured after text changes. Editor and exchange dialogs grow and shrink with wrapped text; the exchange text area keeps at least 300 UI units of height. Synthetic expanded Unicode tests check separation of fields, button sizing, error-message growth, clearing/shrink behavior and unchanged export text. The tests model glyph measurements and cannot establish native font coverage or rendering quality. Very long copy can still exceed a small screen; shorten reviewed copy and check the native UI at the intended scale.

Only enUS ships. Dialog labels/buttons use Blizzard's localized font objects through DetailsFramework; draft fields use `STANDARD_TEXT_FONT`. The default menu font resolves through `STANDARD_TEXT_FONT`; explicitly selected bundled or shared fonts can lack glyphs even when registered. Font availability tests verify provider/loading/fallback behavior, not script coverage. No automatic glyph-coverage fallback is claimed.

Before shipping a reviewed translation, run all smoke suites and test the actual client locale in WoW: settings navigation and narrow panels; editor help, all three labels, long validation errors and action captions; every import/export mode and long result messages; empty/populated menu and tooltips; both title-bar positions; different UI scales. Check native fonts for the translation's script, including player-authored names/commands. Repeat the checks with Default and a selected shared font. Screenshots or native checks must establish the final acceptance; automated phase four alone does not certify another language. The standard-emote dropdown remains a separate feature.
