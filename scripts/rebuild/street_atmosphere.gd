extends RefCounted
## Shared weather clock and source-pixel regions. Original panoramas stay intact.
const PERIODS := ["morning", "noon", "sunset", "night"]
const LIGHTS := [Color(.94,.98,1), Color(1,.99,.94), Color(1,.88,.79), Color(.62,.69,.91)]
const REGIONS := {
 "community": {
  "trees": [Vector4(315,180,420,510),Vector4(710,350,870,510),Vector4(2780,345,2860,478),Vector4(3970,315,4130,512),Vector4(5865,120,6160,505),Vector4(6620,345,6840,513),Vector4(7670,110,7850,500)],
  "grass": [Vector4(895,440,970,515),Vector4(1770,430,1855,515),Vector4(3715,410,3970,515),Vector4(4435,458,4540,515),Vector4(4700,440,4810,515),Vector4(4870,436,4990,515),Vector4(5090,450,5150,515),Vector4(5290,478,5340,515),Vector4(5370,475,5430,515),Vector4(5545,440,5745,515),Vector4(5760,460,5855,515),Vector4(5875,465,5925,515),Vector4(6090,470,6160,515),Vector4(6950,450,7110,515),Vector4(7160,460,7250,515)],
  "sea": [Vector4(970,485,1050,511),Vector4(1170,486,1550,511),Vector4(2990,485,3540,511),Vector4(4840,485,5020,511),Vector4(5110,485,5370,511),Vector4(7150,485,7450,511)],
  "boat": []},
 "residential": {
  "trees": [Vector4(1760,230,1935,505),Vector4(1935,245,2050,508),Vector4(2500,275,2635,512),Vector4(2650,250,2770,512),Vector4(6040,85,6555,510),Vector4(6990,280,7160,512)],
  "grass": [Vector4(860,450,970,515),Vector4(3090,448,3310,515),Vector4(3900,420,4050,515),Vector4(4780,440,4840,515),Vector4(5550,450,5640,515),Vector4(6140,455,6280,515),Vector4(7200,450,7310,515)],
  "sea": [Vector4(1230,484,1580,512),Vector4(3380,484,3610,512),Vector4(3670,484,3890,512),Vector4(5200,484,5480,512),Vector4(5690,484,6000,512)],
  "boat": []},
 "postal": {
  "trees": [Vector4(90,70,340,510),Vector4(1920,150,2060,505),Vector4(2070,330,2200,510),Vector4(3430,120,3720,500),Vector4(5310,250,5460,510),Vector4(5735,350,5900,510)],
  "grass": [Vector4(1020,455,1160,515),Vector4(1660,455,1860,515),Vector4(2710,455,2860,515),Vector4(3100,455,3270,515),Vector4(4290,455,4440,515),Vector4(4780,455,4910,515)],
  "sea": [Vector4(1220,488,1450,513),Vector4(2890,488,3030,513),Vector4(4510,488,4610,513),Vector4(4960,488,5080,513)],
  "boat": []},
 "coastal": {
  "trees": [Vector4(260,50,340,505),Vector4(1860,25,2120,505),Vector4(2130,300,2210,505),Vector4(4000,210,4120,510),Vector4(4400,320,4590,510)],
  "grass": [Vector4(1180,450,1340,515),Vector4(2750,450,2860,515),Vector4(3170,450,3280,515),Vector4(4830,450,4960,515),Vector4(5150,450,5280,515)],
  "sea": [Vector4(1500,475,1760,512),Vector4(2990,475,3140,512),Vector4(3300,475,3520,512),Vector4(4860,475,4950,512),Vector4(5060,475,5140,512)],
  "boat": []}
}

# Rigid painted overlaps must stay still even where crowns/grass share a box.
const RIGID := {
 "coastal": [Vector4(350,90,945,515),Vector4(2180,125,2590,515),Vector4(1595,345,1700,516),Vector4(4065,95,4420,515)],
 "postal": [Vector4(2070,100,2630,515),Vector4(3720,130,4140,515)],
 "community": [Vector4(1890,25,2550,515),Vector4(2550,440,2760,514),Vector4(2870,340,2980,515),Vector4(4150,155,4540,515),Vector4(6200,130,6570,515),Vector4(1030,330,1157,397),Vector4(1082,390,1105,516),Vector4(1584,330,1711,397),Vector4(1636,390,1659,516),Vector4(2854,330,2981,397),Vector4(2906,390,2929,516),Vector4(3640,330,3767,397),Vector4(3692,390,3715,516),Vector4(5029,330,5156,397),Vector4(5081,390,5104,516),Vector4(5635,330,5762,397),Vector4(5687,390,5710,516),Vector4(7066,330,7193,397),Vector4(7118,390,7141,516)],

 "residential": [Vector4(2040,85,2485,514),Vector4(6305,280,6400,515),Vector4(6380,312,6850,515),Vector4(7140,340,7260,515)]
}

static func wind_at(seconds:float, source_x:float=0.0)->float:
 var t:=seconds-source_x/900.0
 var pulse:=pow(maxf(0.0,sin(t*.255-1.25)),6.0)
 return .22+.07*sin(t*.73)+.04*sin(t*1.21+.6)+.67*pulse

static func swell_at(seconds:float,source_x:float=0.0)->float:
 # Same two travelling waves and source-pixel phase as the painted sea shader.
 # Normalize its -0.9..0.9 displacement to a bounded audio envelope.
 return .5+(.65*sin(seconds*.81+source_x*.018)+.25*sin(seconds*1.17-source_x*.011))/1.8

static func time_pair(at_minute:float)->Vector3:
 var m:=fposmod(at_minute,1440.0)
 var knots:=[360.0,540.0,720.0,1050.0,1200.0]
 var ids:=[3,0,1,2,3]
 if m<360 or m>=1200:return Vector3(3,3,0)
 for i in range(4):
  if m<=knots[i+1]:return Vector3(ids[i],ids[i+1],smoothstep(knots[i],knots[i+1],m))
 return Vector3(3,3,0)

static func apply_branches(material:ShaderMaterial,family:String)->void:
 var axes:Array[Vector4]=[]
 var shapes:Array[Vector2]=[]
 for r:Vector4 in REGIONS.get(family,REGIONS.coastal).trees:
  if family=="community" and r.x==5865:continue
  var w:float=r.z-r.x;var h:float=r.w-r.y
  var base:=Vector2((r.x+r.z)*.5,r.y+h*.68)
  for k in range(3):
   var tip:=Vector2(r.x+w*[.15,.58,.86][k],r.y+h*[.32,.12,.38][k])
   axes.append(Vector4(base.x,base.y,tip.x,tip.y))
   shapes.append(Vector2(w*.35,.075 if k!=1 else .045))
 if family=="community":
  var fronds:=[[6020,290,6100,154,43,.045],[6020,288,5940,225,43,.075],[6020,288,6108,235,32,.065],[6020,291,6130,317,38,.085],[6020,292,5945,315,34,.085],[6020,345,5963,326,23,.075]]
  for f:Array in fronds:
   axes.append(Vector4(f[0],f[1],f[2],f[3]));shapes.append(Vector2(f[4],f[5]))
 material.set_shader_parameter("branch_count",axes.size())
 while axes.size()<48:axes.append(Vector4.ZERO);shapes.append(Vector2.ZERO)
 material.set_shader_parameter("branch_axes",axes)
 material.set_shader_parameter("branch_shapes",shapes)

static func apply_regions(material:ShaderMaterial,family:String)->void:
 apply_branches(material,family)
 var spec:Dictionary=REGIONS.get(family,REGIONS.coastal)
 for kind:String in ["trees","grass","sea","boat"]:
  var values:Array[Vector4]=[]
  values.assign(spec[kind])
  material.set_shader_parameter(kind+"_count",values.size())
  while values.size()<(24 if kind=="grass" else 12):values.append(Vector4.ZERO)
  material.set_shader_parameter(kind+"_regions",values)

static func apply_rigid(material:ShaderMaterial,family:String)->void:
 var values:Array[Vector4]=[]
 values.assign(RIGID.get(family,[]))
 if family=="community":
  # Eighth lamp and the exposed pole under the pink pennant.
  values.append(Vector4(7526,330,7654,397))
  values.append(Vector4(7578,390,7602,516))
  values.append(Vector4(1776,438,1785,516))
 material.set_shader_parameter("rigid_count",values.size())
 while values.size()<32:values.append(Vector4.ZERO)
 material.set_shader_parameter("rigid_regions",values)

static func foliage_near(family:String,source_x:float)->float:
 var strongest:=.1
 for r:Vector4 in REGIONS.get(family,REGIONS.coastal).trees:
  strongest=maxf(strongest,1.0-smoothstep(180.0,950.0,absf(source_x-(r.x+r.z)*.5)))
 return strongest
