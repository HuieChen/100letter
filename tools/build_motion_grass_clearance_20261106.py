"""Local, reproducible technical masks for the newly inventoried grass tufts.

Only the existing red clearance channel is changed, never displayed artwork.
The other channels and every pixel outside the listed working windows survive.
Run from any directory; output receipt can be given as the first argument.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPECS = {
    "residential": {
        "source": "assets/authoring/streets_20261101/residential_noon.png",
        "source_sha256": "2f8c9b4f88a1e6628441b181b178e39c288773f8e177b89db615233732621b55",
        "source_size": (7431, 640),
        "windows": [(1727,450,1784,515),(2919,480,2953,515),
                    (5331,465,5394,515),(5660,476,5703,515),
                    (5990,467,6049,515),(6820,490,6862,515),
                    (7345,461,7411,515)],
        "supports": [(1774,445,1784,515),(2909,475,2924,515),
                     (5682,476,5703,515),(6844,490,6862,515)],
        # Two stiff rounded cactus stems were accidentally sampled by the old
        # sea field at y484+. They are not part of the new flexible bent grass.
        "stiff_plants": [(5262,461,5298,515)],
    },
    "coastal": {
        "source": "assets/authoring/town_20261029/clean_road_noon.png",
        "source_sha256": "ff0775a5138b3654a32b257c727b4ddf0091eb2135ffe5a2261eead0a9bb38a8",
        "source_size": (5383, 640),
        "windows": [(994,461,1092,515),(4673,480,4712,515),
                    (4739,491,4773,515),(4959,479,4995,515),
                    (5028,482,5076,515),(5302,493,5339,515),
                    (5358,479,5383,515)],
        "supports": [(1080,461,1109,515),(4715,480,4739,515),
                     (4769,491,4779,515)],
    },
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def grow(mask: np.ndarray, count: int) -> np.ndarray:
    for _ in range(count):
        p = np.pad(mask, 1, constant_values=False)
        mask = np.logical_or.reduce([p[y:y+mask.shape[0], x:x+mask.shape[1]]
                                     for y in range(3) for x in range(3)])
    return mask


def distance(mask: np.ndarray, count: int = 10) -> np.ndarray:
    result = np.zeros(mask.shape, dtype=np.uint8)
    for _ in range(count):
        result += mask
        p = np.pad(mask, 1, constant_values=False)
        mask = np.logical_and.reduce([p[y:y+mask.shape[0], x:x+mask.shape[1]]
                                      for y in range(3) for x in range(3)])
    return result


def mark(mask: np.ndarray, box: tuple) -> None:
    x0,y0,x1,y1 = box
    mask[y0:y1,x0:x1] = True


def build(family: str) -> dict:
    spec = SPECS[family]
    source = ROOT/spec["source"]
    source_hash = sha(source)
    if source_hash != spec["source_sha256"]:
        raise ValueError(f"{family}: artwork changed; remeasure grass before rebuilding its mask")
    source_image = Image.open(source)
    if source_image.size != spec["source_size"]:
        raise ValueError(f"{family}: unexpected source dimensions")
    rgb = np.asarray(source_image.convert("RGB"), dtype=np.float32)/255.0
    r,g,b = rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
    image_path = ROOT/f"assets/authoring/street_motion_masks_20261103/{family}_foliage_clearance.png"
    original = np.asarray(Image.open(image_path)).copy()
    if original.dtype != np.uint8 or original.shape[:2] != rgb.shape[:2] or original.ndim not in (2, 3):
        raise ValueError(f"{family}: invalid technical mask dimensions or format")
    if original.ndim == 3 and original.shape[2] not in (3, 4):
        raise ValueError(f"{family}: expected grayscale, RGB or RGBA mask")
    red = original[:,:,0].copy() if original.ndim == 3 else original.copy()
    scope = np.zeros(red.shape, bool)
    for box in spec["windows"]:
        mark(scope, box)
    # Muted morning grass is identified from the brighter canonical noon art.
    # Both green and olive blades carry their complete painted antialias rim.
    plant = ((g-r > .025)&(g-b > .035)) | ((g-r > -.055)&(np.minimum(r,g)-b > .12))
    selected = plant & scope
    allowed = grow(selected, 9)
    hard = np.zeros(red.shape, bool)
    support_scope = np.zeros(red.shape, bool)
    for box in spec["supports"]:
        mark(support_scope, box)
    # Only original dark pole/base, brown wood and the nearby red mailbox.
    # Foreground grass is excluded before dilation, not painted over afterward.
    pole = (np.maximum(np.maximum(r,g),b) < .68)&(b-g > .012)&(b-r > .015)
    wood = (r-g > .055)&(g-b > .035)
    hard |= support_scope & (pole | wood) & ~plant
    for box in spec.get("stiff_plants", []):
        stiff_scope = np.zeros(red.shape, bool)
        mark(stiff_scope, box)
        hard |= stiff_scope & plant
        x0,y0,x1,y1 = box
        mark(scope, (x0-10,y0-10,x1+10,y1))
    hard = grow(hard, 2)
    hard[515:,:] = True
    allowed &= ~hard
    d = distance(allowed).astype(np.float32)
    t = np.clip((d-2)/8, 0, 1)
    release = np.rint(t*t*(3-2*t)*255).astype(np.uint8)
    # The mask may only open exact original blades and their plain backdrop;
    # existing local supports receive a smooth source/destination margin.
    proposed = np.maximum(red, release)
    clearance = distance(~hard).astype(np.float32)
    u = np.clip((clearance-2)/8, 0, 1)
    support_field = np.rint(u*u*(3-2*u)*255).astype(np.uint8)
    proposed = np.minimum(proposed, support_field)
    red[scope] = proposed[scope]
    result = original.copy()
    if result.ndim == 3:
        result[:,:,0] = red
        assert np.array_equal(result[:,:,1:], original[:,:,1:])
    else:
        result = red
    assert np.array_equal(result[~scope], original[~scope])
    assert not np.any(red[hard & scope])
    Image.fromarray(result).save(image_path)
    assert sha(source) == source_hash, "Source artwork changed"
    return {"family":family,"source":spec["source"],"source_sha256":source_hash,
            "mask":str(image_path.relative_to(ROOT)).replace('\\','/'),
            "mask_sha256":sha(image_path),"changed_pixels":int(np.count_nonzero(result!=original)),
            "outside_scope_changed":0,"other_channels_changed":0,
            "grass_scope":spec["windows"],"stiff_plant_guards":spec.get("stiff_plants", []),
            "rigid_support_pixels":int(np.count_nonzero(hard&scope)),
            "source_art_unchanged":True}


if __name__ == "__main__":
    receipt = {"method":"local technical clearance only; no artwork editing", "families":[build(k) for k in SPECS]}
    result = json.dumps(receipt, indent=2)
    if len(sys.argv)>1:
        Path(sys.argv[1]).write_text(result,encoding="utf-8")
    print(result)
