# Dialogue Manager integration

Official upstream [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager), version 4.2.0, revision `94fe560072ed9972fcb7b331d7f727f8b72c3da1`, MIT, documented for Godot 4.6+. Unmodified addon source and license are in `addons/dialogue_manager`; file hashes are recorded in `tools/dialogue_manager.lock.json`. The runtime autoload is registered in `project.godot`.

The opened food-truck encounter now traverses a real `DialogueResource` with upstream `get_next_dialogue_line`, using its `next_id` and END state. The existing paper, portraits, language preference, reveal/skip behavior, transition cues and Host save owner remain in place. This is not an example-balloon replacement or an installed-but-unused plugin.

Current dialogue copy is intentionally masked. Both graphs retain six alternating Chef/You turns and the existing `……` placeholders. Removed historical prose and unfinished mail story are not restored. The integration supplies sequencing and authoring structure; it is not a claim that full written conversations are finished.

Editable sources: `data/dialogue/chef_zh.dialogue`, `chef_en.dialogue`. Run `Godot --headless --path <project> --script res://tools/bake_authored_dialogue.gd` after author-approved graph edits. This generates the preloaded `.tres` resources. Runtime requires only these compiled resources and their addon dependencies, so it does not depend on raw text files or editor import state. No save-schema changes or campaign mutations are added.

Validation with Godot 4.7.2:

- `tests/managed_chef_dialogue.gd`: 75 checks / 0 failures; 26 actual upstream `got_dialogue` events, bilingual turns, ordered progression, rapid input, reveal-before-advance, END and early exit.
- `tests/managed_chef_host.gd`: 41 checks / 0 failures; actual resident signal → Host → manager → custom paper surface, return/re-entry, walking restored, campaign data unchanged. Requires isolated `--final-save=user://qa/.../state.json`.
- Shared editor scan for both new addons completed with exit 0 and no script/parse errors.

The first fixture used a fixed 0.4-second wait before pressing through the initial art load and produced eight failures. The final fixture waits for the real enter/line lock to settle, bounded at three seconds, and preserves that failed log. It does not change production timing to satisfy the test. Existing raw-image export warnings remain outside this integration; actual PCK regression must be checked separately by the release owner. Automated results are not native listening or final aesthetic approval.
