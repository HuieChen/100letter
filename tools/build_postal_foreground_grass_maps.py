"""Recover omitted postal foreground grass using original-art coordinate maps.

Only technical masks are written. Each uncovered pixel uses a nearby original
same-row sample on the same observed sky/tree/pot surface. The shader transports
the original pigment independently in all four lighting phases, with fixed roots.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/authoring/street_motion_masks_20261103"
SOURCE = ROOT / "assets/authoring/town_20261029"
PERIODS = ("morning", "noon", "sunset", "night")
# Bounds are the visible source-pixel silhouettes, not generated artwork.
GROUPS = [
    {"name": "cloth_tree_tuft", "box": (413, 478, 458, 513), "search": (399, 519)},
    {"name": "small_pot_front", "box": (470, 502, 482, 513), "search": (460, 500)},
    {"name": "long_pot_twins", "box": (630, 499, 648, 513), "search": (621, 659)},
    {"name": "fence_grass_tail", "box": (2875, 498, 2918, 513), "search": (2870, 2928)},
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def surface(group, x, y):
    if group == "cloth_tree_tuft":
        # Observed sloping trunk edge and the left edge of the small pot.
        if x <= 406.0 + (y - 500.0) * 1.72:
            return "tree"
        if y >= 502 and 455.0 + (y - 502.0) * .45 <= x <= 501.0 - (y - 502.0) * .35:
            return "pot"
        return "sky"
    return "pot" if "pot" in group else "sky"


def build():
    sources = {phase: SOURCE / f"post_v2_{phase}.png" for phase in PERIODS}
    hashes = {phase: sha(path.read_bytes()) for phase, path in sources.items()}
    image = np.asarray(Image.open(sources["morning"]).convert("RGB"), dtype=float)
    height, width, _ = image.shape
    assert (width, height) == (6037, 640)
    for path in sources.values():
        assert Image.open(path).size == (width, height)
    alpha = np.zeros((height, width), dtype=np.uint8)
    back = np.zeros((height, width, 4), dtype=np.uint8)
    red, green, blue = image[..., 0], image[..., 1], image[..., 2]
    # These postal blades are olive/yellow, so a green-minus-red test misses them.
    grass = (green > red * .81) & (green - blue > 25) & (blue < green * .77)
    records = []
    for group in GROUPS:
        x0, y0, x1, y1 = group["box"]
        scope = np.zeros((height, width), dtype=bool)
        scope[y0:y1, x0:x1] = True
        seeds = scope & grass
        seed_image = Image.fromarray(seeds.astype(np.uint8) * 255)
        potential = (np.asarray(seed_image.filter(ImageFilter.MaxFilter(5))) > 0) & scope
        core = np.asarray(seed_image.filter(ImageFilter.MinFilter(3))) > 0
        # Keep room for the <=1.7 px sweep and bilinear sampling in either direction.
        px0, px1 = x0 - 4, x1 + 4

        def candidates(x, y, occupied):
            kind = surface(group["name"], x, y)
            return [q for q in range(*group["search"])
                    if not occupied[y, q] and not grass[y, q]
                    and surface(group["name"], q, y) == kind]

        for y in range(y0, y1):
            for x in range(x0, x1):
                if not potential[y, x]:
                    continue
                available = candidates(x, y, potential)
                if not available:
                    continue
                q = min(available, key=lambda at: abs(at - x))
                background = image[y, q]
                local = seeds[max(0, y - 5):y + 6, x - 5:x + 6]
                ys, xs = np.where(local)
                if not len(xs):
                    continue
                ys += max(0, y - 5)
                xs += x - 5
                # Strong original pigment near this pixel estimates its AA coverage.
                score = (image[ys, xs, 1] - image[ys, xs, 2]
                         - .7 * (abs(xs - x) + abs(ys - y)))
                selected = int(score.argmax())
                foreground = image[ys[selected], xs[selected]]
                delta = foreground - background
                value = float(np.clip(np.dot(image[y, x] - background, delta)
                                      / max(1, np.dot(delta, delta)), 0, 1))
                if core[y, x]:
                    value = 1.0
                if value >= .025:
                    alpha[y, x] = round(value * 255)
        occupied = alpha > 0
        mapped = 0
        for y in range(max(0, y0 - 2), y1 + 2):
            for x in range(px0, px1):
                q = x
                if occupied[y, x]:
                    choices = candidates(x, y, occupied)
                    if choices:
                        q = min(choices, key=lambda at: abs(at - x))
                        mapped += 1
                back[y, x] = [q % 256, q // 256, 0, 255]
        count = int(np.count_nonzero(alpha[y0:y1, x0:x1]))
        assert count > 10, f"No usable silhouette: {group['name']}"
        assert mapped == count, f"Missing same-surface background: {group['name']}"
        records.append({**group, "alpha_pixels": count, "mapped_pixels": mapped})
    # Below y512 the shader is exactly rooted; no data reaches neighboring props.
    assert np.count_nonzero(alpha[513:]) == 0
    for phase, path in sources.items():
        assert sha(path.read_bytes()) == hashes[phase], "Original artwork changed"
    Image.fromarray(alpha).save(OUT / "postal_foregrass_alpha.png")
    Image.fromarray(back).save(OUT / "postal_foregrass_backmap.png")
    record = {
        "sources": {phase: {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                            "sha256": hashes[phase]} for phase, path in sources.items()},
        "groups": records,
        "original_art_unchanged": True,
        "background": "Original same-row samples on the same observed surface; no new pigment",
        "motion_bound_source_pixels": 1.7,
        "fixed_root_y": 512,
        "phase_fidelity": "The shared geometry maps transport each original phase's own source RGB",
    }
    (OUT / "postal_foregrass_maps.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    build()
