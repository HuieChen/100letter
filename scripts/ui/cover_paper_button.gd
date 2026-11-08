extends Button
## The supplied lettering is an atlas, not redrawn text. Animate only this
## visual so the hit rectangle stays still during hover, focus and press.
signal paper_hovered
var art:TextureRect
var _motion:Tween
var _hovered:=false
var _held:=false
var _armed:=false
var _pointer_focus:=false

func configure(texture:Texture2D,region:Rect2,label:String)->void:
	text=label # Retain the semantic Button label; visible ink comes from the art.
	for state:String in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state:String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_hover_pressed_color","font_outline_color","font_shadow_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	add_theme_constant_override("outline_size",0)
	mouse_default_cursor_shape=Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	focus_mode=Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=region;atlas.filter_clip=true
	art=TextureRect.new();art.name="AuthoredPaper";art.texture=atlas
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_SCALE
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(art);art.size=size;art.pivot_offset=size*.5
	art.modulate.a=.45 if disabled else 1.0
	mouse_entered.connect(_pointer_entered)
	mouse_exited.connect(_pointer_exited)
	focus_entered.connect(func():_refresh(true))
	focus_exited.connect(func():_held=false;_refresh())
	button_down.connect(func():_held=true;_refresh())
	button_up.connect(func():_held=false;_refresh())
	_arm.call_deferred()

func _pointer_entered()->void:
	if disabled:return
	_hovered=true
	_pointer_focus=true
	# One selected paper, shared by pointer and keyboard navigation.
	if not has_focus():grab_focus()
	else:_refresh(true)

func _pointer_exited()->void:
	_hovered=false
	if _pointer_focus and has_focus():release_focus()
	_pointer_focus=false
	_refresh()

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed:
		_pointer_focus=false

func _arm()->void:
	# A scene may leave before this deferred hover-sound warm-up runs.
	if not is_inside_tree() or is_queued_for_deletion():return
	await get_tree().create_timer(.35).timeout
	if not is_inside_tree() or is_queued_for_deletion():return
	_armed=true

func _refresh(with_sound:bool=false)->void:
	if disabled:return
	var selected:=has_focus()
	if with_sound and _armed:paper_hovered.emit()
	if is_instance_valid(_motion):_motion.kill()
	_motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Keep the lettering crisp and the paper's width fixed: a light lift,
	# contact on press, then a short settle. No zoom, diagonal drift or wobble.
	var offset:=Vector2(0,2) if _held else (Vector2(0,-3) if selected else Vector2.ZERO)
	var tint:=Color(.94,.96,.97,1) if _held else Color.WHITE
	_motion.tween_property(art,"position",offset,.06 if _held else .12)
	_motion.tween_property(art,"modulate",tint,.06 if _held else .12)
