"""Extend the existing technical foreground maps only at the two flower pots.

Original paintings and all previously accepted grass mappings are immutable.
The generated data stores alpha and original same-row background coordinates;
it does not contain newly painted artwork. Requires Pillow and numpy.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/authoring/streets_20261101/community_morning.png'
OUT=ROOT/'assets/authoring/street_motion_masks_20261103'
SOURCE_SHA='bad3d4e903c87b3bd308abb3f21fda565d6cf48c8c02923e488a152ab6c556c5'
SCOPE=(5886,475,5967,516)
OUTSIDE_SHA={
    # Includes the separately validated 2026-11-07 fountain-right technical map.
    'alpha':'993fcb6635348dcadfda879c2d6345ee2137b9937423ae7b5fcae98912f04466',
    'backmap':'e2cc417d34c1847cbaeeb9c7cb2e409ff213cdd6da277bd33e1b5377ba8a6b18',
}
POLYGONS=[
    [(5889,492),(5894,490),(5900,494),(5909,507),(5912,513),(5900,513),(5892,502),(5888,498)],
    [(5912,479),(5918,478),(5922,482),(5921,492),(5923,506),(5926,513),(5909,513),(5910,496)],
    [(5930,481),(5936,480),(5939,483),(5935,490),(5936,503),(5936,513),(5926,513),(5925,495)],
    [(5937,493),(5945,492),(5949,497),(5945,505),(5944,513),(5931,513),(5931,503)],
    [(5953,481),(5959,479),(5963,483),(5963,498),(5958,501),(5952,501),(5951,490)],
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def surface(x,y):
    # Observed straight outlines of the original two pots. Their silhouettes
    # stay rigid; a hidden grass fringe must sample the same pot face, not sky.
    if x <= 5917.0-(y-475.0)*.42:return 'left_pot'
    if x >= 5930.0+(y-470.0)*.035:
        if x>=5948 and y>=500:return 'rock'
        return 'right_pot'
    return 'gap'


def build():
    assert sha(SRC.read_bytes())==SOURCE_SHA, 'Unexpected original art; old geometry must not be applied'
    image=np.asarray(Image.open(SRC).convert('RGB'),dtype=float)
    assert image.shape==(640,9204,3)
    original={name:np.asarray(Image.open(OUT/f'community_foregrass_{name}.png')).copy()
              for name in ['alpha','backmap']}
    assert original['alpha'].shape==(640,9204) and original['backmap'].shape==(640,9204,4)
    x0,y0,x1,y1=SCOPE
    for name,array in original.items():
        unchanged=array.copy();unchanged[y0:y1,x0:x1]=0
        assert sha(unchanged.tobytes())==OUTSIDE_SHA[name], 'Existing accepted mapping changed: '+name
    alpha=original['alpha'].copy();back=original['backmap'].copy()
    alpha[y0:y1,x0:x1]=0;back[y0:y1,x0:x1]=0
    polygon_image=Image.new('L',(9204,640),0)
    draw=ImageDraw.Draw(polygon_image)
    for polygon in POLYGONS:draw.polygon(polygon,fill=255)
    polygon=np.asarray(polygon_image)>0
    green=(image[:,:,1]-image[:,:,0]>8)&(image[:,:,1]-image[:,:,2]>16)
    seeds=green&polygon
    seed_image=Image.fromarray(seeds.astype(np.uint8)*255)
    potential=(np.asarray(seed_image.filter(ImageFilter.MaxFilter(5)))>0)&polygon
    core=np.asarray(seed_image.filter(ImageFilter.MinFilter(3)))>0

    def candidates(x,y,occupied):
        # This local search never crosses a pot silhouette or samples the vine.
        kind=surface(x,y)
        return [q for q in range(5877,5970)
                if not occupied[y,q] and not green[y,q] and surface(q,y)==kind]

    for y in range(477,514):
        for x in range(5888,5965):
            if not potential[y,x]:continue
            available=candidates(x,y,potential)
            if not available:continue
            q=min(available,key=lambda q:abs(q-x))
            background=image[y,q]
            ys,xs=np.where(seeds[y-4:y+5,x-4:x+5])
            if not len(xs):continue
            ys+=y-4;xs+=x-4
            score=image[ys,xs,1]-image[ys,xs,0]-.4*(abs(xs-x)+abs(ys-y))
            nearest=int(score.argmax());foreground=image[ys[nearest],xs[nearest]]
            value=float(np.clip(np.dot(image[y,x]-background,foreground-background)/
                                max(1,np.dot(foreground-background,foreground-background)),0,1))
            if core[y,x]:value=1.0
            if value>=.025:alpha[y,x]=round(value*255)
    for y in range(y0,y1):
        for x in range(x0,x1):
            q=x
            if alpha[y,x]>0:
                choices=candidates(x,y,alpha>0)
                if choices:q=min(choices,key=lambda q:abs(q-x))
            back[y,x]=[q%256,q//256,0,255]
    for name,result in [('alpha',alpha),('backmap',back)]:
        mask=np.ones(result.shape[:2],bool);mask[y0:y1,x0:x1]=False
        assert np.array_equal(result[mask],original[name][mask]), 'Out-of-scope data changed'
        Image.fromarray(result).save(OUT/f'community_foregrass_{name}.png')
    assert sha(SRC.read_bytes())==SOURCE_SHA
    record={'source':str(SRC.relative_to(ROOT)).replace('\\','/'),'source_sha256':SOURCE_SHA,
            'patch':'two_pots_foreground_grass_20261106','scope':SCOPE,'polygons':POLYGONS,
            'alpha_pixels':int(np.count_nonzero(alpha[y0:y1,x0:x1])),
            'outside_patch_unchanged':True,'existing_fountain_trunk_small_pot_mappings_unchanged':True,
            'background':'Original same-row samples, restricted to the same observed pot face / sky gap / rock. No new pigment.',
            'motion_bound_source_pixels':1.6}
    (OUT/'community_foregrass_maps.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps(record,indent=2))


if __name__=='__main__':build()
