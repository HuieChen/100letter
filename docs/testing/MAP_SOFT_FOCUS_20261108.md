# Map destination feedback — 2026-11-08

The runtime selection chevron is replaced with a feathered light over the existing destination artwork and a quiet bilingual location caption below the map. Hover and keyboard changes fade over 0.16 seconds; pressing lowers the light over 0.08 seconds. There is no idle pulse, image distortion or route-line overlay. The 13 existing targets, actual travel routes, latest-input selection, cancellation and focus behavior are preserved.

The original map remains byte-identical: `scroll_map_v2.png`, SHA-256 `3ace307814071c4bb8990a6eb52b28f70cfcbaa9806f9b20a167dd53cc67d815`. Painted arrows already in that supplied illustration are untouched; the removed arrow is the runtime selection marker.

## Reference and design decision

Primary pages checked on 2026-11-08: [Carto](https://store.steampowered.com/app/1172450/Carto/) describes a hand-drawn map-led adventure, [TOEM](https://store.steampowered.com/app/1307580/TOEM_A_Photo_Adventure/) describes relaxed hand-drawn photographic exploration, and [A Short Hike](https://ashorthike.com/) emphasizes exploration at the player's pace. The restrained local light and caption are our design inference for this supplied map, not a claim that those games use this exact UI. No third-party artwork was imported.

## Frozen integration and validation

Runtime commit `ad34bd9` is based on main `dbc6fdb`, preserving the newer supplied title, paper menu, camera, street, input-recovery and bag-navigation work. The export-selection conflict was resolved by regenerating the resource list from the combined source. The final R2 package was built from `628c869`; later documentation changes do not alter its runtime.

Final R2 Windows PCK SHA-256: `49ee8ed87df30c37b0b7e12cf0345b3e064c63a2a407081cbef9e251d60c8982`. The build audit verifies 1,116 mounted entries and 172 raw files. Build used `-SkipChecks` because checks ran separately on this actual frozen PCK, mounted from empty hosts with isolated userdata. Earlier 3cdf51a3 candidate evidence is retained separately; it predates the bag-navigation integration.

| Actual-PCK check | Passed |
| --- | ---: |
| Soft focus, all destinations, original pixels, zh/en at 1280/1920/2560 | 104 |
| Mouse/keyboard selection and actual destination routes | 44 |
| Landscape feedback | 72 |
| Opened exploration routes | 113 |
| Held movement recovery | 67 |
| Modified-shortcut isolation | 106 |
| Pointer and window-focus behavior | 15 |
| Map-held direction close and travel integration probe | 23 |
| Current Host audio teardown | 27 |
| Bag tab focus and remembered photo position | 30 |
| Photo pocket streaming and damaged-image recovery | 70 |
| Total | 671 |

The photo-streaming suite's only decoder errors identify its deliberately corrupt `user://qa/photo-pocket/.../photos/DearSomewhere_9999.png` fixture. There were no unexpected script, shader or teardown errors in the completed suites.

For both map-close and actual map travel, the integration probe measured 0 px of carried-key movement; releasing and pressing again moved approximately 32.64 px. Map actions use real Host input. Movement sampling uses deterministic 120 Hz stepping and simulated focus, as in the existing walker suite. Earlier probe type-declaration, offscreen-window and delayed-focus fixture failures remain in separate logs and are not included as passes.

The final package's 7-second, 60-fps preview was recorded again through Godot MovieWriter and visually inspected. It shows real hover, press and release-outside cancellation; it is silent, normal-speed deterministic capture, not a native performance measurement. MP4 SHA-256: `dd280675bfca39341f376d1f6ace17e6919f3050b0f001b7030be06b60efc47b`.

The official release executable booted for 120 GPU frames and exited 0. Its forced `--quit-after` exit reports 20 ObjectDB instances and 3 resources still in use. The previous main package `f20273e75f0bd5d4f19b3055cb77e0ba83c24057a8edb01bb3c90a9ee63c125f` reproduces the same diagnostic. Explicit Host/audio teardown passes without errors or leaks; forced-exit cleanup is not claimed fixed. The seven historical walker-animation assertions recorded in INPUT_RECOVERY_20261108.md were not rerun or declared fixed here.

Final evidence is retained under the task workspace: `package-qa-map-soft-focus-final-r2`, `package-qa-map-final-r2-regression`, and `package-qa-map-held-input-r2-20261108-154107`. The prior forced-exit comparison remains in `map-shutdown-comparison-20261108`. The final build audit is `test-results/package-20261108-153648/export-audit.json`.

The first R2 movie attempt ran out of C-drive space and was rejected; a Python report read also initially used the wrong Windows text encoding. Both logs are retained. Only this task's generated AVI and large build-cache entries were copied to D-drive archives, individually SHA-256/length verified, then removed from their C-drive cache locations. Audit JSON and logs remain at their original paths. Migration manifests are `D:/CodexArchives/DearSomewhere-map-recordings-20261108/migration-manifest.json` and `D:/CodexArchives/DearSomewhere-map-build-cache-20261108/migration-manifest.json`. The final R2 movie was recorded again successfully with raw output on D; deliverable MP4/PNG are in the final R2 output folder.

No OS input or player-save modification was used. Native/manual play, listening, full-story completion and human aesthetic acceptance remain separate; this is a scoped map-feedback update to the opened exploration demo.
