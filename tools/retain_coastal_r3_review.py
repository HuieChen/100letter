"""Freeze exact current R3 evidence without overwriting earlier review rounds."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/testing/coastal-settings_20261017-r3'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy(p,to):to.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,to)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--engine',required=True);parser.add_argument('--window',required=True);parser.add_argument('--checks',required=True,type=int);args=parser.parse_args()
    engine=ROOT/'test-results'/args.engine;window=ROOT/'test-results'/args.window
    suites=[]
    for path in sorted(engine.glob('*.log')):
        if path.name!='import.log':
            matches=list(re.finditer(r'(\d+)\s+(?:checks|assertions)[^\n]*?(\d+)\s+failures',path.read_text(encoding='utf-8-sig',errors='replace'),re.I))
            if not matches:raise ValueError('No complete actual result: '+path.name)
            count,failures=map(int,matches[-1].groups())
            if failures:raise ValueError('Failed suite: '+path.name)
            suites.append({'suite':path.stem,'checks':count,'failures':failures})
        copy(path,OUT/'engine'/path.name)
    assert len(suites)==25 and sum(x['checks'] for x in suites)==args.checks
    for path in window.iterdir():
        if path.is_file() and path.suffix in {'.json','.log'}:copy(path,OUT/'window'/path.name)
    for kind in ['settings','dialogue']:
        for path in (ROOT/'test-results/ui-reference-20261016'/kind).iterdir():
            if path.suffix in {'.png','.json'}:copy(path,OUT/kind/path.name)
    copy(ROOT/'test-results/ui-reference-20261016/settings-demo-r3-1920.mp4',OUT/'settings-demo-1920.mp4')
    copy(ROOT/'test-results/coastal-film-r3-1080.log',OUT/'film.log')
    for path in (ROOT/'test-results/film-inspect-r3').iterdir():copy(path,OUT/'film'/path.name)
    for folder in ['coastal-focus-20261017-011355','coastal-focus-20261017-011538','coastal-focus-20261017-011630']:
        for path in (ROOT/'test-results'/folder).glob('*.log'):
            if path.name!='import.log':copy(path,OUT/'earlier-rounds'/(folder+'-'+path.name))
    sources={}
    for path in list((ROOT/'scripts/rebuild').glob('*.gd'))+list((ROOT/'scripts/ui').glob('*.gd'))+list((ROOT/'scripts/ui').glob('*.gdshader'))+[ROOT/'assets/faefever_v2/manifest.json',ROOT/'assets/fonts/settings-font-provenance.json',ROOT/'assets/audio/settings-music-provenance.json']:
        sources[path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    artifacts=[{'path':p.relative_to(ROOT).as_posix(),'sha256':digest(p)} for p in sorted(OUT.rglob('*')) if p.is_file() and p.name not in {'evidence.json','native.json','publication.json'} and p.suffix!='.import']
    evidence={'scope':'Focused current Settings PDF-layer, wave/physics, bilingual layout and genuine controls; earlier courier/dialogue preserved. Automated checks do not certify whole-game acceptance.','engine_run':engine.name,'engine_checks':args.checks,'engine_suites':25,'suites':suites,'window_close_reload_checks':29,'studio_python_checks':28,'bitmap_python_checks':3,'video_python_checks':3,'settings_media_python_checks':5,'original_art':'11 exact 1920x1080 embedded JPEGs from the user-authorized 39-page PDF; unchanged bytes, runtime white matte. Original source PDF not published.','water':'MIT Evan Wallace height/velocity equations adapted to bounded 60Hz field; original painted texture refraction, different speed-dependent skim/held-drag pressure. Isolated native GodotPhysics2D floating slices have mass/inertia/damping/contacts. No general CFD claim.','movie':'Actual MovieWriter native1920x1080 24fps 410frames 17.08s with recorded PCM; annotated automated pointer, not native mouse footage or listening approval.','source_sha256_normalized_text':sources,'artifacts':artifacts,'pending':['actual human listening','first-time novice','complete native matrix','new long three-letter/wax story']}
    (OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Retained',len(artifacts),'exact artifacts;',len(suites),'suites /',args.checks,'checks. No final acceptance inferred.')
if __name__=='__main__':main()
