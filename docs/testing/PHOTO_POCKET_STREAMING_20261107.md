# Photo pocket responsiveness — 2026-11-07

The photo pocket previously decoded and resized every original PNG synchronously while opening. Its 96-entry cache did not bound displayed texture references: every offscreen PhotoPrint still retained a GPU texture. A 240-photo fixture took 5559.696 ms to open and retained 240 image holders.

The pocket now keeps stable buttons for keyboard navigation, loads visible rows plus one neighboring row on either side, and clears offscreen image references. A single worker decodes and resizes CPU images; the main thread updates UI and creates the small GPU textures. Captions load only when a print is displayed and refresh on reopening. The shared LRU cache remains bounded at 96 entries. Unreadable prints retain their positions and display localized feedback. Thread-start failure skips the failed item rather than starving subsequent prints.

The original PNGs, notes, landscape composition, authored art, and save paths are preserved. This builds on main f599c0e, including the collaborators' typography, map and scene-motion improvements. It does not reintroduce the canceled paper-wipe transition or expose unfinished dialogue.

## Measured evidence

Windows / Godot 4.7.2 / RTX 4050, with isolated QA files and 240 generated 1600×900 photos:

- Before: 5559.696 ms synchronously opening the pocket, 240 image holders.
- Final source: 42.716 ms; maximum measured close during a decode 19.829 ms.
- Final PCK: 44.640 ms; maximum measured close during a decode 14.717 ms.
- Scrolling the collection keeps image holders at 24 or fewer in the test viewport and the cache at 96 or fewer. These counts describe texture references, not a complete process-memory measurement.

These are local fixture measurements, not a guarantee for every machine or image size. Closing joins one in-flight decode; unusually large external images can still increase close latency. The layout retains a button for every photo, so very large collections may eventually warrant full row virtualization.

## Final package validation

| Suite against actual PCK | Checks | Failures |
| --- | ---: | ---: |
| photo_pocket_streaming | 70 | 0 |
| feedback_landscape_20261106 | 72 | 0 |
| photo_review_resilience | 64 | 0 |
| experience_routes_20261106 | 113 | 0 |
| Total | 319 | 0 |

The photo suite covers all 240 entries, distant keyboard focus, opening the correct print, edited notes on return, original-file hashes, eight closes during loading, a damaged newest image, and an injected thread-start failure followed by a healthy image. Landscape checks cover Chinese/English and 1280×720, 1920×1080, 2560×1440. Package screenshots of the real captured photo and the stress gallery were visually inspected. The actual release EXE also booted and exited with code 0 and no errors.

Build used `-SkipChecks` because the focused suites above were run separately against its actual PCK; this is not a claim that the historical full pipeline passed. The final inventory contains 1101 entries and 168 hash-verified raw includes. Intentional corrupt-photo fixtures produce expected image-decoder errors; there are no other script/render errors or shutdown leaks in the final focused runs. The first injected-error fixture had zero-size test paper and emitted polygon warnings; its dimensions were corrected before final PCK validation.

PCK SHA-256: `a74080e5902277c347595d83a214113d745f5ffe9462424b7f6e1117b3c73ee2`.

Independent code review identified the thread-start starvation issue and the possible close-time wait; both are reflected in the implementation and measurements. Art review used engine captures; no source art changed. Audio code did not change. Actual OS-input playthrough, listening and broad player acceptance were not repeated, and CORE-BOOK remains in review.

Reproduce with an isolated APPDATA / LOCALAPPDATA and the packaged resources:

```powershell
& $Godot --main-pack $Pck --script "$Repo/tests/photo_pocket_streaming.gd" -- --final-save=user://qa/pocket_check/state.json --qa-out=user://qa/pocket_check/captures
```
