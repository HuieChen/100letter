# Authored title menu — 2026-11-08

Reproduces the user's `全部.png` composition using their exact `纯封面.png` and transparent `字.png` originals. Each 7262 × 4085 source remains unchanged; the logo and three paper strips are runtime atlas regions. Asset hashes are recorded in `assets/authoring/title_20261108/provenance.json`.

The paper buttons retain the existing Start, Continue and Settings actions. Visuals lift slightly on mouse/keyboard selection and compress on press, with stable hit rectangles and a short release interval before activation. Rapid activation is coalesced. No-save Continue is dimmed and excluded from keyboard navigation. Starting again still requires the existing overwrite confirmation. The supplied painted lettering remains English; semantic labels and tooltips follow the selected language.

The title retains the licensed ocean ambience and existing activation paper sound. Hover/focus uses the existing paper samples at -30 dB with a shared 180 ms cooldown. Music, SFX and ambience remain on their existing buses. The user's later November 8 request explicitly adds the supplied guitar to the title: the same loop continues at a gentler title gain and follows the Music slider, without restarting or stacking players. No audio samples were generated or replaced.

## Current evidence

- Final runtime package built with selected assets and exact raw PNG includes: 1115 entries, 172 raw files, every packed SHA verified by reopening the PCK.
- Actual final-PCK GPU/input/audio test from an asset-free host: `TITLE_PAPER_CHECKS 28 / 0`. Exercises mouse press/release, hover, Start, Continue, save preservation, both UI locales, Settings return, Down/Enter navigation, ambience muting/restoration and actual nonzero mixed audio samples (peak 0.00468126).
- `python -m unittest discover -s tests -p test_runtime_export.py -q`: 3 passed.
- Native Windows release window inspected: full reference composition visible, paper Settings clicked successfully, top-right × returned to cover. No personal save was created, replaced or loaded during native inspection.
- Local evidence: `D:/Codex-build-cache/dear-somewhere-title-20261108/qa2/` and `native-title.png`.

The first diagnostic checked the press tween before the render frame completed. The corrected check waits for `frame_post_draw`; it observes compression after the real mouse-down event. No production change was needed for this fixture timing issue.

Automated audio output and volume routing were verified; this does not claim human listening acceptance or a full gameplay playthrough. Separate street/settings work remains owned by its respective chats.
