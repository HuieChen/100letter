extends RefCounted
const ROOT="res://assets/authoring/street_motion_masks_20261103/"
static func apply(material:ShaderMaterial,fountain_only:bool=false)->void:
 for name:String in ["alpha","backmap"]:
  var image=Image.load_from_file(ROOT+"community_foregrass_"+name+".png")
  material.set_shader_parameter("foregrass_"+name,ImageTexture.create_from_image(image))
 material.set_shader_parameter("foregrass_enabled",true)
 material.set_shader_parameter("foregrass_fountain_only",fountain_only)
