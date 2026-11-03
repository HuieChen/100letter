extends Control
signal map_requested
signal post_office_requested
signal footstep
signal ambience_changed(wind:float, swell:float, foliage:float)
const UI=preload("res://scripts/ui/paper_ui.gd")
const Walker=preload("res://scripts/rebuild/final_walker.gd")
const Atmosphere=preload("res://scripts/rebuild/street_atmosphere.gd")
var minute:=540
var postal:=false
var district:="coastal"
var source_path:=""
var art:TextureRect
var world:Control
var courier:Control
var can_walk:Callable
var entry_hint:Label
var entry_ready:=false
var fountain:TextureRect
var fountain_frames:Array[Texture2D]=[]
var fountain_time:=0.0
var weather_time:=0.0
var display_minute:=540.0
var _clock_minute:=540.0
var _light_target:=540.0
var time_rate:=0.0
var _light_tween:Tween
var atmosphere_material:ShaderMaterial
var clouds:TextureRect
var cloud_material:ShaderMaterial
var period_textures:Array[Texture2D]=[]
var _time_ids:=Vector2i(-1,-1)
var family:="coastal"
func _ready()->void:
 clip_contents=true
 var period:="morning"
 if minute>=1140 or minute<360:period="night"
 elif minute>=1020:period="sunset"
 elif minute>=660:period="noon"
 var filename:=("post_v2_" if postal else "clean_road_")+period+".png"
 source_path="res://assets/authoring/town_20261029/"+filename
 if district in ["community","residential"]:
  var extension:=".jpg" if district=="residential" and period=="night" else ".png"
  source_path="res://assets/authoring/streets_20261101/"+district+"_"+period+extension
 var pixels:=Image.new()
 if pixels.load(source_path)!=OK:return
 world=Control.new()
 # Display the original art lower and slightly larger. The viewport crops
 # the bottom export strip without modifying any supplied source pixels.
 UI.place(world,self,Rect2(0,0,960.0*pixels.get_width()/pixels.get_height(),960))
 art=TextureRect.new()
 art.texture=ImageTexture.create_from_image(pixels)
 family=district if district in ["community","residential"] else ("postal" if postal else "coastal")
 for phase:String in Atmosphere.PERIODS:
  var path:="res://assets/authoring/town_20261029/"+("post_v2_" if postal else "clean_road_")+phase+".png"
  if district in ["community","residential"]:
   path="res://assets/authoring/streets_20261101/"+district+"_"+phase+(".jpg" if district=="residential" and phase=="night" else ".png")
  var image:=Image.load_from_file(path)
  if image==null or image.is_empty():period_textures.append(art.texture)
  else:period_textures.append(ImageTexture.create_from_image(image))
 atmosphere_material=ShaderMaterial.new()
 atmosphere_material.shader=preload("res://scripts/rebuild/street_atmosphere.gdshader")
 atmosphere_material.set_shader_parameter("community",district=="community")
 # The revised noon painting uses warm roof pigment. Recover the roof
 # silhouette from the matching blue morning painting, never from lighting.
 atmosphere_material.set_shader_parameter("day_geometry",period_textures[0])
 Atmosphere.apply_regions(atmosphere_material,family)
 Atmosphere.apply_rigid(atmosphere_material,family)
 art.material=atmosphere_material
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 UI.place(art,world,Rect2(Vector2.ZERO,world.size))
 if district=="community":
  clouds=TextureRect.new()
  clouds.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  clouds.mouse_filter=Control.MOUSE_FILTER_IGNORE
  cloud_material=ShaderMaterial.new()
  cloud_material.shader=preload("res://scripts/rebuild/street_clouds.gdshader")
  var clearance:=Image.load_from_file("res://assets/authoring/street_motion_masks_20261103/community_cloud_clearance.png")
  cloud_material.set_shader_parameter("clearance",ImageTexture.create_from_image(clearance))
  clouds.material=cloud_material
  UI.place(clouds,world,Rect2(Vector2.ZERO,world.size))
 for index in range(3):
  var frame:=Image.new()
  if frame.load("res://assets/authoring/fountain_20261030/frame_%d.png"%index)==OK:
   fountain_frames.append(ImageTexture.create_from_image(frame))
 if fountain_frames.size()==3 and district in ["coastal","community"]:
  fountain=TextureRect.new()
  fountain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  fountain.mouse_filter=Control.MOUSE_FILTER_IGNORE
  fountain.texture=fountain_frames[0]
  var water_material:=ShaderMaterial.new()
  water_material.shader=preload("res://scripts/rebuild/fountain_water_only.gdshader")
  fountain.material=water_material
  # Reuse the user's imported water frames. Community has the same statue,
  # registered against its fixed bird and basin landmarks in source pixels.
  var fountain_rect:=Rect2((5390.0 if postal else 4104.0), (91.0 if postal else 93.0),337,430)
  if district=="community":fountain_rect=Rect2(386.5,86.7,335.46,427.96)
  UI.place(fountain,world,Rect2(fountain_rect.position*1.5,fountain_rect.size*1.5))
  fountain.modulate={"morning":Color(0.97,0.97,1.0),"noon":Color.WHITE,"sunset":Color(1.0,0.87,0.72),"night":Color(0.45,0.47,0.72)}[period]
 courier=Walker.new()
 courier.actor_height=295
 # Non-destructive actor-only light tint, matched to the supplied time variants.
 var actor_light={"morning":Color(0.94,0.98,1.0),"noon":Color(1.0,0.99,0.94),"sunset":Color(1.0,0.88,0.79),"night":Color(0.62,0.69,0.91)}
 courier.modulate=actor_light[period]
 UI.place(courier,world,Rect2(Vector2.ZERO,world.size))
 courier.configure(null,Rect2(100,872,world.size.x-200,0),Vector2(100,872))
 courier.foot_position_changed.connect(_follow_courier)
 courier.footstep.connect(func():
  if not can_walk.is_valid() or can_walk.call():footstep.emit())
 _follow_courier(courier.foot)
 courier.manual_enabled=true
 if postal:
  entry_hint=UI.label(world,"E 进入",Rect2(world.size.x*0.376-90,490,180,52),28,Color("fff8e8"))
  entry_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  entry_hint.add_theme_color_override("font_outline_color",Color("243d50"))
  entry_hint.add_theme_constant_override("outline_size",6)
  entry_hint.hide()
 UI.button(self,"↩",Rect2(30,28,72,64),func():map_requested.emit()).name="RoadMapReturn"
 set_time_of_day(float(minute))

func set_time_of_day(value:float)->void:
 _clock_minute=value
 display_minute=fposmod(value,1440.0)
 if period_textures.size()!=4:return
 var blend:=Atmosphere.time_pair(display_minute)
 var ids:=Vector2i(int(blend.x),int(blend.y))
 if ids!=_time_ids:
  _time_ids=ids
  art.texture=period_textures[ids.x]
  atmosphere_material.set_shader_parameter("next_art",period_textures[ids.y])
  atmosphere_material.set_shader_parameter("night_a",1.0 if ids.x==3 else 0.0)
  atmosphere_material.set_shader_parameter("night_b",1.0 if ids.y==3 else 0.0)
 atmosphere_material.set_shader_parameter("light_mix",blend.z)
 if is_instance_valid(clouds):
  clouds.texture=period_textures[ids.x]
  cloud_material.set_shader_parameter("next_art",period_textures[ids.y])
  cloud_material.set_shader_parameter("light_mix",blend.z)
 # Stall illumination starts only after sunset has become night.
 var lamps:=smoothstep(1140.0,1200.0,display_minute)
 if display_minute<360.0:lamps=1.0-smoothstep(300.0,360.0,display_minute)
 atmosphere_material.set_shader_parameter("night_lights",lamps)
 if is_instance_valid(courier):courier.modulate=Atmosphere.LIGHTS[ids.x].lerp(Atmosphere.LIGHTS[ids.y],blend.z)
 if is_instance_valid(fountain):fountain.modulate=courier.modulate

func transition_time_of_day(value:float)->void:
 # Saves store cumulative minutes. Keep that clock unwrapped while only the
 # lighting lookup wraps, otherwise saving on day two plays a whole day.
 if _light_tween and _light_tween.is_valid():
  if is_equal_approx(_light_target,value):return
  _light_tween.kill()
 _light_target=value
 if is_equal_approx(_clock_minute,value):return
 _light_tween=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 _light_tween.tween_method(set_time_of_day,_clock_minute,value,1.4)

func set_fountain_time(seconds:float)->void:
 # Keep the original imported three-frame / 3 fps loop, including recordings.
 fountain_time=maxf(0.0,seconds)
 if is_instance_valid(fountain):
  fountain.texture=fountain_frames[int(fountain_time*3.0)%fountain_frames.size()]

func set_weather_time(seconds:float)->void:
 weather_time=seconds
 if atmosphere_material:atmosphere_material.set_shader_parameter("weather_time",weather_time)
 if cloud_material:cloud_material.set_shader_parameter("weather_time",weather_time)

func _process(_delta:float)->void:
 set_weather_time(weather_time+_delta)
 if time_rate!=0.0:set_time_of_day(_clock_minute+time_rate*_delta)
 set_fountain_time(fountain_time+_delta)
 if not is_instance_valid(courier):return
 var source_x:float=courier.foot.x/1.5
 ambience_changed.emit(Atmosphere.wind_at(weather_time,source_x),Atmosphere.swell_at(weather_time,source_x),Atmosphere.foliage_near(family,source_x))
 var allowed:bool=not can_walk.is_valid() or can_walk.call()
 if courier.manual_enabled!=allowed:courier.manual_enabled=allowed

 if is_instance_valid(entry_hint):
  entry_ready=allowed and absf(courier.foot.x-world.size.x*0.376)<220
  entry_hint.visible=entry_ready
func _follow_courier(at:Vector2)->void:
 world.position.x=-clampf(at.x-650,0,world.size.x-1600)
func _unhandled_key_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E and entry_ready:
  entry_ready=false
  get_viewport().set_input_as_handled()
  post_office_requested.emit()
