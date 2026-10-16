"""Retain exact current QA bytes. Does not run tests or approve usability."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/testing/coastal-settings_20261016'
parser=argparse.ArgumentParser()
parser.add_argument('--engine',required=True)
parser.add_argument('--window',required=True)
parser.add_argument('--film',required=True)
parser.add_argument('--film-log',required=True)
args=parser.parse_args()
ENGINE=ROOT/'test-results'/args.engine
WINDOW=ROOT/'test-results'/args.window
OUT.mkdir(exist_ok=True)
def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
suites=[]
for p in sorted(ENGINE.glob('*.log')):
    copy(p,OUT/'engine'/p.name)
    if p.name=='import.log':continue
    matches=list(re.finditer(r'(\d+)\s+(?:checks|assertions)[^\n]*?(\d+)\s+failures',p.read_text(encoding='utf-8-sig',errors='replace'),re.I))
    if not matches:raise ValueError('No fresh suite result: '+p.name)
    count,fail=map(int,matches[-1].groups())
    if fail:raise ValueError('Failed suite: '+p.name)
    suites.append({'suite':p.stem,'checks':count,'failures':fail})
assert len(suites)==23 and sum(x['checks'] for x in suites)==7951
for p in WINDOW.iterdir():
    if p.is_file() and p.suffix in {'.json','.log'}:copy(p,OUT/'window'/p.name)
for kind in ['dialogue','settings']:
    for p in (ROOT/'test-results/ui-reference-20261016'/kind).iterdir():
        if p.suffix in {'.png','.json'}:copy(p,OUT/kind/p.name)
copy(ROOT/'test-results/ui-reference-20261016'/args.film,OUT/'settings-demo-1280.mp4')
copy(ROOT/'test-results/ui-reference-20261016/settings-demo-1920.mp4',OUT/'earlier-failures/settings-before-refraction.mp4')
for name in ['coastal-settings-20261016.log','coastal-settings-20261016-r2.log','coastal-settings-20261016-r3.log','preferences-20261016.log','settings-film-20261016.log']:
    copy(ROOT/'test-results'/name,OUT/'earlier-failures'/name)
for folder,name in [('check-20261016-225152','core_review_input'),('check-20261016-230132','five_case_sealed')]:
    copy(ROOT/'test-results'/folder/(name+'.log'),OUT/'earlier-failures'/(folder+'-'+name+'.log'))
copy(ROOT/'test-results'/args.film_log,OUT/'film.log')
sources={}
for p in list((ROOT/'scripts/rebuild').glob('*.gd'))+list((ROOT/'scripts/ui').glob('*.gd'))+[ROOT/'scripts/ui/settings_water.gdshader',ROOT/'assets/faefever_v2/manifest.json',ROOT/'assets/fonts/settings-font-provenance.json']:
    sources[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
artifacts=[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)} for p in sorted(OUT.rglob('*')) if p.is_file() and p.name not in {'evidence.json','native.json','publication.json'} and p.suffix!='.import']
e={'scope':'Current courier, notebook dialogue and coastal water settings. Automated source/input/GPU/mixer verification; not audio listening or novice acceptance. UI language only; original story/documents retain their language.','engine_run':ENGINE.name,'engine_checks':7951,'engine_suites':23,'suites':suites,'window_close_reload_checks':29,'studio_python_checks':28,'bitmap_python_checks':3,'video_python_checks':3,'settings_media_python_checks':3,'water_revision':'User rejected additive rings. Now refracts original painted texture only; GPU pixel checks verify actual water movement and stable stationery/lemons. No subjective acceptance inferred.','movie':'Actual Godot MovieWriter rendering and mixer, 1280x720 at24fps; automated input fixture, not native mouse recording. File labelled with actual dimensions.','source_sha256_normalized_text':sources,'artifacts':artifacts,'pending':['audio listening','first-time novice','full native matrix','new long three-letter/wax story']}
(OUT/'evidence.json').write_text(json.dumps(e,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Retained',len(artifacts),'artifacts,',len(suites),'suites /7951 checks. Acceptance remains distinct.')
