# Two photo papers and focused presentation corrections

The camera retains landscape prints and adds the original portrait instant-paper
presentation. Click the format control at the top of the viewfinder or press R;
C and the round shutter still take a photo. Instant paper captures the central
square; landscape retains the complete wide scene. Review, notes, ejection,
backpack thumbnails and exported PNGs use the captured image's proportions.
Existing photographs are not rewritten. Switching is blocked while capturing,
reviewing or exporting, and typing R into a caption remains ordinary text input.

The camera-page organization in the [GT7 official camera manual](https://www.gran-turismo.com/gb/gt7/manual/scapes/03)
informed keeping composition choices in the live camera instead of Settings.
The two-state click/R control is this game's implementation, not a copied control.

Community staff portrait alone is 20% smaller. Settings' transparent lemon
SubViewport now uses premultiplied-alpha compositing: the previous ordinary
blend multiplied edge alpha twice and created a dark rim. Supplied art bytes
and the existing pigment-recovery shader are unchanged.

## Sequential review and evidence

- UI implementation/UX: explicit live format state and shortcut, guarded input,
  capture-to-review-to-export proportions, retained image identities and captions.
- Art review: inspected GPU-rendered Chinese/English portrait and landscape
  prints, community portrait and Settings. The thin dark lemon rim is absent.
- QA: `photo_formats_20261107.gd`: 29 checks, 0 failures, both languages,
  capture dimensions, review and export orientation, caption persistence/bounds.
- Regression: photo album visual suite 98/0; review navigation 90/0; backpack
  streaming 70/0 with 240 photos, opening 43.148 ms, longest close 20.524 ms.
- Two console-engine backpack runs exited without a receipt; neither counts as
  a pass. The GUI-engine rerun produced the complete 70/0 receipt.
- Evidence lives in the local `work/format-20261107` task directory. These are
  scoped checks, not whole-game, novice or listening acceptance.

The actual release PCK passed the same 29/0 photo-format suite, and the inventory
verified all 1104 entries including 169 explicit raw assets by SHA-256. Inspected
the packaged live camera in a native window. OS input stopped when the helper
detected user input and the window was minimized; native R/C acceptance remains
unverified rather than being inferred from automated results.

The older general `packaged_content_smoke.gd` still fails five expectations about
disabled generated material roles, the previous plain-text cover, the old lemon
pressure threshold, and arrow-close Settings behavior. This old suite is not
reported as a pass or silently changed for this scoped correction.
