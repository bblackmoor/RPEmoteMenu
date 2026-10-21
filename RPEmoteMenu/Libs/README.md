# Bundled libraries

The addon includes all required libraries. Automated builds fetch their exact
upstream commits from [`.pkgmeta`](../../.pkgmeta); bundled development copies
remain available for local tests and source ZIP installation.

| Library | Repository | Pinned commit | Subdirectory |
| --- | --- | --- | --- |
| LibStub | lua-wow/LibStub | `af45e4a862a4b0bd025dfac95f4697ecdbc5b015` | Root |
| CallbackHandler-1.0 | WoWUIDev/Ace3 | `40f4cc1356ae7fcc0cf71fc0a19dc7d50d6ae6c2` | `CallbackHandler-1.0` |
| LibSharedMedia-3.0 | SquizzCheeze/Squizzumables | `e40d97410035e5b148c4cbec180af6f2b6317bad` | `Libs/LibSharedMedia-3.0` |
| Details Framework | Tercioo/Details-Framework | `653af57120e1287be784d468324590a9c150ae98` | Root |

LibStub's public-domain notice is retained in its source. CallbackHandler's BSD
license, LibSharedMedia's LGPL-2.1 license, and Details Framework's
LGPL-2.1-or-later license are included. Provenance is recorded in `UPSTREAM.json`
and `DetailsFramework/UPSTREAM.json`.

Library behavior is unchanged. The release validator compares every fetched
TOC/XML runtime file against the tested bundled copy, allowing only documented
whitespace normalization. Details Framework's `fw.lua` is copied verbatim to
avoid packager keyword substitutions. Standalone library TOCs, examples, tests
and documentation are excluded from installable ZIPs.

When upgrading a library, update its pin, bundled files and provenance together.
See [Packaging and releases](../../docs/releasing.md) for validation commands.
