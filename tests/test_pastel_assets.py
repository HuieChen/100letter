"""Actual bitmap/export integrity, not an automated claim of style acceptance."""
import hashlib
import json
from pathlib import Path
import re
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

class PastelAssets(unittest.TestCase):
    def test_every_active_role_is_reviewed_new_bitmap_and_decodes(self):
        m=json.loads((ROOT/'assets/faefever_v2/manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(m['style_lock'],'SOLMERE_SOFT_PASTEL_20261004')
        self.assertEqual(len(m['assets']),63)
        for role,entry in m['assets'].items():
            with self.subTest(role=role):
                p=ROOT/entry['path'].removeprefix('res://')
                self.assertTrue(entry['ai_generated'])
                self.assertEqual(entry['style_lock'],m['style_lock'])
                self.assertEqual(entry['sha256'],hashlib.sha256(p.read_bytes()).hexdigest())
                self.assertEqual(entry['source_sha256'],entry['sha256'])
                im=Image.open(p);im.load()
                self.assertEqual(list(im.size),entry['native_dimensions'])
                if 'region' in entry:
                    x,y,w,h=entry['region']
                    self.assertGreater(w,0);self.assertGreater(h,0)
                    self.assertGreaterEqual(x,0);self.assertGreaterEqual(y,0)
                    self.assertLessEqual(x+w,im.width);self.assertLessEqual(y+h,im.height)
                    if role not in ['door_closeup','door_handle','door_plate']:
                        self.assertEqual(im.mode,'RGBA')
                        self.assertEqual(im.getchannel('A').getextrema()[0],0)

    def test_dynamic_export_contains_only_active_generated_images(self):
        m=json.loads((ROOT/'assets/faefever_v2/manifest.json').read_text(encoding='utf-8'))
        text=(ROOT/'export_presets.cfg').read_text(encoding='utf-8')
        line=re.search(r'^export_files=PackedStringArray\((.*)\)$',text,re.M).group(1)
        selected=set(re.findall(r'"([^"]+)"',line))
        images={p for p in selected if p.startswith('res://assets/faefever_v2/')}
        self.assertEqual(images,{e['path'] for e in m['assets'].values()})
        for helper in ['mail_imprint','physical_envelope']:
            self.assertIn('res://scripts/rebuild/'+helper+'.gd',selected)
        self.assertNotIn('res://assets/faefever_v2/backgrounds/cover.png',selected)

    def test_eight_walking_frames_share_feet_scale_and_actual_new_source(self):
        m=json.loads((ROOT/'assets/faefever_v2/manifest.json').read_text(encoding='utf-8'))
        g=json.loads((ROOT/'assets/faefever_v2/characters/courier_walk_regions.json').read_text(encoding='utf-8'))
        self.assertEqual(len(g['frames']),8)
        self.assertEqual(g['source_sha256'],m['assets']['CHAR_courier_walk']['sha256'])
        for f in g['frames']:
            with self.subTest(frame=f['key']):
                self.assertEqual(f['region'],m['assets'][f['key']]['region'])
                self.assertEqual(f['reference_height_px'],420)
                self.assertGreater(f['foot_anchor_px'][0],0)
                self.assertLess(f['foot_anchor_px'][0],f['region'][2])
                self.assertGreater(f['foot_anchor_px'][1],0)
                self.assertLessEqual(f['foot_anchor_px'][1],f['region'][3])

if __name__=='__main__':unittest.main()
