"""Reproduce the approved five original black-matted courier poses.

No AI, repaint, interpolation or source-video writes. Public provenance contains
hashes/coordinates only; decoder logs and source crops remain in ignored review.
Runtime registration is explicit and limited to the courier roles.
"""
import argparse
from collections import deque
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VIDEO_SHA = "f8af71a6daa7a620aa07887528da4e7151e8f55320c525c7bf7d9122f1b3f4a5"
APPROVED_ATLAS_SHA = "1e21e4a48fba1ae3941134da42c38ce652c164a7b795c6ac517da5a745906b9c"
CROP = (170, 135, 490, 635)
ANCHOR = [180.0, 482.0]
REFERENCE_HEIGHT = 463.0
SOURCE_FPS = 8
SOURCE_FRAMES = list(range(5))
STYLE = "USER_VIDEO_COURIER_20261017"
HAIR_HOLE_ROI = (365, 140, 454, 241)
OBSERVED_BAG_GAP_ROIS = {0: [(328, 405, 348, 448)],
                        3: [(295, 415, 330, 455)],
                        4: [(329, 428, 348, 467)]}
ATLAS_NAME = "courier_video_20261017.png"
IDLE_NAME = "courier_video_idle_20261017.png"
PROVENANCE_NAME = "courier_video_provenance_20261017.json"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def connected(mask, seeds, diagonal=False):
    height, width = mask.shape
    result = np.zeros_like(mask)
    queue = deque()
    for y, x in seeds:
        if 0 <= y < height and 0 <= x < width and mask[y, x] and not result[y, x]:
            result[y, x] = True
            queue.append((y, x))
    neighbors = ((-1, 0), (1, 0), (0, -1), (0, 1))
    if diagonal:
        neighbors += ((-1, -1), (-1, 1), (1, -1), (1, 1))
    while queue:
        y, x = queue.popleft()
        for dy, dx in neighbors:
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not result[ny, nx]:
                result[ny, nx] = True
                queue.append((ny, nx))
    return result


def component_records(mask):
    pending = mask.copy()
    result = []
    while pending.any():
        y, x = np.argwhere(pending)[0]
        component = connected(pending, [(int(y), int(x))])
        ys, xs = np.where(component)
        result.append((component, {"area": int(component.sum()),
                      "bbox_source": [int(xs.min()) + CROP[0], int(ys.min()) + CROP[1],
                                      int(xs.max()) + CROP[0] + 1, int(ys.max()) + CROP[1] + 1]}))
        pending[component] = False
    return result


def matte(original, frame_index):
    """Spatial black-matte recovery; protect dark ink, boots and pale interiors."""
    rgb = np.asarray(original.convert("RGB"), dtype=np.float32)
    height, width = rgb.shape[:2]
    if (width, height) != (320, 500):
        raise ValueError("Expected the unchanged shared320x500 source crop")
    black = rgb.max(axis=2) <= 8
    border = [(0, x) for x in range(width)] + [(height - 1, x) for x in range(width)]
    border += [(y, 0) for y in range(height)] + [(y, width - 1) for y in range(height)]
    surround = connected(black, border)
    foreground = ~surround
    hair_holes, bag_gaps, preserved_dark_components = [], [], []
    removed_hole_mask = np.zeros_like(foreground)
    for component, record in component_records(black & ~surround):
        x1, y1, x2, y2 = record["bbox_source"]
        hair = (record["area"] >= 12 and HAIR_HOLE_ROI[0] <= x1 < x2 <= HAIR_HOLE_ROI[2]
                and HAIR_HOLE_ROI[1] <= y1 < y2 <= HAIR_HOLE_ROI[3])
        bag = any(roi[0] <= x1 < x2 <= roi[2] and roi[1] <= y1 < y2 <= roi[3]
                  for roi in OBSERVED_BAG_GAP_ROIS.get(frame_index, []))
        if hair or bag:
            foreground[component] = False
            removed_hole_mask |= component
            (hair_holes if hair else bag_gaps).append(record)
        else:
            preserved_dark_components.append(record)
    central = connected(foreground, [(430 - CROP[1], 350 - CROP[0]),
                                   (300 - CROP[1], 350 - CROP[0])], diagonal=True)
    if central.sum() < 45000:
        raise ValueError("Original torso/hair seeds did not locate the full character")
    discarded = foreground & ~central
    if ((rgb.max(2) > 40) & discarded).sum() > 10:
        raise ValueError("Detached visible source detail needs review instead of deletion")
    core = central.copy()
    for _ in range(3):
        previous = core.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            core &= np.roll(previous, (dy, dx), axis=(0, 1))
    edge = central & ~core
    nearest = rgb.copy()
    best = np.full((height, width), np.inf)
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            if not (dy or dx):
                continue
            valid = np.roll(core, (dy, dx), axis=(0, 1)) & edge
            distance = dx * dx + dy * dy
            take = valid & (distance < best)
            nearest[take] = np.roll(rgb, (dy, dx), axis=(0, 1))[take]
            best[take] = distance
    inferred = (rgb * nearest).sum(axis=2) / np.maximum((nearest * nearest).sum(axis=2), 1)
    inferred = np.maximum(inferred, rgb.max(axis=2) / 255.0)
    alpha = central.astype(np.float32)
    has_local_color = edge & np.isfinite(best)
    alpha[has_local_color] = np.clip(inferred[has_local_color], 0.04, 1)
    recovered = rgb.copy()
    recovered[has_local_color] = np.clip(rgb[has_local_color] / alpha[has_local_color, None], 0, 255)
    recovered[~central] = 0
    rgba = np.dstack([np.rint(recovered).astype(np.uint8), np.rint(alpha * 255).astype(np.uint8)])
    if not np.array_equal(rgba[core, :3], rgb[core].astype(np.uint8)) or not (rgba[core, 3] == 255).all():
        raise ValueError("Opaque authored source pixels changed")
    if not (rgba[removed_hole_mask, 3] == 0).all():
        raise ValueError("Observed background holes retained a matte")
    if any(edge.any() for edge in [rgba[0, :, 3], rgba[-1, :, 3], rgba[:, 0, 3], rgba[:, -1, 3]]):
        raise ValueError("The shared crop clipped an original pose")
    recompose = rgba[:, :, :3].astype(float) * rgba[:, :, 3:4] / 255.0
    error = np.abs(recompose[central] - rgb[central])
    if error.max() > 1.1:
        raise ValueError("Black-matte recovery clipped a recorded color channel")
    ys, xs = np.where(rgba[:, :, 3] > 0)
    bright = core & (rgb.min(2) > 185)
    boot_roi = np.zeros_like(core)
    boot_roi[470 - CROP[1]:630 - CROP[1], 210 - CROP[0]:455 - CROP[0]] = True
    boots = core & boot_roi & (rgb.max(2) < 110)
    eye_roi = np.zeros_like(core)
    eye_roi[240 - CROP[1]:355 - CROP[1], 320 - CROP[0]:455 - CROP[0]] = True
    eyes = core & eye_roi & (rgb.max(2) <= 35)
    return Image.fromarray(rgba), {"alpha_bbox_crop": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1],
                                  "opaque_unchanged_core_pixels": int(core.sum()),
                                  "preserved_bright_core_pixels": int(bright.sum()),
                                  "preserved_dark_boot_core_pixels": int(boots.sum()),
                                  "preserved_dark_eye_core_pixels": int(eyes.sum()),
                                  "transparent_pixels": int((rgba[:, :, 3] == 0).sum()),
                                  "partial_edge_pixels": int(((rgba[:, :, 3] > 0) & (rgba[:, :, 3] < 255)).sum()),
                                  "detached_low_intensity_pixels_discarded": int(discarded.sum()),
                                  "observed_hair_background_holes_made_transparent": hair_holes,
                                  "observed_bag_strap_background_gaps_made_transparent": bag_gaps,
                                  "enclosed_dark_components_preserved_not_assumed_background": preserved_dark_components,
                                  "black_recomposition_foreground_mean_abs_error": float(error.mean()),
                                  "black_recomposition_foreground_max_abs_error": float(error.max())}


def png_bytes(image):
    stream = io.BytesIO()
    image.save(stream, format="PNG")
    return stream.getvalue()


def preserve_or_write(path, content):
    if path.exists():
        if path.read_bytes() != content:
            raise ValueError("Existing versioned output differs; preserve/review it: " + path.name)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def geometry(atlas_sha):
    return {"schema": 2, "source_kind": "user_video_extraction", "source_video_sha256": EXPECTED_VIDEO_SHA,
            "source_sha256": atlas_sha, "source_fps": SOURCE_FPS, "authored_fps": SOURCE_FPS,
            "cycle_seconds": 0.625, "source_cycle_seconds": 0.625,
            "crop_source_px": list(CROP), "frame_count": 5,
            "idle": {"key": "CHAR_courier", "source_frame": 2, "foot_anchor_px": ANCHOR, "reference_height_px": REFERENCE_HEIGHT},
            "frames": [{"key": "CHAR_courier_walk_" + str(i), "region": [i * 320, 0, 320, 500],
                        "foot_anchor_px": ANCHOR, "reference_height_px": REFERENCE_HEIGHT,
                        "source_frame": i, "timestamp_seconds": i / 8, "duration_seconds": 0.125} for i in SOURCE_FRAMES]}


def register(asset_dir, frame_geometry, receipt):
    expected_assets = ROOT / "assets/faefever_v2/characters"
    if asset_dir.resolve() != expected_assets.resolve():
        raise ValueError("Explicit runtime registration is limited to the selected courier asset directory")
    manifest_path = ROOT / "assets/faefever_v2/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    before_other = {key: value for key, value in manifest["assets"].items()
                    if key not in {"CHAR_courier", "CHAR_courier_walk"} and not key.startswith("CHAR_courier_walk_")}
    for key in list(manifest["assets"]):
        if key.startswith("CHAR_courier_walk_"):
            del manifest["assets"][key]

    def entry(name, role, region=None, source_frame=None):
        with Image.open(asset_dir / name) as image:
            dimensions = list(image.size)
        digest = sha(asset_dir / name)
        data = {"path": "res://assets/faefever_v2/characters/" + name, "kind": "character", "ai_generated": False,
                "source_kind": "user_video_extraction", "style_lock": STYLE,
                "authority": "Direct user instruction: replace courier with supplied original walking animation, 2026-10-17.",
                "source_video_sha256": EXPECTED_VIDEO_SHA, "sha256": digest, "source_sha256": digest,
                "native_dimensions": dimensions, "mode": "RGBA", "source_frames": SOURCE_FRAMES,
                "source_fps": SOURCE_FPS, "authored_fps": SOURCE_FPS,
                "review_status": "approved_candidate_source_frames_inspected_runtime_review_pending", "role": role}
        if region is not None:
            data["region"] = region
        if source_frame is not None:
            data["source_frame"] = source_frame
            data["duration_seconds"] = 0.125
        return data

    manifest["assets"]["CHAR_courier"] = entry(IDLE_NAME, "courier_idle", source_frame=2)
    manifest["assets"]["CHAR_courier_walk"] = entry(ATLAS_NAME, "courier_walk_sheet")
    for frame in frame_geometry["frames"]:
        manifest["assets"][frame["key"]] = entry(ATLAS_NAME, "courier_walk_frame", frame["region"], frame["source_frame"])
    manifest["user_animation_override"] = {"source_kind": "user_video_extraction", "style_lock": STYLE,
                                           "source_video_sha256": EXPECTED_VIDEO_SHA, "frame_count": 5,
                                           "source_fps": SOURCE_FPS, "authored_fps": SOURCE_FPS, "cycle_seconds": 0.625,
                                           "provenance": "res://assets/faefever_v2/characters/" + PROVENANCE_NAME}
    qualifier = " Targeted 2026-10-17 courier exception: latest original five-frame user-video replaces only courier idle/walk; old source assets remain preserved."
    if qualifier not in manifest.get("authority", ""):
        manifest["authority"] = manifest.get("authority", "") + qualifier
    after_other = {key: value for key, value in manifest["assets"].items()
                   if key not in {"CHAR_courier", "CHAR_courier_walk"} and not key.startswith("CHAR_courier_walk_")}
    if before_other != after_other:
        raise ValueError("An unrelated asset role changed during courier registration")
    geometry_path = asset_dir / "courier_walk_regions.json"
    geometry_path.write_text(json.dumps(frame_geometry, indent=2) + "\n", encoding="utf-8")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", type=Path, required=True)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    parser.add_argument("--asset-dir", type=Path, default=ROOT / "assets/faefever_v2/characters")
    parser.add_argument("--register", action="store_true")
    args = parser.parse_args()
    original_sha = sha(args.video)
    if original_sha != EXPECTED_VIDEO_SHA:
        raise ValueError("This versioned extractor only accepts the reviewed original video SHA")
    args.review.mkdir(parents=True, exist_ok=True)
    poses, records = [], []
    with tempfile.TemporaryDirectory(prefix="original-courier-", dir=args.review) as temporary:
        decoded = Path(temporary)
        result = subprocess.run([str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-i", str(args.video),
                                 "-map", "0:v:0", "-an", "-fps_mode", "passthrough", str(decoded / "%03d.png")],
                                capture_output=True, text=True, encoding="utf-8", errors="replace")
        (args.review / "decode.log").write_text(result.stderr, encoding="utf-8")
        if result.returncode:
            raise ValueError("Original video decoding failed; see private review log")
        frames = sorted(decoded.glob("*.png"))
        if len(frames) != 5:
            raise ValueError("The complete original video must contain exactly five frames")
        for index, path in enumerate(frames):
            full = Image.open(path).convert("RGB")
            if full.size != (960, 720):
                raise ValueError("Original source dimensions changed")
            original = full.crop(CROP)
            pose, stats = matte(original, index)
            poses.append(pose)
            preserve_or_write(args.review / f"source_{index:02d}.png", path.read_bytes())
            preserve_or_write(args.review / f"source_crop_{index:02d}.png", png_bytes(original))
            preserve_or_write(args.review / f"pose_{index:02d}.png", png_bytes(pose))
            records.append({"source_frame": index, "timestamp_seconds": index / 8, "duration_seconds": 0.125,
                            "decoded_png_sha256": sha(path), "rgba_pixels_sha256": hashlib.sha256(pose.tobytes()).hexdigest(), **stats})
    timing = subprocess.run([str(args.ffmpeg), "-hide_banner", "-i", str(args.video), "-map", "0:v:0",
                             "-vf", "showinfo", "-an", "-f", "null", "NUL"],
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
    (args.review / "timestamps.log").write_text(timing.stderr, encoding="utf-8")
    pts = [float(value) for value in re.findall(r"\bn:\s*\d+\s+pts:\s*\d+\s+pts_time:([0-9.]+)", timing.stderr)]
    if timing.returncode or pts != [0, 0.125, 0.25, 0.375, 0.5]:
        raise ValueError("Actual original PTS does not match the approved eight-fps chronology")
    if sha(args.video) != original_sha:
        raise ValueError("The immutable source changed during extraction")
    atlas = Image.new("RGBA", (1600, 500))
    for index, pose in enumerate(poses):
        atlas.paste(pose, (index * 320, 0))
    atlas_bytes, idle_bytes = png_bytes(atlas), png_bytes(poses[2])
    atlas_sha = hashlib.sha256(atlas_bytes).hexdigest()
    if atlas_sha != APPROVED_ATLAS_SHA:
        raise ValueError("Reproduced atlas differs from the approved source-faithful candidate")
    receipt = {"schema": 2, "source_video_sha256": original_sha, "source_bytes": args.video.stat().st_size,
               "source_dimensions": [960, 720], "source_fps": SOURCE_FPS, "authored_fps": SOURCE_FPS,
               "source_duration_seconds": 0.625, "loop_seconds": 0.625, "source_frames": SOURCE_FRAMES,
               "actual_frame_pts_seconds": pts, "crop": list(CROP), "shared_foot_anchor_px": ANCHOR,
               "reference_height_px": REFERENCE_HEIGHT, "idle_source_frame": 2,
               "idle_source_note": "Unmodified original walking pose2, not a newly authored idle animation.",
               "method": "Original chronological frames; border-connected maxRGB<=8 black matte with observed curl/bag-gap ROIs, enclosed dark ink/boots protected, three-pixel local black-unmatting and maxRGB/255 alpha floor. Opaque RGB unchanged. No AI, scaling, interpolation, repaint or replacement geometry.",
               "hair_background_hole_observed_roi_source_px": list(HAIR_HOLE_ROI),
               "bag_background_gap_observed_rois_source_px": OBSERVED_BAG_GAP_ROIS,
               "original_modified": False, "ai_generated": False,
               "review_status": "approved_candidate_source_frames_inspected_runtime_review_pending",
               "limits": ["H264 source lacks original alpha; very low-intensity boundary pigment/exterior black ink is ambiguous.",
                          "Enclosed dark components outside observed background ROIs remain preserved, not automatically interpreted as holes.",
                          "Five original poses and last-to-first cadence still require real runtime review; no new inbetween poses.",
                          "Stationary source supplies no world travel distance; game gait/footstep calibration is separate."],
               "extractor": {"path": "tools/extract_video_courier_20261017.py", "sha256": sha(Path(__file__)),
                             "ffmpeg_sha256": sha(args.ffmpeg), "numpy_version": np.__version__},
               "assets": {ATLAS_NAME: atlas_sha, IDLE_NAME: hashlib.sha256(idle_bytes).hexdigest()}, "frames": records}
    frame_geometry = geometry(atlas_sha)
    preserve_or_write(args.asset_dir / ATLAS_NAME, atlas_bytes)
    preserve_or_write(args.asset_dir / IDLE_NAME, idle_bytes)
    preserve_or_write(args.asset_dir / PROVENANCE_NAME, (json.dumps(receipt, indent=2) + "\n").encode("utf-8"))
    preserve_or_write(args.review / "geometry_candidate.json", (json.dumps(frame_geometry, indent=2) + "\n").encode("utf-8"))
    if args.register:
        register(args.asset_dir, frame_geometry, receipt)
    print(json.dumps({"source_unmodified": True, "original_frames": len(poses), "source_fps": SOURCE_FPS,
                      "cycle_seconds": 0.625, "atlas_sha256": atlas_sha, "registered": args.register,
                      "runtime_motion_review_pending": True}, indent=2))


if __name__ == "__main__":
    main()
