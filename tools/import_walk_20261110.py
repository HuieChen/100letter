"""Extract the supplied 6 fps MOV; preserve source order and shared registration.

Usage: python tools/import_walk_20261110.py SOURCE_MOV FFMPEG
Only derived frames enter the repository. Never writes the source movie.
"""
import hashlib, json, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
source, ffmpeg = Path(sys.argv[1]), sys.argv[2]
out = root / 'assets/authoring/courier_walk_20261110'
out.mkdir(parents=True, exist_ok=True)
frames = []
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run([ffmpeg, '-v', 'error', '-i', str(source), '-vf',
                    'crop=1400:2200:700:500', '-fps_mode', 'passthrough',
                    str(Path(tmp)/'frame_%02d.png')], check=True)
    inputs = sorted(Path(tmp).glob('frame_*.png'))
    assert len(inputs) == 12, 'Unexpected source duration/frame count'
    for index, path in enumerate(inputs):
        # Shared crop avoids frame-by-frame scaling or registration jitter.
        rgb = np.array(Image.open(path).convert('RGB').crop((80,230,1280,2150)))
        # Decoded HEVC has a black matte. Only near-black matte is removed;
        # character pigments remain unchanged, including the dark boots.
        alpha = np.clip((rgb.max(2).astype(float)-2)/10, 0, 1)
        rgba = np.dstack([rgb, np.rint(alpha*255).astype('uint8')])
        target = out/f'walk_{index:02d}.png'
        Image.fromarray(rgba).save(target)
        frames.append(dict(path='res://'+target.relative_to(root).as_posix(),
                           duration_seconds=1/6, source_frame=index,
                           reference_height_px=1830, foot_anchor_px=[770,1905],
                           sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
(out/'walk.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    fps=6, source_size=[4096,3074], shared_source_crop=[780,730,1200,1920],
    ai_generated=False, frames=frames), indent=2)+'\n', encoding='utf-8')
print(f'Imported {len(frames)} original frames at 6 fps')
