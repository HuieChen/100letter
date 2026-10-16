"""Verify actual packaged media provenance/decoding, not aesthetic or listening approval."""
import hashlib,json,wave,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class SettingsMedia(unittest.TestCase):
    def test_fonts_have_pinned_bytes_and_original_ofl_notices(self):
        info=json.loads((ROOT/'assets/fonts/settings-font-provenance.json').read_text(encoding='utf-8-sig'))
        for name,record in info.items():
            with self.subTest(font=name):
                font=ROOT/'assets/fonts'/f'{name}.ttf'
                self.assertEqual(hashlib.sha256(font.read_bytes()).hexdigest(),record['sha256'])
                self.assertEqual(len(record['commit']),40)
                self.assertTrue(record['upstream'].startswith('https://github.com/google/fonts/tree/'+record['commit']))
                notice=(ROOT/'assets/fonts'/f'{name}-OFL.txt').read_text(encoding='utf-8-sig')
                self.assertIn('SIL OPEN FONT LICENSE',notice)
                self.assertIn('Version 1.1',notice)
                self.assertIn('Copyright',notice)
    def test_water_samples_are_real_short_decodable_recordings(self):
        info=json.loads((ROOT/'assets/audio/foley/water-provenance.json').read_text(encoding='utf-8'))
        self.assertEqual(info['license'],'CC0 1.0')
        self.assertEqual(info['source'],'https://opengameart.org/content/6-short-water-splashes')
        for record in info['files']:
            p=ROOT/'assets/audio/foley'/record['name']
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),record['sha256'])
            with wave.open(str(p)) as w:
                self.assertEqual(w.getnchannels(),1);self.assertEqual(w.getsampwidth(),2);self.assertEqual(w.getframerate(),44100)
                self.assertGreater(w.getnframes()/44100,0.1);self.assertLess(w.getnframes()/44100,2)
    def test_water_and_stationery_have_distinct_alpha_and_hashes(self):
        m=json.loads((ROOT/'assets/faefever_v2/manifest.json').read_text(encoding='utf-8'))['assets']
        water=Image.open(ROOT/m['settings_water']['path'].removeprefix('res://')).convert('RGBA')
        paper=Image.open(ROOT/m['settings_stationery']['path'].removeprefix('res://')).convert('RGBA')
        self.assertEqual(water.getchannel('A').getextrema(),(255,255))
        self.assertEqual(paper.getchannel('A').getextrema(),(255,255))  # original PDF white-matted JPEG; runtime compositor supplies alpha
        self.assertEqual(water.size,paper.size)
        self.assertEqual(water.size,(1920,1080))
        self.assertEqual(m['settings_stationery']['source_kind'],'user_pdf_embedded_image_exact_bytes')
        self.assertNotEqual(m['settings_water']['sha256'],m['settings_stationery']['sha256'])
    def test_adopted_wave_source_is_pinned_and_licensed(self):
        root=ROOT/'third_party/webgl-water'
        info=json.loads((root/'upstream.json').read_text(encoding='utf-8'))
        self.assertEqual(hashlib.sha256((root/'water.js').read_bytes()).hexdigest(),info['sha256'])
        self.assertEqual(len(info['commit']),40)
        self.assertIn('Released under the MIT license',(root/'water.js').read_text(encoding='utf-8'))
        license=(root/'LICENSE-MIT.txt').read_text(encoding='utf-8')
        self.assertIn('Evan Wallace',license);self.assertIn('Permission is hereby granted',license)
    def test_soundtrack_has_original_source_fingerprint_and_license(self):
        info=json.loads((ROOT/'assets/audio/settings-music-provenance.json').read_text(encoding='utf-8'))
        self.assertEqual(info['license'],'CC0 1.0')
        self.assertEqual(info['source'],'https://opengameart.org/content/calm-piano-1-vaporware')
        self.assertGreater(info['duration_seconds'],160)
        self.assertEqual(hashlib.sha256((ROOT/'assets/audio/settings_vaporware.ogg').read_bytes()).hexdigest(),info['sha256'])
if __name__=='__main__':unittest.main()
