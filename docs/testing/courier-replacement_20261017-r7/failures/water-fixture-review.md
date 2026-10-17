# Visible ripple fixture failure review — 2026-10-17

The failed GPU run `coastal-focus-20261017-192212/visible_ripple_input.log`
and its partial images are historical failed evidence. No GPU rerun was
performed by this review. Production shader/field/art and acceptance thresholds
were not changed.

## Proven incorrect occlusion, not a proven water-transform defect

Inspection compared the actual `shallow_1280_idle.png` with the retained
`shallow_1280_1_same_pose_zero_reference.png`. The exposed-water rectangles
`(4,230)-(240,710)`, `(960,0)-(1270,330)` and `(0,580)-(220,720)` are identical:
113280, 102300 and30800 pixels respectively have zero RGB difference.
The reference water is correctly positioned/scaled in those independently
chosen large regions. This does not by itself prove every rendered wave.

Replaying the old identity sample grid with the original five paper JPEG hit
masks (`min RGB <0.975`) and collider-radius+8 fruit exclusion produces21
misclassified samples. They include the actual native Chinese Settings title
and rendered paper/tape/postcard antialias fringes. For example world(804,48),
native pixel(643,38), is actual title RGB(0,89,174) compared with water reference
(146,179,200). Such a foreground sample cannot measure zero-field water
identity or a lighting flash. Other fringe outliers include world(648,12),
(1176,264), (960,816) and(936,876).

The input paper hit silhouette intentionally excludes very pale fringe pixels;
it is not an exact visible-paper occlusion mask. Likewise a native circle
collider is not the full authored fruit silhouette.

## Fixture-only correction

- Add an independent transparent foreground diagnostic SubViewport drawing
  only the five original `PDF_*` paper TextureRects with their actual materials
  and transforms. Its alpha records real partial coverage, not a new artwork.
- Use actual production `FloatingLemons` transparent viewport alpha for fruit
  occlusion at the captured pose, and actual native label/button/range/separator
  rectangles (including label outline size) for UI occlusion.
- No exclusion mask comes from `actual-minus-reference`, wave amplitude or
  observed failure locations. The real/default material remains unchanged.
- Apply these independent masks uniformly to zero-field identity, light-off
  flash comparisons and wave-profile sampling.

## Incorrect page-lifetime assumption and remaining input question

The old stress path clicked the language selector and unconditionally pressed
Esc without proving its menu opened. If that click failed, Esc legitimately
closed Settings; accessing the old `page.field` then caused the recorded
`previously freed` ScriptError. A prior near-lemon return-arrow failure also
allowed subsequent cases to run over a leftover modal.

The fixture now requires a first actual pointer pair to emit exactly one
Button `pressed`, passively records down/up/pressed/native-focus-out counts,
checks that the nested menu exists before Esc, and checks that Esc preserves
the same page before reading its field. References are released before real
menu/exit input can destroy their source canvas. An essential input/lifecycle
failure aborts the fixture with a failed, explicitly partial result instead of
continuing on a leftover or freed modal. There is no click retry, direct
handler invocation or forced application-state repair.

The actual reason for the old failed return arrow/menu click is still unknown.
It is not declared resolved merely because guards prevent its cascade.
The new signal/native-focus trace is intended to diagnose a recurrence.
Root's separately retained MovieR7 trace showed unexpected native input despite
NO_FOCUS. A subsequent root Movie attempt stalled with
`Window.mouse_passthrough=true`; therefore this fixture does **not** set that
flag or claim native pointer isolation. It records the observed value only.
First-pair/focus signal failures remain failures, without a click retry.
Production flags are unchanged; this remains engine input, not an OS playtest.

## Unchanged gates and pending verification

The original3/255 light/dark threshold,1/255 noise threshold,16 sectors,
4worldpx radial bins,24worldpx outward growth,48worldpx band-pair gap,
0.065 lighting-flash limit, global-flash/clipping/paper/timing limits and
real down/up input boundaries remain unchanged. Near-lemon outward growth
failed in the old run; it needs actual retesting after honest occlusion and
must not be called fixed in advance.

Wall-clock mode additionally rejects an active
`Engine.get_write_movie_path()`, because handled MovieWriter CLI arguments
are not reliably present in `OS.get_cmdline_args()` on this Godot4.7.2 launch.
The OS argument check remains supplemental.

Godot `--headless --check-only` and whitespace checks passed after these fixture
edits. That is GDScript syntax verification, not shader compilation, GPU/input
execution, perceived readability, listening or final aesthetic acceptance.


## Actual rerun 195102: remaining rasterization defects, not waived gates

The retained rerun completed778 checks /26 failures without ScriptError or a
modal cascade. All first-pair menu/return operations passed in that run.
It still failed nine zero-field identities, sixteen stress lighting limits,
and shallow-water outward growth at2560. Those are historical failures,
not a passing candidate.

Independent CPU inspection of the retained actual PNGs and unchanged original
JPEG plates identified two measurement errors:

* Native fruit alpha was fetched at one nearest1920x1080 texel, while the
  actual FloatingLemons TextureRect was filtered to the final display.
  At1280, idle world(300,96)/(288,132) differed by3/255 and5/255;
  native nearest alpha was0, but a CPU reconstruction of the original
  pigment matte and final bilinear footprint gave alpha0.01850/0.02179.
  At2560, world(300,96)/(1440,768) differed by14/255 and4/255 with
  corresponding final alpha0.07346/0.01823 and native nearest alpha0.
  The1280 stress peaks39/255 are at world(296,112)/(1496,696), with
  static original fruit fringes and final alpha0.23199/0.21649. The2560
  peak19/255 is the same large-fruit fringe with final alpha0.10612.
  These CPU alpha estimates are diagnostic estimates, not GPU alpha claims.
* The mask coordinate operation `(point/SIZE)*dimensions` was different from
  the color operation `point*scale`. With float32 Vector2 at1920,
  world(420,96) compared actual pixel(504,115) but queried mask(503,115).
  Original postcards JPEG pixel(503,115) is(255,255,255), while(504,115)
  is(240,238,226), exactly the actual UI PNG color. The water reference is
  (191,215,231), giving the recorded49/255 identity failure. This is an
  original physical postcard pixel, not zero-field water motion.

The numerical witnesses are saved in195102_cpu_fruit_sampling.json and
195102_cpu_stress_sampling.json in this ignored draft folder. No screenshot
pixel was edited, and no mask is inferred from observed color difference.

The fixture now independently renders the real FloatingLemons TextureRect
and the five original paper TextureRects/materials together at each final
resolution. Both alpha and compared color use one identical display-pixel
operation. Three idle and three stress alpha PNGs plus bounded failure/peak
coordinates/colors are retained for the next actual GPU run. Layer counts
are mandatory. The fixture viewport is also attached to its own World2D
before setting its canvas transform, removing the explicit renderer
`!viewport->canvas_map.has(p_canvas)` error recorded twelve times at195102.
The error alone did not prove the entire prior alpha scale was wrong: the
property can be cached before canvas attachment, so no such claim is made.

No3/255 crest/trough,2/255 identity,24worldpx outward-growth,0.065 lighting,
clipping, global, paper, timing or input gate changed. The failed shallow2560
growth12worldpx is still unresolved. Its0.108/0.259s coherent fronts were
56/68worldpx; the0.459s92worldpx frame had dark bands but no light bands.
It must pass actual rendered observation or require production tuning;
this measurement repair is not acceptance of that result.

Expected complete next-run count is796 (778 prior +12 six-layer checks
+6 mask PNG saves), subject to actual execution. Headless syntax and
whitespace checks passed. No GPU, source/art edit, build or publication was
performed by this repair task.


## Full check203348: first-arrow failure retained, cause still unproven

After the root's legitimate production gain adjustment(.24 curvature/.08 slope,
unchanged0.055RGB and3worldpx caps), focused202246 completed796/0 visible
checks. The fresh full check then stopped at64/2: the1280 shallow return
arrow received one Button down and one up, but no pressed; native focus-out
count was0. This does not establish a production button defect or prove OS
interference. All screenshots and the original result are preserved by the
parent inwater-visible-r6_failed-arrow-20261017-203348. The exact166470-byte
result is additionally copied here as203348_failed_first_arrow_result.json.

The next fixture sets its own QA Window position after actual Host startup
and each resize, then observes the DisplayServer client rectangle outside
every returned native screen. Readiness is bounded by30 real process frames,
and every named first pair checks the actual geometry again. A passive
InputAudit records buttons/motion/keys with routed-dispatch depth and window
geometry. Button enter/exit/down/up/pressed/native-focus traces include actual
hover/is_pressed state. Depth-zero input is labeled unrouted, not inferred
as an OS device event. It is never swallowed, retried or hidden. Unrouted
armed presses or movement during a named down/up pair cannot become a pass.
Native OS interaction, game-window performance, listening and human usability
remain separate. Original input pair/wave timing boundaries and all visibility
thresholds are unchanged. No production code or passthrough flag was changed.
Syntax/whitespace checks passed; actual full GPU rerun is the parent's next step.


## Typed trace boundary205315 and actual focused211833 correction

The next full run hit an instrumentation error after a successful close:
`_button_state(BaseButton)` received an already-freed target at its typed
argument boundary. Its own internal is_instance_valid guard could not run.
The harness rejected the SCRIPT ERROR even though the partial result printed
70checks/0 failures; that partial result is invalid. Before repair, all
pictures/result, the exact failed fixture source and original log were kept
inwater-visible-r6_failed-typed-argument-20261017-205315.

All nine Button-state call boundaries (including signal closures and passive
InputAudit) now check is_instance_valid before passing target or null into the
still-typed function. A freed target is an expected trace state after a real
successful close, not a reason to retry the click. Post-Esc page access already
requires same_page validity; the saved native lemon is not accessed after Esc.
No threshold, mask, input order or production source changed.

A single focused real GPU run,coastal-focus-20261017-211833, then completed
833checks/0 failures with no renderer/script/shader error or warning. Its
complete three-resolution dataset contains nine source-water cases,30 actual
first Button pairs,12 successful close snapshots with target_freed=true,
177 passive audit events and174 images. Unrouted presses, named-pair motion
and discarded audit counts are0. Nine zero-field identities have changed0.
Observed outward growth(shallow/ink-rich/near-lemon):1280=68/60/60,
1920=28/64/60,2560=64/32/60worldpx. Source SHA values matched current files;
the owned QA override was removed before the next stage. This verifies the
scoped offscreen input/render fixture, not native OS clicks, real gameplay FPS,
listening, independent-player comprehension or final aesthetic acceptance.
The parent will retain this success before a new full regression run.
