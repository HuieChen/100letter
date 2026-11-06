extends ColorRect
var coverage:=0.0:
	set(value):
		coverage=value
		color=Color(0.09,0.085,0.075,coverage)
func _ready()->void:
	name="SceneTransition"
	z_index=200
	mouse_filter=Control.MOUSE_FILTER_STOP
	# A quiet dissolve, without inserting an unrelated full-screen paper image.
	color=Color(0.09,0.085,0.075,coverage)
func cover()->void:
	var motion:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self,"coverage",1.0,.18)
	await motion.finished
func uncover()->void:
	# Keep the cover opaque until the newly positioned world has actually rendered.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var motion:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self,"coverage",0.0,.28)
	await motion.finished
