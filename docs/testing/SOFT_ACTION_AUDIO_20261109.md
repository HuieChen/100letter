# Softer door and camera feedback — 2026-11-09

The user rejected the sharp synthetic shutter and door sound. Replace the procedural shutter with one excerpt from phatcorns' Canon T3i recording (CC0): https://freesound.org/people/phatcorns/sounds/250105/. Keep all original door recordings untouched and select separate processed derivatives.

Camera (revised after the user found the first preview too muffled): 390 ms, 4.8 kHz low-pass, preserved natural attack without compression, 2 ms opening/60 ms closing fades, peak 0.55, playback -10 dB. Opening/closing doors: 1.8 kHz low-pass, soft transient shaping and fades, peak 0.4, playback -18/-19 dB. These are timbre changes as well as lower gain. All use the existing effects bus and mute/volume behavior; no guitar, ambience or visual changes. Immediate accepted-shutter timing is retained.

License, exact source URLs/hashes and processing are recorded in assets/audio/foley/soft_actions_provenance.json. Preview WAVs use the default 0.85 effects slider and actual playback gains. Automated waveform/routing checks establish signal presence and controls, not listening approval; the user has been given previews.

## Final crisp package integration

Base main `a33c34451cae4c95645e53395a8bbf67fc0ca6fa`; runtime `5e66f8eda47a44adfbe3dc017a549f019b60e3a6`. Both source commits 9353190 and e6efe94 are included. The older 2.4 kHz shutter candidate is superseded and was not published. Export conflict resolution retained current main's selection/include rules, removed the deleted procedural helper, and added the three exact WAV files and provenance JSON. Standard build refresh selected 385 resources. Three derived WAV hashes and both unchanged door-source hashes were verified; Freesound's original page independently confirmed the Canon recording and CC0 license.

Final PCK SHA-256 `2d66f188d3fb96f2375585536a46123ee2ffe280e9d0ebdfd519a11ec4bb092c` (266626860 bytes). Actual PCK, isolated per-suite userdata and D-drive photo outputs: camera/door feedback 23/23, orderly close during camera exposure 6/6, focused title music continuity 7/7. Total 36 checks, zero failures; no script errors or shutdown leak diagnostics in these completed suites. Shutter waveform peak 0.549957; native guitar bus peak 0.061964. Guitar source SHA and the same playback across title/world/title were verified. No human listening approval is implied.

The optional full `title_paper_20261108` suite on the superseded soft candidate stopped producing screenshots after its language/title rebuild and timed out after 180 seconds. Its owned process was terminated by the runner; log and partial captures are retained under `D:/Codex-build-cache/dear-somewhere-soft-audio-20261109/checks`. This unresolved full-UI check is not counted as passing or declared a new production regression. Final-package guitar verification uses the separate focused mixer/transition test; no production title code changed.

Final evidence: `D:/Codex-build-cache/dear-somewhere-crisp-audio-20261109/checks/receipt.json`; audit `test-results/package-20261109-132911/export-audit.json`. Builds, isolated saves/photos and package backups stay on D:. Recheck running processes before any Latest replacement and preserve any active game.
