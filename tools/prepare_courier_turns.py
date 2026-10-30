"""Crop approved turn cells without repainting source RGB/alpha; keep provenance."""
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image
import numpy as np
import cv2

p=argparse.ArgumentParser()
p.add_argument('--early',required=True)
p.add_argument('--late',required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
out=root/'assets/authoring/courier_turn_20261031';out.mkdir(exist_ok=True,parents=True)
data={'authorization':'2026-10-31 user permits supplemental generated turn frames; original gait and front idle retained',
      'sources':[],'frames':[]}
for part,source,n in [('early',Path(a.early),2),('late',Path(a.late),3)]:
 im=Image.open(source).convert('RGBA')
 shutil.copy2(source,out/f'{part}_sheet.png')
 data['sources'].append({'file':f'{part}_sheet.png','sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
 for i in range(n):
  cell=im.crop((i*im.width//n,0,(i+1)*im.width//n,im.height))
  mask=(np.asarray(cell)[:,:,3]>64).astype('uint8')
  count,labels,stats,centers=cv2.connectedComponentsWithStats(mask)
  x,y,w,h,area=stats[1+np.argmax(stats[1:,4])]
  sprite=cell.crop((max(0,x-2),max(0,y-2),min(cell.width,x+w+2),min(cell.height,y+h+2)))
  cap=np.asarray(sprite)[:int(sprite.height*.33)]
  mask=(cap[:,:,3]>128)&(cap[:,:,0]>45)&(cap[:,:,0]<135)&(cap[:,:,1]>30)&(cap[:,:,1]<100)&(cap[:,:,2]<65)
  cy,cx=np.where(mask)
  center=(np.percentile(cx,2)+np.percentile(cx,98))*.5
  index=len(data['frames']);name=f'turn_{index}.png';sprite.save(out/name)
  data['frames'].append({'path':'res://assets/authoring/courier_turn_20261031/'+name,
        'reference_height_px':sprite.height,'foot_anchor_px':[float(center)+sprite.height*15/704,sprite.height-2]})
(out/'turns.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print('Prepared',len(data['frames']),'turn frames. Authored endpoints are not replaced.')
