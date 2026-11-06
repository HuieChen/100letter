# Existing exploration: camera, paper and conversation pass

The user authorized both open-source integrations and a higher overall finish. This pass changes presentation and interaction machinery while retaining supplied artwork, save state, and unopened narrative. It is a reviewable polish increment, not a claim of industry-leading or final artistic acceptance.

## Implemented

- Official Phantom Camera 0.11.0.3, pinned `9874dfe6882724362ee10b15788f7811beb6371a`, drives the actual street follow transform. A custom bridge applies its damped output to the existing Control panorama, so HUD and authored hit coordinates do not inherit a root camera transform. Map arrivals snap to their real destinations, normal motion eases and settles, and modal composition remains frozen.
- Official Dialogue Manager 4.2.0, pinned `94fe560072ed9972fcb7b331d7f727f8b72c3da1`, sequences the existing six-turn chef encounter via precompiled standard `.tres` resources. Both languages, cancellation, rapid input and re-entry are covered. The intentional ellipsis remains; no removed or unfinished dialogue has been restored.
- Map/paper surfaces enter with a short centered motion. Pause sheets have a restrained contact shadow. Original HUD cutouts have contact shadows and consistent held/hover/focus priorities.
- A warm paper-edge transition covers scene replacement and reveals the arrival. The existing busy guard still rejects duplicate navigation and defers quit safely. Dialog dismissal remains synchronous where callers depend on it.
- Dialogue closeups hide the small world cast while the large portraits are shown, then restore the world actors on exit; duplicate representations no longer protrude above the paper.
- Export includes upstream class-name dependencies, both MIT licenses and the compiled dialogue resources. The source `.dialogue` files remain editable, with `tools/bake_authored_dialogue.gd` updating their runtime resources.

## Verification

Actual PCK, loaded with the matching Godot editor and external test scripts from a package working directory, no source project fallback:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| Cinematic transition, rapid activation, closeup cast restore and paper exit | 9 | 0 |
| Actual chef resident → host → managed conversation | 41 | 0 |
| Dialogue backend and surface | 75 | 0 |
| Phantom framing, damping, bounds and modal freeze | 132 | 0 |
| Exploration comfort | 58 | 0 |
| Exploration destinations and save failure/retry | 113 | 0 |
| Photo review resilience | 64 | 0 |
| **Total** | **492** | **0** |

Official release executable GPU boot: 120 frames, exit 0, no script/shader/resource errors in the boot log. Package inventory: 1,092 entries, 167 exact raw includes verified. Runtime export Python regressions: 3/0. The build used `-SkipChecks` after separate scoped testing; the entire historical pipeline is not claimed as green. The older package-suite failures recorded in PHOTO_REVIEW_POLISH_20261106.md remain separate from this validation.

The legacy authored-street test was updated openly: exact hard-glued camera alignment is replaced by immediate target updates, bounded follow lag and convergence after settling. This reflects the explicitly requested new behavior, not tolerance added to conceal a regression.

Screenshots inspected: original street arrival, partial paper wipe, conversation (before/after duplicate-cast correction), pause sheet and actual walking frames. No source artwork was repainted. Visual review remains agent inspection, not player aesthetic acceptance. Sound design/listening and a full novice playthrough are not certified. Composition still inherits substantial empty sky from the original panoramas; neither plugins nor these checks replace authored scene-density and narrative work.

## Coordination and review

Camera and dialogue were implemented in separate ownership scopes, with independent read-only review of the paper/UI changes. Review caught held-press feedback priority and a deferred paper-layout pivot issue; both were corrected before packaging. No production story gate was marked complete on the strength of automated results.
