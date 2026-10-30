# Courier turn and compositing correction — 2026-10-31

## User review and scope
The user rejected the first generated eight-frame replacement gait and its turn eyes. That candidate is removed from runtime/export and kept only under ignored test-results. The live gait again uses the five authored Procreate-derived poses and the supplied front idle. No supplied background, original frame, or private source file is repainted. Current permission explicitly allows generated supplementary turns.

## Current change
- Five new turn intermediates bridge the existing profile pose to the existing front idle, and reverse when walking starts. Poses are selected sequentially at full opacity, not overlaid as two translucent faces. The latest set uses the supplied front eye shape; the earlier rejected set is not selected.
- Authored walking retains frame order and source 125ms cadence at 200worldpx/s; actual travelled distance drives the cycle. Each original cutout now registers against a cap landmark, with identical 704px reference height rather than per-frame scaling.
- Turning can reverse when movement restarts. Configure resets the transition; stopping and focus loss preserve callback ownership and bounded motion. Idle completion is included in process shutdown conditions.
- Fountain overlay keeps only bright blue water from the supplied video; the statue, birds and basin remain the unchanged painted background. This removes the duplicated statue's dark cutout contour. The water mask rejects its dark video border as well.
- Courier rendering removes the outer low-alpha fringe with a 0.65 source-texel inner-alpha sample. RGB inside the sprite is unchanged. Vertex tint is captured separately so the texture is not accidentally multiplied by itself.

## Evidence and limits
- `tests/courier_motion_check.gd`: 40 checks, 0 failures. Five authored walk poses; five turn supplements plus endpoints; all poses present; 30/60/144fps travel; reversal; bounded quick restarts; stable idle; focus-loss callback cancellation; Shift distance; distance-cycle wrapping.
- `tests/authored_street_check.gd`: pass (authored poses, fountain frames, Shift, braking, postal entry proximity).
- GPU recordings: `test-results/turn-corrected.avi`, 480 decoded frames / 8s; profile, early turn, late turn and authored endpoint inspected in `turn-corrected-strip.jpg`. The previously failed preview helper parse is recorded as a fixture failure, corrected before this recording.
- GPU fountain inspection: `test-results/edges-after.png`; source statue restored instead of overlaying the entire extracted statue. Shader was corrected to avoid double-multiplying source RGB.
- Native Windows input is NOT_ASSESSED: both available UI runtimes failed initialization with “failed to write kernel assets / path not found”. Launching a window and GPU replay are not native A/D acceptance.
- Forced test-process exit still reports 16 ObjectDB instances / 3 resources. This pre-existing shutdown diagnostic remains unresolved. No claim of full-game acceptance, perfect interpolation, human listening approval or final animation approval.

## Sequential review
Design: constrain this revision to the rejected gait, turn and visible matte edges. Implementation: preserve authored sources and callbacks, separate water from sculpture. Art review: reject first generated gait and first eye set, inspect latest registered turn sequence against original endpoints. QA: test restart/reversal/focus/arrival and actual rendered frames. Audio: no soundtrack/routing changes, listening not reassessed. Producer: do not advance the separate campaign/book work or treat this revision as accepted by the user.
