"""Open only two inspected postal grass patches in the technical clearance.

Original four-phase paintings are immutable hash-guarded inputs. The mask's
other channels and every pixel outside these local windows remain unchanged.
"""
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
from PIL import Image

from build_motion_grass_clearance_20261106 import grow, distance

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "morning": "524c9c8c1c120b74be4bd025d06f5e521d06b5a4084e1c4fdb977f090071dc20",
    "noon": "6f8c7dc4956593c4abf9f2697149be25fa44a0be5d785fa3ca4218eda06a7ca2",
    "sunset": "5d9e3937b41c91c0e1012812d7764c31374b4182cc678ffb006ca9a1f4c2cfe2",
    "night": "e509d52d73624fd72eac9bbb322d97855217043f48a2a5ed7ae062133ad460e9",
}
WINDOWS = [(1858, 438, 1902, 516), (2948, 460, 3092, 518)]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    paths = {p: ROOT / f"assets/authoring/town_20261029/post_v2_{p}.png" for p in SOURCES}
    before = {p: sha(path) for p, path in paths.items()}
    assert before == SOURCES, "Original postal painting changed; remeasure before rebuilding"
    rgb = np.asarray(Image.open(paths["noon"]).convert("RGB"), dtype=np.float32) / 255
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    path = ROOT / "assets/authoring/street_motion_masks_20261103/postal_foliage_clearance.png"
    original = np.asarray(Image.open(path)).copy()
    assert original.shape[:2] == (640, 6037)
    red = original[:, :, 0].copy() if original.ndim == 3 else original.copy()
    scope = np.zeros(red.shape, bool)
    for x0, y0, x1, y1 in WINDOWS:
        scope[y0:y1, x0:x1] = True
    # Canonical noon identifies the lime and muted olive blade pigments. The
    # neighboring dark, round shrub is a different material, never selected.
    grass = (r > .38) & (g-r > -.055) & (g-r < .11) & (np.minimum(r, g)-b > .12)
    selected = grass & scope
    yy, xx = np.indices(red.shape)
    hard = np.zeros(red.shape, bool)
    hard |= (xx > 1850) & (xx < 1910) & (g-r > .10) & (r < .4)
    pole_scope = (xx >= 2970) & (xx <= 2987) & (yy >= 430)
    hard |= pole_scope & (np.maximum(np.maximum(r, g), b) < .68) & (b-g > .012) & (b-r > .015)
    hard = grow(hard, 1)
    # Observed ground edges: horizontal below the bent lime blade, gently
    # sloped under the lamp. Keep roots and the complete ground edge rigid.
    roots = ((xx < 2000) & (yy >= 506)) | ((xx > 2900) & (yy >= 515.0-.045*(xx-2940)))
    hard |= roots
    allowed = grow(selected & ~hard, 11) & ~hard
    d = distance(allowed).astype(np.float32)
    u = np.clip((d-1)/7, 0, 1)
    release = np.rint(u*u*(3-2*u)*255).astype(np.uint8)
    clearance = distance(~hard).astype(np.float32)
    # Four source pixels suffice for the shader's bounded displacement; a
    # larger margin unnecessarily immobilizes the tiny blade beside the pole.
    v = np.clip((clearance-1)/3, 0, 1)
    guard = np.rint(v*v*(3-2*v)*255).astype(np.uint8)
    proposed = np.minimum(np.maximum(red, release), guard)
    red[scope] = proposed[scope]
    result = original.copy()
    if result.ndim == 3:
        result[:, :, 0] = red
        assert np.array_equal(result[:, :, 1:], original[:, :, 1:])
    else:
        result = red
    assert np.array_equal(result[~scope], original[~scope])
    assert not red[scope & hard].any()
    Image.fromarray(result).save(path)
    after = {p: sha(pth) for p, pth in paths.items()}
    assert after == before
    return {"method": "Localized source-aware technical clearance; immutable original art",
            "source_sha256_before": before, "source_sha256_after": after,
            "mask_sha256": sha(path), "windows": WINDOWS,
            "changed_pixels": int(np.count_nonzero(result != original)),
            "outside_scope_changed": 0, "other_channels_changed": 0,
            "protected_pole_shrub_root_pixels": int(np.count_nonzero(scope & hard))}


if __name__ == "__main__":
    receipt = json.dumps(build(), indent=2)
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(receipt, encoding="utf-8")
    print(receipt)
