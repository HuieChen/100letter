extends RefCounted
## One restrained material language for the existing paper surfaces.
static func enter(surface:Control)->void:
	if not is_instance_valid(surface):return
	surface.pivot_offset=surface.size*.5
	surface.scale=Vector2.ONE*.978
	surface.modulate.a=0.0
	var motion:=surface.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(surface,"scale",Vector2.ONE,.24)
	motion.tween_property(surface,"modulate:a",1.0,.18)

static func backing(color:Color)->StyleBoxFlat:
	var paper:=StyleBoxFlat.new()
	paper.bg_color=color
	paper.border_color=Color("dbcfb7")
	paper.set_border_width_all(1)
	paper.border_width_bottom=2
	paper.set_corner_radius_all(3)
	paper.shadow_color=Color(.12,.16,.15,.22)
	paper.shadow_size=18
	paper.shadow_offset=Vector2(0,9)
	return paper
