"""Register inspected, unchanged ImageGen layers. No art generation or editing."""
from pathlib import Path
from PIL import Image
import json, hashlib
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'assets/faefever_v2/manifest.json'
m=json.loads(p.read_text(encoding='utf-8'))
if m.get('settings_ui_override',{}).get('source_pdf_sha256'):
    raise SystemExit('Historical AI-layer registration is superseded by the authored Settings PDF. Use extract_settings_pdf.py; preserve current source selection.')
for role,name in [('settings_water','settings_water_20261016.png'),('settings_stationery','settings_stationery_20261016.png')]:
    dst=ROOT/'assets/faefever_v2/ui'/name
    sha=hashlib.sha256(dst.read_bytes()).hexdigest()
    m['assets'][role]={'path':'res://'+dst.relative_to(ROOT).as_posix(),'native_dimensions':list(Image.open(dst).size),'ai_generated':True,'style_lock':'SOLMERE_COASTAL_UI_20261016','sha256':sha,'source_sha256':sha,'source_kind':'imagegen_reference_edit','review':'Inspected separate water and stationery layers; text/controls removed; original reference preserved.'}
m['settings_ui_override']={'scope':['settings_water','settings_stationery'],'authority':'Supplied blue water Settings reference and subsequent ripple/dragging request, 2026-10-16.'}
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=ROOT/'tests/test_pastel_assets.py'
s=p.read_text(encoding='utf-8').replace("len(m['assets']),62)","len(m['assets']),64)").replace("self.assertEqual(entry['style_lock'],m['style_lock'])","self.assertEqual(entry['style_lock'],'SOLMERE_COASTAL_UI_20261016' if role in {'settings_water','settings_stationery'} else m['style_lock'])")
p.write_text(s,encoding='utf-8')
p=ROOT/'tools/refresh_export_selection.py'
s=p.read_text(encoding='utf-8')
if 'assets/fonts/DynaPuff-OFL.txt' not in s:
    s=s.replace('assets/fonts/Caveat-OFL.txt,','assets/fonts/Caveat-OFL.txt,assets/fonts/DynaPuff-OFL.txt,assets/fonts/ZCOOLKuaiLe-OFL.txt,assets/fonts/settings-font-provenance.json,assets/audio/foley/WATER_CC0.txt,assets/audio/foley/water-provenance.json,')
p.write_text(s,encoding='utf-8')
print('Registered two inspected settings layers with hashes; no acceptance inferred.')
