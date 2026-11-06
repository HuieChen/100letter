# Map, painted door and landscape photograph revision

The user's latest corrections remove map outlines, reject the door's rectangular feedback, require landscape instant photographs, and remove the intrusive departure transition. Original image files remain unchanged.

- Map: removed the traced building silhouettes entirely. A small warm ink chevron above the current target, hand cursor and a compact pressed state identify the destination without covering neighbouring art. Mouse hover and keyboard focus share the same target feedback. No added labels, rectangles or rings.
- Door: removed the perimeter and full-door wash, plus the floating tooltip. Only a quiet highlight on the painted handle responds; the existing delayed activation and modal/transition guards remain.
- Photos: review, ejection, camera thumbnail and bag prints are landscape. The entire source photograph fits inside a 16:9 window, including both edges; non-16:9 existing images are fitted without cropping or stretching. Notes remain editable and persisted. Bag notes now stay on the white photo margin with single-line ellipsis for long notes.
- Scene passage: retains the shared passage controller and input lock, but replaces the cream paper sweep with a short neutral dissolve. The arriving world renders behind the opaque cover before it fades out. Other cinematic camera and managed dialogue changes from dac55ea remain intact.

## Verification

After integration with dac55ea, Godot 4.7.2 with GPU rendering completed these suites with explicit completion summaries:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| feedback_landscape_20261106 | 72 | 0 |
| experience_routes_20261106 | 113 | 0 |
| photo_review_resilience | 64 | 0 |
| cinematic_exploration_review | 9 | 0 |

The focused suite checks both photo edges through rendered pixels, Chinese/English layouts at 1280x720, 1920x1080 and 2560x1440, notes on disk, actual capture/development, bag placement, all 13 map hit regions, keyboard focus, and door arrival. Screenshot inspection found and corrected a bag-caption minimum-height defect before the final run. The resilience suite intentionally loads corrupt QA photos; its corresponding decoder errors are expected. Other suites have no script errors; pre-existing raw-image import warnings remain.

Reproduction (using a fresh QA save directory):

```powershell
& $Godot --path . --script res://tests/feedback_landscape_20261106.gd -- --final-save=user://qa/feedback_new/state.json --preferences=user://qa/feedback_new/preferences.json --qa-out=user://qa/feedback_new/captures
```

All checks use isolated QA files. These are real engine/GPU input simulations and inspected render captures, not a new OS-input playthrough or player acceptance. Native desktop control remains stopped at the user's earlier request. Final integrated package validation belongs to the coordinated release pipeline; no claim of an industry certification or complete campaign acceptance is made.
