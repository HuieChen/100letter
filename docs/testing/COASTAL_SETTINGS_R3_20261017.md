# Settings R3 — original layers and continuous water, 2026-10-17

This is a focused Settings revision, preserving the courier, notebook dialogue,
accepted environments, original case progression and saves. It supersedes R1
bright additive rings and R2 static-lemon/subtle-only refraction, without claiming
that the whole game or new long three-letter session is complete.

## Original artwork

The supplied 设置界面.pdf is unchanged: 39 pages, each containing a white-matted
1920×1080 JPEG, no alpha/OCG layers. Eleven exact embedded images are grouped into
water, stationary paper/postcards and physical lemon parts. Runtime matte shader
supplies exterior transparency; no AI repaint/blending. Blank white text/knob
pages cannot reconstruct the original Procreate glyphs. Real text/controls replace
them. The complete small three-part lemon is also scaled for the clipped large
slice so movement cannot reveal a missing top edge. Provenance and the verification
import tool record this explicitly; original PDF remains private and untouched.

## Real behavior

- Continuous 96×54 height/velocity surface field, fixed60Hz, spatial propagation
  and damping. MIT Evan Wallace step/drop equations adapted to Godot; original
  source, pinned commit/hash and license retained. Original painted texture is
  displaced by its local surface gradient; no additive bright circles/glow.
- Click: expanding pulse. Slow skim: small directional wake. Fast swipe: stronger
  leading pressure/trailing depression. Held drag: stronger disturbance. Actual
  pointer speed drives response. Paper silhouettes/control interactions are excluded.
- Native isolated GodotPhysics2D, two real RigidBody2D slices with different mass,
  inertia, damped movement/rotation, contacts and bounds. Near water wave arrives
  before pushing; near swipe transfers directional momentum. Distant water does
  not push fruit; rapid-input speed/queue limits prevent launching objects. No
  constant forced wobble or teleport-back animation; not a general fluid/CFD claim.
- All eight Settings functions remain connected to actual behavior, independently
  saved and restored. Solid opaque knob cores in normal/hover/disabled state.
  Matching back arrow and Esc; nested dropdown first dismisses with Esc.
- Chinese uses its own centered bold title, 600-weight labels, measured right
  column and safe bottom selector gap; English uses DynaPuff body/Lilita One title.
  Font originals and OFL licenses are pinned and byte-verified, including the
  existing Noto Sans SC against its actual upstream font. UI language selection
  does not pretend the authored campaign/documents were translated.
- Licensed CC0 original short water recordings, strength/position variation and
  dedicated SFX bus; quieter skims and secondary fruit contact. CC0 complete
  Vaporware track by The Cynic Project crossfades in through the real Music bus;
  closing Settings restores the original game's motif. No OS volume changes.

## Found and repaired in this round

1. White-matte shader multiplied color twice: original PDF colors were darkened;
   corrected single composite, original JPEG bytes remain unchanged.
2. Binary sensitivity value .84 did not exactly equal JSON-restored .84; normalize
   to the slider's .01 precision before saving, without weakening restore checks.
3. Variable Chinese font rendered thin at default100; use the actual integer weight
   axis, verify 600/700 and inspect rendered output. Bottom speed label overlapped
   its selector; separate measured Chinese column/gap and regress it.
4. Tests assumed collider node names / PackedFloat32Array API methods; fixtures
   corrected to actual geometry/type and Array conversion, failures retained.
5. Historical register_coastal_ui.py could overwrite current authored PDF roles;
   guarded so superseded AI-layer import fails instead of undoing this revision.

## Evidence

Current frozen check counts, source fingerprints and exact retained artifacts:
[evidence.json](coastal-settings_20261017-r3/evidence.json).
Normal, exit, wrong action, repeat, rapid input, isolated save/reload, actual buses,
zh/en and 1280×720 /1920×1080 /2560×1440 are covered by source input/render checks.
Native OS input and official PCK/EXE checks are reported separately, never inferred
from these tests. Prior R1/R2 evidence is retained under its dated folder.

[Native1080 video](coastal-settings_20261017-r3/settings-demo-1920.mp4): actual
MovieWriter rendering/mixer, 1920×1080 at24fps, 410frames /17.08seconds, CRF15 H264,
non-silent recorded PCM (peak.426, RMS.0119). The displayed pointer is a test
annotation; this is automated footage, not a recording of human mouse input.
At0.5s near-small-slice click;3.6s slow skim;6.1s fast swipe;7.5s held drag;
9.3s Music slider;11.5s language menu;13.3s heavier-slice click;16.5s back arrow.

Surface step CPU p95 about2.4ms in the focused run on this RTX4050 laptop;
machine-specific budget check is retained, not a guarantee for all hardware.
Human listening, first-time novice comprehension, complete native matrix and the
new three long letters/actual wax sequence remain separate acceptance work.

## Frozen R3 result

25 engine suites /8,037 checks /zero assertion failures; independent window
close/reload29; workflow28, bitmap3, courier-video3, licensed media5. Exact
source run check-20261017-012230 and window-close-20261017-012922 retained.
Actual PCK406 checks /zero failures, official Windows EXE GPU boot120 frames.
PCK SHA256 8e5ed175012ab670ecd9d96edd949fa9e832718999fe40a0c00b49440077a229.
Content-inspector exit still reports18 ObjectDB /4 resources in use; actual release
boot stderr is empty. Inspector cleanup root cause remains unassigned; this is
not silently marked fixed or attributed to the release process.

Current R3 OS input separately confirms title→Settings, near-lemon water click,
later physical displacement, held water drag with stationery stable, Master drag,
zh→en, F11 fullscreen/windowed with synchronized selector, visible return arrow,
reentry, Esc and actual process restart restoring settings. Fourteen unedited
target-window captures retained; the foreign floating-toolbar capture was excluded
and preserved privately. The immediate close assertion raced asynchronous window
closure; fresh enumeration proves original HWND gone and one new HWND. Native
record lists exact remaining coverage, including the other sliders/passive-speed
paths automated rather than inventing current native approval.

## Publication

Source `987de19bc4caec714262d04f5869e70b253241c2` pushed to main; both exact-source CI runs completed successfully. [Windows R3 prerelease](https://github.com/HuieChen/100letter/releases/tag/solmere-coastal-water-r3-2026-10-17). ZIP93681989 bytes, SHA256 `94d9d208545c7594d1a7101036fa006822d8b2eacff3db1a75db0c42ff46de84`, GitHub digest identical. Actual ZIP CRC and embedded EXE/PCK fingerprints checked. [Receipt](coastal-settings_20261017-r3/publication.json). This publication is a focused UI review and does not mark full-game acceptance complete; later documentation-only commits preserve the packaged runtime.
