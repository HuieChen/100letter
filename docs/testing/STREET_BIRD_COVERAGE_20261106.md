# Sky gull motion coverage — 2026-11-06

The previous production shader animated only two gulls in the community panorama. Inspection of all four original panorama families found additional painted sky gulls, and different bird layouts between the coastal time variants. The fountain's carved birds, signs and stars are not part of this inventory.

## Source inventory

| Panorama family | Morning | Noon | Sunset | Night |
| --- | ---: | ---: | ---: | ---: |
| Community | 9 | 9 | 9 | 9 |
| Residential | 10 | 10 | 10 | 0 |
| Postal | 8 | 8 | 8 | 8 |
| Coastal | 6 | 6 | 6 | 3 |

These are 119 bird instances across 16 source paintings, not 119 different birds. The noon total is 33. Residential night intentionally contains no birds. Coastal morning/sunset have a different left pair and an additional small middle bird; the noon left trio is absent from those paintings. Each source in a daylight crossfade therefore receives its own inventory and displacement. No missing birds are painted into the other phases.

## Change

- `street_bird_motion.gd` records observed source rectangles, wing attachments, independent timing and displacement bounds. It passes separate A/B inventories to the production panorama and cloud materials.
- `street_birds.gdshaderinc` bends each original wing around its fixed body, with different short wingbeat bursts and gliding intervals. It only changes source sampling; it adds no feather, color, texture, cutout or glow.
- The first two common gulls have overlapping rectangular margins. An initial nearest-owner method crossed six original edge pixels on the second gull. Connected-component inspection measured a clean sky gap at `s = y + 0.48 * (x - 1030)`: the first bird's pigment is at `s <= 164.6`, the second's at `s >= 180.24`. Their continuous partition lies inside `168..176`. Other overlaps use a bounded continuous convex blend instead of a hard winner.
- The existing night-star clearance field protects original star pixels. The current cloud overlay excludes the union of the two phases' gull regions at the destination pixel. Displaced cloud-source sampling and time-pair endpoint changes are a separate follow-up audit, not covered by the first 286 checks below.
- Actual Road testing exposed a second existing interaction: postal's gull at `(1925,156)` was inside a broad tree-motion region. The production shader now suppresses that underlying displacement for the corresponding bird region before applying its wing motion. All four postal phases keep the wing attachment fixed.
- Each inventory supplies a bounding rectangle for an early shader return. Ground and most architectural pixels do not traverse the gull arrays.

No supplied panorama, fountain frame, audio asset or existing technical mask was modified for this work. The old two-gull helper remains unused for compatibility with historical standalone audits; production uses the new per-phase functions.

## Verification

`tests/street_bird_coverage_20261106.gd` runs the actual `coastal_road.gd` scene, including its cloud overlay, at a 1280×720 viewport with the normal 1600×900 logical layout. It covers all four families and four daylight knots, every visible source gull, ten motion times over 12 seconds, cloud/material wiring, changed original wing pixels and fixed wing attachments.

Final result: **286 checks, zero failures**. There are 119 measured bird instances. A separate minimal-host GPU capture of the same bird shader covered the same 16 source variants at ten times; every active bird changed, with at least 123 changed source pixels in its capture region, zero measured attachment error and zero changed samples outside the allowed bird regions. Offscreen GPU captures at normal viewport size and enlarged extreme-pose edge comparisons were inspected. The residential night image remains bird-free.

Earlier failures are retained in the local audit evidence: the first harness attempted to hide the Godot main window, which Godot rejects; the first actual Road run had four failures caused by postal's overlapping tree field. Neither is counted as a successful final run.

The source-run engine emits its usual `Image.load_from_file` export warnings. The release pipeline must continue bundling the raw panorama/mask files, and the final package must be tested separately. These GPU and source-image checks do not certify a human playthrough, subjective motion acceptance, or the rest of the game's motion coverage.

Local evidence for this change is in the task's `audit-streets/bird-gpu-v3` and `audit-streets/bird-road-v3` directories; the latter contains `receipt.json`. Original-image contact sheets and per-phase bird crops are retained alongside those runs.


## Final exported cloud overlay regression

The final package uses the same `weather_time` for both wing layers, and converts the source-pixel wing displacement to UV with `texel`. A late-wind test caught both an earlier unit error (distant scenery fragments) and a clock mismatch; neither failed package is delivered. `street_bird_cloud_sampling_20261106.gd` independently compares the original wing pixels with and without the cloud overlay at five wind times, including 891.69 and 998.31 seconds, across all four source phases in residential and postal. Final exported PCK: **145 checks, zero failures**; the actual Road inventory remains **286 checks, zero failures**. The final delivery PCK SHA is `1c7a8b45cef0e2e4c09fb9b94fdff1b7d03c9a4a613c003f9f97dabf0cdec1fa`. These are offscreen GPU tests, not native input or human acceptance.
