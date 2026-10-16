"""Adversarial asset/provenance checks for the requested original video cutout."""
import hashlib
import json
from pathlib import Path
import unittest
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/faefever_v2/characters'


class VideoCourier(unittest.TestCase):
    def test_complete_cycle_without_duplicate_or_recording_frames(self):
        g=json.loads((ASSETS/'courier_walk_regions.json').read_text(encoding='utf-8'))
        m=json.loads((ROOT/'assets/faefever_v2/manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(g['source_kind'],'user_video_extraction')
        self.assertEqual([f['source_frame'] for f in g['frames']],[3,9,15,21,27,33])
        self.assertEqual(g['authored_fps'],5)
        self.assertAlmostEqual(sum(f['duration_seconds'] for f in g['frames']),1.2)
        atlas=Image.open(ASSETS/'courier_video_20261016.png')
        self.assertEqual(atlas.size,(1290,315))
        hashes=[]
        for frame in g['frames']:
            entry=m['assets'][frame['key']]
            self.assertEqual(entry['region'],frame['region'])
            x,y,w,h=frame['region']
            arr=np.array(atlas.crop((x,y,x+w,y+h)))
            hashes.append(hashlib.sha256(arr.tobytes()).hexdigest())
            self.assertTrue((arr[0,:,3]==0).all() and (arr[-1,:,3]==0).all())
            self.assertTrue((arr[:,0,3]==0).all() and (arr[:,-1,3]==0).all())
            self.assertGreater((arr[:,:,3]==0).sum(),39000)
            self.assertGreater(((arr[:,:,3]>0)&(arr[:,:,3]<255)).sum(),700)
            self.assertGreater((arr[:,:,3]==255).sum(),14000)
            # Light source hair remains opaque instead of disappearing with the white surround.
            self.assertGreater(((arr[:,:,:3].min(axis=2)>190)&(arr[:,:,3]==255)).sum(),2000)
        self.assertEqual(len(set(hashes)),6)

    def test_idle_is_the_same_original_pose_with_common_anchor(self):
        g=json.loads((ASSETS/'courier_walk_regions.json').read_text(encoding='utf-8'))
        atlas=Image.open(ASSETS/'courier_video_20261016.png')
        idle=Image.open(ASSETS/'courier_video_idle_20261016.png')
        self.assertEqual(idle.tobytes(),atlas.crop((860,0,1075,315)).tobytes())
        self.assertEqual(g['idle']['foot_anchor_px'],[128,298])
        for f in g['frames']:
            self.assertEqual(f['foot_anchor_px'],g['idle']['foot_anchor_px'])
            self.assertEqual(f['reference_height_px'],g['idle']['reference_height_px'])

    def test_provenance_is_honest_and_original_video_not_published(self):
        p=json.loads((ASSETS/'courier_video_provenance_20261016.json').read_text(encoding='utf-8'))
        self.assertFalse(p['ai_generated'])
        self.assertFalse(p['original_modified'])
        self.assertEqual(len(p['source_video_sha256']),64)
        for name,digest in p['assets'].items():
            self.assertEqual(hashlib.sha256((ASSETS/name).read_bytes()).hexdigest(),digest)
        public=(ASSETS/'courier_video_provenance_20261016.json').read_text(encoding='utf-8')
        self.assertNotIn('xwechat_files',public)
        self.assertNotIn('wxid_',public)
        preset=(ROOT/'export_presets.cfg').read_text(encoding='utf-8')
        self.assertIn('courier_video_provenance_20261016.json',preset)
        self.assertNotIn('c9ad1d5647ac8620614ec53024e8c988.mp4',preset)


if __name__=='__main__':unittest.main()
