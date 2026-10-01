class_name LetterInsert
extends Control
## The page taken from an opened envelope. The text remains selectable and
## scrollable, while the folded lower corner is the physical close target.

signal closed

var heading: String = ""
var body: String = ""
var text_view: RichTextLabel
var fold_button: Button

func configure(next_heading: String, next_body: String) -> void:
	heading=next_heading
	body=next_body
	if is_inside_tree(): _build()
	queue_redraw()

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_STOP
	resized.connect(_layout)
	_build()
	_layout()

func _build() -> void:
	if is_instance_valid(text_view):
		text_view.queue_free()
	for child in get_children():
		if child is Button: child.queue_free()
	text_view=RichTextLabel.new()
	text_view.text=body
	text_view.selection_enabled=true
	text_view.scroll_active=true
	text_view.add_theme_font_size_override("normal_font_size",22)
	text_view.add_theme_constant_override("line_separation",9)
	text_view.add_theme_color_override("default_color",Color("3b4b43"))
	text_view.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	add_child(text_view)
	fold_button=Button.new()
	fold_button.flat=true
	fold_button.tooltip_text="收起纸页"
	fold_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state: String in ["normal","hover","pressed","focus"]:
		fold_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_child(fold_button)
	fold_button.pressed.connect(func(): closed.emit())
	fold_button.mouse_entered.connect(queue_redraw)
	fold_button.mouse_exited.connect(queue_redraw)
	_layout()

func _layout() -> void:
	if is_instance_valid(text_view):
		text_view.position=Vector2(75,114)
		text_view.size=Vector2(maxf(1,size.x-150),maxf(1,size.y-227))
	if is_instance_valid(fold_button):
		fold_button.position=Vector2(size.x-190,size.y-96)
		fold_button.size=Vector2(157,75)
	queue_redraw()

func _draw() -> void:
	var page := Rect2(Vector2.ZERO,size)
	draw_rect(Rect2(page.position+Vector2(14,18),page.size),Color(0.10,0.11,0.09,0.29))
	draw_rect(page,Color("ead8b5"))
	draw_rect(Rect2(10,10,size.x-20,size.y-20),Color("fff4d7"))
	draw_rect(page,Color("947b5c"),false,2.0)
	draw_line(Vector2(18,size.y*0.57),Vector2(size.x-18,size.y*0.57),Color("ddccaa"),1.5,true)
	draw_line(Vector2(18,size.y*0.58),Vector2(size.x-18,size.y*0.58),Color("fff9e5"),1.0,true)
	draw_line(Vector2(44,84),Vector2(size.x-44,84),Color("b8ae92"),1.3,true)
	draw_string(get_theme_font("font"),Vector2(65,57),heading,HORIZONTAL_ALIGNMENT_LEFT,size.x-130,29,Color("364f48"))
	draw_string(get_theme_font("font"),Vector2(74,size.y-37),"点右下角折页 · 收回信中",HORIZONTAL_ALIGNMENT_LEFT,size.x-220,17,Color("786e58"))
	var corner := PackedVector2Array([Vector2(size.x-102,size.y-102),Vector2(size.x-22,size.y-102),Vector2(size.x-22,size.y-22)])
	draw_colored_polygon(corner,Color("dfcda8"))
	draw_polyline(PackedVector2Array([Vector2(size.x-102,size.y-102),Vector2(size.x-22,size.y-22),Vector2(size.x-22,size.y-102)]),Color("a79371"),2,true)
	draw_string(get_theme_font("font"),Vector2(size.x-156,size.y-41),"收起 ↘",HORIZONTAL_ALIGNMENT_LEFT,115,20,Color("31574d"))
