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
	size = Vector2(740, 430) if not is_note else Vector2(360, 440)
	mouse_default_cursor_shape = CURSOR_DRAG
	text_label = RichTextLabel.new()
	text_label.position = Vector2(38, 88)
	if not handwriting.is_empty(): text_label.position.y=113
	text_label.size = Vector2(size.x - 76, size.y - 135)
	if not handwriting.is_empty(): text_label.size.y-=25
	text_label.add_theme_font_size_override("normal_font_size", 23 if not is_note else 21)
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
	draw_style_box(PaperUI.style(Color(0.16,0.22,0.2,0.13)), Rect2(Vector2(7,10),size))
	draw_style_box(PaperUI.style(Color("fff6df"),Color("c7bca3"),3),Rect2(Vector2.ZERO,size))
	var f = get_theme_font("font")
	draw_string(f,Vector2(30,38),serial,HORIZONTAL_ALIGNMENT_LEFT,size.x-70,17,PaperUI.MUTED)
	if not handwriting.is_empty() and not reverse:
		var sample_font: Font=load("res://assets/fonts/Caveat.ttf") if ResourceLoader.exists("res://assets/fonts/Caveat.ttf") else f
		draw_string(sample_font,Vector2(38,85),handwriting,HORIZONTAL_ALIGNMENT_LEFT,size.x-155,33,PaperUI.INK)
	if not is_note:
		draw_rect(Rect2(size.x-100,22,70,56),PaperUI.CORAL if urgent else PaperUI.TEAL)
		draw_string(f,Vector2(size.x-88,56),"急" if urgent else "邮",HORIZONTAL_ALIGNMENT_LEFT,50,24,PaperUI.PAPER)
		draw_line(Vector2(30,size.y-47),Vector2(size.x-30,size.y-47),Color("d5cbb5"),1)
		draw_string(f,Vector2(32,size.y-20),"背面 · 点击右边翻回" if reverse else "按住纸边移动 · 右边缘翻面 · 字区滚轮阅读 · 纸边滚轮缩放",HORIZONTAL_ALIGNMENT_LEFT,size.x-45,16,PaperUI.MUTED)
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
			var zoom = clampf(scale.x + (0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1),0.8,1.24)
			scale = Vector2.ONE*zoom
			moved.emit(position,scale.x,reverse)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position()-drag_offset
		position.x = clampf(position.x,20,1500-size.x*scale.x)
		position.y = clampf(position.y,230,760-size.y*scale.y)
		accept_event()
