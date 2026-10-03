# QA report · 2026-10-03

Scope: archive/book layout correction, source requirement reconciliation, and regression against the existing five-case campaign. This is a development checkpoint, not final game/Steam-quality acceptance.

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
