extends Node
## Source-preserving motion for the supplied cover and postal room atlas.
const SHADER=preload("res://scripts/rebuild/scene_local_motion.gdshader")
var material:ShaderMaterial
var motion_time:=0.0
static func attach_cover(cover:TextureRect)->Node:
 return _attach(cover,0)
static func attach_room(image:TextureRect)->Node:
 return _attach(image,1)
static func _attach(image:TextureRect,kind:int)->Node:
 var driver=load("res://scripts/rebuild/scene_local_motion.gd").new()
 driver.name="LocalSceneMotion"
 driver.material=ShaderMaterial.new()
 driver.material.shader=SHADER
 driver.material.set_shader_parameter("scene_kind",kind)
 image.material=driver.material
 image.add_child(driver)
 return driver
func set_motion_time(seconds:float)->void:
 motion_time=seconds
 material.set_shader_parameter("motion_time",motion_time)
func _process(delta:float)->void:
 set_motion_time(motion_time+delta)
