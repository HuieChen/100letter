class_name ResidentPortrait
extends Control
## New painted resident sprites, separate from locked source portraits.
## Stage actors use the same visible height convention as the courier.

const Actor = preload("res://scripts/ui/courier_actor.gd")
var resident_id: String = "nora_vale"
var actor_height: float = 0.0
var show_shadow: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func configure(id: String = "nora_vale") -> void:
	resident_id = id
	queue_redraw()


func _draw() -> void:
	var height: float = actor_height if actor_height > 0.0 else minf(size.y - 16.0, size.x * 2.35)
	height = maxf(height, 1.0)
	var feet := Vector2(size.x * 0.5, size.y - 8.0)
	if show_shadow:
		draw_set_transform(feet + Vector2(0, 2), 0.0, Vector2(1.0, 0.22) * height / Actor.HEIGHT)
		draw_circle(Vector2.ZERO, 19, Color(0.20, 0.32, 0.29, 0.12))
		draw_set_transform(Vector2.ZERO)
	if resident_id == "chenyuan":
		Actor.draw_chenyuan(self, feet, height)
	else:
		Actor.draw_resident(self, feet, height)
