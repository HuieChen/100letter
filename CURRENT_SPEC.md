# Current specification — reviewed 2026-10-03

Authority: newest explicit user feedback → this file → Master Runbook/reference mapping → older packs. See docs/REQUIREMENTS_REVIEW_20261003.md. Old specifications cannot reintroduce rejected interactions.

## Preserve the accepted game
Active entry: scenes/final_slice.tscn. Retain the morning framework at 1fefd070fa35edbf7f6eb3c221933bd876197bba, scene composition, selected generated art, campaign and player saves. No exact 10:30 snapshot was located. Rejected empty teal desk/coral box stays inactive. External PSD/source packs and collaborator history stay intact; user-filled/locked art is excluded from public runtime selection.
Visual target: simple illustrated 2D, irregular dark outlines, large flat shapes, low detail, cream/teal/dusty blue/coral/lemon. No 3D/isometric/photorealism or excessive damaged textures. Necessary new bitmap objects use ImageGen and visual inspection; no global scenery replacement. Cover direction: simple large game name; the older illustrated-cover request is superseded.

## Complete physical interactions first
Work one complete chain at a time: book → bag/letter → map → NPC → walking/guidance. Current failure log and phase screenshots/state walkthrough are required. Existing approval is sufficient; silence is not acceptance.
- World objects respond as objects. Doors have handle/board/opening feedback; containers expose contents after actual opening. No dead buttons or fake decorative affordances.
- One envelope, two faces, one complete paper. Click/double-click/drag focuses the object over the existing surface. Move/flip/zoom/return it. No separate details/hold action labels or address/postmark/body cards.
- Every focused mode has a visible × and Esc. Safe blank dismissal is additional. Nested inspection returns predictably.
- Books use page corners and paper sounds, one encountered person per spread with portrait and observed context. Unknown facts remain unknown; the player writes provisional deductions. Empty tabs are absent.
- Map destination click closes it and starts a short transition, retaining travel-time consequences. No second walking-confirm step.
- Guidance uses natural NPC purpose and object/cursor response, not narrator/control-hint overlays, arrows or flashing. Rich dialogue contains actual clues and remembers questions.
- Stable feet, preloaded animation, responsive input; small object, medium completion and large human feedback. Authentic sound needs listening, not just Dummy-driver tests.
- World writing and system UI remain distinct. Evidence/archive/resolution slips are physical documents. Wrap text inside safe areas, never under icons. Shared tab geometry, anchors/containers; 1920×1080 reference, 1280×720 and 2560×1440; Chinese/English.

## Newly authorized three-letter session
After existing usability chains: continuous session of at least 30 minutes without forced wait padding. Supervisor introduces exceptional letters in a portable bag/case. Letter01 needs multi-round NPC and environmental reasoning; Letter02 needs an envelope puzzle/repair; Letter03 cannot be uniquely solved publicly until the player independently chooses available opening tools. No narrator/secret UI opening hint.
Each letter: about 1,000 Chinese characters. Letter03: delayed breakup from a now happily married couple, distributed harsh passages and semantic edits including negation/loving-word removal. Preserve immutable originals, visible changes and choices. Reinsert/fold/repair; real wax/spoon/candle/pour/stamp/cool/lift sequence. Instant rubber stamping is inadequate. Human/moral consequences, no automatic good-person score or guaranteed saved marriage.
This supersedes the old Cases02–05 content freeze, not the old campaign/save schema. Planning mapping letter01→case01, letter02→case03, letter03→case04 is not implemented migration. Authoring simulation/estimated duration is not playable/novice acceptance.

## Delivery and evidence
Publish reviewed source and matching playable package to HuieChen/100letter main. Fetch first, preserve collaborator commits, no force push/private-history merge. Verify exact remote SHA/CI. Historical Windows ZIP is not current delivery.
Per mode: normal/visible-exit/Esc/error/rapid-input/reentry/save-restore/focus-loss/language/responsive checks, fresh automated AND actual-window evidence. Never call blocked checks passed or scripted input human testing. Root QA_REPORT.md lists blockers.
WeChat File Transfer Assistant reporting is authorized but tool-blocked: retain local phase packages and continue without bypass. Denied videos stay unviewed; no exhaustive frame-analysis claim.
