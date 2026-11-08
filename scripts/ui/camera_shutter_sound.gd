extends RefCounted
## Original procedural mechanical double-click; no borrowed recording.
## Cached by AudioFeedback and routed through the existing effects bus.
static func make_stream()->AudioStreamWAV:
 var rate:=44100
 var count:=int(rate*.18)
 var bytes:=PackedByteArray();bytes.resize(count*2)
 var rng:=RandomNumberGenerator.new();rng.seed=190905
 var low:=0.0
 for i in range(count):
  var t:=float(i)/rate
  low=lerpf(low,rng.randf_range(-1.0,1.0),.34)
  var sound:=0.0
  for k in range(2):
   var elapsed:=t-(.009 if k==0 else .063)
   if elapsed>=0.0:
    var attack:=1.0-exp(-elapsed*2600.0)
    var envelope:=attack*exp(-elapsed*(125.0 if k==0 else 90.0))
    var body:=sin(TAU*(740.0 if k==0 else 520.0)*elapsed)*.23
    sound+=(low*.94+body)*envelope*(1.0 if k==0 else .82)
  bytes.encode_s16(i*2,int(clampf(sound*1.7,-.85,.85)*32767.0))
 var stream:=AudioStreamWAV.new()
 stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate
 stream.stereo=false;stream.loop_mode=AudioStreamWAV.LOOP_DISABLED;stream.data=bytes
 return stream
