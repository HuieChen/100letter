# Supplied case — original alpha intake and next mechanical chain

The PNG is already genuinely transparent. The black shown by the initial viewer is its display backdrop, not a baked black matte. Source:1200×1800 RGBA,139,231bytes,SHA256`a71124f3bbc69172cad71019e019cbc1e4e95501634b1a4ee7f9f7e9cad6c95a`. It contains2,037,423alpha-zero pixels,118,751opaque pixels and3,826partial-alpha pixels.2,924alpha-zero pixels are enclosed inside the case's used bounding box, including the actual handle opening. They remain untouched.

`case_source_crop.png` is413×377 from source bbox(621,1022)-(1034,1399), SHA`482e17655d0a424cf94f242a942abdbda6e153ac1326c26e72be5c80ceb7c6fd`. `case_source_crop_padded.png` is445×409 with16pixels of original transparent surround. Both derivatives have exactly the source RGBA pixels, without filtering, smoothing, recoloring, matte extraction or repaint. Fresh images omit EXIF/dpi metadata. Source text/stickers/yellow protruding decoration remain as drawn. Local QA contact images over checkerboard/light/dark are retained in `test-results/supplied-case_20261017/`; they are not runtime art. Originals and current game art are unchanged.

## What the source actually supplies

One flattened closed case in a three-quarter perspective, with a handle, two front straps, side hardware, printed wording and decorative elements. It is not a layered file. The front/right seam and possible hardware regions are recorded as approximate observations in `geometry_intake.json`; identifying the two gold attachments as hinges or clasps still needs source-art/rig review. No isolated latch, lid reverse, interior cavity, missing backing surface or open-case frame is present. The protruding yellow decoration overlaps other painted surfaces, so it cannot safely be detached without revealing absent pixels.

Therefore the original closed composite is a safe authored closed-object intake, **not** a ready replacement for each of the existing three component roles. Copying it into base/lid/latch roles would duplicate the whole case and produce a fake opening. Cutting away the front and filling the revealed hole with arbitrary program geometry would also invent artwork that the intake has not supplied.

## Existing real state chain to preserve

Actual implementation: `scripts/rebuild/postal_desk.gd`, mounted by `final_playable.gd:_counter`.

- Case roles are `mail_box_base`, `mail_box_lid`, `mail_box_latch`; there are no currently registered bag-specific aliases. Current generated source files and hashes are in `intake.json`.
- Single `latch_open` controls unlocking. A locked lid responds with rejection/audio; an unlocked lid can be dragged upward continuously or toggled with a short0.32second physical tween.
- `lid_open>0.82` exposes the envelope stack; `lid_open>0.88` permits the first waiting letter to be picked up.
- The envelope follows the pointer. Clicking it or dragging it into the existing inspection region emits `mail_taken`; the host then calls `core.take_case`, retains custody and enters the real workbench. An invalid drop returns the same letter in0.16seconds.
- Pending/tween guards protect repeated input. Focus loss clears held objects and settles the lid/letter.

The current620×250case-base rectangle has ratio2.48. The new original has ratio1.095. A direct nonuniform stretch into that rectangle would distort the source by more than2.2× in relative aspect and mismatch its perspective. Preserve aspect and recompute the physical placement, hit regions, occlusion and envelope size/position. A contained250px-high closed source is about274pxwide; the current390pxwide letter stack would not fit it unchanged.

## Proposed complete next chain

1. Place the authored closed case as one physical world object with alpha-aware hover and source-mapped hardware targets; handle/straps must not advertise unavailable actions.
2. Give each genuine fastening a small movement/snap response at its painted position. If source rig establishes two straps, maintain two released states rather than pretending the old single latch covers both.
3. Drive an actual separately authored front/lid surface about its established hinge from pointer movement. Keep the stationary body/handle, moving face/stickers/strap parts, back of the lid and cavity as coherent overlapping components. Do not move source decorations independently unless their hidden backing is available.
4. Reveal the same physical envelope stack through the opening; letters remain occluded until a real opening permits access. Transfer custody only after pickup/valid placement, reusing the current `mail_taken→core.take_case→workbench` chain.
5. Return the letter, settle invalid drags, close the lid and refasten at real positions. Check repeat entry, rapid input, mouse-up outside, focus loss, Esc/visible back, progress restoration and both languages at1280/1920/2560.

Required source surfaces before a source-faithful complete opening: separate closed/moving face, stationary case body/cavity, lid back/interior, and fastening/strap parts with the areas they uncover. These may be provided as author layers/open-pose assets, or an explicitly designed complementary art set in the next implementation pass. They cannot be recovered as original hidden pixels from this flattened PNG. Intake leaves the existing working container selected until that complete chain exists.

## Focused regressions to investigate in the next chain

Static source review finds two existing affordance mismatches worth testing during the case rebuild: `_any_target` advertises the old latch even while the lid is open, but its input branch only acts when`lid_open<0.1`; the latch sprite rotates while its `LATCH` rectangle remains fixed. These are source observations, not newly reproduced native/GPU failures. New rig/hit regions should follow actual moving parts and remove hover where an action is unavailable.

The exact closed-object derivatives and intake records are retained here as authoring material. They are not registered in the runtime manifest or selected in the Windows export. Complete lid/interior/fastener art and a current state-chain review are required before replacing the existing working mail case. No gameplay/save or original source file was changed by this intake.
