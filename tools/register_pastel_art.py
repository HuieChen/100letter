"""Register reviewed ImageGen bitmaps as AtlasTextures; never repaint pixels.

Input is a local generation receipt with paths/prompts. Supplied source artwork
is never loaded as an edit target or copied into the playable export.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
STYLE = 'SOLMERE_SOFT_PASTEL_20261004'

def digest(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main() -> None:
    args=argparse.ArgumentParser();args.add_argument('--receipt',required=True)
    receipt=json.loads(Path(args.parse_args().receipt).read_text(encoding='utf-8'))
    target=ROOT/'assets/faefever_v2';manifest_path=target/'manifest.json'
    prior=json.loads(manifest_path.read_text(encoding='utf-8'))
    backup=ROOT/'test-results/style-reference/pre-restyle'
    backup.mkdir(parents=True,exist_ok=True)
    # Only generated runtime assets are replaced. Preserve a local copy as well
    # as the existing Git history, including their registration manifest.
    if not (backup/'manifest.json').exists():shutil.copy2(manifest_path,backup/'manifest.json')
    old_res=Image.open(ROOT/prior['assets']['BG_residential']['path'].removeprefix('res://')).size
    assets={};generation_files={}
    def copy(key: str, filename: str) -> Path:
        src=Path(receipt[key]['path']);dst=target/filename
        dst.parent.mkdir(parents=True,exist_ok=True)
        if dst.exists() and not (backup/dst.name).exists():shutil.copy2(dst,backup/dst.name)
        shutil.copy2(src,dst);generation_files[key]=dst
        assert digest(src)==digest(dst)
        return dst
    def entry(role: str,key: str,p: Path,region=None):
        im=Image.open(p)
        v={'path':'res://'+p.relative_to(ROOT).as_posix(),'source':Path(receipt[key]['path']).name,
           'generator':'image_gen.imagegen','ai_generated':True,'style_lock':STYLE,
           'prompt':receipt[key]['prompt'],'sha256':digest(p),'source_sha256':digest(Path(receipt[key]['path'])),
           'native_dimensions':list(im.size),'mode':im.mode,'review_status':'image_inspected_runtime_review_pending',
           'notes':'Generated PNG bytes preserved unchanged; atlas selection only, no procedural painting or recoloring.'}
        if region is not None:
            x,y,w,h=map(int,region);assert w>0 and h>0 and x>=0 and y>=0 and x+w<=im.width and y+h<=im.height
            v['region']=[x,y,w,h]
        assets[role]=v
    def region_box(im: Image.Image,box):
        # Select a reviewed object's bounding rectangle, preserving every alpha
        # value and every internal paper pinhole exactly as generated.
        x0,y0,x1,y1=map(int,box)
        alpha=im.getchannel('A').crop((x0,y0,x1,y1))
        # Barely visible stray alpha far outside the painted silhouette must
        # not shrink a whole prop or move its apparent hinge away from its hit
        # target. Select the visible silhouette plus its soft fringe; do not
        # alter any pixels or internal transparency in the generated bitmap.
        bounds=alpha.point(lambda a:255 if a>16 else 0).getbbox()
        assert bounds is not None
        bounds=(max(0,bounds[0]-3),max(0,bounds[1]-3),min(alpha.width,bounds[2]+3),min(alpha.height,bounds[3]+3))
        return [x0+bounds[0],y0+bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]]
    def atlas(key: str,roles: list[str],boxes):
        p=copy(key,'props/pastel_'+key+'_20261004.png');im=Image.open(p)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        for role,box in zip(roles,boxes,strict=True):entry(role,key,p,region_box(im,box))
    for role in ['BG_post_office','BG_community_center','BG_residential','BG_bus_stop','BG_lookout','BG_chess_stall','BG_tarot_shop']:
        p=copy(role,'backgrounds/'+role+'.png');entry(role,role,p)
    p=copy('workroom','backgrounds/BG_workroom.png');entry('BG_workroom','workroom',p)
    p=copy('wall','backgrounds/wall_closeup.png');entry('wall_closeup','wall',p)
    atlas('docs',['mail_box_base','mail_box_lid','mail_box_latch','envelope_front','envelope_back','envelope_flap','handbook_open','handbook_closed','resolution_slip'],
          [(15,115,545,425),(555,110,1010,420),(1075,145,1210,425),(25,475,485,765),(495,475,907,765),(908,540,1250,725),(15,797,645,1170),(650,785,950,1170),(965,780,1255,1190)])
    p=copy('lid','props/pastel_case_lid_20261004.png');im=Image.open(p)
    entry('mail_box_lid','lid',p,region_box(im,(0,0,im.width,im.height)))
    atlas('tools',['magnifier','opener','restorer','press','pen','postal_seal','eraser','sealer','repair_label','protector','replacement_strip','seal_mark'],
          [(0,0,420,395),(420,0,750,395),(750,0,1100,395),(1100,0,1440,395),(0,395,420,735),(420,395,750,735),(750,395,1100,735),(1100,395,1440,735),(0,735,420,1080),(420,735,750,1080),(750,735,1140,1080),(1140,735,1440,1080)])
    atlas('misc',['letter_paper','drawer_open','drawer_front','satchel','book_index_tab','attachment_photo','old_music_photo','wall_plate_old','wall_plate_new'],
          [(40,35,400,502),(405,145,838,430),(839,200,1250,350),(15,505,455,859),(458,585,819,779),(821,505,1265,875),(7,875,436,1250),(437,915,825,1190),(826,910,1257,1190)])
    p=copy('back','props/pastel_envelope_back_20261004.png');im=Image.open(p)
    entry('envelope_back','back',p,region_box(im,(round(im.width*.025),round(im.height*.045),round(im.width*.995),round(im.height*.977))))
    # Cast is a regular three by two atlas, with whole silhouettes; no portrait
    # is synthesized separately. The book crops the same encountered character.
    p=copy('cast','characters/pastel_cast_20261004.png');im=Image.open(p)
    for n,role in enumerate(['CHAR_courier','CHAR_elsie','CHAR_chenyuan','CHAR_mira','CHAR_june','CHAR_clerk']):
        c=n%3;r=n//3;entry(role,'cast',p,region_box(im,(c*512,r*512,(c+1)*512,(r+1)*512)))
    p=copy('walk','characters/CHAR_courier_walk.png');im=Image.open(p)
    frames=[]
    for n in range(8):
        c=n%4;r=n//4;x0=round(c*im.width/4);x1=round((c+1)*im.width/4);y0=round(r*im.height/2);y1=round((r+1)*im.height/2)
        rect=region_box(im,(x0,y0,x1,y1));entry('CHAR_courier_walk_'+str(n),'walk',p,rect)
        alpha=np.asarray(im.getchannel('A'))[rect[1]:rect[1]+rect[3],rect[0]:rect[0]+rect[2]]
        visible=np.argwhere(alpha>128);assert visible.size
        foot_y=int(visible[:,0].max())+1
        # Head/torso axis, rather than spread toe tips, binds the pose to feet.
        upper=visible[visible[:,0]<rect[3]*.48]
        pivot=float(np.median(upper[:,1]))
        frames.append({'key':'CHAR_courier_walk_'+str(n),'region':rect,'foot_anchor_px':[pivot,foot_y],
                       'reference_height_px':420,'alpha_threshold':128,'connected_component_area':len(visible)})
    entry('CHAR_courier_walk','walk',p)
    geom={'source':p.name,'source_sha256':digest(p),'dimensions':list(im.size),
          'method':'Reviewed generated eight-pose atlas. All pixels unchanged. Common 420px scale; opaque shoe baseline and head/torso axis bind frames to world feet.', 'frames':frames}
    (target/'characters/courier_walk_regions.json').write_text(json.dumps(geom,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    p=copy('map_refined','props/town_map.png');im=Image.open(p);entry('town_map','map_refined',p,region_box(im,(0,0,im.width,im.height)))
    # Existing aliases also resolve exclusively to the newly generated assets.
    for alias,role in [('workroom','BG_workroom'),('service_paper','letter_paper'),('game_icon','envelope_front'),('cover','letter_paper')]:
        assets[alias]=dict(assets[role]);assets[alias]['notes']+=' Alias '+role+'. Cover bitmap is not displayed; title remains plain typography.'
    paper=assets['letter_paper'];x,y,w,h=paper['region'];assets['paper_corner']=dict(paper);assets['paper_corner']['region']=[x+w-70,y+h-70,70,70]
    res=assets['BG_residential'];new_res=res['native_dimensions']
    for role in ['door_closeup','door_handle','door_plate']:
        old=prior['assets'][role]['region'];rect=[round(old[0]/old_res[0]*new_res[0]),round(old[1]/old_res[1]*new_res[1]),round(old[2]/old_res[0]*new_res[0]),round(old[3]/old_res[1]*new_res[1])]
        assets[role]=dict(res);assets[role]['region']=rect
    assert set(assets)==set(prior['assets']), ('uncovered roles',set(prior['assets'])-set(assets))
    manifest={'style_lock':STYLE,'authority':'Latest direct user image and global-restyle instruction, 2026-10-04.',
              'assets':assets,'generation_receipts':{k:{'file':v.name,'sha256':digest(v)} for k,v in generation_files.items()}}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    preset_path=ROOT/'export_presets.cfg';preset=preset_path.read_text(encoding='utf-8')
    selected=re.search(r'^export_files=PackedStringArray\((.*)\)$',preset,re.M).group(1)
    paths=re.findall(r'"([^"]+)"',selected)
    paths=[p for p in paths if not p.startswith('res://assets/faefever_v2/')]
    paths+=sorted({v['path'] for v in assets.values()})
    paths+=['res://scripts/rebuild/mail_imprint.gd','res://scripts/rebuild/physical_envelope.gd']
    preset=re.sub(r'^export_files=PackedStringArray\(.*\)$','export_files=PackedStringArray('+', '.join('"'+p+'"' for p in sorted(set(paths)))+')',preset,flags=re.M)
    preset_path.write_text(preset,encoding='utf-8')
    print('Registered',len(assets),'roles from',len(generation_files),'reviewed ImageGen outputs. No original pixels edited.')

if __name__=='__main__':main()
