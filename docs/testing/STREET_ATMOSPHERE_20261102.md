# Street art, weather and sound review — 2026-11-02

Scope: the user's November community-street replacements, subtle outdoor motion and synchronized ambience, and the requested community walking/daylight video. This is not whole-game or gait-quality acceptance.

## Supplied art and rendering

All four 9204×640 community paintings are copied byte-for-byte from the November batch. `assets/authoring/streets_20261101/provenance.json` contains current source names and SHA-256. Earlier copies remain in Git history and the private QA backup. No source painting was repainted or regenerated.

All four street families use continuous displacement of the original painting. Crown sway has a fixed root, fine tips and grass move at different periods, and sea bands use two slow travelling waves. Most wind is gentle with an occasional stronger travelling gust. Rigid guards keep buildings, roofs, signs and lamps stationary. There are no separate cutout edges. Current supplied scenes have no identified visible sailboat; the unused boat branch is not evidence of an implemented boat animation.

Daylight blends the actual supplied morning/noon/sunset/night images at the same UV position. The courier tint follows the same blend. Cumulative save time and wrapped display time are separate: saving on day two, repeated saves, and crossing midnight cannot trigger a full-day light sweep. Regular play retains its action-based clock; the recording alone accelerates the time of day.

The revised warm noon image exposed an existing night-window repair bug: its roof no longer matched the former blue-pigment mask. Geometry now comes from the matching morning painting. The 25×25 source-region repair keeps the foreground roof in front of the lit window without modifying source files.

## Sound

New CC0 Stek59 leaf rustle is filtered, looped with a crossfade, and mixed quietly beneath the supplied guitar. Local wind strength and proximity to foliage control its gain; the ocean gain uses the same travelling wave time/position phase as the picture. Postal, community, residential and coastal routes retain location-specific levels. Indoor/title leaf sound fades away. Real audio buses, sliders, mute and shutdown cover the new player.

References studied for motion principles: [Unity Lost Crypt](https://cdn.bfldr.com/S5BC9Y64/at/g4bpkhf75nbjwvmpzvsmcv/2D_Tools_Lost_Crypt_eBook.pdf), [Victor Karp foliage wind](https://victorkarp.com/godot-foliage-wind/), [Spiritfarer animation interview](https://www.toonboom.com/thunder-lotus-games-on-animating-the-afterlife-in-spiritfarer), and [LUNA walking study](https://www.lantern-studio.com/blog/2018/10/18/devlog-18-mind-the-gap-the-study-of-lunas-character-walking-system). These informed principles, not copied runtime code/assets; no claim of exhaustive full-playthrough or frame-by-frame coverage is made.

## Regression evidence

Actual Compatibility-renderer checks after replacement:

| Check | Result |
| --- | --- |
| Painted weather motion, fixed structures, source endpoints, time boundaries, sound envelope and retirement | 125 / 0 failures |
| Street imports, map routing, footsteps and roof repair | 93 / 0 |
| Courier controller, Shift, stopping | 75 / 0 |
| Courier alpha render | 23 / 0 |
| Independently timed authored blink | 6 / 0 |
| Real audio settings and progress isolation | 20 / 0 |
| Audio shutdown and ownership | 40 / 0 |
| Ocean/guitar selection and quiet/strong wave gain | 5 / 0 |

Errors found and corrected: warm-noon roof mask failure; cumulative-day clock sweep; repeat-save tween restart; sound/visual spatial phase mismatch; rigid noticeboard/bus-stop overlap; stale tests assuming the previous static ocean gain and removed settings music. Failed logs are retained privately rather than represented as passing runs.

The source export succeeds and the recording loads the actual exported PCK from an isolated project, verifies all eight street image hashes and decodes the leaf audio. The editor emitted an unrelated invalid Blender-path warning during export scanning; no Blender asset is part of this update. Current package/runtime evidence must not be conflated with a published Windows installer.

## Walking rejection and limits

The generated eight-pose supplemental legs were rejected by the user as worse and scissor-like. They are removed from production and export, retained only under ignored QA material. The original five full-body walking poses and their established cadence are restored. No new generated face or leg sheet is shipped. Mipmaps reduce downscaling shimmer; the authored blink is timed independently of walking/Shift. This does not supply the missing natural passing poses or establish that perceived gait stutter is fixed. Gait quality remains OPEN.

Recording uses scripted D input, the real production street renderer/audio, and an accelerated review clock. It is a visual/audio review artifact, not native held-key performance proof or a player usability test. Native Windows automation failed with `failed to write kernel assets` after bounded retry/reset. Human listening, visual acceptance, and remaining gait correction are not certified by automated results. The user's latest delivery instruction is direct chat delivery, not WeChat.
