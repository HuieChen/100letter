# Settings R4 — press, release and source edges

Historical unpublished candidate: user supplied new overlap/Chinese-layout,
flow-document and Dear Somewhere naming updates after these checks. R4 was
never pushed or released. R5 supersedes this pre-layout source; these counts
and artifacts remain historical evidence, not current-source acceptance.

Focused follow-up to the user's rounded-menu, varied-water, lemon white-fringe
and physical-press feedback. Original Settings JPEG/PDF bytes, campaign, courier,
dialogue, other artwork and player saves are preserved. Current results and exact
artifacts are recorded in [evidence.json](coastal-settings_20261017-r4/evidence.json).
This is a Settings review, with whole-game final acceptance still pending.

## Behavior

- Closed selector, popup panel, option hover/press and focus outline share rounded
  corners; bilingual 1280/1920/2560 renders and actual option inputs are checked.
- Consecutive taps vary bounded ellipse, orientation, radius and strength. Smooth
  spatial propagation varies by at most 3.5%; there is no energy injection while
  idle. Pointer speed and held dragging retain their distinct directional wakes.
- A lemon-only shader recovers original pigment from white-matted antialiasing.
  Cream flesh/pith remain opaque; original JPEGs and generic paper matte are
  unchanged. Rotated/scaled real GPU cutouts are checked against the old fringe.
- Actual down holds pressure until up. A damped buoyancy spring moves the original
  source sprites a few pixels into the water, with less than 4% apparent shrink.
  Native collider/body scale is unchanged. Centre/edge impulses, mass, native
  inertia, drag and rotation determine different movement and recoil. Release
  produces a small rebound which settles, not a periodic wobble or canned tween.
- Water is displaced at the rim on down/up, with separate short wet contact cues
  through the existing SFX bus. Paper, text and controls remain fixed. Held state
  releases on outside up, Esc, arrow, focus loss, window exit and language rebuild.
  Rebuild preserves physical position/spring progress without retaining capture.
- Display choices close their popup first, then coalesce native changes outside
  the button-release callback. Identical window properties are not rewritten.
  Twelve real-input decoration cycles interleave resolutions and zh/en; first
  clicks must work, with no retry or direct popup-helper workaround.

## Failures found

1. Previous generic white-key retained mixed white/pigment edge pixels. Dedicated
   lemon matte removes the fringe while retaining the original cream interior.
2. Native decoration was changed during dropdown button release. Close-first,
   deferred/coalesced application and duplicate-property guards repair that race.
3. A new display test mistakenly treated stretched Texture metadata as physical
   pixel dimensions. Actual decoded render image is 1280×720 while logical
   metadata is 1024×576. The test now checks decoded physical pixels; failed logs
   remain retained. See [Godot viewport source](https://github.com/godotengine/godot/blob/master/scene/main/viewport.cpp).
4. Full route reached the ceramic-plate approach but a late focus-out cancelled
   it after about 18 pixels. Initial focus now comes from the actual Window;
   non-focusable windows retain accepted mouse destinations while external keys
   cannot interrupt them. Focusable game windows still cancel on focus loss, and
   keyboard movement always cancels. The native flag regression requires an actual
   renderer: the headless backend ignores this flag, so its failed attempt is
   preserved and the test runs as a GPU fixture. No clue click is retried or state
   injected to conceal failure. [Window flag semantics](https://docs.godotengine.org/en/stable/classes/class_window.html#enum-window-flags).

## Review evidence and limits

[1920×1080 demonstration](coastal-settings_20261017-r4/settings-demo-1920.mp4)
is actual Godot MovieWriter rendering and mixer, with annotated automated pointer
input. It demonstrates centre hold/rebound, edge hold/torque, a heavier slice,
varied water, a live slider, rounded English menu and return. It is not native
mouse footage or a human listening result. This R4 candidate exposed no targetable
native window during the attempted OS check; that check was not completed. Current
matching-package native scope belongs to the separate R5 report.

Engine, physical-window unit, complete case routes, wrong/exit/repeat paths,
rapid input, save/restore, original media/licenses, actual PCK behavior and official
Windows boot are recorded separately. Source/evidence fingerprints reject later
changes. The actual release forced-quit stderr records18 ObjectDB /4 audio
resources at shutdown; inspector stderr is empty. Raw bytes are unchanged. The
prior attribution to the inspector was reversed and is corrected here. Human listening, novice comprehension, a complete
native matrix and the requested new long three-letter/wax sequence remain pending.

Work was divided among the root implementation/QA/publication, water variation,
lemon matte/press and display-transition diagnosis agents. This is four actual
participants, not a claim that the 49 upstream studio roles ran simultaneously.
