# Exploration / recorder review — 2026-11-11

Completed runtime scope: continuous photography, film previews with basic/advanced adjustment, original comparison, actor visibility, source images and photo metadata, favorites/place filters, directional ambience recording and replay, naming/recovery, click-to-walk target and cancellation, precise map landmark feedback. No story unlock, source-art repaint or user-guitar replacement.

Reference UI correction: the user rejected the first full-width recording panel. Final recorder has only edge HUD, optional direction line and an opt-in library that closes when recording starts. See the source links and specific visual comparison in ../../Exploration_Polish_20261110.md.

## Evidence

- Actual final PCK, launched from an empty runtime directory: **148 checks, zero failures** across seven suites. Counts and audio measurements: receipt.json. No source checkout fallback was used for runtime resources; external fixtures loaded compiled scripts from the PCK.
- Final core package suites: photos 23, recorder 35, navigation 12, accepted-photo application close 6. Audio package regressions: host/music 27, scene transitions 22, shutter 23.
- Source map regressions: map_soft_focus_20261108 and map_pet_feedback_20261109 passed. Map image pixels are retained, feedback follows the selected building, and pet hotspots preserve the underlying location caption.
- Standard tools/check.ps1 completed successfully, including Python studio/media checks and the headless preference, mail state, walker, dialogue, queue and envelope suites. Additional runtime export Python tests: 3 passed. Final edge HUD then passed the packaged GPU suites above. Private archive checks were not requested/run.
- Packaging audit: 1,165 entries, 184 raw runtime files verified. Official release EXE hash verified against the existing official-template manifest. The only post-build runtime-file edit was removal of trailing whitespace on an empty camera-script line; no token, logic or asset change.
- zh/en recorder and photo layouts reviewed at 1280x720, 1920x1080 and 2560x1440 via engine screenshots; final live recording image shows timer, red indicator and actual meter without a scene-blocking panel.

## Corrections found during review

The first recorder meter drew below its panel and hint text lacked contrast; both corrected, then the panel itself removed per latest user instruction. Arrow keys now adjust pickup with record-button focus and release cleanly. A meter test originally looked only at the final instant after a bird call; it now measures the whole recording interval and separately validates nonzero, unclipped saved PCM. The intentional disk-write failure test emits engine errors by design, retains PCM and verifies successful retry. These are not unhandled production failures.

Legacy walker assertions assumed six poses and an identical full-image anchor even though approved independent idle/turn art and crop registration were already selected. Fixture now checks all loaded authored poses, approved per-frame registration and completion of the existing turn/settle sequence. No walker implementation or animation asset was changed. Legacy dialogue fixture now waits for actual entry/exit transitions and isolates pagination from typewriter timing; product behavior remains unchanged. Both revised suites pass (61 and 19 checks).

## Acceptance limits

The actual Windows release opened a visible Dear Somewhere window. CUA then timed out awaiting permission to bind the app, so OS mouse input, full human playthrough and subjective speaker/headphone listening remain **unverified**. Dummy-driver PCM capture, native voice identity and screenshot reviews are never presented as a listening pass. No unrelated story/studio gate has been advanced. The release can be published within the user's existing scope with this limitation recorded; do not label it whole-game or reference-game-equivalence acceptance.
