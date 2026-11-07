extends RefCounted
const ROOT="res://assets/authoring/street_motion_masks_20261103/"
static func apply(material:ShaderMaterial,fountain_only:bool=false,family:String="community")->void:
 var prefix:="postal" if family=="postal" else "community"
 for name:String in ["alpha","backmap"]:
  var texture=preload("res://scripts/rebuild/street_texture_cache.gd").auxiliary(family,ROOT+prefix+"_foregrass_"+name+".png")
  if texture==null:return
  material.set_shader_parameter("foregrass_"+name,texture)
 material.set_shader_parameter("foregrass_enabled",true)
 material.set_shader_parameter("foregrass_fountain_only",fountain_only)
 material.set_shader_parameter("foregrass_postal",family=="postal")
