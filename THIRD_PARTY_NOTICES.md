# Third-party workflow material

Claude Code Game Studios — Copyright (c) 2026 Donchitos.

Source: https://github.com/Donchitos/Claude-Code-Game-Studios

Pinned revision: `b21fa0f7f289fc3e726cf36fb12b9bc1e7a51e4d`.

The project-local reference snapshot is distributed under the MIT license retained in `third_party/claude-code-game-studios/LICENSE`. The original `.claude` files, README, CLAUDE.md and project.yaml are retained unchanged; file hashes are recorded in `tools/studio/upstream.lock.json`. The Solmere/Codex adapter and explicit project-specific overrides are documented in `docs/STUDIO_WORKFLOW.md`.

This is development workflow material. Its hooks are not activated in this Codex session and it is not a Godot runtime dependency.

## Settings fonts and water audio — 2026-10-16

DynaPuff and ZCOOL KuaiLe are bundled under SIL Open Font License 1.1. The unchanged font files, original copyright/license notices and pinned upstream commits/SHA256 are retained in assets/fonts. The OFL permits bundling with commercial software when its notices are retained; this does not permit selling the font by itself. DynaPuff is the chunky Latin Settings face; ZCOOL KuaiLe supplies Chinese, with the existing readable font fallback. Letters/story text retain their established font.

Primary license sources: https://github.com/google/fonts/tree/main/ofl/dynapuff and https://github.com/google/fonts/tree/main/ofl/zcoolkuaile.

The three quiet water-touch samples are PCM decodes of ezwa/qubodup's CC0 `6 short water splashes`. Original listing: https://opengameart.org/content/6-short-water-splashes. Source archive, decoded filenames, hashes and durations are recorded in assets/audio/foley/water-provenance.json; CC0 notice is WATER_CC0.txt. Original source archive is retained privately, not included in the game. Actual listening acceptance remains pending.


Settings R3 sources (2026-10-17): exact original authored PDF JPEG layers (user authorized grouping); runtime white-matte compositing, no AI repaint. Lilita One, DynaPuff, ZCOOL KuaiLe and Noto Sans SC: original SIL OFL1.1 notices and pinned font hashes in assets/fonts. Evan Wallace WebGL Water: pinned MIT water.js step/drop equations ported into scripts/ui/water_field.gd; third_party/webgl-water retains original source/header, commit/hash and full MIT notice. No upstream JavaScript or demo photographs executed. Native GodotPhysics2D (Godot MIT) supplies actual 2D rigid-body contacts. Vaporware by The Cynic Project / cynicmusic.com / pixelsphere.org: complete CC0 track, source https://opengameart.org/content/calm-piano-1-vaporware; assets/audio/settings-music-provenance.json records unchanged source fingerprint and Ogg transcode.
