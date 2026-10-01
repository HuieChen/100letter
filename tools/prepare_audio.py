from pathlib import Path
import numpy as np,subprocess,json,hashlib,shutil,wave
import argparse
args=argparse.ArgumentParser(description='Rebuild the CC0 game audio excerpts. Sources and hashes are in assets/audio/foley/source_downloads.json.')
args.add_argument('--sources',type=Path,required=True);args.add_argument('--ffmpeg',required=True);args.add_argument('--output',type=Path,default=Path('assets/audio/foley'));args=args.parse_args()
BASE=args.sources;OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
FF=args.ffmpeg;RATE=32000;records=[]
def read(path,start=0,duration=None,lowpass=10000):
 cmd=[FF,'-v','error','-ss',str(start),'-i',str(path)]
 if duration:cmd+=['-t',str(duration)]
 cmd+=['-af',f'highpass=f=70,lowpass=f={lowpass}','-ac','1','-ar',str(RATE),'-f','f32le','-']
 return np.frombuffer(subprocess.check_output(cmd),dtype=np.float32).copy()
def save(name,source,start=0,duration=None,loop=False,lowpass=10000,peak=.55):
 a=read(BASE/source,start,duration,lowpass); a-=np.mean(a); a*=peak/max(.001,float(abs(a).max()))
 if loop:
  n=min(int(RATE*.8),len(a)//4);ramp=np.linspace(0,1,n);a=np.concatenate([a[n:-n],a[-n:]*(1-ramp)+a[:n]*ramp])
 else:
  n=min(int(.015*RATE),len(a)//4);a[:n]*=np.linspace(0,1,n);n=min(int(.07*RATE),len(a)//4);a[-n:]*=np.linspace(1,0,n)
 # A mono downmix and peak normalization never hard clips the original preview.
 target=OUT/(name+('.ogg' if loop else '.wav'))
 cmd=[FF,'-y','-v','error','-f','f32le','-ar',str(RATE),'-ac','1','-i','-']
 cmd+=(['-c:a','libvorbis','-q:a','4'] if loop else ['-c:a','pcm_s16le'])+[str(target)]
 subprocess.run(cmd,input=a.astype(np.float32).tobytes(),check=True)
 records.append({'output':target.name,'source_file':source,'start_seconds':start,'duration_seconds':round(len(a)/RATE,4),'loop_crossfade_seconds':.8 if loop else 0,'lowpass_hz':lowpass,'peak_linear':round(float(abs(a).max()),4),'rms_linear':round(float(np.sqrt(np.mean(a*a))),6),'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
for i,(start,duration) in enumerate([(0.68,.72),(1.65,.62),(2.8,.68)]): save('paper_'+str(i+1),'paper.mp3',start,duration)
save('paper_slide','paper.mp3',2.18,.45,lowpass=6200)
save('paper_unfold','paper.mp3',.68,1.65)
save('bell','bell.mp3',0,2.8,lowpass=10000,peak=.4)
save('birds','birds.wav',0,3,lowpass=9500,peak=.48)
save('door_open','door/door-01.flac',0,None,lowpass=6800)
save('door_close','door/door-02.flac',0,None,lowpass=6800)
for surface in ['concrete','wood','grass']:
 for i in range(3):save(f'step_{surface}_{i+1}',f'impact/Audio/footstep_{surface}_00{i}.ogg',peak=.5)
for i in range(2):save(f'stamp_{i+1}',f'impact/Audio/impactWood_medium_00{i}.ogg',lowpass=5500)
save('wood_piece','impact/Audio/impactWood_light_002.ogg',lowpass=6000)
save('tool_metal','impact/Audio/impactMetal_light_003.ogg',lowpass=4300,peak=.32)
save('sea_bed','sea.mp3',6,32,True,6500,.6)
save('town_bed','town.mp3',15,32,True,4200,.55)
save('room_bed','town.mp3',15,32,True,900,.35)
save('wind_bed','wind.mp3',36,30,True,6800,.55)
save('tram_pass','tram.mp3',8.5,14,False,4800,.5)
(OUT/'sample_manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'source_downloads.json').write_text(json.dumps(json.loads((BASE/'downloads.json').read_text())+json.loads((BASE/'freesound_downloads.json').read_text()),indent=2))
shutil.copy(BASE/'impact/License.txt',OUT/'KENNEY_CC0.txt')
print(json.dumps({'files':len(records),'bytes':sum(r['bytes'] for r in records),'durations':[(r['output'],r['duration_seconds']) for r in records]},indent=2))
