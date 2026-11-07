# Ground grass and postal hanging sheets, 2026-11-07

The requested grass was often either absent from the motion inventory or
reduced below a visible screen-pixel displacement by several overlapping
feathers. The cloth hems also inherited a small-prop displacement cap.

Changes:

- Release grass tips while keeping rooted bases and side/support clearances.
- Increase the bounded bend of existing foreground grass, including the two
  community pots and the previously suppressed blade near source x4805.
- Add source-derived foreground mappings for four postal tufts and the right
  side of the shared fountain. These use original pigment and same-row
  background coordinates, with roots fixed; no new art or texture animation.
  Shared maps are sampled in source-pixel coordinates, so the shorter
  residential panorama does not displace the mask onto unrelated locations.
- Add six local postal regions for the bent blade and lamp-side cluster.
  Exclude those postal grass regions from the overlapping sea motion field.
- Give the three postal sheets one continuous hanging response. Their upper
  attachment bands, ropes and supporting wood remain fixed; the original
  checks move with the cloth surface without travelling shading waves.

Source GPU evidence:

- Hanging sheets: 124 checks, zero failures, four lighting variants. Matched
  hem travel at the normal 1280-window scale: 2.75, 3.75 and 3.00 pixels.
- Postal open grass: 183 checks, zero failures, seven independently observed
  blades, four variants, source and normal-scale renders, pole/shrub/root guards.
- Existing community pots, object boundaries and full object inventory:
  140, 198 and 109 checks respectively, zero failures.
- Independent normal Road captures cover 30 targets and 21 rigid landmarks.
  Every target has measured motion; all 21 rigid landmarks stay pixel-stable.
  Median measured upper-blade edge excursion rises from 0.77 to 2.00 pixels;
  nine formerly zero-motion targets now move. This is a sample, not a claim
  that every painted plant is flexible grass or has identical motion.
- 39 supplied artwork files retain their previous SHA-256 values. Technical
  mask builders assert source hashes and scope preservation. Postal open-grass
  mask reconstruction is idempotent.
- The focused four-variant Road review covers 56 blade observations and 44
  rigid-region observations. All blades move and all rigid regions stay
  unchanged. This caught and corrected the residential shared-map coordinate
  bug; its two fountain blade tips now travel about 2.2 to 2.3 screen pixels.

Tests are actual offscreen GPU renders, not headless dummy-rendering proof or
human playthrough acceptance. A run with exit code zero but without its final
completion marker/receipt was discarded. Final exported-PCK checks and normal
speed recording are delivered alongside the build and identify its exact SHA.
The current demo scope, player saves, original audio and other chats' UI work
remain separate from this animation correction.
