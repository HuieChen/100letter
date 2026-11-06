# Open-source candidates for the existing exploration demo

Checked against upstream documentation on 2026-11-06. Recommendations below are integration judgments for this repository, not claims that the plugins have been installed or validated here.

| Project | License / documented engine support | Practical use here | Decision |
| --- | --- | --- | --- |
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | MIT; upstream README lists Godot 4.4+ | Damped follow, camera priorities and smooth transitions between framed subjects | Strong candidate for later camera work. Current scenery uses a custom Control-based view, so adding the plugin alone would not improve it; first adapt a single scene to Camera2D and check original composition/hit areas. |
| [Dialogue Manager 4](https://github.com/nathanhoad/godot_dialogue_manager) | MIT; Godot 4.6+ | Branching conversation authoring, conditions and translation workflow | Good when resident dialogue expands. Keep the current authored paper/portrait renderer and save-state authority; prototype one existing conversation before a migration. Does not authorize reopening unfinished narrative. |
| [GUT](https://github.com/bitwes/Gut) | MIT; Godot 4 versions available | Repeatable persistence and interaction boundary tests | Already installed here at pinned 9.7.1. Integrity was checked this round. Extend current coverage rather than introducing another test framework. |

For the immediate UI polish, Godot's own [focus navigation](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html) and Tween controls fit the existing framework. This round fixes covered-control focus and photograph error handling directly. No new runtime dependency is required for those improvements.

Recommended order: finish error/focus/save consistency → prototype one camera transition with original art → migrate a resident conversation if authoring complexity warrants it. Preserve upstream license notices for any future imported code. These candidates do not require replacement artwork or generated water/light effects.
