extends RefCounted
## Observed source silhouettes, in unchanged panorama pixels. The coastal
## paintings deliberately have different birds at different times of day.
const MAX_BIRDS := 12
const MASK_ROOT := "res://assets/authoring/street_motion_masks_20261103/"
static var _night_clearance:Dictionary = {}

static func _bird(box:Vector4,body:Vector2,seed:float)->Dictionary:
 return {"box":box,"anchor":Vector4(body.x,body.y,seed,clampf((box.z-box.x)*.035+.65,1.5,4.2))}

static func inventory(family:String,period:int)->Array[Dictionary]:
 var birds:Array[Dictionary]=[]
 if family=="residential" and period==3:return birds
 if family!="coastal":
  birds=[
   _bird(Vector4(975,148,1056,175),Vector2(1014,170),.3),
   _bird(Vector4(1038,161,1086,185),Vector2(1061,180),1.9),
   _bird(Vector4(1015,201,1098,230),Vector2(1054,225),3.2),
   _bird(Vector4(1882,124,1964,164),Vector2(1925,156),4.6),
   _bird(Vector4(2967,238,3022,257),Vector2(2996,251.5),.9),
   _bird(Vector4(3018,255,3080,279),Vector2(3050,274),2.4)]
  if family!="postal":birds.append(_bird(Vector4(3857,194,3930,230),Vector2(3895,223),5.2))
  birds.append(_bird(Vector4(4629,171,4679,192),Vector2(4656,187),3.8))
  birds.append(_bird(Vector4(4675,189,4730,220),Vector2(4700,212),6.4))
  if family=="residential":birds.append(_bird(Vector4(6955,182,7055,222),Vector2(7005,213),7.8))
  return birds
 if period in [0,2]:
  birds.append(_bird(Vector4(927,96,1044,143),Vector2(987,137),.5))
  birds.append(_bird(Vector4(1042,112,1117,147),Vector2(1088,139),2.1))
 elif period==1:
  birds.append(_bird(Vector4(1272,76,1375,115),Vector2(1331,108),.5))
  birds.append(_bird(Vector4(1375,98,1448,129),Vector2(1412,122),2.1))
  birds.append(_bird(Vector4(1475,180,1509,203),Vector2(1492,197),4.1))
 if period in [0,2]:
  birds.append(_bird(Vector4(2883,247,2983,281),Vector2(2925,275),3.3))
  birds.append(_bird(Vector4(2862,279,2908,303),Vector2(2884,298),5.8))
 else:birds.append(_bird(Vector4(2884,247,2942,281),Vector2(2925,274),3.3))
 birds.append(_bird(Vector4(3558,263,3610,289),Vector2(3584,283),6.7))
 birds.append(_bird(Vector4(3606,272,3671,301),Vector2(3638,294),8.2))
 return birds

static func apply(material:ShaderMaterial,family:String,period_a:int,period_b:int)->void:
 if material==null:return
 for variant:int in range(2):
  var suffix:="_a" if variant==0 else "_b"
  var period:int=period_a if variant==0 else period_b
  var birds:=inventory(family,period)
  var boxes:Array[Vector4]=[]
  var anchors:Array[Vector4]=[]
  var bounds:=Vector4(INF,INF,-INF,-INF)
  for bird:Dictionary in birds:
   boxes.append(bird.box);anchors.append(bird.anchor)
   var box:Vector4=bird.box
   bounds=Vector4(minf(bounds.x,box.x-7.0),minf(bounds.y,box.y-7.0),maxf(bounds.z,box.z+7.0),maxf(bounds.w,box.w+7.0))
  material.set_shader_parameter("bird_count"+suffix,birds.size())
  material.set_shader_parameter("bird_bounds"+suffix,Vector4.ZERO if birds.is_empty() else bounds)
  while boxes.size()<MAX_BIRDS:boxes.append(Vector4.ZERO);anchors.append(Vector4.ZERO)
  material.set_shader_parameter("bird_boxes"+suffix,boxes)
  material.set_shader_parameter("bird_anchors"+suffix,anchors)
  material.set_shader_parameter("bird_night"+suffix,period==3)
 if not _night_clearance.has(family):
  var path:=MASK_ROOT+family+"_cloud_star_clearance.png"
  if FileAccess.file_exists(path):_night_clearance[family]=ImageTexture.create_from_image(Image.load_from_file(path))
 if _night_clearance.has(family):material.set_shader_parameter("bird_night_clearance",_night_clearance[family])
