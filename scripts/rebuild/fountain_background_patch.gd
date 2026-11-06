extends TextureRect
# Isolated proposal: derive each family's mask from its own noon source. Original Image
# objects and animation bytes are never modified. Insert immediately before the
# fountain node; call set_time_of_day alongside the road's existing time update.
const Atmosphere=preload("res://scripts/rebuild/street_atmosphere.gd")
const PATCH=Rect2i(488,380,123,67)
const REGIONS=[Rect2i(488,380,16,20),Rect2i(598,382,13,20),Rect2i(502,390,21,57),Rect2i(588,390,13,57)]
const DONORS=[Vector2i(486,486),Vector2i(612,612),Vector2i(500,523),Vector2i(586,603)]
const BASE_FOUNTAIN=Rect2(386.5,86.7,335.46,427.96)
var patch_rect:Rect2i
var regions:Array[Rect2i]=[]
var donors_by_region:Array[Vector2i]=[]
var horizon_range:Vector2i
var period_textures:Array[Texture2D]=[]
var patch_material:ShaderMaterial

func configure(sources:Array[Texture2D],fountain_rect_source_pixels:Rect2=BASE_FOUNTAIN)->void:
 assert(sources.size()==4)
 var ratio:=fountain_rect_source_pixels.size/BASE_FOUNTAIN.size
 var offset:=fountain_rect_source_pixels.position-BASE_FOUNTAIN.position*ratio
 patch_rect=_map_rect(PATCH,ratio,offset)
 regions.clear();donors_by_region.clear();period_textures.clear()
 for k in range(REGIONS.size()):
  regions.append(_map_rect(REGIONS[k],ratio,offset))
  donors_by_region.append(Vector2i(roundi(float(DONORS[k].x)*ratio.x+offset.x),roundi(float(DONORS[k].y)*ratio.x+offset.x)))
 horizon_range=Vector2i(ceili(418.0*ratio.y+offset.y-0.001),floori(441.0*ratio.y+offset.y+0.001))
 var reference:Image=sources[1].get_image()
 var masks:Array[PackedVector2Array]=[]
 for k in range(regions.size()):
  var points:=PackedVector2Array()
  var r:Rect2i=regions[k]
  for y in range(r.position.y,r.end.y):
   for x in range(r.position.x,r.end.x):
    if _mask_at(reference,x,y,k):points.append(Vector2(x,y))
  masks.append(points)
 for source:Texture2D in sources:
  var src:Image=source.get_image()
  # Keep the original RGB opaque outside the changed water pixels. A sparse
  # alpha mask filtered over the old water creates a second antialias fringe.
  var patch:=src.get_region(patch_rect)
  patch.convert(Image.FORMAT_RGBA8)
  for k in range(regions.size()):
   var donors:Vector2i=donors_by_region[k]
   var hl:=_horizon(src,donors.x)
   var hr:=_horizon(src,donors.y)
   for point:Vector2 in masks[k]:
    var p:=Vector2i(point)
    var c:Color
    if donors.x==donors.y:c=src.get_pixel(donors.x,p.y)
    else:
     var t:=float(p.x-donors.x)/float(donors.y-donors.x)
     var h:=lerpf(hl,hr,t)
     c=_sample_col(src,donors.x,float(p.y)+hl-h).lerp(_sample_col(src,donors.y,float(p.y)+hr-h),t)
    c.a=1.0
    patch.set_pixelv(p-patch_rect.position,c)
  period_textures.append(ImageTexture.create_from_image(patch))
 expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 position=Vector2(patch_rect.position)*1.5
 size=Vector2(patch_rect.size)*1.5
 patch_material=ShaderMaterial.new()
 var patch_shader:=Shader.new()
 patch_shader.code="shader_type canvas_item; render_mode unshaded; uniform sampler2D next_art : source_color, filter_linear, repeat_disable; uniform float light_mix=0.0; void fragment(){COLOR=mix(texture(TEXTURE,UV),texture(next_art,UV),light_mix);}"
 patch_material.shader=patch_shader
 material=patch_material
 set_time_of_day(720.0)

func set_time_of_day(value:float)->void:
 if period_textures.size()!=4:return
 var blend:=Atmosphere.time_pair(fposmod(value,1440.0))
 texture=period_textures[int(blend.x)]
 patch_material.set_shader_parameter("next_art",period_textures[int(blend.y)])
 patch_material.set_shader_parameter("light_mix",blend.z)

static func _map_rect(r:Rect2i,ratio:Vector2,offset:Vector2)->Rect2i:
 # Round inward: the lower limit must not enter the painted basin rim.
 var lo:=Vector2(r.position)*ratio+offset
 var hi:=Vector2(r.end)*ratio+offset
 var p:=Vector2i(ceili(lo.x-0.001),ceili(lo.y-0.001))
 return Rect2i(p,Vector2i(floori(hi.x+0.001),floori(hi.y+0.001))-p)

func _mask_at(reference:Image,x:int,y:int,k:int)->bool:
 var roi:Rect2i=regions[k]
 for oy in range(-1,2):
  for ox in range(-1,2):
   var p:=Vector2i(x+ox,y+oy)
   if k<2 and not roi.has_point(p):continue
   var c:=reference.get_pixelv(p)
   if k<2:
    var sky:=reference.get_pixel(donors_by_region[k].x,p.y)
    if c.r-sky.r>10.0/255.0 and c.g-sky.g>7.0/255.0:return true
   else:
    var cyan:=c.g-c.r>15.0/255.0 and c.b-c.r>8.0/255.0 and c.b-c.g<14.0/255.0 and c.g>120.0/255.0
    var lo:=minf(c.r,minf(c.g,c.b))
    var hi:=maxf(c.r,maxf(c.g,c.b))
    if cyan or (hi-lo<30.0/255.0 and lo>210.0/255.0):return true
 return false

func _horizon(source:Image,x:int)->float:
 var best:=-1.0
 var edge:=float(horizon_range.x)+0.5
 for y in range(horizon_range.x,horizon_range.y):
  var a:=source.get_pixel(x,y)
  var b:=source.get_pixel(x,y+1)
  var strength:=Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length_squared()
  if strength>best:
   best=strength
   edge=float(y)+0.5
 return edge

static func _sample_col(source:Image,x:int,y:float)->Color:
 var base:=int(floor(y))
 return source.get_pixel(x,base).lerp(source.get_pixel(x,base+1),y-float(base))
