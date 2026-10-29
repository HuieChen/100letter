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
func _ready()->void:
 clip_contents=true
 var period:="morning"
 if minute>=1140 or minute<360:period="night"
 elif minute>=1020:period="sunset"
 elif minute>=660:period="noon"
 var filename:=("post_" if postal else "road_")+period+".png"
 if not postal and period=="noon":filename="road_noon.jpg"
 var pixels:=Image.new()
 if pixels.load("res://assets/authoring/town_20261029/"+filename)!=OK:return
 world=Control.new()
 UI.place(world,self,Rect2(0,0,900.0*pixels.get_width()/pixels.get_height(),900))
 art=TextureRect.new()
 art.texture=ImageTexture.create_from_image(pixels)
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 UI.place(art,world,Rect2(Vector2.ZERO,world.size))
 courier=Walker.new()
 courier.actor_height=210
 UI.place(courier,world,Rect2(Vector2.ZERO,world.size))
 courier.configure(null,Rect2(100,837,world.size.x-200,0),Vector2(100,837))
 courier.manual_enabled=true
 if postal:
  var door:=UI.button(world,"",Rect2(world.size.x*0.410,530,120,215),func():
   if absf(courier.foot.x-world.size.x*0.418)<220:post_office_requested.emit())
  door.name="PostalStreetDoor"
 UI.button(self,"↩",Rect2(30,28,72,64),func():map_requested.emit()).name="RoadMapReturn"
func _process(_delta:float)->void:
 if not is_instance_valid(courier):return
 var allowed:bool=not can_walk.is_valid() or can_walk.call()
 if courier.manual_enabled!=allowed:courier.manual_enabled=allowed
 world.position.x=-clampf(courier.foot.x-650,0,world.size.x-1600)

