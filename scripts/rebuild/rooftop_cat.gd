extends Control
signal meowed
const Art=preload("res://scripts/rebuild/authored_dialogue_art.gd")
const UI=preload("res://scripts/ui/paper_ui.gd")
var allowed:Callable
var language:Callable
var bubble:TextureButton
var caption:Label
var _until:=0
var _motion:Tween
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hit:=Button.new();hit.name="CatBody";hit.flat=true
	hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state:String in ["normal","hover","pressed","focus"]:hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	UI.place(hit,self,Rect2(Vector2.ZERO,size));hit.pressed.connect(_meow)
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble=TextureButton.new();bubble.name="CatBubble"
	bubble.texture_normal=Art.texture("cat_bubble.png")
	var rim:=ShaderMaterial.new();rim.shader=preload("res://scripts/rebuild/cat_bubble_rim.gdshader")
	rim.set_shader_parameter("rim_color",Color("493450"));bubble.material=rim
	bubble.ignore_texture_size=true; bubble.stretch_mode=TextureButton.STRETCH_SCALE
	bubble.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	UI.place(bubble,self,Rect2(32,-55,72,48))
	caption=UI.label(bubble,"...",Rect2(4,3,64,36),27,Color("4a3a32"))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	caption.clip_text=true;caption.size=Vector2(64,36)
	bubble.pressed.connect(_meow)
	for target:BaseButton in [hit,bubble]:
		target.mouse_entered.connect(func():_feedback(true))
		target.mouse_exited.connect(func():_feedback(false))
		target.focus_entered.connect(func():_feedback(true))
		target.focus_exited.connect(func():_feedback(false))
func _process(_delta:float)->void:
	bubble.visible=not allowed.is_valid() or allowed.call()
	if Time.get_ticks_msec()>=_until:
		caption.text="...";caption.add_theme_font_size_override("font_size",27)
func _feedback(active:bool)->void:
	if _motion and _motion.is_valid():_motion.kill()
	_motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(bubble,"position:y",-58.0 if active else -55.0,.13)
func _meow()->void:
	if allowed.is_valid() and not allowed.call():return
	if Time.get_ticks_msec()<_until:return
	_until=Time.get_ticks_msec()+1250
	caption.text="Meow!" if language.is_valid() and language.call()=="en" else "喵～"
	caption.add_theme_font_size_override("font_size",17)
	meowed.emit()
	if _motion and _motion.is_valid():_motion.kill()
	_motion=create_tween().set_trans(Tween.TRANS_SINE)
	_motion.tween_property(bubble,"position:y",-52.0,.07)
	_motion.tween_property(bubble,"position:y",-57.0,.14)
	_motion.tween_property(bubble,"position:y",-55.0,.16)
