# Rounded typography and authored chef dialogue — 2026-11-04

## Scope
- Runtime Chinese: ChillRoundF; Latin: DynaPuff (weight 450). Noto Sans SC remains a rare-glyph fallback. Settings retains its rounded Lilita One English heading. Both selected families ship with their OFL licenses.
- Replaced explicit legacy handwriting overrides in books, observations, mail, deduction and resolution controls. Authored words painted into background images remain untouched.
- Added supplied food-truck chef, supplied cat bubble, supplied paper dialogue and original chef/courier portraits. Source JPEG bytes are immutable; independent alpha masks remove the matte. Intentional white outline applies only to dialogue portraits.
- Six bilingual introductory dialogue pages; no fabricated quest reward or campaign progression.

## Verification
- Godot 4.7.2 actual GPU input/render harness: 24 checks, 0 failures; empty runtime stderr.
- Tested E interaction, mouse close button, Esc, movement suspension/restoration, repeated entry, final-page exit, all six English pages, Chinese layout, 1280x720 / 1920x1080 / 2560x1440 and night lighting.
- Exported PCK: rounded font, glyph coverage, all eight authored textures/masks and production scene resources load successfully.
- Visually reviewed 1920x1080 day-world, Chinese and English dialogue. Fixed speaker text extending left of the supplied nameplate. Replaced noisy color-key outline with a filtered independent alpha mask after the first visual review.
- Evidence: test-results/dialogue_20261104 (local screenshots/logs/package); tests/authored_chef_dialogue.gd (reproducible source test).

## Limits / unresolved
- Native desktop manual acceptance is not completed; offscreen GPU input/render checks do not substitute for a user playthrough.
- Initial package startup/instant-shutdown probe reported ObjectDB/resource leaks. The final package probe checks resource loading only and exits cleanly; full packaged startup/shutdown remains unverified. The full source GPU dialogue harness exits cleanly.
- Headless export prints the existing unset Blender-import path warning; this task imports no Blender model.
- Background motion edits from the other active task are not part of this commit or this typography acceptance.
- No claim that the full campaign or every historical issue is complete.

## License sources
- https://github.com/Warren2060/ChillRound
- https://github.com/google/fonts/tree/main/ofl/dynapuff
