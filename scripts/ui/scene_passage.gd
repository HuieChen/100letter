extends ColorRect
var coverage:=0.0:
	set(value):
		coverage=value
		if material:material.set_shader_parameter("coverage",coverage)
func _ready()->void:
	name="SceneTransition"
	z_index=200
	mouse_filter=Control.MOUSE_FILTER_STOP
	var ink:=ShaderMaterial.new()
	ink.shader=preload("res://scripts/ui/scene_passage.gdshader")
	material=ink
func cover()->void:
	var motion:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self,"coverage",1.0,.28)
	await motion.finished
func uncover()->void:
	material.set_shader_parameter("revealing",true)
	# One painted-frame beat before the sheet lifts keeps the arrival coherent.
	await get_tree().process_frame
	var motion:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self,"coverage",0.0,.42)
	await motion.finished
