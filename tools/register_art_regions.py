"""Declare runtime subregions of unchanged generated art; never edits image pixels."""
import copy, json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
path = root/'assets/faefever_v2/manifest.json'
manifest = json.loads(path.read_text(encoding='utf-8'))
assets = manifest['assets']
def alias(key, original, region=None):
    data = copy.deepcopy(assets[original])
    data['derived_from'] = original
    data['notes'] = 'Runtime atlas selection of unchanged ImageGen source; no pixel modification.'
    if region is not None: data['region'] = region
    assets[key] = data
alias('workroom', 'BG_workroom')
alias('service_paper', 'letter_paper')
alias('paper_corner', 'letter_paper', [822,1310,120,120])
alias('door_closeup', 'BG_residential', [290,180,285,520])
alias('door_handle', 'BG_residential', [461,455,74,79])
alias('door_plate', 'BG_residential', [993,426,108,37])
walk = json.loads((root/'assets/faefever_v2/characters/courier_walk_regions.json').read_text(encoding='utf-8'))
for frame in walk['frames']:
    alias(frame['key'], 'CHAR_courier_walk', frame['region'])
    assets[frame['key']]['foot_anchor_px'] = frame['foot_anchor_px']
    assets[frame['key']]['reference_height_px'] = frame['reference_height_px']
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered 6 derived regions from unchanged AI sources.')
