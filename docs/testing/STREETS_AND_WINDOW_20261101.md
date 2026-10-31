# Supplied streets, roof occlusion and soft footsteps — 2026-11-01

## Scope and observed defect

The latest 42×58 user crop was located in the supplied community night original at approximately source (2132,301), by multi-scale comparison (correlation 0.9955), then checked visually against the noon variant. The lit first window had been painted above the foreground inquiry-office roof. This was present in the source artwork, not a moving-camera seam.

The runtime repair recovers the roof silhouette from the supplied noon variant, samples nearby night roof pigment, and affects only a 25×25 source-pixel region. Originals are unchanged; daytime art remains unchanged. The GPU comparison checks both a formerly warm overlap pixel and zero changed pixels outside the repair bounds. See `streets_20261101/window_before.png` and `window_after.png`.

## Imports and navigation

- Eight originals copied byte-for-byte: community/grocery/market/food-truck street, and residential/lookout/bus-stop street, each morning/noon/sunset/night. Dimensions 9204×640 and 7431×640; provenance records SHA-256 and supplied names.
- All seven new map destinations route to the relevant street at x=100, its left end. Existing postal and tarot streets remain selected for their existing destinations. No extra map text labels.
- New streets do not reuse old positional breeze/fountain masks: those would deform different buildings or paste an old fountain in the wrong place. Bespoke ambient motion for the two new panoramas is not implemented in this import pass.
- Export filters explicitly contain the original PNG/JPG files, provenance, road script and roof shader. Actual exported PCK loads all eight exact-hash originals, all six soft step WAVs, and both scripts.

## Footsteps

The current coastal walker emitted contacts but the active playable host had never connected them to audio. The connection is now complete and modal-gated. Use existing Kenney Impact Sounds 1.0 recordings, CC0 (commercial use permitted), with a 100 Hz high-pass, 2800 Hz low-pass and 6 ms onset fade. Three pavement variants and three wood variants, no immediate same-variant repeat, -20 dB playback, subtle 0.98–1.02 pitch variation. Actual distance-driven contacts trigger them; idle does not. Every outdoor authored lane is paved, so residential/chess locations no longer imply grass.

The clips are decoded and routed through `SolmereFoley`; SFX zero mutes and restoring the slider unmutes. Existing supplied guitar and ocean routing are unchanged. License and hashes: `assets/audio/foley/soft_steps_provenance.json`, `KENNEY_CC0.txt`. Source: https://kenney.nl/assets/impact-sounds . Human listening/comfort acceptance is not claimed.

## Sequential review and evidence

- Design/UX: retain source art and canonical save-location keys; no invented interiors or fake new actions. Map click closes map and enters one street.
- Implementation: district-specific source selection, bounded source-derived roof occlusion, contact-to-audio connection, raw-file export coverage.
- Art: inspected all eight 1920×1080 GPU screenshots and enlarged before/after roof crops. The first repair attempt sampled too far left and picked up the gable; rejected and changed to an interior roof sample with a warm-window mask.
- QA: current GPU `street_import_20261101.gd`: **93 checks, 0 failures**; current GPU courier regression **66 checks, 0 failures**; existing street suite passes postal proximity, camera, braking and Shift. Error logs empty for these final GPU runs.
- Package: actual PCK check passes 14 assets, exact source hashes, decoded samples and loadable road/roof resources.
- Native Windows: latest Dear Somewhere window inspected. Actual mouse clicks on return arrow, grocery and bus-stop map destinations successfully switch streets and close the map. D was tapped once, but this does not establish sustained native A/D/Shift cadence or listening acceptance.
- First audio fixture failed because it compressed several seconds of walking into one engine frame while prior map one-shots still occupied the voice pool. Replaced with a real-time test and audio retirement interval; failure retained in `test-results/streets-import.log`.
- Earlier headless existing-street run reported the existing courier sampler compiler warning despite printing PASS. Final checks used actual NVIDIA OpenGL rendering instead; do not count the headless output as visual proof.
- CORE-BOOK and broad game acceptance remain open. No campaign or full-game completion claim; no published Windows release refreshed in this pass. Review PCK is local in ignored test-results.

Logs: `streets-import-final.log`, `streets-motion.log`, `streets-existing.log`, `packed-streets.log` alongside the evidence images. Live preview uses isolated `user://qa/streets_20261101/live.json`; original saves were not edited.
