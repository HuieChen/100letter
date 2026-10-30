extends Control
signal map_requested
signal post_office_requested
const UI=preload("res://scripts/ui/paper_ui.gd")
const Walker=preload("res://scripts/rebuild/final_walker.gd")
var minute:=540
var postal:=false
var art:TextureRect
var world:Control
var courier:Control
var can_walk:Callable
var entry_hint:Label
var entry_ready:=false
var fountain:TextureRect
var fountain_frames:Array[Texture2D]=[]
var fountain_time:=0.0
func _ready()->void:
 clip_contents=true
 var period:="morning"
 if minute>=1140 or minute<360:period="night"
 elif minute>=1020:period="sunset"
 elif minute>=660:period="noon"
 var filename:=("post_v2_" if postal else "clean_road_")+period+".png"
 var pixels:=Image.new()
 if pixels.load("res://assets/authoring/town_20261029/"+filename)!=OK:return
 world=Control.new()
 # Display the original art lower and slightly larger. The viewport crops
 # the bottom export strip without modifying any supplied source pixels.
 UI.place(world,self,Rect2(0,0,960.0*pixels.get_width()/pixels.get_height(),960))
 art=TextureRect.new()
 art.texture=ImageTexture.create_from_image(pixels)
 var breeze:=ShaderMaterial.new()
 breeze.shader=preload("res://scripts/rebuild/street_breeze.gdshader")
 breeze.set_shader_parameter("postal",postal)
 art.material=breeze
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 UI.place(art,world,Rect2(Vector2.ZERO,world.size))
 for index in range(3):
  var frame:=Image.new()
  if frame.load("res://assets/authoring/fountain_20261030/frame_%d.png"%index)==OK:
   fountain_frames.append(ImageTexture.create_from_image(frame))
 if fountain_frames.size()==3:
  fountain=TextureRect.new()
  fountain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  fountain.mouse_filter=Control.MOUSE_FILTER_IGNORE
  fountain.texture=fountain_frames[0]
  UI.place(fountain,world,Rect2((5390.0 if postal else 4104.0)*1.5,(91.0 if postal else 93.0)*1.5,337*1.5,430*1.5))
  fountain.modulate={"morning":Color(0.97,0.97,1.0),"noon":Color.WHITE,"sunset":Color(1.0,0.87,0.72),"night":Color(0.45,0.47,0.72)}[period]
 courier=Walker.new()
 courier.actor_height=295
 # Non-destructive actor-only light tint, matched to the supplied time variants.
 var actor_light={"morning":Color(0.94,0.98,1.0),"noon":Color(1.0,0.99,0.94),"sunset":Color(1.0,0.88,0.79),"night":Color(0.62,0.69,0.91)}
 courier.modulate=actor_light[period]
 UI.place(courier,world,Rect2(Vector2.ZERO,world.size))
 courier.configure(null,Rect2(100,872,world.size.x-200,0),Vector2(100,872))
 courier.manual_enabled=true
 if postal:
  entry_hint=UI.label(world,"E 进入",Rect2(world.size.x*0.376-90,490,180,52),28,Color("fff8e8"))
  entry_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  entry_hint.add_theme_color_override("font_outline_color",Color("243d50"))
  entry_hint.add_theme_constant_override("outline_size",6)
  entry_hint.hide()
 UI.button(self,"↩",Rect2(30,28,72,64),func():map_requested.emit()).name="RoadMapReturn"
func _process(_delta:float)->void:
 fountain_time+=_delta
 if is_instance_valid(fountain):fountain.texture=fountain_frames[int(fountain_time*3.0)%3]
 if not is_instance_valid(courier):return
 var allowed:bool=not can_walk.is_valid() or can_walk.call()
 if courier.manual_enabled!=allowed:courier.manual_enabled=allowed
 world.position.x=-clampf(courier.foot.x-650,0,world.size.x-1600)

 if is_instance_valid(entry_hint):
  entry_ready=allowed and absf(courier.foot.x-world.size.x*0.376)<220
  entry_hint.visible=entry_ready
func _unhandled_key_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E and entry_ready:
  entry_ready=false
  get_viewport().set_input_as_handled()
  post_office_requested.emit()
