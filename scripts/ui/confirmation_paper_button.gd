extends Button
## Generated paper artwork; live typography and a stable hit target.
const PAPER=preload("res://assets/ui/confirmation_20261109/rounded_paper.png")
const FONT=preload("res://assets/fonts/DearRounded.tres")
var lift:=0.0:
	set(value):lift=value;queue_redraw()
var _hover:=false
var _motion:Tween
func _ready()->void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state:String in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state:String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	mouse_entered.connect(func():_hover=true;grab_focus();_settle())
	mouse_exited.connect(func():_hover=false;_settle())
	focus_entered.connect(_settle);focus_exited.connect(_settle)
	button_down.connect(_settle);button_up.connect(_settle)
	resized.connect(queue_redraw)
func _settle()->void:
	if _motion and _motion.is_valid():_motion.kill()
	var target:=2.0 if button_pressed else (-2.0 if has_focus() or _hover else 0.0)
	_motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self,"lift",target,.07 if button_pressed else .13)
	queue_redraw()
func _draw()->void:
	var active:=has_focus() or _hover
	var tint:=Color("dce9df") if active else Color.WHITE
	if button_pressed:tint=Color("cbdace")
	if disabled:tint.a=.48
	# Atlas sampling excludes empty generator canvas, keeping the PNG immutable.
	draw_texture_rect_region(PAPER,Rect2(Vector2(0,lift),size),Rect2(30,125,2120,470),tint)
	var font_size:=23
	while FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>size.x-64 and font_size>17:font_size-=1
	var width:=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline:=(size.y-FONT.get_height(font_size))*.5+FONT.get_ascent(font_size)+lift
	draw_string(FONT,Vector2((size.x-width)*.5,baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("355b51") if active else Color("665240"))
