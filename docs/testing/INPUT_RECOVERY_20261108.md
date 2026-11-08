# Input recovery and shortcut isolation

Baseline b0fa079 reproduced 22.63 pixels of unintended travel after holding Right in Pause and closing with Escape. Ctrl+M/C/E also opened the map/camera/door. This change blocks each already-held movement key until its release when manual movement or window focus resumes. New directions, release/repress in one frame, Shift acceleration and click travel remain available. Ctrl/Alt/Meta combinations no longer trigger host, camera or door shortcuts; ordinary shortcuts and Shift combinations remain available.

Validation uses isolated userdata, hidden GPU windows, synthetic engine input and simulated focus notifications. It does not establish native Alt-Tab, listening or player acceptance. Source assets are unchanged and the walker regression verifies their hashes.

The actual PCK passed shortcut modifiers (106), walker resume (67), pointer-only focus (15), opened-feature comfort (58), and routes (113): 359 checks, zero failures. Source shortcut and walker tests also passed. The legacy final_walker_smoke suite still reports seven animation-related failures (pose count, five anchor comparisons and 144 Hz arrival idle). The same seven failures were reproduced against unchanged b0fa079. They are retained as an existing acceptance gap, not counted as passing checks. Its manual-input case now releases/represses D to verify a new intentional press interrupts click travel; the new resume suite separately requires held keys to stay blocked.

The initial package build was rejected by its exact-content hash check when C: ran out of space. Only this chat's generated package audits and old release backup files were copied to D:, SHA-256 verified, then removed from their original cache paths. Migration manifests are under D:/Codex-build-cache/input-polish-20261108/. No player saves, source art or unrelated project files were removed. The replacement package was rebuilt and independently tested. Build used -SkipChecks because the listed checks ran separately on the actual PCK.

Full gameplay, old animation assertions and human acceptance remain open. This is a focused input correction for the opened exploration demo.
