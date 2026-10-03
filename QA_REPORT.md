# QA report · 2026-10-03

## Transparent letter intake — 2026-10-04

All five PDF pages and the separately supplied envelope are exported as RGBA PNGs in `assets/authoring/letter01_20261004`. User correction requires interior white paper pinholes to be transparent too; version 1 failed this intent and is excluded. Version 2 uses the built-in background-extraction tool, copied unchanged. Read-only pixel inspection verifies alpha minimum zero, interior fully transparent pixels (envelope 6; pages 74/62/32/45/49 in the recorded paper inset) and zero opaque near-white pixels in that inset. Full source/render/output pages were visually compared; handwriting and signature are readable, but pixel-exact equivalence is not claimed. Original PDF/JPG are untouched. These authoring exports do not yet replace live letter objects or expand the playable story.

## Latest tab and onboarding repair — 2026-10-04

Physical chapter slips now use one upright ImageGen paper sprite behind the unchanged original book. Equal geometry, horizontal writing, no underline/dashboard frame; the whole painted slip is clickable. Empty chapters remain absent. The original book bitmap and all scenery/characters are unchanged.

Opening object response is repaired: after releasing the latch, either click or drag the actual lid. A 0.32-second hinge transition ignores duplicate clicks; the locked lid resists. Click or drag the exposed envelope to lift the same object into inspection. The visible cross returns it to the existing counter and saves observed face/custody; it cannot leave a duplicate envelope in the box. The supervisor gives a short first goal, including the actual community notice location. No narrator tutorial or task arrow is introduced. Dialogue layout now measures wrapped glyphs instead of assuming a character count determines height.

Fresh full run `test-results/check-20261004-002452` passes all 17 engine suites, including both five-case routes and amended handoff. `counter_onboarding_input` passes 54 assertions across three resolutions, using visible objects and crosses; book passes 1,628 assertions in Chinese/English at three resolutions; shared core UI passes 196. Window close/reload passes 29 checks in `test-results/window-close-20261004-002958`. 28 workflow gate tests also pass. These are automated engine/input checks, not human usability approval.

Failures retained: the first new onboarding fixture incorrectly injected unscaled input; it was corrected to the existing viewport-input adapter. The next test found a real short-dialogue scrollbar/height problem at all three sizes; measuring actual glyph layout fixed it. Passing final logs and 1920 images are retained under `docs/testing/tabs-guide_20261004`. The precise native window and audio/novice acceptance remain separate. Earlier complete results below are historical.

Remaining acceptance gaps: no first-time human playtest or audio listening; complete three-letter 30-minute story/wax workflow still pending. Guidance for the entire campaign is not certified by the first-counter fix. CORE-BOOK remains under review, not silently marked complete. Publication is a development checkpoint.

Native checkpoint: actual Windows input verified the title/new-game entry, supervisor visible cross, book opening, the full paper tab edge, book cross, bag opening and direct envelope entry into the physical inspection surface. The retained game-only frame is `docs/testing/tabs-guide_20261004/native_book_letters.png` (855×512). User input interrupted the box/letter and later flip actions; those steps are not claimed as independently completed native tests. Automated coverage remains distinct. Current player progress is preserved; native audio/novice/full-chain checks remain pending.

## Latest studio production integration

CCGS now has project-local production stories, responsibility boundaries, design inputs, active-board/dependency checks, materialized handoff briefs, adversarial role records, change-impact routing and finish/handoff commands. This is sequential responsibility review, not independent multi-agent or 49-agent execution. See [actual use report](docs/testing/STUDIO_PRODUCTION_20261003.md).

28 workflow/evidence rejection tests pass. The first new test run had a Windows GBK/UTF-8 read failure; explicit UTF-8 fixed it. Role QA found the book input fixture depended on an ignored local background; it now uses the selected public BG_workroom bitmap with a resource-path assertion. The current selected-art book run `test-results/studio/book/20261003T135546061667Z` passes 1,484 checks, retains 25 GPU captures and unchanged runtime/test inputs during the run. Three resolutions and component language headings are covered, not full-game English or actual player input.

A prior run `20261003T134329678948Z` returned zero without a fresh final report and was correctly rejected. Its partial engine log is retained in docs/testing/studio_20261003/incomplete-engine.log. The subsequent exact GUI-editor run completed, but the interruption's root cause is not proved. The producer board keeps this observation open. Required native, listening and novice criteria still lack evidence; real finish/handoff must remain NOT_COMPLETE. No runtime script, art or original save changed. Older full-core/Windows results below belong to 5402b72 and are historical, not a new full regression for this tooling phase.

Scope: historical-requirement review, plain-title cover, archive, direct bag/letter manipulation, immediate map transitions, dialogue exits, movement loading and regression against the existing five-case campaign. This is a development checkpoint, not final game/Steam-quality acceptance.

## Latest core review — 2026-10-03 evening

No new ImageGen artwork was created. The accepted scene/character/material bitmaps and original player saves are preserved. The cover uses a plain cream ground and the game name. Bag envelopes directly enter the same physical workbench, with no Inspect_/Carry_ action buttons. Map destination selection puts away the map and begins one transition; busy guards prevent bag/book/pause interference. Dialogue and topic pages have a visible cross. Crosses over changing backgrounds have their own light ground. Routine narrator/control strips are removed; the supervisor explains the first real task in dialogue. Current postal writing wraps within the envelope's actual safe area; nine existing walking poses are preloaded and focus loss cancels stale walk callbacks.

Frozen-source run **test-results/check-20261003-210543** completed all 16 engine suites with **7,297 assertions and zero failures**. Its separate exact-PID window-close/reload probe **test-results/window-close-20261003-211039** passed another **29 assertions**, both exits zero. Combined: **7,326 engine/probe assertions**. These counts are not independent players, measured quality scores or acceptance votes.

| Suite | Checks |
|---|---:|
| mail_physics_state_smoke | 728 |
| final_case_state_smoke | 3348 |
| final_walker_smoke | 33 |
| scene_dialogue_input_smoke | 19 |
| postal_desk_live_queue | 28 |
| envelope_text_bounds_smoke | 21 |
| field_observation_smoke | 218 |
| field_book_smoke | 1483 |
| mail_workbench_input_smoke | 170 |
| resolution_slip_smoke | 75 |
| final_host_boundary_smoke | 32 |
| final_resolution_draft_smoke | 42 |
| core_review_input | 196 |
| five_case_sealed | 344 |
| five_case_delegate | 346 |
| amended_handoff | 214 |
| Exact-owned-window close / fresh-process reload | 14 / 15 |

The new hosted review checks visible cross and Esc, actual bag envelope flip/drag/wheel/reentry, single-trip charging and rapid HUD clicks during travel, repeated NPC conversation and return to control, at 1280×720, 1920×1080 and 2560×1440. Book component headings are checked in Chinese and English. The full hosted routes use actual engine-routed pointer/keyboard events; full-route source hashes remain unchanged. Component tests have isolated fixtures, not invented player runs. Workflow inventory verification and 12 evidence-rejection tests also pass; that adapter result is separate from gameplay.

### Retained failures and fixes

- **check-20261003-204049:** a 2560-size synthetic chapter click missed; the test then accessed a null editor. The test now supplies correct mouse masks/motion and stops on missing controls instead of hanging. Final 1,483 book checks pass.
- **check-20261003-204506:** three title assertions used the default save slot; one dialogue cross release did not close. Isolated fixture slots now redraw before assertions, and cross activation is on press with duplicate-close protection. Final hosted checks pass at all three sizes.
- **check-20261003-204846:** one current-resident source did not open, then the harness cascaded into invalid targets/null access. Added bounded scene/walker/core diagnostics and stopped the continuation before dereferencing a wrong modal. A focused sealed route and two subsequent full runs did not reproduce the source miss. Its root cause is **not proved**; keep it as an intermittent observation requiring native investigation.
- **five-diagnosis-20261003.log:** a diagnostic command accidentally used the headless dummy renderer while requesting PNGs. That invocation was stopped and is not passing GPU evidence; the rerun used the actual OpenGL renderer.
- Screenshot review found a dark-on-dark bag cross and a capture taken during the envelope lift. Crosses now have light backing; reviewed envelope captures wait for the real lift to finish. The final frozen-source run includes these changes.
- Code review found that HUD bag/book/pause could interrupt the pre-fade part of an already committed journey. Added guards and rapid real pointer checks. One destination still costs one journey and arrival restores control.

### Matching package and native limits

Current local package: `outputs/100letter-Windows-Core-Review-20261003` outside this source checkout. Built with the SHA-verified official 4.7.2 template after the final run; SkipChecks avoided repeating the completed run, and is not a new validation result. Actual PCK inspection and release executable GPU boot passed in **test-results/verify-package-20261003-211229**. The PCK inspector checks the new plain cover, not just that a title loads. Selected export inventory excludes private originals, old entries, reference pictures, tests and development files.

EXE SHA256: `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`. PCK SHA256: `d96b2cbdd6874725109d101bec3b0bada2093f44a0b64a614c75374b675b337e`. Exported GDScript is compiled; raw source files are not falsely compared to compiled bytecode.

For native review, an identical EXE/PCK copy with a QA-only configuration was verified to use a separate `Solmere-Native-Core-Review-20261003` user-data folder. Computer Use returned its unique real game window, but activation failed and a refreshed capture showed the Windows lock screen. **No native mouse action or audio listening was performed.** Native checks stop at lock-screen protection; the owned QA child was closed, and original saves remain untouched. Automated OS WM_CLOSE does not replace this missing real playthrough.

Final game acceptance remains **NOT_COMPLETE**. Pending: the intermittent source-opening observation, full native and novice usability, audio listening, all-scene door/prop response review, full-game English switching, new meaningful 30-minute/three-letter session, approximately 1,000-character letters, distributed semantic edits, actual wax-making sequence and all reference-footage analysis. See the 42-row requirement review; no old-campaign pass closes these requirements. The older public Release is not this current package.

Screenshots/state explanation: [core phase report](docs/testing/CORE_REVIEW_20261003.md). Sanitized current suite/source/package evidence is stored in `docs/testing/CORE_QA_20261003.json`. Main publication and exact remote SHA/CI are verified separately from local tests.

## Earlier book phase — historical evidence

## Implemented and inspected

Writing is bound to separate clipped paper leaves. Page headings, section tabs and body text have bounded readable areas; useful chapter tabs share dimensions/baseline and align with their painted paper. Existing hand-drawn portraits are presented as busts without changing image files. A person occupies one spread with observed conversation/source information. The visible ×, Esc, page-corner navigation, animation and sound cues remain functional. Original saves, core rules and adopted scene artwork are unchanged.

The phase screenshots and state explanation are in docs/testing/BOOK_REVIEW_20261003.md. Inspected: person portrait and notes; English source heading/tab fit; provisional claims and source references. Inspection covers those actual rendered screenshots, not every frame or all original reference videos.

## Automated checks

Fresh book evidence: test-results/studio/book/20261003T105639997532Z/evidence.json. Source inputs remained unchanged during capture. The book suite passed 1,477 repeated layout/input assertions at 1280×720, 1920×1080 and 2560×1440 with Chinese/English component headings, and retained 25 GPU screenshots. It checks paper containment, wrapped label height, readable buttons, shared tab bounds, known/unknown identities, page corners, rapid input, ×/Esc, reentry and recorded draft reload. Longer source quotes remain verbatim. These are synthetic Godot GUI events, not OS input.

The frozen-source run test-results/check-20261003-184633 passed these 14 engine suites (7,050 assertions, zero failures):

| Suite | Checks |
|---|---:|
| mail_physics_state_smoke | 728 |
| final_case_state_smoke | 3348 |
| final_walker_smoke | 31 |
| scene_dialogue_input_smoke | 18 |
| postal_desk_live_queue | 28 |
| field_observation_smoke | 218 |
| field_book_smoke | 1477 |
| mail_workbench_input_smoke | 170 |
| resolution_slip_smoke | 75 |
| final_host_boundary_smoke | 31 |
| final_resolution_draft_smoke | 42 |
| five_case_sealed | 336 |
| five_case_delegate | 338 |
| amended_handoff | 210 |

That check.ps1 invocation then returned failure at the window probe's strict PID ownership guard. After correcting its console-launcher selection, the separate window probe test-results/window-close-20261003-185616/report.json passed 14 input assertions + 15 fresh-process reload assertions with both process exits zero. No assertion or guard was bypassed. Combined completed engine/probe assertions: 7,079. The closed window was an isolated automated child; this is not a human clicking the game ×.

Upstream workflow inventory and 12 evidence rejection regressions pass. That validates the adapter, not the game. Private original-asset archival checks are separate and were not part of this public gameplay run.

## Failures found and correction history

1. An untyped name expression failed Godot parsing. Added its explicit String type and reran.
2. Page selection could wait without a bound in the test. Added a bounded navigation check; failed evidence is retained.
3. Keeping anchor offsets when normalizing controls doubled their positions. Corrected anchor application and checked every writing control against its own paper leaf.
4. Screenshot inspection showed an English tab label too close to the irregular paper edge. Reduced English tab type size and checked actual painted tab bounds.
5. An earlier complete route failed its source-immutability check because edits were made during that run. Reran with runtime/test inputs frozen; no stale run is used as final evidence.
6. The amended-route test stalled while awaiting frame_post_draw for an offscreen static viewport. Replaced the shared route screenshot wait with a main-thread draw of the actual viewport; subsequent regression results are recorded below. No cached image or invented pass was substituted. See [Godot RenderingServer.force_draw](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw).
7. The window-close probe was given the official console launcher, whose engine child had a different PID. It refused the event. It now resolves the matching GUI executable before launching, while retaining the exact process/HWND ownership check; the rerun used child=engine=28780 and passed reload verification.

## Pending/manual boundaries

- The native gameplay attempt was blocked by a Windows battery warning (PickerHost.exe); successful OS input was not established. A later isolated launch did not expose an independently targetable game window. Automated fixture windows were not treated as native manual evidence.
- Native focus loss, mouse-only novice use and audio listening remain unverified. Dummy audio proves no listening quality.
- The book accepts localized component headings for QA; whole-game language switching and translated authored content are not implemented by this fix.
- The integrity gate must remain NOT_COMPLETE without actual native checks; no player approval is inferred from silence.
- Bag direct interaction, map confirmation removal, movement polish, richer NPC guidance and the new three-letter session remain separate work. See docs/REQUIREMENTS_REVIEW_20261003.md for the 42 requirement checks and gaps.
- Existing GitHub Windows Release is the older morning build; it must not be described as the corrected archive build.

## Matching local review package

Built with the SHA-verified official Godot 4.7.2 Windows template after the checks above; build.ps1 used SkipChecks to avoid repeating the already completed checks. That flag is not a new pass. Local output: outputs/100letter-Windows-Book-Review-20261003 outside the publication worktree. The selected-resource ZIP has no forbidden original/private assets. Godot exports compiled GDScript, so raw source bytes cannot be compared directly to that compiled file. A separate headless probe loaded the actual PCK, verified the new paper bounds/tab size and mounted the book with its localized component API: PASS. This does not prove native execution or usability.

Package exe SHA256: d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562. PCK SHA256: f5ecb84dd9df895bb62316d6b2ef8ea3ed8a7b52b428be6a7b4cb83c3202b500. Sanitized checks/capture/package hashes: docs/testing/BOOK_QA_20261003.json.

Source publication to HuieChen/100letter main is authorized. Exact remote commit and CI evidence are verified separately from local checks; screenshots alone never establish publication.
