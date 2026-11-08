# Map paper feedback — 2026-11-08

The user rejected the map's light as too conspicuous. The map no longer has a material or illumination overlay: hover, keyboard selection and held press leave its artwork pixels unchanged. Selection is identified by the bilingual location caption. The caption now fits its text (168–340 logical pixels), uses a slightly translucent paper background without a shadow, and moves down only 2 pixels while pressed. Existing pointer/keyboard targeting, hand cursor, destination routes and cancellation remain intact.

Runtime source: `6c4c9a7`, on main `ecc53c6`, preserving the latest street continuity changes. PCK SHA-256: `bfb0820b2b55d7f3e40736d2092cbb1dcc18147363d620e9bcfb0e50d74cb5d7`. Original map SHA remains `3ace307814071c4bb8990a6eb52b28f70cfcbaa9806f9b20a167dd53cc67d815`.

The actual PCK passed 288 checks from empty hosts with isolated userdata: revised map visual/input suite 104, input modality 44, exploration routes 113 and explicit audio teardown 27. GPU samples confirm unchanged map pixels over all 13 destination hovers and held press, readable zh/en captions at 1280/1920/2560, and intact cancellation/keyboard routing. No unexpected errors or leaks occurred in these completed suites. Captures were visually inspected and a new 7-second preview recorded from this package.

The initial test rewrite used the Windows default text decoding and changed its close-button comparison from × to a different character; that fixture could not find Close and failed. Its original log is retained in `work/package-qa-map-paper`; only that isolated failed fixture process was stopped. The comparison was corrected and all checks rerun in `work/package-qa-map-paper-verified`. The game source and package were unaffected by the test-only encoding issue.

Build audit: `test-results/package-20261108-191127/export-audit.json`, 1,116 entries and 172 raw files verified. `-SkipChecks` only skips build-script tests; the above tests ran separately on the frozen package. Raw movie output is on D to avoid repeating the earlier C-drive exhaustion.

This replaces the rejected lighting treatment recorded in MAP_SOFT_FOCUS_20261108.md. No OS input or original save changes were used. Full manual playthrough, human aesthetic acceptance and previously documented unrelated cleanup/animation gaps remain separate.
