"""Read-only integrity checks for approved display alpha derivatives.
Uses component labelling independently from the writer's propagation routine.
"""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import label,distance_transform_edt
ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def exterior(mask):
    components,_=label(mask)
    border=np.unique(np.concatenate((components[0],components[-1],components[:,0],components[:,-1])))
    border=border[border!=0]
    return np.isin(components,border)
def verify():
    original_catalog=json.loads((ROOT/'docs/ASSET_INTEGRITY.json').read_text(encoding='utf8'))
    originals=[{'path':v['path'],'sha256_ok':sha(ROOT/v['path'])==v['sha256']} for v in original_catalog['files']]
    assert all(v['sha256_ok'] for v in originals)
    manifest=json.loads((ROOT/'docs/DISPLAY_DERIVATIVES.json').read_text(encoding='utf8'))
    results=[]
    for item in manifest['assets']:
        original=np.array(Image.open(ROOT/item['source']).convert('RGBA'))
        display=np.array(Image.open(ROOT/item['display']).convert('RGBA'))
        assert original.shape==display.shape
        rgb=original[:,:,:3];lo=rgb.min(2);spread=rgb.max(2).astype(np.int16)-lo.astype(np.int16)
        baseline=exterior(((lo>=247)&(spread<=6))|(original[:,:,3]==0))
        changed=original[:,:,3]!=display[:,:,3]
        extra=changed & ~baseline
        distance=distance_transform_edt(~baseline)
        jpeg=Path(item['source']).suffix.lower() in ('.jpg','.jpeg')
        allowed_edge=(distance<=3)&(lo>=228)&(spread<=20) if jpeg else np.zeros_like(baseline)
        actual_external=exterior(display[:,:,3]==0)
        check={
            'location':item['location'],
            'source_hash_ok':sha(ROOT/item['source'])==item['source_sha256'],
            'display_hash_ok':sha(ROOT/item['display'])==item['display_sha256'],
            'dimensions_identical':list(Image.open(ROOT/item['source']).size)==item['size'],
            'rgb_identical':bool(np.array_equal(original[:,:,:3],display[:,:,:3])),
            'only_authorized_white_alpha_cleared':bool(np.all(display[:,:,3][changed]==0) and np.all((baseline|allowed_edge)[changed])),
            'all_changed_alpha_exterior_connected_4_neighbour':bool(np.all(actual_external[changed])),
            'no_additional_changes_beyond_3_source_pixels':bool(np.all(distance[extra]<=3)),
            'protected_non_near_white_alpha_unchanged':bool(not np.any(extra & ((lo<228)|(spread>20)))),
            'pixels_cleared':int(changed.sum()),'additional_jpeg_edge_pixels':int(extra.sum()),
            'maximum_extra_distance_source_pixels':float(distance[extra].max()) if np.any(extra) else 0.0,
            'alpha_values_introduced':sorted(int(v) for v in np.unique(display[:,:,3][changed])),
        }
        assert all(v for k,v in check.items() if isinstance(v,bool)),check
        assert check['pixels_cleared']==item['pixels_cleared']
        assert check['additional_jpeg_edge_pixels']==item['additional_jpeg_edge_pixels']
        results.append(check)
    report={'verified_on':'2026-10-01','original_file_hashes_verified':len(originals),
        'scope':'Read-only source/display hashes, dimensions and every RGB pixel. Four-neighbour exterior connectivity independently checked with component labelling. JPEG-only extra alpha clearing constrained to near-white pixels within 3 original-image pixels of fixed baseline outside; no deeper or colored alpha changes.',
        'original_checks':originals,'display_checks':results,'failures':0}
    (ROOT/'docs/testing/ASSET_DISPLAY_VERIFICATION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print('DISPLAY_INTEGRITY: %d originals, %d displays, 0 failures'%(len(originals),len(results)))
    for row in results: print(row['location'],row['pixels_cleared'],'edge',row['additional_jpeg_edge_pixels'],'max distance',row['maximum_extra_distance_source_pixels'])
if __name__=='__main__':verify()
