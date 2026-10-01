extends Control
## Illustrated scenery is an image-generation asset, never procedural geometry.
## The same painted corner pixels are drawn above actors to preserve occlusion.
const CANVAS := Vector2(1600,900)
const ROOT := "res://assets/generated/environments/"
var foreground: bool = false
var location_id: String = "post_office"
var minute: int = 540
var _painting: Texture2D

func configure(id: String, in_front: bool = false, at_minute: int = 540) -> void:
	location_id=id
	foreground=in_front
	minute=at_minute
	var path=ROOT+id+".png"
	if ResourceLoader.exists(path): _painting=load(path)
	queue_redraw()

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if _painting==null: return
	if not foreground:
		draw_texture_rect(_painting,Rect2(Vector2.ZERO,size),false)
		return
	# Ordinary render regions of the generated painting, not altered user art.
	var source_scale: Vector2=_painting.get_size()/CANVAS
	var target_scale: Vector2=size/CANVAS
	for corner in [Rect2(0,815,178,85),Rect2(1450,815,150,85)]:
		draw_texture_rect_region(_painting,Rect2(corner.position*target_scale,corner.size*target_scale),Rect2(corner.position*source_scale,corner.size*source_scale))
