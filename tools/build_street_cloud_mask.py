"""Build a technical sky-clearance field; never rewrite supplied artwork."""
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'assets/authoring/streets_20261101/community_morning.png'
rgb = np.asarray(Image.open(source).convert('RGB'), dtype=np.int16)
h, w = rgb.shape[:2]
# The original blue sky and two-tone clouds. Warm foreground, foliage and
# dark supports are excluded before a conservative clearance is computed.
sky = (rgb[:,:,1] > rgb[:,:,0] + 8) & (rgb[:,:,2] > rgb[:,:,1] + 3)
sky[455:,:] = False
# Pale/blue architecture, distant land, and source-painted birds stay fixed.
fixed = [(1890,0,2550,530),(2550,436,2760,530),(4150,145,4540,530),
         (6200,125,6575,530),(7880,220,8370,530),(8370,210,8725,530),
         (480,60,655,360),(970,140,1105,230),(1900,110,1980,170),
         (2990,240,3110,300),(3800,180,3960,240),(4620,160,4760,220),
         (0,455,w,640),(2850,395,3570,640),(8900,420,w,640)]
for x0,y0,x1,y1 in fixed: sky[y0:y1,x0:x1]=False
# Erode then blur at quarter scale. The resulting continuous flow field is
# zero well before any object; its original antialias rim never gets pulled.
small = Image.fromarray(np.uint8(sky)*255).resize((w//4,h//4),Image.Resampling.BOX)
small = small.filter(ImageFilter.MinFilter(11)).filter(ImageFilter.GaussianBlur(8))
field = np.asarray(small.resize((w,h),Image.Resampling.BILINEAR)).astype(np.float32)/255
field = np.clip((field-.60)/.40,0,1)
yy = np.arange(h)[:,None]
field *= np.clip((455-yy)/35,0,1) * np.clip((yy-30)/35,0,1)
out = ROOT / 'assets/authoring/street_motion_masks_20261103'
out.mkdir(exist_ok=True)
Image.fromarray(np.uint8(np.rint(field*255))).save(out/'community_cloud_clearance.png')
print('Cloud clearance generated; original panorama unchanged:',out)
