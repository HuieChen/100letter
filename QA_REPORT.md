# QA report · 2026-10-03

2026-10-23 BLENDER_ENVELOPE_MODEL: Blender 5.1.1 builds an editable `.blend` and textured `.glb` from the exact user-supplied 1280×1280 envelope image. The front print and raised seal use the packed original texture; paper core, cut edge, rear folds and raised wax are separate editable geometry. Fresh Blender reopen confirms the source image is packed; fresh GLB import confirms 11 mesh objects and the embedded 1280×1280 texture. Three Cycles previews were visually checked (front, three-quarter and back). This is a standalone prop asset; it is not represented as integrated into the game runtime.

2026-10-20 POST_OFFICE_START_SCENE: the user-supplied split 3840×1080 image is the formal scene after Start. Two rooms are wired into the existing start/door/desk/book/mail flow; source JPEG hash is preserved. GPU input: room component34/0, new-start route199/0, retained core-route regressions1194/0; 1,427 routed checks total/0 failures. Studio28 and source artwork3 also pass. The earlier room-exit assertion mismatch and isolated import/temp-directory failures are retained as history and not described as runtime regressions. Current native novice usability, listening, complete story and visual acceptance remain open. Full scope: docs/testing/POST_OFFICE_OPENING_20261020.md.

2026-10-19 PUBLICATION_CHECKPOINT: runtime source321c351 is verified on main; fresh background browser confirms main CI39149304808 and tag CI39150528207 success (art source78ada94 CI39148799224 also success). Current ZIP88,043,468bytes/SHA256b1777b807f670c460352171c72bd7e2610cf1e07ddc5d56c2b75636607dbe7d4 is locally CRC/PCK verified, with full original ChillRoundF license beside the executable and inside PCK. Windows release asset upload remains NOT_UPLOADED after TLS/zero-byte transport failure; public prerelease currently has source archives only. Do not claim Windows download publication. Exact receipt: docs/testing/pelican-font_20261019/publication.json. All prior native/novice/listening/story/teardown acceptance limits remain open.

2026-10-19 PELICAN_FONT_SCOPED_REVIEW: 16 original ImageGen outputs registered across54 generated roles, 18 original authored Settings/courier roles unchanged. Chinese Settings uses original ChillRoundF/OFL1.1 with full bundled notice and measured raster weights. Current complete source command40suites/13,938checks/0failures; supplemental engine-close/reload29; Python28/3/9/5. Actual current PCK424/0 and official headless120-frame boot/exit0. Failed localized-font-name and retired-package-style assertions retained separately. No packaged GPU/native window was opened under background-only instruction. Forced --quit-after teardown still reports18ObjectDB/fourresources; no clean-shutdown or full-game acceptance claim. Prior water measurement nondeterminism, native/novice/listening and new long-letter story remain open. See docs/testing/PELICAN_FONT_20261019.md and frozen77-artifact manifest. CORE-BOOK remains review.

2026-10-18 CORE_LOOP_REVIEW: complete public sheets replace fake covers/hidden row clicks; presentation, privacy, source availability and save boundaries verified. Recipient dialogue connects actual delivery to counter resolution. Settings real mixer/reveal/manipulation effects and confirmation localization checked. Selected final sequential batches: 40 runtime suites / 13,776 checks / zero failures, supplemental engine-close/reload29, Python28/3/9/5. Earlier failures retained, including unresolved periodic-water image-measurement nondeterminism. New Chinese font and Pelican Post global art are subsequent in-progress changes, not covered by this frozen checkpoint. Native/novice/listening/new three-letter story remain unassessed/incomplete. Detailed results and limitations: docs/testing/CORE_LOOP_FULLFLOW_20261018.md; exact artifacts: docs/testing/core-loop_20261018/evidence.json. CORE-BOOK remains review.

2026-10-17 R7_SCOPED_REVIEW: latest supplied five-pose courier selected unchanged, actual8fps/.625s with source-pose2 idle/shared anchor and distance-driven acceleration/retarget/braking. Current signed height-field water crest/trough feedback .24/.08 retains authored PDF and hard3px/.055caps. Complete same-production-source QA matrix38suites/12,321checks/0failures; engine close/reload29; Python28/3/9/5; actualPCK423/0 and official120GPUframes/exit0. Full-attempt fixture failures remain recorded, not relabeled. Current package actual mouse confirms New/supervisor cross/door/right-left movement/settling; later map input interrupted, no further OS input. Forced --quit-after retains18ObjectDB/4resources unresolved. Current courier/water operation clips fully decoded with nonzero mixers; not nativeFPS/listening approval. New transparent supplied suitcase original crop/holes retained AUTHORING ONLY; missing interior/lid/fastener rig is not faked with old art. Sourcebd04a23 and QA-only follow-up170baeb verified on main; actual170baeb CI success. Matching R7 ZIP93,809,777bytes/SHA2564ec4d8155e34d5d526fe39b132fd75d0c8ff18ca9417e67317361a1ed6ac3330 verified uploaded at https://github.com/HuieChen/100letter/releases/tag/dear-somewhere-courier-r7-2026-10-17. Receipt docs/testing/courier-replacement_20261017-r7/publication.json; broad game/art/audio/novice/story acceptance remains open and CORE-BOOK remains review. Details: docs/testing/COURIER_REPLACEMENT_R7_20261017.md.


2026-10-17 SETTINGS_R5_REVIEW_CHECKPOINT: Dear Somewhere plain-name cover; source-preserving blue/tape/fruit edge repair, real draggable opaque knobs, bilingual layout and rounded menus, visible arrow/Esc, dirty-preference failure exits, own-audio retirement and moving original fruit shadows/arcs. Actual final source check-20261017-180716:36 suites/11375 checks/0failures; engine-generated close/fresh reload29/0 with empty stderr; Python28/3/3/5. Fresh actual PCK427/0 and official release120-frame boot0; all4packaged shaders match tested source SHA and packaged no_focus=false. Content inspector stderr is empty; forced release --quit-after still reports18ObjectDB/4audio resources, so this route is not described as clean. Matching R5 native mouse/key input confirms Master drag, zh/en, F11 fullscreen label, first-click menu, nested Esc, exposed-water/fruit interaction and arrow-to-title. Further F11 return was interrupted by external user input; OS close/restart remain pending. Before/after same-gesture1322-frame60fps MovieWriter clips have6press observations each/0failures and verified full decode/nonzero mix, not measured real-timeFPS or listening. Latest human feedback "点击后应该有波纹" leaves click-wave readability active for rework despite168mechanical checks passing. Source/package/publication is a development checkpoint, not final game acceptance. Exact227artifacts, failure history and scopes: [R5 review](docs/testing/COASTAL_SETTINGS_R5_20261017.md). Source5d0367e verified on main; matching R5 ZIP93,699,086bytes and SHA256fd02994afa49e46dd508dcd9e0be935838b7a2917961b722221784d32055443a confirmed by GitHub, both exact-source CI runs success. Receipt docs/testing/coastal-settings_20261017-r5/publication.json. Latest visible-click-ripple feedback remains active; R3/R4 below remain historical.

2026-10-17 SETTINGS_R3_SOURCE_PACKAGE_NATIVE_REVIEW: unchanged authored PDF layers; continuous speed-dependent water field; native floating fruit; independently localized Chinese layout; opaque knobs, matching arrow/Esc, licensed music/foley. Frozen25 suites8037 checks, window29, Python28/3/3/5; actualPCK406 and official release120 frames. Current OS input confirms water/fruit/drag, Master, zh/en, F11 labels, return/Esc/reentry/restart. Correction from retained raw logs: content-inspector stderr is empty; the forced official-release --quit-after boot reports18 ObjectDB/4 audio resources at shutdown. This historical warning was previously attributed to the wrong probe and remained unresolved in R3. Human listening, novice/full native matrix and new long three-letter/wax session remain incomplete. Published source987de19 to main; both exact-source CI runs passed. Matching Windows R3 release uploaded with size93681989 and verified ZIP/GitHub SHA25694d9d208545c7594d1a7101036fa006822d8b2eacff3db1a75db0c42ff46de84. Receipt docs/testing/coastal-settings_20261017-r3/publication.json. Later documentation-only commit does not change packaged runtime. Details: docs/testing/COASTAL_SETTINGS_R3_20261017.md. Earlier rounds below are historical.


## Coastal Settings and integrated water correction — 2026-10-17

Final source `check-20261016-235932`: **23 suites / 7,951 assertions / zero failures**, including both full five-case routes and amended handoff. Window close/reload29, workflow28, generated bitmap3, courier extraction3, font/water integrity3 also pass. Settings219 includes real slider/bus/persistence/dropdown/typewriter behavior plus rendered water movement and unchanged paper/menu/lemon pixels at three sizes. Notebook dialogue54, real offscreen display28, preference model22 and physical manipulation6 remain distinct suites.

User rejected the R1 additive bright rings as visually pasted on. Current shader only refracts authored paint, with small irregular spreading displacement and decay; stationery/text and solid lemon slices remain stable. Only exposed water invokes quiet CC0 samples, and sliders use dry feedback. R1 native testing found stale F11 mode text despite actual window change; model-to-view synchronization fixes it and has independent regression coverage. Historical R1 native images/notes, earlier test failures and old water demo are retained, not relabelled as current success.

All eight Settings functions act on real runtime behavior and independent atomic preferences. Chinese/English labels fit actual measured columns; English is explicitly UI-only, preserving original story/document text. DynaPuff and ZCOOL KuaiLe commercial-use-compatible OFL1.1 notices and CC0 water provenance ship with the package. Current 1080 images and 720p/24fps actual engine MovieWriter demonstration are in [phase report](docs/testing/COASTAL_SETTINGS_20261016.md); automatic input recording is not native mouse footage. Matching R2 actual PCK298 and official release120 frames pass, SHA256 `ddb9d517e5d642a6d7cf51e4747e9f96ce944352dc607c5dd00cee6a580737f0`. Both exits retain18 ObjectDB/4 resource cleanup diagnostics; root cause unassigned. Actual R2 restart/title/Settings opening confirmed saved UI language and tracks. Other input interrupted water testing, so R2 native water/F11/Esc are pending, despite source regression checks. Preview remains open; subsequent observed changes are not attributed to our input. Two actual captures and this boundary are retained in native-r2/native.json. Listening, novice, complete native matrix and the new long three-letter/wax story remain pending; CORE-BOOK stays review.

## Supplied courier animation — 2026-10-16

Frozen isolated source: 18 suites / 7,622 assertions / zero failures. Separate close/reload 29, workflow 28, bitmap 3, video extraction 3 and GPU scene/pose probe 48 pass. Matching package: decoded PCK 162 / official release boot 120 frames pass. Both package exits retain 18 ObjectDB / 4 resource cleanup diagnostics. Native matching-package title observed; New interrupted by user-input detection, so native walking remains pending. Ordered notebook dialogue and interactive water Settings are next.

Original video right-hand colored courier now replaces idle/walk, with six actual poses, shared feet/scale, preserved internal light areas and explicit non-AI provenance. Initial plume clipping was found and fixed by widening the common crop, not weakening the border test. Focus/interruption failure in the first full delegate route is retained; isolated full rerun and normal whole-game rendering passed. Native source check only reached title/New/supervisor; subsequent user-input/minimized-window interruptions prevent claiming native walking completion. See [phase report](docs/testing/COURIER_VIDEO_20261016.md) and retained raw evidence. New dialogue/settings references remain ordered next work. Original video, other art, campaign and saves are preserved.

## Current published pastel package and native review — 2026-10-04

Game source `3f7b452d8807acccb533015cf9e5fa59dd03f557` is on main; both source-commit CI runs succeeded. The [matching Windows prerelease](https://github.com/HuieChen/100letter/releases/tag/solmere-pastel-2026-10-04) has a GitHub-verified 74,014,707-byte ZIP and SHA256 `664cd4d294a9b8f64e4b879c86d33934a614015fed1c89d198f48d8d398b4498`. Its actual PCK passes 170 content checks and the official release EXE passes 120 GPU boot frames. Final source-frozen regression is 18 suites / 7,615 assertions / zero failures, with separate window/reload 29, workflow 28 and PNG/atlas tests 3.

Actual mouse input in this same R2 package confirms case latch/hinge/extraction, the same envelope's edge flip/zoom/drag/cross return/reentry/Esc, book paper-corner turn/cross, whole painted map landmark arrival and NPC approach/dialogue topics/cross. Twenty-one final-package native captures and six package artifacts are retained in [native.json](docs/testing/pastel-global_20261004/native.json). Earlier package failures remain separately labelled; no passed result is substituted for the map roof miss before its fix.

Package inspector exit stderr records 18 leaked ObjectDB instances and 4 resources still in use, despite all 170 content assertions passing. Root cause remains unassigned; retain this observation rather than calling the entire log error-free. The separate official release GPU boot stderr is empty. This does not certify long-running memory behavior.

This closes the current global visual-update/publication phase, not highest final acceptance. Native coverage is one Chinese window flow, with separate automated bilingual/responsive frames. Listening, novice blind test, full native matrix and the requested new long three-letter/actual wax-material story remain incomplete; CORE-BOOK remains review. WeChat phase text was sent with a Codex label; image sending stopped after user-input detection and a new draft was preserved. Source screenshots and final-package raw captures remain available locally and on main.

Latest map follow-up: native roof click missed the old label-only target; complete landmark hit regions now preserve label placement. Final check-20261004-183533: 18 suites / 7615 checks / zero failures; independent roof input checks arrival at three resolutions. This supersedes the earlier 7,594-check source for packaging. See docs/testing/PASTEL_GLOBAL_20261004.md.

## Global pastel bitmap replacement — 2026-10-04

Latest direct instruction globally supersedes earlier art locking. All 63 selected runtime roles now use 17 inspected soft pastel/picture-book ImageGen outputs, with unchanged generated PNG bytes and registered transparent atlas regions. Retain the morning framework, campaign and saves; external originals remain immutable; cover remains plain game-name typography. Fix complete book-paper registration, upright tabs, same physical envelope/visible address on return, left paper-edge flipping, and box hinge/latch placement. Final frozen check-20261004-172827: 18 suites / 7,594 assertions / zero failures, mail input 86, book 1,626, window close/reload 29, workflow 28, actual bitmap/export tests 3. Retained failures and role findings: [phase report](docs/testing/PASTEL_GLOBAL_20261004.md). Package and native evidence are separate; novice/listening/full native matrix/new three-letter wax story remain unaccepted. CORE-BOOK remains review.

## Physical mail continuity repair — 2026-10-04

Latest feedback: the experience feels unreal and unresponsive. This phase only corrects the existing hand-carried box → extraction → inspection → return chain. It retains accepted scenery, letter assets, story and save schema. Inspection keeps the actual open counter behind the same envelope; zoom remains anchored to the pointer, and dragging can immediately take over an unfinished zoom. Pickup, flip, invalid drop and return have short physical transitions. Static counter redraws and repeated postal-text layout were removed.

Actual raw input exposed two close/save blockers: attached label rounding drift after fractional multi-frame drags, and approximate replay skipping a tiny real move in an old save. Both now preserve rigid attachment while retaining strict full material comparison; independently forged label changes still fail. Native mouse review also exposed a stale box-lid rendering and a duplicate envelope icon on reentry; both were fixed and checked explicitly.

Frozen-source final run `check-20261004-140043`: **18 suites / 7,585 assertions / zero failures**, including 77 direct rapid/fractional input checks and the existing complete case routes. Window close/reload: **29**, studio workflow tests: **28**. Four full 1920×1080 captures, source fingerprints, earlier failing runs and a state walkthrough are retained in [phase report](docs/testing/TACTILE_MAIL_20261004.md). Repeated drag coverage was expanded to 40 regrabs after the first rigid-position fix still failed. Offscreen QA windows no longer steal desktop focus; real game focus-loss behavior remains intact.

Matching package source/main `1fc42e6199e03e91d41cf3b4b91fad131e2d76f3`: actual PCK decoding **167** and official release GPU boot **120 frames** pass; PCK SHA256 `40a0b66dcf169330be34f624f64400c2dc9f4759ce8696837d684684a24a3144`. [Windows prerelease](https://github.com/HuieChen/100letter/releases/tag/solmere-tactile-mail-2026-10-04) upload is confirmed by GitHub size and SHA256 digest; both source-commit CI runs succeeded. The first source publication omitted ignored log files from Git; the immediate follow-up retained all exact evidence bytes and latest CI passed. No force push or collaborator history rewrite.

Matching native package reached title, actual mouse New game and visible supervisor. Clicking the visible supervisor cross returned `unknown screenshotId screenshot-0`; fresh window/state selection and one retry failed identically, so further native input stopped. `native.json` distinguishes this partial check from earlier source diagnostics, which discovered the lid/duplicate bugs before their final fixes. No matching final-package chain success, audio listening, novice acceptance, complete native bilingual/responsive matrix or new three-letter/wax story acceptance is implied. CORE-BOOK remains review; this is a development correction checkpoint.

## Actual paper-corner repair — 2026-10-04

Real mouse testing found that the drawn bottom page corner did not respond: the old hit region was inside page content. Both hit regions now align with painted corners, with no modern rectangular hover background. The regression fixture clicks independent artwork coordinates rather than control centers. Existing art, story and saves are unchanged.

Fresh full run `check-20261004-044026`: 17 engine suites / 7,494 assertions / zero failures; new book run: 1,626 assertions / 25 GPU images; window close/reload: 29; studio Python tests: 28. Formal PCK verification: 167 checks and release GPU boot of 120 frames, PCK SHA256 `cddb5f6c6f3f3cef310ad1379c431e1dc25ad17e5d9ece26b1e826123ce603ff`.

Actual isolated Windows-package restart/Continue retained observed envelope/return addresses. Mouse clicks on painted right and left corners successfully changed people pages 1/2 -> 2/2 -> 1/2. The visible cross and Esc both returned to the real scene; reentry retained records. 1285×751 logical native captures and separate full 1920×1080 GPU captures are retained in `docs/testing/corner-review_20261004`. See `docs/testing/CORNER_REVIEW_20261004.md`. The old native helper failures below are historical, preserved as failures rather than replaced by this result.

The first rebuild omitted the bundled Python path and failed its asset precheck; supplying the same verified Python runtime fixed packaging. An isolated EXE copy initially remained locked during process cleanup, so its copy failed; subsequent exact EXE/PCK byte hashes were verified before native testing. No user-owned process or production save was replaced. Listening, novice usability and the complete native matrix remain pending; CORE-BOOK stays in review and the new long three-letter/wax story remains incomplete. This is a development repair checkpoint, not final acceptance.

## Open-source QA adoption — 2026-10-04

License review distinguishes GUT's MIT code from its OFL 1.1 bundled fonts. Four official font notices are retained separately and checked by the pinned-dependency verifier. This documentation-only follow-up does not change gameplay, the 259 upstream files or the exported review package.

GUT 9.7.1 is pinned with its MIT license and 259 byte-verified upstream files, without enabling plugins/autoloads/update hooks. Fresh production model run: 8 tests, 580 assertions, zero failures/skips. Independent save locations test invalid-command atomicity, repeated custody, hidden information, UI copies, corrupt-save recovery, tool cancellation and remote NPC guards. See docs/OPEN_SOURCE_ADOPTION_20261004.md and docs/testing/GUT_20261004.md. Original 7,496 engine assertions remain a distinct earlier current-runtime run; GUT is not native/UI/audio/player acceptance.

The first integration report did not complete due to a timestamp/test-count assumption; retained and fixed. It also found a JPEG evidence capture wrongly named PNG: corrected extension with unchanged bytes and references. Final Godot import is error-free. Evidence directories are excluded from Godot import and exact-byte checkout is specified. No production save or visual framework migration.

Fresh native follow-up used the current Windows package and an isolated `user://qa/native-book-20261004-0243/progress.json` slot: real mouse input confirmed title, new game and supervisor cross. Further book input returned `Computer Use helper already has an active request`, then `unknown screenshotId screenshot-0`; another application's window occluded the target during recovery. Stopped this owned QA process only. No additional book/flip/listening success is inferred, and the user's existing game process/save was retained. Other work continued as instructed.

## Transparent letter intake — 2026-10-04

All five PDF pages and the separately supplied envelope are exported as RGBA PNGs in `assets/authoring/letter01_20261004`. User correction requires interior white paper pinholes to be transparent too; version 1 failed this intent and is excluded. Version 2 uses the built-in background-extraction tool, copied unchanged. Read-only pixel inspection verifies alpha minimum zero, interior fully transparent pixels (envelope 6; pages 74/62/32/45/49 in the recorded paper inset) and zero opaque near-white pixels in that inset. Full source/render/output pages were visually compared; handwriting and signature are readable, but pixel-exact equivalence is not claimed. Original PDF/JPG are untouched. These authoring exports do not yet replace live letter objects or expand the playable story.

## Latest tab and onboarding repair — 2026-10-04

Physical chapter slips now use one upright ImageGen paper sprite behind the unchanged original book. Equal geometry, horizontal writing, no underline/dashboard frame; the whole painted slip is clickable. Empty chapters remain absent. The original book bitmap and all scenery/characters are unchanged.

Opening object response is repaired: after releasing the latch, either click or drag the actual lid. A 0.32-second hinge transition ignores duplicate clicks; the locked lid resists. Click or drag the exposed envelope to lift the same object into inspection. The visible cross returns it to the existing counter and saves observed face/custody; it cannot leave a duplicate envelope in the box. The supervisor gives a short first goal, including the actual community notice location. No narrator tutorial or task arrow is introduced. Dialogue layout now measures wrapped glyphs instead of assuming a character count determines height.

Fresh full run `test-results/check-20261004-002452` passes all 17 engine suites, including both five-case routes and amended handoff. `counter_onboarding_input` passes 54 assertions across three resolutions, using visible objects and crosses; book passes 1,628 assertions in Chinese/English at three resolutions; shared core UI passes 196. Window close/reload passes 29 checks in `test-results/window-close-20261004-002958`. 28 workflow gate tests also pass. These are automated engine/input checks, not human usability approval.

Failures retained: the first new onboarding fixture incorrectly injected unscaled input; it was corrected to the existing viewport-input adapter. The next test found a real short-dialogue scrollbar/height problem at all three sizes; measuring actual glyph layout fixed it. Passing final logs and 1920 images are retained under `docs/testing/tabs-guide_20261004`. The precise native window and audio/novice acceptance remain separate. Earlier complete results below are historical.

Remaining acceptance gaps: no first-time human playtest or audio listening; complete three-letter 30-minute story/wax workflow still pending. Guidance for the entire campaign is not certified by the first-counter fix. CORE-BOOK remains under review, not silently marked complete. Publication is a development checkpoint.

Native checkpoint: actual Windows input verified the title/new-game entry, supervisor visible cross, book opening, the full paper tab edge, book cross, bag opening and direct envelope entry into the physical inspection surface. The retained game-only frame is `docs/testing/tabs-guide_20261004/native_book_letters.jpg` (856×511 capture). User input interrupted the box/letter and later flip actions; those steps are not claimed as independently completed native tests. Automated coverage remains distinct. Current player progress is preserved; native audio/novice/full-chain checks remain pending.

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

## 2026-10-30 authored street replacement
- Four clean street PNGs copied byte-for-byte; all four SHA-256 comparisons match supplied originals.
- Production road selects clean_road morning/noon/sunset/night PNGs. Postal street unchanged.
- GPU render inspected: painted-in duplicate actor removed, extracted courier remains at left.
- Generated manifest art is blocked; generic system sheets use a solid background, old save ending/failure cannot reopen old counter on resume.
- Headless boot: no parse errors. Forced short shutdown still reports 18 leaked objects / 4 resources; not resolved in this asset replacement.
- Native keyboard A/D and E manual regression remains pending; rendering is not input verification.
