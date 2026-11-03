"""Build technical alpha masks; never repaint or resave supplied RGB files.

The runtime samples the original JPEG and this independently generated mask.
Small isolated JPEG ringing is removed before the dialogue-only outline.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter

root = Path(__file__).resolve().parents[1]
folder = root / 'assets/authoring/dialogue_20261104'
records = {}
for source in folder.glob('*_source.jpg'):
    rgb = np.array(Image.open(source).convert('RGB'))
    # Supplied white clothing is blue/cream tinted; paper white is neutral.
    mask = Image.fromarray(np.uint8(rgb.min(axis=2) < 248) * 255)
    mask = mask.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MinFilter(3))
    # Retain an antialiased contour, with the matte safely inside the pigment.
    mask = mask.filter(ImageFilter.GaussianBlur(0.45))
    dest = source.with_name(source.stem + '_mask.png')
    mask.save(dest)
    records[source.name] = {'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                            'mask': dest.name, 'source_pixels_unchanged': True}
(folder / 'provenance.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
