"""Extract the explicitly requested original animation, without AI redrawing.

Video decoding is FFmpeg; only the recorded white surround is made transparent.
Never writes to the supplied source video. Public provenance contains its hash,
not the user's filesystem path or the screen recording itself.
"""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE_FRAMES = [3, 9, 15, 21, 27, 33]  # zero-based: authored poses 1..6
CROP = (420, 180, 635, 495)  # padding includes the complete plume; left draft ends before x420
ANCHOR = [128.0, 298.0]  # source stage x548/y478; one fixed coordinate for all poses
REFERENCE_HEIGHT = 286.0
STYLE = "USER_VIDEO_COURIER_20261016"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def connected(mask, seeds):
    h, w = mask.shape
    result = np.zeros_like(mask)
    queue = deque()
    for y, x in seeds:
        if 0 <= y < h and 0 <= x < w and mask[y, x] and not result[y, x]:
            result[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not result[ny, nx]:
                result[ny, nx] = True
                queue.append((ny, nx))
    return result


def matte(image):
    rgb = np.array(image.convert("RGB"), dtype=np.float32)
    h, w = rgb.shape[:2]
    white = rgb.min(axis=2) >= 239
    border = [(0,x) for x in range(w)] + [(h-1,x) for x in range(w)]
    border += [(y,0) for y in range(h)] + [(y,w-1) for y in range(h)]
    surround = connected(white, border)
    foreground = ~surround
    # Preserve enclosed white eyes/clothing. Discard detached recording specks.
    central = connected(foreground, [(90,130), (140,130), (210,125)])
    if central.sum() < 5000:
        raise ValueError("Character seed did not locate the complete body")
    opaque = central.copy()
    for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
        opaque &= np.roll(central, (dy,dx), axis=(0,1))
    alpha = central.astype(np.float32)
    edge = central & ~opaque
    # Local white-unmatting of only the perimeter; interior RGB is untouched.
    best = np.full((h,w), 999.0)
    nearest = rgb.copy()
    for dy in range(-3,4):
        for dx in range(-3,4):
            if not (dy or dx): continue
            valid = np.roll(opaque, (dy,dx), axis=(0,1)) & edge
            distance = float(dx*dx + dy*dy)
            take = valid & (distance < best)
            nearest[take] = np.roll(rgb, (dy,dx), axis=(0,1))[take]
            best[take] = distance
    direction = 255-nearest
    inferred = ((255-rgb)*direction).sum(axis=2) / np.maximum((direction*direction).sum(axis=2), 1)
    alpha[edge] = np.clip(inferred[edge], 0.05, 1)
    recovered = rgb.copy()
    recovered[edge] = np.clip((rgb[edge]-255*(1-alpha[edge,None]))/alpha[edge,None], 0, 255)
    recovered[~central] = 0
    rgba = np.dstack([np.rint(recovered).astype(np.uint8), np.rint(alpha*255).astype(np.uint8)])
    return Image.fromarray(rgba), {"opaque_interior_pixels":int(opaque.sum()),
                                  "transparent_pixels":int((rgba[:,:,3]==0).sum()),
                                  "partial_edge_pixels":int(((rgba[:,:,3]>0)&(rgba[:,:,3]<255)).sum())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", type=Path, required=True)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    args = parser.parse_args()
    source_hash = sha(args.video)
    args.review.mkdir(parents=True, exist_ok=True)
    target = ROOT / "assets/faefever_v2/characters"
    output = target / "courier_video_20261016.png"
    standing = target / "courier_video_idle_20261016.png"
    poses, statistics = [], []
    with tempfile.TemporaryDirectory(prefix="solmere-video-") as temporary:
        frames = Path(temporary)
        subprocess.run([str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-i", str(args.video),
                        "-an", "-fps_mode", "passthrough", str(frames/"%03d.png")], check=True)
        for index in SOURCE_FRAMES:
            decoded = frames/("%03d.png" % (index+1))
            with Image.open(decoded) as frame:
                if frame.size != (1024,720): raise ValueError("Source video dimensions changed")
                original = frame.crop(CROP).convert("RGB")
            pose, stats = matte(original)
            poses.append(pose)
            statistics.append({"source_frame":index, "decoded_frame_sha256":sha(decoded), **stats})
            pose.save(args.review/("pose_%02d.png" % len(poses)))
            original.save(args.review/("source_crop_%02d.png" % len(poses)))
    width, height = poses[0].size
    atlas = Image.new("RGBA", (width*len(poses),height), (0,0,0,0))
    for index, pose in enumerate(poses): atlas.paste(pose, (index*width,0))
    atlas.save(output)
    poses[4].save(standing)  # narrowest leg separation; same author, fixed anchor
    geometry = {"schema":2,"source_kind":"user_video_extraction","source_video_sha256":source_hash,
                "source_sha256":sha(output),"source_fps":30,"authored_fps":5,
                "cycle_seconds":1.2,"cycle_distance_px":142.0,
                "crop_source_px":list(CROP),"frame_count":6,
                "idle":{"key":"CHAR_courier","foot_anchor_px":ANCHOR,"reference_height_px":REFERENCE_HEIGHT},
                "frames":[{"key":"CHAR_courier_walk_"+str(i),"region":[i*width,0,width,height],
                           "foot_anchor_px":ANCHOR,"reference_height_px":REFERENCE_HEIGHT,
                           "source_frame":SOURCE_FRAMES[i],"duration_seconds":0.2} for i in range(6)]}
    (target/"courier_walk_regions.json").write_text(json.dumps(geometry,indent=2)+"\n",encoding="utf-8")
    manifest_path = ROOT/"assets/faefever_v2/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for key in list(manifest["assets"]):
        if key.startswith("CHAR_courier_walk_"): del manifest["assets"][key]
    def entry(path, role, region=None):
        im = Image.open(path)
        data = {"path":"res://"+path.relative_to(ROOT).as_posix(),"kind":"character",
                "ai_generated":False,"source_kind":"user_video_extraction","style_lock":STYLE,
                "authority":"Direct user instruction: extract the right-hand colored animation and replace the courier, 2026-10-16.",
                "source_video_sha256":source_hash,"sha256":sha(path),"source_sha256":sha(path),
                "native_dimensions":list(im.size),"mode":"RGBA","source_frames":SOURCE_FRAMES,
                "review_status":"source_frames_inspected_runtime_review_pending","role":role}
        if region is not None: data["region"] = region
        return data
    manifest["assets"]["CHAR_courier"] = entry(standing,"courier_idle")
    manifest["assets"]["CHAR_courier_walk"] = entry(output,"courier_walk_sheet")
    for frame in geometry["frames"]:
        manifest["assets"][frame["key"]] = entry(output,"courier_walk_frame",frame["region"])
    manifest["authority"] = manifest["authority"].split(" Targeted 2026-10-16 exception:")[0]+" Targeted 2026-10-16 exception: original user-video courier replaces generated courier only."
    manifest["user_animation_override"] = {"source_kind":"user_video_extraction","style_lock":STYLE,
                                           "source_video_sha256":source_hash,"frame_count":6,
                                           "provenance":"res://assets/faefever_v2/characters/courier_video_provenance_20261016.json"}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    receipt = {"source_video_sha256":source_hash,"original_modified":sha(args.video)!=source_hash,
               "source_dimensions":[1024,720],"source_fps":30,"source_duration_seconds":100/30,
               "source_frames":SOURCE_FRAMES,"crop":list(CROP),"authored_fps":5,"loop_seconds":1.2,
               "method":"Original video frames; border-connected white removal preserves enclosed white detail; local edge white-unmatting; common unscaled canvas. No generative repaint.",
               "excluded":"Left draft, frame numbers, recording UI and final system-overlay frames.",
               "ai_generated":False,"assets":{output.name:sha(output),standing.name:sha(standing)},"frames":statistics}
    (target/"courier_video_provenance_20261016.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    poses[0].save(args.review/"transparent-loop.png",save_all=True,append_images=poses[1:],duration=200,loop=0,disposal=0,blend=0)
    previews = args.review/"preview-frames"
    previews.mkdir(exist_ok=True)
    contact = Image.new("RGB",(width*6,height+26),(218,229,218))
    for i,pose in enumerate(poses):
        stage = Image.new("RGB",pose.size,(218,229,218))
        stage.paste(pose,mask=pose.getchannel("A"))
        stage.save(previews/("%02d.png" % (i+1)))
        contact.paste(stage,(i*width,26))
    draw=ImageDraw.Draw(contact)
    for i in range(6): draw.text((i*width+12,6),"Pose "+str(i+1),fill=(35,40,35))
    contact.save(args.review/"cutout-contact.png")
    subprocess.run([str(args.ffmpeg),"-y","-hide_banner","-loglevel","error","-stream_loop","2","-framerate","5",
                    "-i",str(previews/"%02d.png"),"-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2,scale=iw*2:ih*2:flags=neighbor,fps=30",
                    "-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart",str(args.review/"animation-preview.mp4")],check=True)
    print(json.dumps({"poses":len(poses),"source_unmodified":not receipt["original_modified"],"atlas_sha256":sha(output),"statistics":statistics}))


if __name__ == "__main__": main()
