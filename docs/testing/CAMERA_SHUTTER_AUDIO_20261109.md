# Camera shutter feedback — 2026-11-09

Camera feedback was mapped to `snap`, a quiet paper-slide recording at -18 dB, and emitted only after PNG writing. The camera now has a dedicated original procedural mechanical double-click, emitted once when a capture is accepted. The existing busy/closing/gallery guards prevent extra sounds; failed writes remain errors, not successful-photo notifications.

The short 180 ms non-looping waveform is generated and cached once, with a bounded peak, two damped transients and no downloaded samples. Playback uses the existing effects bus at -8 dB, follows effects volume and master mute, and leaves the guitar/ambience players and settings `snap` unchanged. Original art and recordings are not modified.

The actual Host regression checks immediate trigger before disk completion, duplicate prevention, native playback, waveform energy/peak, photo save, failure recovery, mute/restore and continuous music voice: 17 checks passed. Offscreen engine tests do not establish human listening acceptance. Final-PCK results accompany publication.
## Integrated package — 2026-11-09

Integrated on main `5348311e376936a73126274400f4ba35d93e3fb8`, preserving the supplied cover guitar, Settings session actions, current map and grass. Runtime commit: `6f412b093f9645dc02748e574d3607f87bcdd130`. Standard `tools/build.ps1` completed the raw-resource inventory; the export selection includes the new procedural audio helper. No source art, audio recordings or user saves were modified.

PCK SHA-256: `0ea1bef5aeb8bbf71ee1090172ab603f193a34dc9fb30ca21c070cca6d663df1` (266485588 bytes). Actual PCK with independent isolated userdata per suite, offscreen GPU and native audio: camera shutter 17/17; host close during exposure 6/6; title/guitar 34/34. Total 57 checks, zero failures, no script/shader errors or shutdown leaks. Shutter source waveform peak: 0.849945; measured title guitar bus peak: 0.065119. Human listening acceptance remains separate.

Evidence: `D:/Codex-build-cache/dear-somewhere-shutter-20261109/checks/receipt.json`; build inventory: `test-results/package-20261109-010206/export-audit.json`. The final package is retained separately. Only the idle wo-2 Latest is eligible for replacement; the running new-chat Latest must remain unchanged until normal exit.

