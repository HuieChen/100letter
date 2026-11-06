extends Control
signal map_requested
signal post_office_requested
signal footstep
signal cat_requested
signal ambience_changed(wind:float, swell:float, foliage:float)
const UI=preload("res://scripts/ui/paper_ui.gd")
const Walker=preload("res://scripts/rebuild/final_walker.gd")
const Atmosphere=preload("res://scripts/rebuild/street_atmosphere.gd")
const TextureCache=preload("res://scripts/rebuild/street_texture_cache.gd")
const CameraDirector=preload("res://scripts/rebuild/street_camera_director.gd")
var minute:=540
var postal:=false
var district:="coastal"
var source_path:=""
var art:TextureRect
var world:Control
var courier:Control
var can_walk:Callable
var entry_hint:Button
var locale:="zh"
var entry_ready:=false
var _entering:=false
var fountain:TextureRect
var fountain_background:TextureRect
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
var camera_director:Node2D
func _ready()->void:
 clip_contents=true
 # Run the camera after the courier's committed foot movement in this frame.
 process_priority=1
 var period:="morning"
 if minute>=1140 or minute<360:period="night"
 elif minute>=1020:period="sunset"
 elif minute>=660:period="noon"
 var filename:=("post_v2_" if postal else "clean_road_")+period+".png"
 source_path="res://assets/authoring/town_20261029/"+filename
 if district in ["community","residential"]:
  var extension:=".jpg" if district=="residential" and period=="night" else ".png"
  source_path="res://assets/authoring/streets_20261101/"+district+"_"+period+extension
 family=district if district in ["community","residential"] else ("postal" if postal else "coastal")
 var period_paths:Array[String]=[]
 for phase:String in Atmosphere.PERIODS:
  var path:="res://assets/authoring/town_20261029/"+("post_v2_" if postal else "clean_road_")+phase+".png"
  if district in ["community","residential"]:
   path="res://assets/authoring/streets_20261101/"+district+"_"+phase+(".jpg" if district=="residential" and phase=="night" else ".png")
  period_paths.append(path)
 var selected_index:int=Atmosphere.PERIODS.find(period)
 period_textures=TextureCache.acquire(family,period_paths,selected_index)
 if period_textures.size()!=4:return
 if family=="postal":
  # Register the nine morning end props to the other phases; originals stay immutable.
  var patch:=Image.load_from_file("res://assets/authoring/street_registration_20261106/postal_morning_cluster_patch.png")
  var registered:=preload("res://scripts/rebuild/postal_morning_registration.gd").apply(period_textures[0].get_image(),patch)
  period_textures[0]=ImageTexture.create_from_image(registered)
 world=Control.new()
 # Display the original art lower and slightly larger. The viewport crops
 # the bottom export strip without modifying any supplied source pixels.
 var selected:Texture2D=period_textures[selected_index]
 UI.place(world,self,Rect2(0,0,960.0*selected.get_width()/selected.get_height(),960))
 camera_director=CameraDirector.new()
 add_child(camera_director)
 art=TextureRect.new()
 art.texture=selected
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
 var cloud_path:="res://assets/authoring/street_motion_masks_20261103/%s_cloud_clearance.png"%family
 if FileAccess.file_exists(cloud_path):
  clouds=TextureRect.new()
  clouds.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  clouds.mouse_filter=Control.MOUSE_FILTER_IGNORE
  cloud_material=ShaderMaterial.new()
  cloud_material.shader=preload("res://scripts/rebuild/street_clouds.gdshader")
  var clearance:=Image.load_from_file(cloud_path)
  cloud_material.set_shader_parameter("community_sky",family=="community")
  cloud_material.set_shader_parameter("clearance",ImageTexture.create_from_image(clearance))
  var star_path:="res://assets/authoring/street_motion_masks_20261103/%s_cloud_star_clearance.png"%family
  if FileAccess.file_exists(star_path):
   cloud_material.set_shader_parameter("star_clearance",ImageTexture.create_from_image(Image.load_from_file(star_path)))
   cloud_material.set_shader_parameter("protect_night_stars",true)
  clouds.material=cloud_material
  UI.place(clouds,world,Rect2(Vector2.ZERO,world.size))
 for index in range(3):
  var frame:=Image.new()
  if frame.load("res://assets/authoring/fountain_20261030/frame_%d.png"%index)==OK:
   fountain_frames.append(ImageTexture.create_from_image(frame))
 if fountain_frames.size()==3 and district in ["coastal","community","residential"]:
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
  if district in ["community","residential"]:fountain_rect=Rect2(386.5,86.7,335.46,427.96)
  if not postal:
   fountain_background=preload("res://scripts/rebuild/fountain_background_patch.gd").new()
   fountain_background.configure(period_textures,fountain_rect)
   world.add_child(fountain_background)
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
  entry_hint=preload("res://scripts/ui/hand_paper_button.gd").new()
  entry_hint.name="PostOfficeEntryHint"
  entry_hint.z_index=4
  entry_hint.caption="E  Enter" if locale=="en" else "E  进入"
  entry_hint.caption_size=23
  entry_hint.nameplate_texture=preload("res://scripts/rebuild/authored_quickbar.gd").entry_nameplate_texture()
  UI.place(entry_hint,world,Rect2(0,0,142,72))
  entry_hint.pressed.connect(_request_entry)
  entry_hint.hide()
 if family=="postal":
  var cat_hotspot:=Control.new()
  cat_hotspot.name="RooftopCatHotspot"
  cat_hotspot.z_index=4
  cat_hotspot.mouse_filter=Control.MOUSE_FILTER_STOP
  cat_hotspot.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  UI.place(cat_hotspot,world,Rect2(Vector2(3870,236)*1.5,Vector2(91,68)*1.5))
  cat_hotspot.gui_input.connect(func(event:InputEvent):
   if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
   if can_walk.is_valid() and not can_walk.call():return
   get_viewport().set_input_as_handled()
   cat_requested.emit())
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
  atmosphere_material.set_shader_parameter("foregrass_original_art",art.texture)
  atmosphere_material.set_shader_parameter("next_art",period_textures[ids.y])
  atmosphere_material.set_shader_parameter("night_a",1.0 if ids.x==3 else 0.0)
  atmosphere_material.set_shader_parameter("night_b",1.0 if ids.y==3 else 0.0)
 atmosphere_material.set_shader_parameter("light_mix",blend.z)
 if is_instance_valid(clouds):
  clouds.texture=period_textures[ids.x]
  cloud_material.set_shader_parameter("next_art",period_textures[ids.y])
  cloud_material.set_shader_parameter("light_mix",blend.z)
  cloud_material.set_shader_parameter("night_a",1.0 if ids.x==3 else 0.0)
  cloud_material.set_shader_parameter("night_b",1.0 if ids.y==3 else 0.0)
 # Stall illumination starts only after sunset has become night.
 var lamps:=smoothstep(1140.0,1200.0,display_minute)
 if display_minute<360.0:lamps=1.0-smoothstep(300.0,360.0,display_minute)
 atmosphere_material.set_shader_parameter("night_lights",lamps)
 if is_instance_valid(courier):courier.modulate=Atmosphere.LIGHTS[ids.x].lerp(Atmosphere.LIGHTS[ids.y],blend.z)
 if is_instance_valid(fountain):fountain.modulate=courier.modulate
 if is_instance_valid(fountain_background):fountain_background.set_time_of_day(display_minute)

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
 # Hold composition perfectly still while the player uses a camera or modal.
 world.position.x=-camera_director.advance(_delta,allowed)

 if is_instance_valid(entry_hint):
  entry_ready=not _entering and allowed and absf(courier.foot.x-world.size.x*0.376)<220
  entry_hint.visible=entry_ready or _entering
  entry_hint.position=courier.foot+Vector2(74,-courier.actor_height*0.68-entry_hint.size.y*0.5)
func _follow_courier(at:Vector2)->void:
 camera_director.frame_foot(at.x,world.size.x)
 world.position.x=-camera_director.scroll
func _unhandled_key_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E and entry_ready:
  get_viewport().set_input_as_handled()
  _request_entry()

func _request_entry()->void:
 if not entry_ready or _entering:return
 _entering=true
 entry_ready=false
 entry_hint.keyboard_press()
 await get_tree().create_timer(0.12).timeout
 if not is_inside_tree():return
 _entering=false
 if can_walk.is_valid() and not can_walk.call():return
 post_office_requested.emit()
