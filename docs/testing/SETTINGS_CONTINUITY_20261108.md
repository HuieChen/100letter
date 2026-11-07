# Settings navigation continuity — 2026-11-08

The opened settings page had two reproducible keyboard breaks: Down/Left from its close button could move behind an expanded dropdown, and returning to Pause selected Resume instead of the Settings opener. The initial GPU/input reproduction failed 3 of 5 assertions. The same reproduction passed 5/5 after correction.

Expanded selectors now suspend background controls' focus modes, restoring their original modes when dismissed. Arrow/Tab navigation stays in the selector or its visible close button. Returning to Pause restores its Settings action after the new sheet's initial focus, including a language change. A deferred settings rebuild is ignored once its close animation has started.

Current-source validation: `tests/settings_focus_continuity_20261108.gd` passed 144/0 using actual GUI key events in Chinese 720p and English 1080p. It covers all four selectors, four arrow directions, Tab/Shift+Tab, nested Escape, unchanged covered values, restored slider control, saved keyboard volume, and same-turn language change plus repeated close. GPU screenshots of the expanded selector and restored pause focus were inspected. Existing save-failure input 91/0, experience flow 58/0 and preferences 23/0 also passed.

The independent Windows pack `6efa6f37ebcecb1917b74b4269f2b926f86bf21d3606d422daa9150f6465f577` passed the same 144 assertions from an empty host with no source fallback. No unexpected engine/script/shader or shutdown-leak diagnostics occurred. Its runtime source is commit `cae9ead`. The package is a validation candidate; the coordinated combined build may contain later cover/camera/motion commits and is recorded separately by its owner.

The first expanded regression fixture addressed a dropdown child by its default Panel name instead of its actual SettingsOptionsPanel name, so it timed out. This test harness error was retained and corrected to the stable option name, then rerun; it was not counted as a passing run. Player saves were isolated throughout. No native OS interaction, listening approval, full-story completion or long-session player acceptance is claimed.
