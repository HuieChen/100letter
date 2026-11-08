# Street continuity and repeated-entry refinement — 2026-11-08, pass 2

Scope: existing streets and their sound/scene transitions. No source artwork, audio samples, visual strength, UI layout, story availability or player saves were changed.

## Fixes

The camera discarded elapsed time above 50 ms although courier movement consumes up to 250 ms. At 200 world pixels/second, measured settled follow lag was 123.8 px at 5 FPS and 34.4 px at 60 FPS. Passing zero also corrupted Phantom Camera's internal damping velocity and made the next transform non-finite. The director now rejects non-positive/non-finite deltas, processes positive bounded substeps, and interpolates the sampled target over those steps. It still consumes the existing Phantom Camera damping; normal 60 Hz transforms match the old implementation exactly. Measured 5–60 Hz follow lag is now 34.4066 px, with less than 1 px difference at 144 Hz. The 250 ms cap matches the courier.

Repeated streets also rebuilt identical runtime postal-registration/fountain composites, reading full panoramas back from the GPU. These immutable derived textures now share the existing two-family cache. Source resource identity and fountain geometry qualify reuse; callers receive separate arrays and retain their own materials/animation state. Missing or invalid postal registration patches still retry on a later entry. The originals remain untouched and eviction releases cached derivatives.

## Focused evidence

- Camera cadence: 40 checks, zero failures, including zero/negative/non-finite values, disabled/resume, bounds, teleports, the long-frame cap and unchanged 60 Hz reference transforms.
- Actual Road/Phantom GPU integration: 132 checks, zero failures.
- Repeated streets: 69 checks, zero failures; three phase framebuffer comparisons, original mask identity, texture reuse and weak-reference release after eviction. Independent comparison of all RGBA bytes at fixed noon poses matches the previously published c833 PCK in all four families.
- Warm Road construction, three samples per family in this QA process: community 41.20 → 3.24 ms, postal 65.09 → 3.62 ms, residential 36.49 → 3.46 ms, coastal 25.06 → 3.34 ms. These are construction measurements, not end-to-end scene latency, GPU FPS or a minimum-machine guarantee. Cold loads remain necessary; memory stays bounded to two families.
- Actual Host audio passage: 22 checks, zero failures. The original guitar and four ambient playback voices continue through outdoor/interior transitions, pause and rapid settings reentry; bed levels crossfade, explicit master mute survives focus notifications, and shutdown releases owned voices. No production audio correction was needed.
- Held-key arrivals were inspected separately. Actual scene changes already cancel movement, so the unproven arrival concern was not patched. Scripted departure walking remains intact.

These are isolated-data GPU/engine-input checks, not new human mouse-feel or listening acceptance. Final exported-PCK results are delivered with the shared release manifest. Local source evidence: `D:/Codex-build-cache/dear-somewhere-motion-pass2-20261108/`.
