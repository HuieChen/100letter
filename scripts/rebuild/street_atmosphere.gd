extends RefCounted
## Shared weather clock and source-pixel regions. Original panoramas stay intact.
const PERIODS := ["morning", "noon", "sunset", "night"]
const LIGHTS := [Color(.94,.98,1), Color(1,.99,.94), Color(1,.88,.79), Color(.62,.69,.91)]
const REGIONS := {
 "community": {
  "trees": [Vector4(315,180,420,465),Vector4(248,375,402,505),Vector4(419,270,480,460),Vector4(710,350,870,510),Vector4(840,322,900,505),Vector4(2780,345,2860,478),Vector4(3970,315,4130,512),Vector4(4670,375,4738,505),Vector4(5865,120,6160,505),Vector4(6735,340,6840,440),Vector4(7610,88,7842,310),Vector4(8020,469,8100,531),Vector4(5947,385,6004,479)],
  "grass": [Vector4(366,459,403,515),Vector4(425,480,470,515),Vector4(647,476,707,515),Vector4(832,480,886,515),Vector4(895,440,970,515),Vector4(1003,474,1030,515),Vector4(1770,425,1855,515),Vector4(1840,405,1891,515),Vector4(1913,403,2009,515),Vector4(2520,442,2647,515),Vector4(2707,497,2741,515),Vector4(3458,486,3478,515),Vector4(3483,500,3499,515),Vector4(3618,477,3641,515),Vector4(3640,501,3657,515),Vector4(3772,438,3887,515),Vector4(3950,481,4026,515),Vector4(4613,465,4650,515),Vector4(4650,463,4677,515),Vector4(4704,442,4785,515),Vector4(4791,457,4825,515),Vector4(4908,436,5044,515),Vector4(5151,469,5212,515),Vector4(5328,485,5363,515),Vector4(5417,488,5474,515),Vector4(5579,453,5748,515),Vector4(5778,475,5816,515),Vector4(5816,473,5873,515),Vector4(5896,473,5970,515),Vector4(6011,478,6059,515),Vector4(6775,482,6822,515),Vector4(6846,458,6955,515),Vector4(6998,466,7026,515),Vector4(7036,489,7060,515),Vector4(7072,483,7101,515)],
  "sea": [Vector4(970,485,1050,511),Vector4(1170,486,1550,511),Vector4(2990,485,3540,511),Vector4(4840,485,5020,511),Vector4(5110,485,5370,511),Vector4(7150,485,7450,511)],
  "boat": []},
 "residential": {
  "trees": [Vector4(315,180,420,465),Vector4(248,375,402,505),Vector4(419,270,480,460),Vector4(710,350,870,510),Vector4(840,322,900,505),Vector4(1760,230,1935,505),Vector4(1935,245,2050,508),Vector4(2500,275,2635,512),Vector4(2650,250,2770,512),Vector4(6040,85,6555,510),Vector4(6990,280,7160,512),Vector4(2380,72,2492,164),Vector4(2400,160,2487,279),Vector4(2015,210,2210,317),Vector4(1975,433,2090,515),Vector4(2435,385,2575,515)],
  "grass": [Vector4(366,459,403,515),Vector4(425,480,470,515),Vector4(647,476,707,515),Vector4(832,480,886,515),Vector4(895,440,970,515),Vector4(3773,401,3891,515),Vector4(3887,389,4021,515),Vector4(4013,422,4115,515),Vector4(4148,487,4272,515),Vector4(4267,476,4452,515),Vector4(4447,481,4632,515),Vector4(4627,487,4792,515),Vector4(4771,448,4896,515),Vector4(4883,402,4996,515),Vector4(4990,428,5090,515),Vector4(5550,450,5640,515),Vector4(6140,455,6280,515),Vector4(7200,450,7310,515)],
  "sea": [Vector4(1230,484,1580,512),Vector4(3380,484,3610,512),Vector4(3670,484,3890,512),Vector4(5200,484,5480,512),Vector4(5690,484,6000,512)],
  "boat": []},
 "postal": {
  "trees": [Vector4(90,70,340,510),Vector4(710,250,843,508),Vector4(1920,150,2060,505),Vector4(2070,330,2200,510),Vector4(3430,120,3720,500),Vector4(3970,378,4086,497),Vector4(5310,250,5460,510),Vector4(5735,350,5900,510)],
  "grass": [Vector4(130,460,190,515),Vector4(238,468,370,515),Vector4(710,460,790,515),Vector4(790,466,850,515),Vector4(850,474,915,515),Vector4(1020,455,1160,515),Vector4(1660,455,1860,515),Vector4(2710,455,2860,515),Vector4(3100,455,3270,515),Vector4(4290,455,4440,515),Vector4(4780,455,4910,515)],
  "sea": [Vector4(1220,488,1450,513),Vector4(2890,488,3030,513),Vector4(4510,488,4610,513),Vector4(4960,488,5080,513)],
  "boat": []},
 "coastal": {
  "trees": [Vector4(260,50,340,505),Vector4(815,450,918,497),Vector4(914,437,998,498),Vector4(1640,405,1800,515),Vector4(1860,0,2172,505),Vector4(2130,300,2210,505),Vector4(4000,210,4190,510),Vector4(3970,397,4108,510),Vector4(4400,320,4590,510),Vector4(4558,337,4612,508)],
  "grass": [Vector4(0,483,82,515),Vector4(90,478,160,515),Vector4(168,476,240,515),Vector4(818,486,900,515),Vector4(900,480,997,515),Vector4(1180,450,1340,515),Vector4(2750,450,2860,515),Vector4(3170,450,3280,515),Vector4(4830,450,4960,515),Vector4(5150,450,5280,515)],
  "sea": [Vector4(1500,475,1760,512),Vector4(2990,475,3140,512),Vector4(3300,475,3520,512),Vector4(4860,475,4950,512),Vector4(5060,475,5140,512)],
  "boat": []}
}

# Rigid painted overlaps must stay still even where crowns/grass share a box.
const RIGID := {
 "coastal": [Vector4(350,90,945,515),Vector4(2180,125,2590,515),Vector4(1595,345,1700,516),Vector4(4065,95,4420,515)],
 "postal": [Vector4(2070,100,2630,515),Vector4(3720,130,4140,515)],
 "community": [Vector4(1890,25,2550,515),Vector4(2550,440,2760,514),Vector4(2870,340,2980,515),Vector4(4150,155,4540,515),Vector4(6200,130,6570,515),Vector4(1030,330,1157,397),Vector4(1082,390,1105,516),Vector4(1584,330,1711,397),Vector4(1636,390,1659,516),Vector4(2854,330,2981,397),Vector4(2906,390,2929,516),Vector4(3640,330,3767,397),Vector4(3692,390,3715,516),Vector4(5029,330,5156,397),Vector4(5081,390,5104,516),Vector4(5635,330,5762,397),Vector4(5687,390,5710,516),Vector4(7066,330,7193,397),Vector4(7118,390,7141,516)],

 "residential": [Vector4(2040,85,2485,514),Vector4(6305,280,6400,515),Vector4(6380,312,6850,515),Vector4(7140,340,7260,515),Vector4(390,444,700,515),Vector4(480,65,655,358),Vector4(146,469,273,515),Vector4(796,454,904,515)]
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
  if family=="community" and int(r.x) in [5865,6735,7610,8020]:continue
  if family=="coastal" and int(r.x)==1860:continue
  var w:float=r.z-r.x;var h:float=r.w-r.y
  var base:=Vector2((r.x+r.z)*.5,r.y+h*.68)
  for k in range(3):
   var tip:=Vector2(r.x+w*[.15,.58,.86][k],r.y+h*[.32,.12,.38][k])
   axes.append(Vector4(base.x,base.y,tip.x,tip.y))
   var stiffness:=.018 if family in ["community","residential"] and int(r.x) in [315,419,840] else (.075 if k!=1 else .045)
   shapes.append(Vector2(w*.35,stiffness))
 if family=="coastal":
  # The tall banana has eight original leaf attachments, not three synthetic
  # crown axes. Include its highest and rightmost tips beyond the old box.
  var blades:=[[2036,347,2111,18,38,.11],[2034,347,1974,48,34,.12],
   [2033,348,1916,113,35,.12],[2033,349,1885,176,31,.13],
   [2034,350,1900,298,21,.13],[2035,352,1914,333,17,.13],
   [2037,350,2154,202,30,.12],[2037,353,2094,360,17,.10]]
  for blade:Array in blades:
   axes.append(Vector4(blade[0],blade[1],blade[2],blade[3]));shapes.append(Vector2(blade[4],blade[5]))
 if family=="community":
  var fronds:=[[6020,290,6100,154,43,.045],[6020,288,5940,225,43,.075],[6020,288,6108,235,32,.065],[6020,291,6130,317,38,.085],[6020,292,5945,315,34,.085],[6020,345,5963,326,23,.075]]
  fronds.append_array([[6783,414,6745,376,19,.075],[6783,414,6767,353,19,.06],[6783,414,6817,353,19,.065],[6783,414,6818,408,17,.09],[6783,414,6744,413,17,.09],[7723,218,7623,198,28,.065],[7723,218,7652,291,28,.075],[7723,218,7730,99,25,.045],[7723,218,7768,126,26,.055],[7723,218,7824,197,27,.075],[7723,218,7782,260,24,.08]])
  fronds.append_array([[8053,509,8035,479,11,.075],[8053,509,8075,480,11,.08],[8053,509,8034,508,10,.09],[8053,509,8089,518,11,.1]])
  for f:Array in fronds:
   axes.append(Vector4(f[0],f[1],f[2],f[3]));shapes.append(Vector2(f[4],f[5]))
 material.set_shader_parameter("branch_count",axes.size())
 while axes.size()<48:axes.append(Vector4.ZERO);shapes.append(Vector2.ZERO)
 material.set_shader_parameter("branch_axes",axes)
 material.set_shader_parameter("branch_shapes",shapes)

static func apply_regions(material:ShaderMaterial,family:String)->void:
 material.set_shader_parameter("family_id",{"community":0,"residential":1,"postal":2,"coastal":3}.get(family,3))
 if family in ["community","residential"]:
  preload("res://scripts/rebuild/street_foreground_grass.gd").apply(material,family=="residential")
 apply_branches(material,family)
 # Linear data, not a painted texture: a conservative smooth distance from
 # rigid supports keeps every original pigment on one continuous surface.
 var path:="res://assets/authoring/street_motion_masks_20261103/%s_foliage_clearance.png"%family
 if FileAccess.file_exists(path):
  var image:=Image.load_from_file(path)
  material.set_shader_parameter("foliage_clearance",ImageTexture.create_from_image(image))
  material.set_shader_parameter("smooth_foliage",true)
 var spec:Dictionary=REGIONS.get(family,REGIONS.coastal)
 for kind:String in ["trees","grass","sea","boat"]:
  var values:Array[Vector4]=[]
  values.assign(spec[kind])
  material.set_shader_parameter(kind+"_count",values.size())
  while values.size()<({"trees":24,"grass":48,"sea":12,"boat":12}[kind]):values.append(Vector4.ZERO)
  material.set_shader_parameter(kind+"_regions",values)

static func apply_rigid(material:ShaderMaterial,family:String)->void:
 var values:Array[Vector4]=[]
 values.assign(RIGID.get(family,[]))
 if family=="community":
  # Eighth lamp and the exposed pole under the pink pennant.
  values.append(Vector4(7526,330,7654,397))
  values.append(Vector4(7578,390,7602,516))
  values.append(Vector4(1776,438,1785,516))
  values.append(Vector4(390,444,700,515))
  values.append(Vector4(480,65,655,358))
  values.append(Vector4(146,469,273,515))
  values.append(Vector4(796,454,904,515))
 material.set_shader_parameter("rigid_count",values.size())
 while values.size()<32:values.append(Vector4.ZERO)
 material.set_shader_parameter("rigid_regions",values)

static func foliage_near(family:String,source_x:float)->float:
 var strongest:=.1
 for r:Vector4 in REGIONS.get(family,REGIONS.coastal).trees:
  strongest=maxf(strongest,1.0-smoothstep(180.0,950.0,absf(source_x-(r.x+r.z)*.5)))
 return strongest
