# Object-specific street motion correction — 2026-11-03

User-reported defects: flag and shrub blended together, lamps bent, old leaf edge remained visible, walking looked choppy, and motion lacked plausible response to wind.

## Actual faults and corrections

The prior recording loaded a base PCK then overlaid raw GDScript. Base `.gd.remap` files still selected the old compiled helper: actual runtime had 7 grass regions and 5 rigid regions. Matching raw source hashes did not prove execution of those scripts. Current recording resolves current source directly through an isolated recording project and asserts 15 grass regions, 22 rigid regions and 24 branch axes from the instantiated material.

Community has eight streetlamps (source x=1092.5,1646.5,2916.5,3702.5,5091.5,5696.5,7128.5,7588.5). All heads/poles and the exposed pink-pennant pole are protected. Candidate plant rectangles now use original morning geometry to reject rigid supports and adjacent cloth at both destination and final sampled coordinate. Cloth has a separate top-anchored travelling ripple. A continuous contact falloff preserves its painted overlap with the shrub without a hard masking seam.

Antialiased leaf pixels include sky color. Weighting displacement by green-pixel membership left a stationary secondary outline. The complete eligible painted contour and surrounding sky now receive continuous displacement; rigid objects and cloth remain explicitly excluded. Rigid palm trunks, fruit and pots receive dense5x5 source-pixel dilation plus explicit leaning-trunk capsules and a fruit ellipse covering the swept sampling margin so their own antialiased rims cannot be carried into the moving foliage/sky. Original source panoramas are not repainted or rewritten.

Motion uses a shared spatial wind field. Damped-spring harmonic response gives long fronds slower response and lag, while short grass recovers faster. Branch deformation follows an inverse arc rather than axis stretching; free tips receive small faster flutter. Roots/attachments stay fixed. This is a restrained procedural 2D approximation, not a full plant/cloth physics simulation. Night-only stall light and quieter existing ambience are preserved.

The Windows hidden/minimized renderer could stop drawing while the old film timeline continued. The replacement recorder defers an explicit GPU draw for each logical frame and captures immediately after it. It records native1920x1080 at60fps. A two-second current-source probe decoded120 frames with120 unique images and zero repeated adjacent frames. The five original courier poses and8fps source cadence remain unchanged; missing authored in-between poses are not invented. The walker regression passed75/75; that does not certify subjective gait smoothness.

## Verification

- Current-source general GPU regression:131 checks,0 failures.
- Independent object-boundary GPU regression:198 checks,0 failures across morning/noon/night and0/1.25/9/20 seconds. Pixel selections are independent of runtime region lists: eight lamp silhouettes, flag pole, cloth/plant color isolation, separate motion, and single-contour palm edge scans including low-opacity antialias pixels, and fixed wood/fruit/pot rims at additional time56.
- Visual source/capture comparison: pink flag/shrub border continuous; no extra palm outline; all sampled poles straight.
- No grid, bone overlay, debug outlines or parameter text appears in the game/video.
- User aesthetic and listening acceptance remains pending. Final film fully decoded:64.00seconds,1920x1080,60fps,3840frames;0 consecutive repeated frames throughout the walking segment;3840 explicit GPU draws;64/64 unique one-second frame captures. Audio mean-34.4dB,peak-15.5dB. File: C:/Users/22416/Documents/Codex/2026-11-02/wo-2/outputs/Community_Object_Motion_Corrected.mp4. Exact file/source hashes are in receipt-20261103.json.

## References actually consulted

- NVIDIA GPU Gems3 chapter6, tree hierarchy, damping/stiffness, branch response and shared wind: https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-6-gpu-generated-procedural-wind-animations-trees
- NVIDIA GPU Gems3 chapter16, main/detail bending, per-leaf stiffness/phase, length constraints: https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-16-vegetation-procedural-animation-and-shading-crysis
- User-supplied leaf/grass videos, previously extracted reference frames.
- Alan Becker follow-through/overlapping lesson page located; full video playback was not verified: https://www.youtube.com/watch?v=4OxphYV8W3E
- Godot official RenderingServer.force_draw documentation: https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw

No external runtime shader code or artwork was copied. Originals, existing saves/progress and unrelated changes are preserved.
