"""Create original, quiet acoustic-style feedback; no sampled recordings."""
from pathlib import Path
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
rng = np.random.default_rng(100)

def save(name, values):
    values = np.clip(values, -.88, .88)
    pcm = (values * 32767).astype('<i2')
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1 if pcm.ndim == 1 else 2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())

def pluck(freq, seconds=2.0):
    t = np.arange(int(seconds * RATE)) / RATE
    env = (1 - np.exp(-t * 170)) * np.exp(-t * 2.9)
    return env * sum(np.sin(2 * math.pi * freq * (i+1) * t) / ((i+1)**2.4) for i in range(5))

for name, seconds, freq in [('paper',.22,130),('flip',.29,160),('map',.5,80),('snap',.15,180),('tool',.2,200),('stamp',.2,95),('deliver',.8,440),('bell',.7,660)]:
    t = np.arange(int(seconds*RATE))/RATE
    noise = rng.standard_normal(t.size)
    noise = np.convolve(noise,np.ones(10)/10,'same')
    env = np.sin(math.pi*np.minimum(t/seconds,1))**2 * np.exp(-t*6)
    tone = np.sin(2*math.pi*freq*t)*np.exp(-t*28)
    save(name,.28*noise*env + .13*tone)

length = 48
music = np.zeros(int(length*RATE))
chords = [(196,246.94,293.66),(174.61,220,261.63),(164.81,196,246.94),(146.83,196,220)]
for bar in range(12):
    chord = chords[bar % 4]
    for beat in range(6):
        start = int((bar*4 + beat*.56)*RATE)
        note = pluck(chord[beat%3]*(2 if beat in (2,5) else 1),2)
        end = min(start+len(note),len(music))
        music[start:end] += note[:end-start] * (.10 if beat%2 else .14)
fade = np.minimum(np.arange(len(music))/RATE/2,1)*np.minimum((len(music)-np.arange(len(music)))/RATE/2,1)
save('afternoon',music*fade)

t = np.arange(RATE*24)/RATE
noise = rng.standard_normal(len(t))
surf = np.convolve(noise,np.ones(70)/70,'same')
surf *= .23 + .12*np.sin(2*math.pi*t/8)
fade = np.minimum(t,1)*np.minimum(24-t,1)
save('sea',surf*fade)
print('Generated 10 original audio assets.')
