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
	bubble.ignore_texture_size=true; bubble.stretch_mode=TextureButton.STRETCH_SCALE
	bubble.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	UI.place(bubble,self,Rect2(24,-65,88,58))
	caption=UI.label(bubble,"…",Rect2(5,8,78,36),18,Color("665240"))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode=TextServer.AUTOWRAP_OFF
	bubble.pressed.connect(_meow)
	for target:BaseButton in [hit,bubble]:
		target.mouse_entered.connect(func():_feedback(true))
		target.mouse_exited.connect(func():_feedback(false))
		target.focus_entered.connect(func():_feedback(true))
		target.focus_exited.connect(func():_feedback(false))
func _process(_delta:float)->void:
	bubble.visible=not allowed.is_valid() or allowed.call()
	if Time.get_ticks_msec()>=_until:caption.text="…"
func _feedback(active:bool)->void:
	if _motion and _motion.is_valid():_motion.kill()
	_motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(bubble,"position:y",-68.0 if active else -65.0,.13)
func _meow()->void:
	if allowed.is_valid() and not allowed.call():return
	if Time.get_ticks_msec()<_until:return
	_until=Time.get_ticks_msec()+1250
	caption.text="Meow!" if language.is_valid() and language.call()=="en" else "喵～"
	meowed.emit()
	if _motion and _motion.is_valid():_motion.kill()
	_motion=create_tween().set_trans(Tween.TRANS_SINE)
	_motion.tween_property(bubble,"position:y",-62.0,.07)
	_motion.tween_property(bubble,"position:y",-67.0,.14)
	_motion.tween_property(bubble,"position:y",-65.0,.16)
