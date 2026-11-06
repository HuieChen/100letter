# Photo review resilience and preview memory

Scope: the opened exploration demo, specifically camera → print → note → return. Original artwork, captures, save formats, scenery and unopened narrative remain unchanged. This is a scoped correction, not whole-game acceptance.

## Reproduced defects and changes

- Loading a damaged PNG previously changed `_review_index` before decode succeeded. The old print remained on screen, and editing its note could overwrite the damaged photo's sidecar. Photo identity now changes only after successful decode; an inline localized error preserves the current print and note target.
- Tab could focus the shutter/thumbnail underneath the photo review. The nested surface now excludes these covered controls from keyboard focus, restoring shutter focus on return.
- Opening an unreadable photo directly from the bag left no review surface or explanation. The album now shows an error and usable navigation/exit, and restores the note editor when a valid photo opens.
- Camera thumbnails now use a maximum 256-pixel texture dimension instead of uploading the full capture. Original PNG bytes and full-size review textures are retained. This bounds preview texture allocation; it is not an FPS claim.

## Evidence and limits

`tests/photo_review_resilience.gd` initially reproduced 13 failures in 44 checks. After correction it passed; the expanded final suite covers 64 checks including both languages, damaged input, wrong-target note protection, repeated Tab, rapid shutter input, same-frame note save, original-byte preservation, and 1280/1920/2560 renders. A synthetic blue photo is intentional test content, not replacement game art. Corrupt-file decoder errors in this suite are expected fixture output; assertion failures must be zero.

Additional current-source suites: `experience_comfort_20261106.gd` 58/0 and `experience_routes_20261106.gd` 113/0. Export inventory unit tests: 3/0. Pinned GUT 9.7.1 integrity: 259 upstream files and four font notices verified.

The existing `verify_package.ps1` / `packaged_content_smoke.gd` suite returned 424 checks / 5 failures. Its assertions still cover the old generated-art roles, plain cover, former water pressure and old close behavior. This failure is retained, not relabeled as a pass or suppressed. Current-feature tests are separately executed against the actual PCK with an external test script and no project-path fallback. Do not interpret them as validation of the retired mail flow.

Final independent PCK results: photo resilience 64/0, exploration comfort 58/0, routes 113/0. The matching release executable also completed a 120-frame GPU boot with exit 0. The package inventory contains 678 entries with 163 raw files verified. The build used `-SkipChecks` because scoped tests were run separately; the historical full check pipeline is not claimed as passed.

Sequential responsibility review (one agent, no independent reviewers): UX/implementation reviewed identity-preserving failures and modal exits; QA reproduced failure before the patch and exercised the above cases; art review inspected Chinese 1280 and English 2560 screenshots for clipping and stable paper layout, without changing source art; audio triggers were preserved, but fresh listening acceptance was not performed. Native window observation covered map/pause/camera layout; full OS-input photography was interrupted by window focus changes and is not counted as completed. The historical CORE-BOOK gate remains open.

Run the regression with the project open in Godot 4.7.2 (GPU required):

```text
Godot --path <project> --script res://tests/photo_review_resilience.gd
```

The suite writes only under `user://qa/photo_review_resilience/`, using a unique run directory. Screenshots and a JSON receipt are retained there. Local package audit, raw logs and before/after failures are kept in the task workspace; they are not player content.
