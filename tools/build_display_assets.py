"""User-authorized local outer-white alpha cleanup, 2026-10-01.

Original files, decoded RGB, full canvas and colored interior pixels remain
unchanged. The JPEG-only second pass reaches at most 3 original-image pixels
from the established external transparent component. No image-model input.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation, distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
EDGE_RADIUS = 3.0
EDGE_MIN = 228
EDGE_SPREAD = 20


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clean_alpha(original, jpeg=False):
    rgb = original[:, :, :3]
    low = rgb.min(axis=2)
    spread = rgb.max(axis=2).astype(np.int16) - low.astype(np.int16)
    candidate = ((low >= 247) & (spread <= 6)) | (original[:, :, 3] == 0)
    seed = np.zeros(candidate.shape, dtype=bool)
    seed[0, :] = candidate[0, :]
    seed[-1, :] = candidate[-1, :]
    seed[:, 0] = candidate[:, 0]
    seed[:, -1] = candidate[:, -1]
    outer = binary_propagation(seed, mask=candidate)
    extra = np.zeros_like(outer)
    if jpeg:
        # Distance is measured once against the old external boundary. It is
        # never recomputed during cleanup, so this cannot progressively erode
        # pale architecture or walk deeper through an internal white region.
        distance = distance_transform_edt(~outer)
        narrow_white = (distance <= EDGE_RADIUS) & (low >= EDGE_MIN) & (spread <= EDGE_SPREAD)
        expanded = binary_propagation(outer, mask=outer | narrow_white)
        extra = expanded & ~outer
    mask = outer | extra
    result = original.copy()
    result[:, :, 3][mask] = 0
    assert np.array_equal(result[:, :, :3], original[:, :, :3])
    assert np.array_equal(result[~mask], original[~mask])
    return result, outer, extra


def build(destination):
    destination.mkdir(parents=True, exist_ok=True)
    data = json.loads((ROOT / 'data/game.json').read_text(encoding='utf8'))
    records = []
    for location in data['locations']:
        name = location['asset']
        source = ROOT / 'assets/locked_user' / name
        out = destination / (name + '.png')
        source_hash = digest(source)
        original = np.array(Image.open(source).convert('RGBA'))
        jpeg = source.suffix.lower() in ('.jpg', '.jpeg')
        result, outer, extra = clean_alpha(original, jpeg)
        Image.fromarray(result).save(out)
        assert digest(source) == source_hash
        records.append({
            'location': location['id'], 'source': 'assets/locked_user/' + name,
            'display': 'assets/display_user/' + out.name,
            'size': [int(original.shape[1]), int(original.shape[0])],
            'source_sha256': source_hash, 'display_sha256': digest(out),
            'pixels_cleared': int(((original[:, :, 3] > 0) & (outer | extra)).sum()),
            'baseline_pixels_cleared': int(((original[:, :, 3] > 0) & outer).sum()),
            'additional_jpeg_edge_pixels': int(extra.sum()),
            'edge_radius_source_pixels': EDGE_RADIUS if jpeg else 0,
            'rgb_unchanged': True, 'outside_authorized_alpha_mask_unchanged': True,
            'interior_unchanged': True,
        })
        print(location['id'], 'baseline', records[-1]['baseline_pixels_cleared'],
              'narrow JPEG edge', records[-1]['additional_jpeg_edge_pixels'])
    return {
        'version': 2,
        'authorization': 'User explicitly allowed local outer-white removal and narrow externally connected JPEG white-edge refinement on 2026-10-01. Originals retained. RGB unchanged. No AI input.',
        'method': '8-bit RGBA; baseline RGB min>=247 and range<=6, plus existing alpha=0; four-neighbour border-connected component. JPEG only: RGB min>=228, range<=20, Euclidean distance<=3 source pixels from the fixed baseline outer component, still four-neighbour connected. Only alpha set to zero; full dimensions retained.',
        'edge_refinement': {'jpeg_only': True, 'minimum_rgb': EDGE_MIN, 'maximum_rgb_range': EDGE_SPREAD, 'maximum_source_pixel_radius': EDGE_RADIUS, 'connectivity': 4, 'distance_reference': 'fixed baseline outer component; never iteratively widened'},
        'assets': records,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--preview-dir', type=Path, help='Write candidate PNGs and manifest here without changing runtime assets.')
    args = parser.parse_args()
    destination = args.preview_dir if args.preview_dir else ROOT / 'assets/display_user'
    manifest = build(destination)
    path = destination / 'DISPLAY_DERIVATIVES.json' if args.preview_dir else ROOT / 'docs/DISPLAY_DERIVATIVES.json'
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
