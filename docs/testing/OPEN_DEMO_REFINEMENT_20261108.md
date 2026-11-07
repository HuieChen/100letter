# Open-demo refinement — 2026-11-08

Scope: the currently open exploration demo. Original panorama, foliage, fountain frames and audio samples stay unchanged; title artwork is coordinated separately with the UI chat.

## Corrected behavior

- Postal fountain now clears the fixed painted water behind the original three-frame animation, as the other streets already did. The runtime-derived repair has a two-source-pixel RGB border and transparent outer texels, removing its crop-edge seam while preserving the statue, pillar and basin.
- Settings language changes update the active street and post-office entry caption immediately, without rebuilding the scene or moving the courier/camera.
- An accepted shutter followed immediately by Back or window close finishes exposure and writes its raw PNG before closing. It does not wait through the decorative print animation. Save failure still supports retry and deliberate close.
- Foliage/foreground/cloud/star technical masks and original fountain textures reuse the existing two-family cache. Eviction releases cache ownership; resources still used by a live street remain valid. No shader material treatment or animation amplitude changed.

## Evidence and limits

- `fountain_composite_20261108.gd`: 504 checks, zero failures across four street families, four phases and dusk blending. Tests original frame bytes, order, loop and visible motion, and fixed statue/pillar/basin pixels. A negative control using the old unpadded crop fails 20 seam checks. The fixed-region comparison allows only 1/255 filtering roundoff.
- `street_asset_reuse_20261108.gd`: 51 checks, zero failures. Re-entry frames are byte-identical at noon, dusk and night; masks retain source pixels; textures are shared only within the bounded lifetime and release after eviction.
- `live_world_interaction_20261108.gd`: 27 checks, zero failures, including real Settings pointer-input language changes, stable scene/actor position, shutter+Escape, restored HUD/movement and capture failure/Back.
- `host_photo_capture_close_20261108.gd`: 6 checks, zero failures, including repeated engine window-close notifications during real exposure and exactly one saved PNG.
- Existing photo format (29/29), export-close (7/7) and export-failure (8/8) regressions pass. The format fixture now drains the existing audio lifecycle before teardown, removing its resource-leak false failure. Final package evidence is recorded separately against its exact PCK hash.
- `audio_current_host_20261108.gd`: 27 checks, zero failures. Repeated settings entry preserves the original guitar playback, separate volumes and master mute restore correctly, cat cues debounce, muted cues do not create voices, exterior one-shots retire indoors and water buses do not multiply. Production audio remains unchanged.
- 38 supplied street/actor/fountain source assets match the prior SHA-256 ledger. The separately authorized cover replacement is excluded from that old-cover comparison.

Repeated actual Road construction in three samples per family averaged: community 131.96 → 42.93 ms, residential 124.38 → 38.11 ms, postal 91.88 → 64.03 ms, coastal 72.79 → 29.80 ms. These are separate offscreen process measurements, not player FPS or a general performance promise. Postal now also performs its previously missing water repair.

All engine checks use isolated QA data, offscreen GPU rendering and engine-injected input. They do not establish native mouse feel, listening acceptance or a full player playthrough. No OS input was used.

Local evidence root: `D:/Codex-build-cache/dear-somewhere-refinement-20261108/` (fountain, interaction, cache receipts and before/after entry timings).
