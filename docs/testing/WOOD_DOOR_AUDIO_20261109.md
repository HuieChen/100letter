# Wooden opening-door recording — 2026-11-09

The opening cue now uses a real wooden kitchen-door recording by Pfannkuchn, excerpt 1.04–2.06 seconds, at the existing -18 dB gain. The saved original Freesound page identifies an old wooden kitchen door and links CC0 1.0. Exact source, excerpt and processing are retained in `assets/audio/foley/soft_actions_provenance.json` and the shipped audio credits. Closing-door audio and the accepted crisp shutter remain byte-identical.

Base main `e1baf18e0f7f0c4a483d323c0da6a8e5f9b4b44e`; runtime `9d042ab2669ae15fc1d3e35b5f7cfa8958cf5a74`, integrating a763992. Standard `tools/build.ps1` produced complete PCK SHA-256 `c1ccabce50b4df15f8ee4fc53c7e736169f98028d7abc7d5184c2b29c55fb419` (266642156 bytes), with original include paths unchanged.

Actual PCK native-audio/GPU Host regression: 23 checks, zero failures, no script errors or shutdown leaks. A separate actual-PCK FileAccess SHA check verifies all three selected WAVs: wooden opening `5d3c7be232eab10e811ffaf028b1a0b15551216ad96e96d5b06f868318e2da5c`; accepted shutter `d73022dd805a1c457f6aba07c1da45afe401ff1b4b4cdf95bf735ffb34860350`; retained closing `d3327ab3775dd82924ae6d6669181f806d88fc8baf9e09d0d677862d303ca929`.

The first hash fixture additionally expected the unused original opening WAV as a raw runtime file. It is preserved in source, not required in this selected-resource package. That fixture log is retained; the corrected separation verifies the three actual runtime WAVs inside the PCK and the untouched original in source. No production asset change was made to silence that fixture.

Evidence: `D:/Codex-build-cache/dear-somewhere-wood-door-20261109/checks`; export audit `test-results/package-20261109-134041/export-audit.json`. All build/test/backup outputs are on D:. Only idle Latest directories may be synchronized. Unrelated full UI tests were not repeated; earlier title screenshot timeout remains open. Wood-door subjective approval and whole-game acceptance are not inferred from these checks.
