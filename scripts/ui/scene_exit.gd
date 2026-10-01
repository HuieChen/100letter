extends Button
## A small path sign inside the world. Travelling through it uses the same
## game clock as the map, while the map remains available for distant routes.
var destination: String = ""
var minutes: int = 0
var leftward: bool = false

func _ready() -> void:
	flat = true
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	tooltip_text = "步行 %d 分钟前往 %s" % [minutes,destination]
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	var active: bool = is_hovered() or has_focus()
	var body := PackedVector2Array([Vector2(0,5),Vector2(size.x-16,5),Vector2(size.x,38),Vector2(size.x-16,72),Vector2(0,72)])
	if leftward:
		body = PackedVector2Array([Vector2(16,5),Vector2(size.x,5),Vector2(size.x,72),Vector2(16,72),Vector2(0,38)])
	draw_colored_polygon(body,Color("f4e8cb") if active else Color("e9d9b9"))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline,Color("61766b"),1.6,true)
	var arrow: String = "←" if leftward else "→"
	var x: float = 17 if leftward else 9
	draw_string(get_theme_font("font"),Vector2(x,33),destination,HORIZONTAL_ALIGNMENT_LEFT,size.x-34,19,Color("345951"))
	draw_string(get_theme_font("font"),Vector2(x,58),"%s  步行 %d 分钟" % [arrow,minutes],HORIZONTAL_ALIGNMENT_LEFT,size.x-34,15,Color("647a6d"))
