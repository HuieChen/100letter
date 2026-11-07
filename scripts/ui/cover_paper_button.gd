extends Button
## The supplied lettering is an atlas, not redrawn text. Animate only this
## visual so the hit rectangle stays still during hover, focus and press.
signal paper_hovered
var art:TextureRect
var _motion:Tween
var _hovered:=false
var _held:=false
var _armed:=false

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
	mouse_entered.connect(func():_hovered=true;_refresh(true))
	mouse_exited.connect(func():_hovered=false;_refresh())
	focus_entered.connect(func():_refresh(true))
	focus_exited.connect(func():_held=false;_refresh())
	button_down.connect(func():_held=true;_refresh())
	button_up.connect(func():_held=false;_refresh())
	_arm.call_deferred()

func _arm()->void:
	await get_tree().create_timer(.35).timeout
	_armed=true

func _refresh(with_sound:bool=false)->void:
	if disabled:return
	var selected:=_hovered or has_focus()
	if with_sound and _armed:paper_hovered.emit()
	if is_instance_valid(_motion):_motion.kill()
	_motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var factor:=.975 if _held else (1.018 if selected else 1.0)
	var offset:=Vector2(0,2) if _held else (Vector2(5,-4) if selected else Vector2.ZERO)
	_motion.tween_property(art,"scale",Vector2.ONE*factor,.07 if _held else .16)
	_motion.tween_property(art,"position",offset,.07 if _held else .16)
