# Studio workflow adoption QA — 2026-10-03

Scope: project-local Codex adaptation of Donchitos/Claude-Code-Game-Studios. This report does not accept the game or mark the three-letter session playable.

## Provenance and integration

- Official repository/API matched the user-provided title, 49 roles and 25k+ stars. API returned 25,663 stars; fixed revision `b21fa0f7f289fc3e726cf36fb12b9bc1e7a51e4d`.
- Retained MIT license and 289-file snapshot; SHA-256 inventory verified. Actual snapshot contains 49 role definitions and 74 skills. Nothing is downloaded or executed during `verify`.
- Existing game, scene, art and saves are preserved. The snapshot is not a game plugin; `.gdignore` excludes it from Godot import. Claude hooks/settings remain inactive.
- `tools/studio.py brief` maps complete state chains to relevant role responsibilities. Current mode is solo sequential; no agents are counted as running because definitions exist.
- `tools/check.ps1` invokes snapshot verification and evidence-gate regression. GitHub Actions checks this adaptation; it does not provide native game acceptance.

## Executed checks

| Check | Result | Boundary |
|---|---|---|
| Pinned snapshot, role/skill inventory and mapped local suite | PASS | File integrity and workflow mapping |
| 12 Python regression tests | PASS | Reject stale inputs, missing or changed evidence, zero tests, failed/wrong suite, missing native review, failed/unknown checks, wrong dimensions, truncated PNG, path escape and upstream tampering |
| Existing local book suite through adapter | 139 checks / 0 failures | Scripted GPU viewport input with isolated userdata and Dummy audio; 7 real viewport captures retained locally |
| Clean main checkout before book correction | 137 checks / 4 failures | Scaled book could not select `helena_rota` or `IncludeSource`; genuine failures retained in the run log |
| Clean publication checkout after book correction | 139 checks / 0 failures | The unchanged scaled-input assertions now pass; current book remains pending native review |
| Gate on that automated evidence without native review | NOT_COMPLETE, expected exit code 2 | Refuses to close task despite engine PASS; does not infer player approval |

The 139-check result belongs to the locally modified book source, not a statement that every published game mode is complete. The publication also carries the previously prepared book source/test correction after the clean main checkout exposed four scaled-input failures; the runtime art and campaign are unchanged. The book chain remains in review. Captures/logs are local under `test-results/studio/book/`; the report records their limitation rather than treating their existence as native testing.

## Remaining game acceptance work

Actual-window input review, focus loss, Chinese/English layout, full target-resolution checks and listening remain pending for the book chain. Bag manipulation, map transition, NPC affordance and movement corrections remain in the existing queue. The three-letter authoring data is a simulation, not implemented gameplay or measured novice duration.

The gate can validate provenance and completeness of recorded evidence. It cannot establish whether a person actually performed a claimed review, judge aesthetics or predict player satisfaction; actual observation and candid reporting remain necessary.

Published-candidate book source SHA-256: `5bcf0e21a99061a0586201b723b08c14e8d81f4c15e2904c469404718b596b33`. The gate was run on this candidate and returned the expected exit code **2** with `NOT_COMPLETE`.
