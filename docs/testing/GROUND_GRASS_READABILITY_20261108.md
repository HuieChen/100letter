# Ground grass readability — 2026-11-08

The user still could not perceive ground-grass motion. At normal 1280x720 scale, several small postal blades had only 0.24–0.75 px median edge excursion across eight seconds. Passing changed-pixel checks had not established perceptibility.

Increase only the grass contribution before the existing bounded foliage displacement, and distribute bending farther down the free blade while preserving fixed roots and rigid clearance. Foreground blades keep the same 1.6–1.7 source-pixel maximum sweep and source/background maps; their bounded wind response is quicker and less concentrated at the very tip. No original art, texture, audio, mask or settings animation is changed.

Source render comparison covers 30 independently selected blade crops across 10 views/four streets, with 21 rigid/root guards unchanged. Examples (median edge excursion at real screen scale over eight seconds): postal fence 0.239 → 1.354 px; tiny postal pot blade 0.472 → 1.332 px; community small blade 1.127 → 2.300 px; residential lamp blades 1.891 → 4.469 px; coastal lamp 3.015 → 6.002 px. Not every blade increases: the isolated community 4805 blade retains its constrained overlap response, measured 1.376 px. Small occluded blades remain conservative to avoid repainting their background.

The actual Host live-clock test advances naturally in all four streets and verifies shader clock/grass connections (12 checks). Captured crops were reviewed for continuity; engine rendering and numerical measurements are not a claim of human acceptance. Exported-PCK checks and final publication receipts accompany the release.

Evidence: D:/Codex-build-cache/dear-somewhere-motion-pass2-20261108/grass-visible/.

## Integrated Windows package

Integrated on `ecc53c6`; runtime commit `ca605caae08e69abb61913c53abab6957620ac15`. Standard `tools/build.ps1` export completion and raw-asset audit produced PCK SHA-256 `06964b45e65064bf72e67dae586c449b5a90968138701f69452d15c2c1dc6e4d`. Process-local TEMP/TMP were on D:; no global environment changes. Historical broad checks were skipped in favor of these actual-package checks.

Actual PCK, isolated userdata, offscreen GPU: live Host clock 12/12; street object boundaries 198/198; pot/foreground grass 140/140. Visibility capture covers 30 targets in 10 views across four streets, with all 21 rigid/root guards unchanged. All 680 PNGs match the reviewed source render byte for byte. No script/shader errors or shutdown leaks occurred. Source four-phase grass coverage additionally passed 366 checks; this is separate source evidence, not added to the PCK count.

Package evidence: `D:/Codex-build-cache/dear-somewhere-grass-release-20261108/checks/receipt.json`, `source-frame-comparison.json`; inventory: `test-results/package-20261108-191332/export-audit.json`. User visual acceptance remains pending. The unfinished cover/settings exit work is not included.

### Concurrent map update preserved in final package

GitHub main advanced to `13d8e5f` during publication. Its caption-only map correction is merged unchanged in runtime `a1ba97f12c14d137e1a294835b86db0b2a048a7b`. The final standard build supersedes the temporary grass-only package above: PCK `92d891b2a626471bf2eb480017029fbb633c26fff567d9a5dacaf808175877e1` (266480768 bytes). All four grass checks/captures were rerun, plus map feedback 104/104: 454 assertions, 30 grass targets, 21 unchanged guards. The 680 grass PNGs match the previous validated capture. The caption-only map screenshot was inspected; no rejected spotlight is restored.

Final evidence: `D:/Codex-build-cache/dear-somewhere-grass-map-20261108/checks`; export audit `test-results/package-20261108-191946/export-audit.json`. Local network API requests returned HTTP 504; the GitHub connector exposed the newer main and prevented publishing without its map correction. No force update or unrelated worktree edits were used.
