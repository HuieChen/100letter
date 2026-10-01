class_name MailCard
extends Control

signal moved(card_position: Vector2, card_scale: float, reverse: bool)
signal cue(kind: String)

var front = ""
var back = ""
var serial = ""
var reverse = false
var urgent = false
var opened = false
var restored = false
var tamper = 0.0
var dragging = false
var drag_offset = Vector2.ZERO
var text_label: RichTextLabel
var is_note = false
var handwriting = ""

func _ready() -> void:
	size = Vector2(440, 600) if not is_note else Vector2(360, 440)
	mouse_default_cursor_shape = CURSOR_DRAG
	text_label = RichTextLabel.new()
	text_label.position = Vector2(38, 88) if is_note else Vector2(54, 92)
	if not handwriting.is_empty(): text_label.position.y=113
	text_label.size = Vector2(size.x - 76, size.y - 135) if is_note else Vector2(size.x - 108, size.y - 151)
	if not handwriting.is_empty(): text_label.size.y-=25
	text_label.add_theme_font_size_override("normal_font_size", 21)
	text_label.add_theme_color_override("default_color", PaperUI.INK)
	text_label.add_theme_constant_override("line_separation",5)
	text_label.selection_enabled = true
	text_label.scroll_active = true
	text_label.mouse_filter = MOUSE_FILTER_STOP
	add_child(text_label)
	refresh()

func refresh() -> void:
	if text_label:
		text_label.text = back if reverse else front
		text_label.scroll_to_line(0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(11,13),size),Color(0.17,0.16,0.12,0.23))
	draw_rect(Rect2(Vector2.ZERO,size),Color("f7edcf"))
	draw_rect(Rect2(Vector2(8,8),size-Vector2(16,16)),Color("fff7df"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("a99471"),false,1.6)
	# Creases and lightly worn corners keep this a handled sheet of paper.
	draw_line(Vector2(8,size.y*0.53),Vector2(size.x-8,size.y*0.53),Color("e4d6b8"),1.3,true)
	draw_line(Vector2(19,size.y*0.54),Vector2(size.x-19,size.y*0.54),Color("fff9e9"),1.0,true)
	draw_line(Vector2(36,18),Vector2(26,39),Color("d8c8a8"),2,true)
	draw_line(Vector2(size.x-38,size.y-15),Vector2(size.x-22,size.y-42),Color("d8c8a8"),2,true)
	var f = get_theme_font("font")
	draw_string(f,Vector2(51,42),serial,HORIZONTAL_ALIGNMENT_LEFT,size.x-110,17,PaperUI.MUTED)
	if not is_note:
		draw_string(f,Vector2(51,68),"背面记录" if reverse else "今日来信",HORIZONTAL_ALIGNMENT_LEFT,size.x-110,18,Color("8a806a"))
	if not handwriting.is_empty() and not reverse:
		var sample_font: Font=load("res://assets/fonts/Caveat.ttf") if ResourceLoader.exists("res://assets/fonts/Caveat.ttf") else f
		draw_string(sample_font,Vector2(38,85),handwriting,HORIZONTAL_ALIGNMENT_LEFT,size.x-155,33,PaperUI.INK)
	if not is_note:
		draw_rect(Rect2(size.x-93,22,48,53),PaperUI.CORAL if urgent else PaperUI.TEAL)
		draw_string(f,Vector2(size.x-84,57),"急" if urgent else "邮",HORIZONTAL_ALIGNMENT_LEFT,38,24,PaperUI.PAPER)
		draw_line(Vector2(49,size.y-49),Vector2(size.x-49,size.y-49),Color("d5cbb5"),1)
		draw_string(f,Vector2(51,size.y-23),"背面 · 点右缘翻回" if reverse else "移纸 · 右缘翻面 · 字区滚动",HORIZONTAL_ALIGNMENT_LEFT,size.x-91,16,PaperUI.MUTED)
		if reverse:
			draw_polyline(PackedVector2Array([Vector2(8,55),Vector2(size.x/2,110),Vector2(size.x-8,55)]),Color("c9b991"),2)
		if opened:
			draw_line(Vector2(15,7),Vector2(size.x-18,7),Color("ba785d"),3 if tamper > 20 else 1.5)
		if restored:
			draw_rect(Rect2(30,4,size.x-60,15),Color(0.73,0.75,0.60,0.36 if tamper < 30 else 0.65))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not is_note and (event.double_click or event.position.x > size.x-26):
				reverse = not reverse
				cue.emit("flip")
				refresh()
				moved.emit(position,scale.x,reverse)
			elif event.pressed:
				dragging = true
				drag_offset = get_global_mouse_position()-global_position
				move_to_front()
				cue.emit("paper")
			else:
				dragging = false
				moved.emit(position,scale.x,reverse)
				cue.emit("paper")
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var zoom = clampf(scale.x + (0.06 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.06),0.9,1.08)
			scale = Vector2.ONE*zoom
			moved.emit(position,scale.x,reverse)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position()-drag_offset
		position.x = clampf(position.x,475,1210-size.x*scale.x)
		position.y = clampf(position.y,190,810-size.y*scale.y)
		accept_event()
