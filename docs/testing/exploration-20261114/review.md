# Exploration / recorder / unified UI review — 2026-11-14

## Scope

This is a focused revision of the already-open exploration features. It covers the camera paper ritual, camera control skin, recorder field HUD, walk input while recording, map destination dwell, scene-specific recording sources and the package export. It does not unlock the narrative flow or change supplied artwork.

## Reference basis

- [SEASON recorder screenshot](https://www.shacknews.com/article/133862/season-letter-to-the-future-review-score): sparse edge status and a readable scene.
- [SEASON audio design](https://side.inc/lab/season-a-letter-to-the-future-experiencing-audio-recording-as-a-game-mechanic): recording as observation, direction and review.
- [TOEM](https://www.playstation.com/en-us/games/toem/) and its [camera design discussion](https://www.gamedeveloper.com/design/q-a-designing-the-photogenic-vignettes-and-camera-play-in-snap-happy-adventure-i-toem-i-): camera as a purposeful observation tool with clear viewfinder affordances.
- [ZOOM H1essential manual](https://zoomcorp.com/documents/2936/E_H1essential_rev2.pdf): separate REC state, stereo L/R level display, waveform history and file-list review.
- [CC0 Waterflow Sound](https://opengameart.org/content/waterflow-sound): the added fountain layer is an unmodified CC0 source; provenance is recorded beside the file.

The implementation borrows interaction patterns, not pixels or authored assets. Dear Somewhere's own identity is the warm paper surface, ink typography, teal level/focus marks, coral recording state, small offset shadows and the existing hand-drawn viewfinder.

## Implemented observations

- Camera controls use the shared paper/ink/teal language and remain readable against the painted street. Film controls are grouped as an instrument panel; the bottom paper slot and gradual slide/develop animation are restored for both landscape and instant formats.
- Recorder monitoring is an edge HUD with a compact stereo instrument card, L/R meter, short waveform history and coral REC state. The central scene remains clear. The library is opt-in and is the only recorder state that pauses walking.
- While recording, the courier accepts WASD/arrow movement and ground clicks; right-click still cancels a walk. Guitar music is silent on recorder entry and resumes after close. Playback ducks the scene bus separately.
- Scene voice layers reuse the existing painted anchors and add a fountain, market, food-truck, tram, lookout-wind and small book/chess/grocery details. The recorder captures `SolmereAmbience` only.
- Map labels use a 260 ms hover dwell and a 300 ms exit grace. Rapid flyovers leave the current paper label in place until the next building is actually selected.

## Evidence

- Source-scoped GPU/Dummy-mixer suites: 94 checks, 0 failures (camera 28, recorder 42, navigation 18, host close 6).
- The same four suites loaded the actual exported PCK from an empty runtime directory: 94 checks, 0 failures. No source-checkout fallback was used.
- Package inventory: 1,247 entries and 240 raw files in the final package built after merging the collaborator main branch. The final inventory includes the fountain MP3, birds, bell, town, tool, tram, wind and paper detail sources used by the field soundscape.
- The final merged main commit is `ace1c645781fef51d0fdc12ea1dbc2f8d0908431`; GitHub Actions run [43545586632](https://github.com/HuieChen/DearSomewhere/actions/runs/43545586632) is green. The full legacy `tools/check.ps1 -GpuChecks` reached the existing display suite and reported one failure in the unmodified display-settings chain: `visible close survives repeated render-resolution changes`. The scoped source/package suites above are clean; the legacy display failure is retained as a separate acceptance gap rather than hidden.

## Acceptance limits

Dummy audio validates PCM capture, routing and meter data, not speaker/headphone quality. The actual Windows release and OS mouse playthrough were not counted as passed in this run. Native listening, novice discovery and full-game aesthetic acceptance remain open.
