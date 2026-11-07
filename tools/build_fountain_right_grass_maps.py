"""Add only the four original fountain-right blades to the technical maps."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/authoring/street_motion_masks_20261103"
ART = ROOT / "assets/authoring/streets_20261101"
SCOPE = (643, 475, 701, 515)
BOX = (647, 478, 697, 514)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def build():
    sources = [ART / (family + "_" + phase +
                      (".jpg" if family == "residential" and phase == "night" else ".png"))
               for family in ("community", "residential")
               for phase in ("morning", "noon", "sunset", "night")]
    hashes = {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p.read_bytes()) for p in sources}
    image = np.asarray(Image.open(sources[0]).convert("RGB"), dtype=float)
    original = {name: np.asarray(Image.open(OUT / f"community_foregrass_{name}.png")).copy()
                for name in ("alpha", "backmap")}
    alpha, back = original["alpha"].copy(), original["backmap"].copy()
    sx0, sy0, sx1, sy1 = SCOPE
    alpha[sy0:sy1, sx0:sx1] = 0
    back[sy0:sy1, sx0:sx1] = 0
    x0, y0, x1, y1 = BOX
    scope = np.zeros(image.shape[:2], bool)
    scope[y0:y1, x0:x1] = True
    green = (image[..., 1] - image[..., 0] > 9) & (image[..., 1] - image[..., 2] > 18)
    seeds = green & scope
    seed_image = Image.fromarray(seeds.astype(np.uint8) * 255)
    potential = (np.asarray(seed_image.filter(ImageFilter.MaxFilter(5))) > 0) & scope
    core = np.asarray(seed_image.filter(ImageFilter.MinFilter(3))) > 0

    def candidates(y, occupied):
        # x697 is the rigid flowerpot edge; never sample its green front plane.
        return [q for q in range(632, 697) if not occupied[y, q] and not green[y, q]]

    for y in range(y0, y1):
        for x in range(x0, x1):
            if not potential[y, x]:
                continue
            available = candidates(y, potential)
            if not available:
                continue
            q = min(available, key=lambda at: abs(at - x))
            background = image[y, q]
            ys, xs = np.where(seeds[y - 5:y + 6, x - 5:x + 6])
            if not len(xs):
                continue
            ys += y - 5
            xs += x - 5
            score = image[ys, xs, 1] - image[ys, xs, 0] - .4 * (abs(xs - x) + abs(ys - y))
            selected = int(score.argmax())
            foreground = image[ys[selected], xs[selected]]
            delta = foreground - background
            value = float(np.clip(np.dot(image[y, x] - background, delta) / max(1, np.dot(delta, delta)), 0, 1))
            if core[y, x]:
                value = 1.0
            if value >= .025:
                alpha[y, x] = round(value * 255)
    occupied = alpha > 0
    for y in range(sy0, sy1):
        for x in range(sx0, sx1):
            q = x
            if occupied[y, x]:
                choices = candidates(y, occupied)
                assert choices, f"Missing fountainwall reference at {x},{y}"
                q = min(choices, key=lambda at: abs(at - x))
            back[y, x] = [q % 256, q // 256, 0, 255]
    outside = np.ones(alpha.shape, bool)
    outside[sy0:sy1, sx0:sx1] = False
    for name, result in (("alpha", alpha), ("backmap", back)):
        assert np.array_equal(result[outside], original[name][outside]), "Existing mapped area changed"
        Image.fromarray(result).save(OUT / f"community_foregrass_{name}.png")
    for path in sources:
        assert sha(path.read_bytes()) == hashes[str(path.relative_to(ROOT)).replace("\\", "/")]
    record = {"scope": SCOPE, "silhouette_box": BOX,
              "alpha_pixels": int(np.count_nonzero(alpha[sy0:sy1, sx0:sx1])),
              "all_existing_maps_outside_scope_unchanged": True,
              "sources_unchanged_sha256": hashes,
              "motion_bound_source_pixels": 1.7, "fixed_root_y": 513,
              "background": "Original same-row fountainwall samples; flowerpot and rounded plant excluded"}
    (OUT / "community_fountain_right_grass_maps.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    build()
