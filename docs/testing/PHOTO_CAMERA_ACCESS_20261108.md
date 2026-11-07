# Camera gallery access recovery — 2026-11-08

With healthy older captures and a damaged newest PNG, the camera hid its entire gallery entry. Opening the collection from the camera was impossible even though the bag still held healthy photos. A newly missing selected PNG similarly left the player outside review navigation. The new regression reproduced 14 failures before the fix.

The miniature now searches backward for the most recent readable print and remembers its index, so clicking it opens the image that was actually drawn. If every image is unavailable, a neutral paper entry still opens the error state with previous/next/back controls. A failed first selection also opens these controls when its file disappears after the miniature was rendered. Failed reads do not change the identity of an already visible healthy print; note saving remains tied to that identity. Empty collections still hide the entry.

No original photos or notes are repaired, deleted, or silently replaced. Existing landscape/instant formats, album export, caption checkpointing and the authored imagery are preserved. The scan normally reads only the newest image; a run of damaged images requires checking further entries and is not background-threaded.

## Validation

Godot 4.7.2 / Windows / isolated QA userdata. Each suite below passed against the actual exported PCK, with external test scripts and no source-project fallback:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| photo_camera_access_20261108 | 32 | 0 |
| photo_review_navigation_20261107 | 90 | 0 |
| photo_review_resilience | 64 | 0 |
| photo_album_export_20261107 | 54 | 0 |
| photo_formats_20261107 | 29 | 0 |
| Total | 269 | 0 |

The new suite covers Chinese/English, actual thumbnail-button activation, two consecutive damaged newest images, disappeared files, all-bad collections, note ownership, original image hashes, return focus, a fresh capture recovering the collection, and empty galleries. Existing suites cover keyboard navigation, failed note writes, export and both paper formats. Missing/corrupt fixture decoder messages are expected; no unexpected script errors, shader failures or shutdown leaks were observed. The format suite initially exited before running because its required QA-save argument was omitted; it passed when rerun with that isolation argument.

The release EXE booted and exited 0. Render captures were inspected for readable failure feedback and usable navigation/back controls. These are engine/GPU checks, not a new OS-input walkthrough, listening test or broad player acceptance. CORE-BOOK remains in review. Build used `-SkipChecks`; the listed suites were run separately on its actual package.

Independent read-only review confirmed both the disappearing entry and its hard-coded newest-photo click target. This change fixes both. Source art and audio were not modified.

Reproduce with isolated APPDATA/LOCALAPPDATA:

```powershell
& $Godot --main-pack $Pck --script "$Repo/tests/photo_camera_access_20261108.gd" -- --final-save=user://qa/camera_access/state.json --qa-out=user://qa/camera_access/captures
```
