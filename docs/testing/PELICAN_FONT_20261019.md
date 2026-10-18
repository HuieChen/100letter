# Pelican Post drawing language and commercial Chinese Settings font

Status: **scoped review checkpoint**, not whole-game quality acceptance. Original saves, campaign state and supplied source artwork are preserved.

## What is selected

Sixteen original ImageGen PNG outputs now supply **54 generated runtime art roles**: eight environments, wall closeup, five NPCs, physical books/papers/envelopes, tools, bag, photos, plates, map and notebook dialogue leaf. The new language follows the actual inset gameplay in the [official Pelican Post screenshots](https://drewg8.itch.io/pelican-post): chunky dark pixel contours, simple rounded silhouettes, flat cream/teal/coral/plum planes and limited local shadows. Its marketing postcard frame, cast, text and exact buildings are not copied. Prompts and untouched PNG hashes are recorded in `assets/faefever_v2/pelican_20261018/candidate-provenance.json`; atlas bounds are measured from actual generated alpha components, not reused from old sheets. No procedural painting/recoloring supplied the replacement bitmaps.

The first post-office candidate added planters and changed the floor; the first chess scene invented a door; the first lookout changed the instrument case to a sign. Those were rejected. The selected corrections use only the existing **AI-generated** layout as the second reference. No user-drawn scene was submitted for AI blending.

**18 explicit authored roles remain unchanged**: the original Settings PDF layers and exact five-pose video-courier selections. Their complete manifest records compare equal before/after registration. This is a real visual exception; generated-art replacement does not mean the entire game's appearance is now perfectly uniform or pixel-identical to Pelican Post. Original files remain intact and prior selected generated art remains in source/history.

## Chinese Settings font

Replaced Chinese headline, captions and selectors with **ChillRoundF / 寒蝉全圆体**, original unmodified upstream bytes from commit `46dda1602729b58de96e3fdee9f918d7aaa64727`, `ChillRound/ChillRoundF.ttf`. SHA256: `ebeb471ae9778a26012a18136f8a9ae99450832cd8bb259265684720d60839f0`.

The [author's SIL OFL 1.1 license](https://github.com/Warren2060/ChillRound/blob/46dda1602729b58de96e3fdee9f918d7aaa64727/LICENSE) permits commercial software embedding with copyright/license retained. The full original notice is bundled in source and PCK; the font is not offered as a standalone sale. Other language and story fonts are preserved. Local raster weight is 0.6 for captions and a lighter 0.3 for the large headline, keeping the inner strokes of “置” open. Source artwork, water simulation, floating-fruit physics, real controls and persistence are unchanged by the font replacement.

## Current actual checks

[Frozen evidence](pelican-font_20261019/evidence.json): one complete current source command, **40 runtime suites / 13,938 checks / zero failures**, plus 29 supplemental engine-close/reload checks. Python studio/art/courier/media: 28 / 3 / 9 / 5 passing tests. This includes Chinese/English at 1280/1920/2560; actual glyph bounds; all four expanded menus; solid slider manipulation; arrow/Esc and repeat entry; real mixer and dialogue effects; source-reading/save guards; two complete existing five-case routes (345/347) and the amendment handoff (215). The new Chinese settings suite has 501 checks, including actual Chinese glyph availability in the loaded base font.

Actual current PCK: **424 checks / zero failures**, including adopted images, original authored exceptions, new font/notice decoding, current four shader fingerprints and absence of the temporary QA no-focus override. Official Windows executable completed a 120-frame **headless** boot. No packaged GPU/native window was opened under the user's background-only instruction. Source GPU checks are distinct from package GPU/native acceptance.

The first font fixture asserted an English internal family name, while the actual loaded font supplied a localized name. Changed the fixture to verify the loaded base resource; retained the failed 501-check/three-failure log. The first package inspector still required the retired pastel style identifier; retained its 424/one-failure report, changed the expected literal to the new requested style, and reran on the same PCK. Neither correction bypasses glyph, bounds, hash or resource checks.

Current forced `--quit-after` headless boot still reports **18 ObjectDB instances / four resources** at engine teardown, as in the previous release. This is not repaired or described as a clean shutdown; actual engine-close/save/reload has its own passing check and is not an OS-titlebar test. Earlier repeated-texture water-offset measurement nondeterminism remains documented; this full current suite passed its unchanged checks.

## State walkthrough and acceptance boundary

Start a shift → supervisor introduction → operate the physical case and take its envelope → read the whole object → travel and approach public sources → read/flip/move the actual source → notebook/save retains observed facts → speak to recipient and hand over mail → recipient naturally mentions counter processing → return to the actual counter → fill/review/stamp the slip → later envelopes become available. This walkthrough describes the existing verified route; it is not the proposed new long three-letter story.

No independent novice playtest, human listening or complete native OS-input run was completed. The new thousand-word letters, dispersed edits, realistic wax-material chain and five-day/24-letter campaign remain incomplete. Complete written reference routes and actual screenshot coverage are distinguished in `docs/FULL_FLOW_REFERENCE_REVIEW_20261018.md`; no full Pelican Post demo playthrough is claimed. CORE-BOOK remains review; no independent reviewer or acceptance handoff is fabricated.

Actual 1920×1080 frames: [Chinese Settings](pelican-font_20261019/screenshots/settings/zh_1920.png), [English Settings](pelican-font_20261019/screenshots/settings/en_1920.png), [post office](pelican-font_20261019/screenshots/world/world_post_office.png), [residential scene](pelican-font_20261019/screenshots/world/world_residential.png). These are GPU fixture captures, not native desktop screenshots.

## Publication checkpoint

Runtime source `321c351815124980029f1552175212e37b84338c` is verified on main; [exact main CI passed](https://github.com/HuieChen/100letter/actions/runs/39149304808), and [matching source-tag CI passed](https://github.com/HuieChen/100letter/actions/runs/39150528207). The current Windows ZIP is 88,043,468 bytes, SHA256 `b1777b807f670c460352171c72bd7e2610cf1e07ddc5d56c2b75636607dbe7d4`, CRC/PCK checked locally at D:/CodexBuilds/DearSomewhere-Windows-Pelican-Font-20261019.zip.

The prerelease source tag was created successfully, but Windows asset upload timed out with zero bytes sent and subsequent API TLS connections reset. A fresh guest-browser inspection confirms only the two automatic source archives are visible. Therefore Windows online download publication remains **NOT_UPLOADED**, distinct from source publication and package validation. The complete original ChillRoundF notice is also included as a human-readable file in the local ZIP Licenses directory. See publication.json for receipt and exact limits.
