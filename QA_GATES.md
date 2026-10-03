# QA gates

The uploaded snapshot is not accepted. Compilation, unit counts and a running process are insufficient evidence of usability.

The CCGS/Codex adaptation in docs/STUDIO_WORKFLOW.md is now part of this workflow. tools/studio.py verifies its pinned source and captures current engine evidence; its gate must reject missing native review, stale source, absent/changed evidence, unknown checks and unresolved blockers. Adapter/CI success is not whole-game acceptance. Current checks use local Godot suites, not inactive upstream Claude hooks.

For each complete state chain check normal path, visible exit without Esc, Esc, invalid actions, rapid input, re-entry, save/reload, focus loss, Chinese/English and responsive sizes 1920×1080 / 1280×720 / 2560×1440. Confirm no text clipping/overlap, no missing asset, no misleading affordance, no leaked private content and no user art modification.

Automated engine input tests supplement actual-window manual testing. Capture full actual viewport screenshots and recording where feasible, otherwise a precise state walkthrough. Do not describe scripted input as human testing. Save QA_REPORT.md with failures and remaining scope limitations.

At most three focused correction passes; unresolved affected work becomes BLOCKED. Latest direct instruction removes approval waits: send phase evidence, allow five minutes for feedback, then continue safe complete-chain work. Silence is not acceptance; incoming feedback overrides the direction. Tool-blocked WeChat reports are saved locally and do not stop engineering.
