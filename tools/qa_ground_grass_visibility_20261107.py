"""Measure normal-scale grass blade-edge excursion from the companion Godot fixture.
Example: python tools/qa_ground_grass_visibility_20261107.py --evidence-dir PATH
Needs Pillow and NumPy. The original captures are never modified. This reports
image displacement and rigid guards; it does not claim human visual acceptance.
"""
from pathlib import Path
from PIL import Image
import numpy as np,json,argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence-dir',type=Path,required=True)
parser.add_argument('--after',default='after')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
p=args.evidence_dir;after_name=args.after;data=json.loads((p/'baseline/capture.json').read_text())
after_capture=json.loads((p/after_name/'capture.json').read_text())
guards=[{'group':g['id'],**guard} for g in after_capture['groups'] for guard in g['guards']]
expected={(g['id'],t['name']) for g in data['groups'] for t in g['targets']}
actual={(g['id'],t['name']) for g in after_capture['groups'] for t in g['targets']}
if expected!=actual:raise SystemExit('Incomplete or mismatched baseline/after target inventory')
def measure(a):
 rgb=a[...,:3]/255.;r,g,b=rgb.transpose(2,0,1)
 return np.maximum(0,np.minimum(g-r+0.12,np.minimum(r,g)-b-0.09))
def percentile(xs,weights,q):
 if weights.sum()<.001:return None
 c=np.cumsum(weights);return float(np.interp(q*c[-1],c,xs))
rows=[]
for group in data['groups']:
 if not (p/after_name/group['id']).exists():raise SystemExit('Missing after images for '+group['id'])
 for target in group['targets']:
  result={"group":group['id'],"name":target['name']}
  for kind in ['baseline','after']:
   frames=np.stack([np.asarray(Image.open(p/(after_name if kind=='after' else kind)/group['id']/(target['name']+f'_{n:02}.png')).convert('RGB')) for n in range(17)])
   special={"small_1015":(17,25),"fountain_left":(5,25),"fountain_right":(27,29),"chair_blades":(51,43)}
   if target['name'] in special:
    x,y=special[target['name']];reference=np.asarray(Image.open(p/'baseline'/group['id']/(target['name']+'_00.png')).convert('RGB'))[y,x,:3].astype(float)
    pigment=np.maximum(0,1-np.linalg.norm(frames.astype(float)-reference,axis=3)/65.0)
   else: pigment=np.stack([measure(a) for a in frames])
   h,w=pigment[0].shape
   # Exclude a 5-pixel crop border and bottom third; independently observed free blade tips.
   occupied=[y for y in range(5,h-5) if pigment[0,y,2:-2].sum()>.15]
   ys=occupied[:max(1,round(len(occupied)*.70))]
   edges=[];centroids=[];edges4=[]
   for y in ys:
    weights=pigment[:,y,:].copy();weights[:,:2]=0;weights[:,-2:]=0
    if np.any(weights.sum(axis=1)<.05):continue
    for q in [.15,.85]:
     pos=[percentile(np.arange(w),v,q) for v in weights];edges.append(np.ptp(pos));edges4.append(np.ptp(pos[:9]))
    c=[float((np.arange(w)*v).sum()/v.sum()) for v in weights];centroids.append(np.ptp(c))
   result[kind]={"blade_rows":len(centroids),"four_second_median_edge_excursion_screen_px":round(float(np.median(edges4)),3) if edges4 else None,"four_second_p90_edge_excursion_screen_px":round(float(np.quantile(edges4,.9)),3) if edges4 else None,"median_edge_excursion_screen_px":round(float(np.median(edges)),3) if edges else None,"p90_edge_excursion_screen_px":round(float(np.quantile(edges,.9)),3) if edges else None,"median_row_centroid_excursion_screen_px":round(float(np.median(centroids)),3) if centroids else None}
  rows.append(result)
(args.output or p/('displacements.json' if after_name=='after' else 'displacements_'+after_name+'.json')).write_text(json.dumps({'guards':guards,'rigid_guard_failures':[g for g in guards if g['max_changed_pixels']>0],"method":"Source-observed blade-tip crops from actual 1280x720 Road render, independent olive/green pigment chroma, with four source-observed color references for brown/green tips; upper occupied blade rows only. Per row, 15th/85th pigment quantile edges tracked across 0..8 s; reported median and p90 peak-to-peak excursion in real screen pixels. These are image measurements, not shader displacement metadata or changed-pixel counts. No single threshold is claimed to prove human visibility.","rows":rows},indent=2))
for r in rows:print(r['group'],r['name'],r['baseline']['median_edge_excursion_screen_px'],r['after']['median_edge_excursion_screen_px'])


if any(g['max_changed_pixels']>0 for g in guards):raise SystemExit('Rigid surface variation requires review')
if any(r['after']['median_edge_excursion_screen_px'] is None for r in rows):raise SystemExit('A blade has no usable measured rows')
