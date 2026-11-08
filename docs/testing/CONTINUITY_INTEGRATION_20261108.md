# Street continuity integration — 2026-11-08

Base: `182dee6e80917dd5d2504aa758c28ed2c4262c0f`; runtime: `3bcc01458283801e375719a9347d13651f6f8781`.
Preserves the published map, bag and input corrections. Integrates immutable street composite reuse and frame-independent camera damping from commits 4346964 and bcea188. Original scene art and save formats are unchanged.

Actual exported PCK SHA-256: `0bddb0e1701bfc2e6f33f44b1f46037dfd8cb518cbcdceab67bfa9445ec161a4` (266481408 bytes).
Built on D: with the recorded Godot 4.7.2 template and audited runtime inventory. Tests ran against this PCK without a source project path, with isolated userdata and offscreen GPU rendering.

| Suite | Checks | Failures |
| --- | ---: | ---: |
| phantom_camera_cadence_20261108 | 40 | 0 |
| phantom_street_camera | 132 | 0 |
| street_asset_reuse_20261108 | 69 | 0 |
| fountain_composite_20261108 | 504 | 0 |
| audio_transition_continuity_20261108 | 22 | 0 |
| bag_navigation_20261108 | 30 | 0 |
| walker_resume_input_20261108 | 67 | 0 |
| shortcut_modifiers_20261108 | 106 | 0 |
| map_soft_focus_20261108 | 104 | 0 |
| Total | 1074 | 0 |

Logs contain no script/shader errors or shutdown leak diagnostics. The community fountain screenshot was inspected. Evidence is retained under `D:/Codex-build-cache/dear-somewhere-integrated-20261108/candidate-checks` with the export audit in `test-results/package-20261108-161623`.

The independent cover/safe-exit work is not included: it remains uncommitted and under validation at publication preparation. Native OS-input, listening and whole-story acceptance were not repeated. Seven legacy final_walker_smoke failures reproduce on the earlier baseline; they remain unresolved, not counted as passes. CORE-BOOK remains in review.
