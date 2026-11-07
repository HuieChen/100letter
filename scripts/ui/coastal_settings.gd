extends Control
signal closed
signal cue(kind:String)
signal water_audio(point:Vector2,strength:float,body_contact:bool)
const UI=preload("res://scripts/ui/paper_ui.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const WaterShader=preload("res://scripts/ui/settings_surface_refraction.gdshader")
const MatteShader=preload("res://scripts/ui/pdf_white_matte.gdshader")
const TapeMatteShader=preload("res://scripts/ui/pdf_tape_matte.gdshader")
const ColorMatteShader=preload("res://scripts/ui/pdf_color_matte.gdshader")
const CompanionShader=preload("res://scripts/ui/lemon_companion_water.gdshader")
const PhysicsSurface=preload("res://scripts/ui/settings_pool.gd")
const WaterState=preload("res://scripts/ui/settings_water_state.gd")
const Feedback=preload("res://scripts/ui/settings_feedback.gd")
const NumberFont=preload("res://assets/fonts/DearRounded.tres")
const MENU_RADIUS:=10
const COMPANION_HOME:Array[Vector2]=[Vector2(145,65),Vector2(1406,685)]
const COMPANION_RADII:Array[Vector2]=[Vector2(230,340),Vector2(190,260)]
var preferences:Node
var _font:FontVariation
var _water:TextureRect
var _material:ShaderMaterial
var _paper_mask:Image
var _drops:Array[Vector3]=[]
var _time:=0.0
var _last_drop:=-1.0
var _save_timer:Timer
var _error:Label
var _closing:=false
var controls:Dictionary={}
var _dropdown:Control
var _dropdown_owner:Button
var _dropdown_focus_modes:Dictionary={}
var _option_values:Dictionary={}
var _option_texts:Dictionary={}
var surface:Node2D
var _headline:Font
var _paper_masks:Array[Image]=[]
var _paper_materials:Array[ShaderMaterial]=[]
var field:RefCounted
var _flow_material:ShaderMaterial
var _last_body_poses:Array[Vector3]=[]
var _feedback:Node
var _wakes:Array[Vector4]=[]
var _touches:Array[Vector4]=[]
var _entrance:Tween
var _has_built:=false
var _tap_count:=0
var _stroke_count:=0
var _last_motion:=-1.0
var _last_skim_audio:=-1.0
var _last_pointer:=Vector2(-1,-1)
var _held_lemon:=-1
var _water_canvas:SubViewport
var _companion_material:ShaderMaterial
var _companion_pose:Array[Vector4]=[]
var _water_canvas_updates:=0
func configure(model:Node) -> void:
	preferences=model
	if not preferences.changed.is_connected(_model_changed):preferences.changed.connect(_model_changed)
	_build()
func _configure_fonts()->void:
	_font=load("res://assets/fonts/DearRounded.tres")
	_headline=_font
func _t(zh:String,en:String) -> String:return en if preferences.values.language=="en" else zh
func _image(key:String,rect:Rect2) -> TextureRect:
	var image:=TextureRect.new();image.texture=Art.texture(key);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(image,self,rect);return image
func _build() -> void:
	if _closing:return
	_close_options()
	_release_held_lemon()
	if is_instance_valid(_entrance):_entrance.kill()
	if not _closing:_set_page_opacity(1.0)
	if is_instance_valid(_feedback):_feedback.reset()
	_configure_fonts()
	var focused:=get_viewport().gui_get_focus_owner()
	var restore_focus:String=focused.name if is_instance_valid(focused) and is_ancestor_of(focused) else "CloseSettings"
	var previous:Dictionary=surface.snapshot() if is_instance_valid(surface) else {}
	for child in get_children():remove_child(child);child.queue_free()
	_dropdown=null
	_dropdown_owner=null
	_feedback=Feedback.new();add_child(_feedback)
	controls.clear();_option_values.clear();_option_texts.clear();mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	# Compose original PDF layers at their actual native resolution, not a resized AI redraw.
	_water_canvas=SubViewport.new();_water_canvas.size=Vector2i(1920,1080);_water_canvas.transparent_bg=false
	_water_canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(_water_canvas)
	_companion_material=null;_companion_pose.clear()
	for spec:Array in [["settings_water_base",1.0,false],["settings_water_pattern",0.14,true],["settings_water",0.24,false]]:
		var image:=TextureRect.new();image.texture=Art.texture(spec[0]);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.size=Vector2(1920,1080);image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if spec[2]:
			_companion_material=ShaderMaterial.new();_companion_material.shader=CompanionShader
			_companion_material.set_shader_parameter("opacity",spec[1]);_companion_material.set_shader_parameter("world_size",Vector2(1600,900))
			_companion_material.set_shader_parameter("home_large",COMPANION_HOME[0]);_companion_material.set_shader_parameter("home_small",COMPANION_HOME[1])
			_companion_material.set_shader_parameter("radii_large",COMPANION_RADII[0]);_companion_material.set_shader_parameter("radii_small",COMPANION_RADII[1])
			image.material=_companion_material;image.name="AuthoredLemonCompanionWater"
		else:image.modulate.a=spec[1]
		if spec[0]=="settings_water_base":image.self_modulate=Color(0.88,0.99,1.0,1.0)
		_water_canvas.add_child(image)
	_water=TextureRect.new();_water.texture=_water_canvas.get_texture();_water.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_water.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(_water,self,Rect2(0,0,1600,900));_water.name="SettingsWater"
	_material=ShaderMaterial.new();_material.shader=WaterShader;_water.material=_material
	if field==null:field=WaterState.new()
	_material.set_shader_parameter("height_field",field.texture)
	_last_body_poses.clear()
	_water.mouse_filter=Control.MOUSE_FILTER_STOP;_water.gui_input.connect(_water_input)
	var physics_view:=SubViewport.new();physics_view.size=Vector2i(1920,1080);physics_view.transparent_bg=true;physics_view.world_2d=World2D.new();add_child(physics_view)
	physics_view.canvas_transform=Transform2D(Vector2(1.2,0),Vector2(0,1.2),Vector2.ZERO)
	surface=PhysicsSurface.new();physics_view.add_child(surface)
	if not previous.is_empty():surface.restore_state(previous)
	_refresh_companion_pose(true)
	surface.contact_audio.connect(func(point:Vector2,strength:float):water_audio.emit(point,strength,true))
	surface.lemon_press_changed.connect(_lemon_press_water)
	var lemon_layer:=TextureRect.new();lemon_layer.texture=physics_view.get_texture();lemon_layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lemon_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(lemon_layer,self,Rect2(0,0,1600,900))
	lemon_layer.name="FloatingLemons"
	# Transparent SubViewport pixels already contain premultiplied alpha. Applying
	# alpha twice darkens the antialiased rind into an unintended black outline.
	var lemon_blend:=CanvasItemMaterial.new();lemon_blend.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	lemon_layer.material=lemon_blend
	_paper_masks.clear()
	_paper_materials.clear()
	for key:String in ["settings_paper_shadow","settings_papers","settings_tape","settings_stationery","settings_postcards"]:
		var paper:=_image(key,Rect2(0,0,1600,900));var matte:=ShaderMaterial.new();matte.shader=MatteShader
		if key in ["settings_tape","settings_papers"]:
			matte.shader=TapeMatteShader
			matte.set_shader_parameter("paper_plate",key=="settings_papers")
			if key=="settings_papers":matte.set_shader_parameter("pigment_uv",Vector2(795.5/1920.0,45.5/1080.0))
		elif key=="settings_stationery":matte.shader=ColorMatteShader
		paper.material=matte;paper.name="PDF_"+key
		_paper_materials.append(matte)
		_paper_masks.append(paper.texture.get_image())
	var heading:=_label(_t("设置","Settings"),Rect2(510,18,534,109),72 if preferences.values.language=="zh" else 94,Color("0059ae"))
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font",_headline);heading.name="SettingsHeading"
	heading.add_theme_color_override("font_outline_color",Color.WHITE);heading.add_theme_constant_override("outline_size",7)
	var cross:=Button.new();cross.name="CloseSettings";cross.text="×";cross.flat=true
	cross.tooltip_text=_t("关闭设置","Close settings")
	cross.add_theme_font_size_override("font_size",48);cross.add_theme_color_override("font_color",Color("0059ae"))
	cross.add_theme_color_override("font_outline_color",Color("fff9ee"));cross.add_theme_constant_override("outline_size",2)
	cross.set_meta("light_surface",true)
	for state:String in ["normal","hover","pressed","focus"]:cross.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	cross.add_theme_color_override("font_focus_color",Color("fff4ba"));cross.add_theme_color_override("font_hover_color",Color("fff4ba"))
	# A consistent screen-corner close target, outside paper/artwork controls.
	UI.place(cross,self,Rect2(1504,28,64,64));cross.pressed.connect(request_close)
	_feedback.bind_button(cross)
	_option("language",_t("界面语言","Language"),Rect2(636,165,217,40),Rect2(864,169,159,40),["zh","en"],[_t("中文 · 界面","中文 · UI"),"English · UI"])
	_option("display_mode",_t("显示模式","Display Mode"),Rect2(526,252,297,40),Rect2(864,252,159,40),["windowed","fullscreen","borderless"],[_t("窗口","Windowed"),_t("全屏","Full Screen"),_t("无边框","Borderless")])
	_option("resolution",_t("画面分辨率","Resolution"),Rect2(526,310,295,40),Rect2(864,310,159,40),["auto","1280x720","1600x900","1920x1080"],["AUTO","1280 × 720","1600 × 900","1920 × 1080"])
	_separator(389)
	_slider("master",_t("整体音量","Master Volume"),428,0.0,1.0)
	_slider("music",_t("音乐音量","Music Volume"),478,0.0,1.0)
	_slider("sfx",_t("音效音量","SFX Volume"),528,0.0,1.0)
	_slider("ambience",_t("环境音量","Ambience Volume"),578,0.0,1.0)
	_separator(615)
	_slider("sensitivity",_t("鼠标灵敏度","Mouse Sensitivity"),658,0.5,2.0)
	controls.sensitivity.tooltip_text=_t("纸面缩放与平移；物件仍紧随指针。","Paper zoom and pan; held objects remain attached to the pointer.")
	_option("text_speed",_t("文字显示速度","Text Speed"),Rect2(526,718,274,40),Rect2(804,715,161,42),["slow","normal","fast","instant"],[_t("慢","Slow"),_t("中","Normal"),_t("快","Fast"),_t("即时","Instant")])
	# A short system status uses the existing clear gap above the first divider,
	# avoiding both headline typography and interactive tracks/postcard art.
	# It survives rebuilds via the model, and is absent after a successful save.
	_error=UI.label(self,_preference_error_text(),Rect2(864,357,128,25),16,Color("fff4ba"));_error.name="SettingsSaveError"
	_error.autowrap_mode=TextServer.AUTOWRAP_OFF;_error.clip_text=true;_error.size=Vector2(128,25)
	_save_timer=Timer.new();_save_timer.one_shot=true;_save_timer.wait_time=0.3;add_child(_save_timer);_save_timer.timeout.connect(_save)
	_update_water()
	_focus_page()
	var restored:=find_child(restore_focus,true,false) as Control
	if is_instance_valid(restored):restored.grab_focus()
	else:cross.grab_focus()
	if not _has_built:_play_entrance()
	_has_built=true

func _focus_loop(items:Array) -> void:
	for i:int in items.size():
		items[i].focus_next=items[i].get_path_to(items[(i+1)%items.size()])
		items[i].focus_previous=items[i].get_path_to(items[(i-1+items.size())%items.size()])

func _focus_page() -> void:
	var items:Array=[get_node("CloseSettings")]
	items.append_array(controls.values());_focus_loop(items)
func _label(text:String,rect:Rect2,font_size:int=29,color:Color=Color.WHITE) -> Label:
	var label:=Label.new();label.text=text
	label.add_theme_font_override("font",_font);label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	# Fit measured glyphs in the reference's fixed columns, never cover the adjacent track.
	while font_size>19 and _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x:
		font_size-=1;label.add_theme_font_size_override("font_size",font_size)
	label.clip_text=true;UI.place(label,self,rect);return label
func _option(key:String,label:String,label_rect:Rect2,rect:Rect2,values:Array,texts:Array) -> void:
	_option_values[key]=values.duplicate();_option_texts[key]=texts.duplicate()
	if preferences.values.language=="zh":label_rect.position.x=580;label_rect.size.x=221
	var caption:=_label(label,label_rect,32 if preferences.values.language=="zh" else 29);caption.name="SettingLabel_"+key
	if preferences.values.language=="zh":caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var choice:=Button.new();choice.name="Setting_"+key
	choice.text=str(texts[values.find(preferences.values[key])]);choice.alignment=HORIZONTAL_ALIGNMENT_LEFT
	choice.add_theme_font_override("font",_font);choice.add_theme_font_size_override("font_size",21 if preferences.values.language=="zh" else 19)
	choice.add_theme_color_override("font_color",Color("c7e8ff"))
	choice.add_theme_color_override("font_hover_color",Color.WHITE)
	choice.add_theme_color_override("font_focus_color",Color("fff4ba"))
	choice.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var style:=UI.style(Color("0059ae"),Color.TRANSPARENT,MENU_RADIUS);style.content_margin_left=7;style.content_margin_right=24;style.content_margin_top=2;style.content_margin_bottom=2
	for state in ["normal","hover","pressed"]:
		var state_style:=style.duplicate() as StyleBoxFlat
		if state!="normal":state_style.bg_color=Color("0874c2")
		choice.add_theme_stylebox_override(state,state_style)
	var focus_style:=style.duplicate() as StyleBoxFlat
	focus_style.bg_color=Color.TRANSPARENT;focus_style.border_color=Color("fff4ba")
	choice.add_theme_stylebox_override("focus",focus_style)
	UI.place(choice,self,rect);controls[key]=choice
	var arrow:=Label.new();arrow.text="▼";arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_color_override("font_color",Color.WHITE);arrow.add_theme_font_size_override("font_size",14)
	UI.place(arrow,choice,Rect2(rect.size.x-25,1,22,rect.size.y-2))
	_feedback.bind_button(choice,arrow)
	choice.pressed.connect(func():
		if _closing:return
		_open_options(key,choice,values,texts))

func _open_options(key:String,choice:Button,values:Array,texts:Array) -> void:
	_close_options()
	# A nested selector owns keyboard navigation as well as pointer input.
	# Spatial arrow navigation must not reach settings behind its scrim.
	for id:String in controls:
		_dropdown_focus_modes[id]=controls[id].focus_mode
		controls[id].focus_mode=Control.FOCUS_NONE
	_dropdown_owner=choice
	_feedback.set_expanded(choice,true)
	_dropdown=Control.new();_dropdown.name="SettingsDropdown";UI.place(_dropdown,self,Rect2(0,0,1600,900))
	var blocker:=ColorRect.new();blocker.color=Color.TRANSPARENT;UI.place(blocker,_dropdown,Rect2(0,0,1600,900))
	blocker.gui_input.connect(func(event:InputEvent):
		if event is InputEventMouseButton and event.pressed:_close_options();get_viewport().set_input_as_handled())
	var height:=values.size()*46.0+12.0
	var top:=choice.position.y+choice.size.y+4.0
	if top+height>785.0:top=choice.position.y-height-4.0
	var box:=UI.panel(_dropdown,Rect2(choice.position.x,top,maxf(choice.size.x,196.0),height),Color("0059ae"))
	box.name="SettingsOptionsPanel"
	box.add_theme_stylebox_override("panel",UI.style(Color("0059ae"),Color.TRANSPARENT,MENU_RADIUS))
	box.mouse_filter=Control.MOUSE_FILTER_STOP
	var rows:Array=[]
	for index:int in values.size():
		var row:=Button.new();row.name="Option_"+key+"_"+str(index);row.text=str(texts[index])
		row.add_theme_font_override("font",_font);row.add_theme_font_size_override("font_size",19)
		row.add_theme_color_override("font_color",Color.WHITE);row.add_theme_color_override("font_hover_color",Color("fff4b7"))
		row.flat=false
		# All dropdown states share the same rounded silhouette; no square default focus frame.
		for state:String in ["normal","hover","pressed","focus"]:
			var fill:=Color("0874c2") if state in ["hover","pressed"] else Color("0059ae")
			var border:=Color("c7e8ff") if state=="focus" else Color.TRANSPARENT
			if state=="focus":fill=Color.TRANSPARENT
			var style:=UI.style(fill,border,MENU_RADIUS);style.content_margin_left=5;style.content_margin_right=5;style.content_margin_top=5;style.content_margin_bottom=5
			row.add_theme_stylebox_override(state,style)
		UI.place(row,box,Rect2(6,6+index*46,box.size.x-12,44))
		_feedback.bind_button(row)
		rows.append(row)
		row.pressed.connect(func():
			_close_options()
			preferences.set_value(key,values[index]);choice.text=str(texts[index]);cue.emit("paper");_save()
			if key=="language":_build.call_deferred())
		if values[index]==preferences.values[key]:row.grab_focus()
	# The visible cross remains usable in one click even while a dropdown is open.
	move_child(get_node("CloseSettings"),get_child_count()-1)
	# Arrow keys stay in the open menu instead of Godot's spatial search finding
	# an unrelated setting behind it. Tab also retains access to the close button.
	for index:int in rows.size():
		rows[index].focus_neighbor_top=rows[index].get_path_to(rows[(index-1+rows.size())%rows.size()])
		rows[index].focus_neighbor_bottom=rows[index].get_path_to(rows[(index+1)%rows.size()])
	rows.append(get_node("CloseSettings"));_focus_loop(rows)
	_feedback.menu_open(box,top<choice.position.y)

func _close_options() -> void:
	for id:String in _dropdown_focus_modes:
		if controls.has(id) and is_instance_valid(controls[id]):controls[id].focus_mode=_dropdown_focus_modes[id]
	_dropdown_focus_modes.clear()
	var restore_focus:=_dropdown_owner
	if is_instance_valid(restore_focus):_feedback.set_expanded(restore_focus,false)
	_dropdown_owner=null
	if is_instance_valid(_dropdown):remove_child(_dropdown);_dropdown.queue_free()
	_dropdown=null
	if is_instance_valid(get_node_or_null("CloseSettings")) and not controls.is_empty():_focus_page()
	if is_instance_valid(restore_focus) and restore_focus.is_visible_in_tree() and not restore_focus.is_queued_for_deletion():restore_focus.grab_focus()
func _separator(y:float) -> void:
	var line:=ColorRect.new();line.color=Color(0.7,0.91,1.0,0.18);line.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(line,self,Rect2(560,y,470,3))
func _slider(key:String,text:String,y:float,minimum:float,maximum:float) -> void:
	var chinese:bool=preferences.values.language=="zh"
	if chinese and key=="sensitivity":text="操作灵敏度"
	var caption:=_label(text,Rect2(580,y-6,221,40) if chinese else Rect2(526,y-10,271,46),32 if chinese else 29);caption.name="SettingLabel_"+key
	if chinese:caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var slider:=HSlider.new();slider.name="Setting_"+key
	slider.focus_mode=Control.FOCUS_ALL
	slider.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	slider.min_value=minimum;slider.max_value=maximum;slider.step=0.01;slider.value=preferences.values[key]
	# Native HSlider places a 24px thumb inside its bounds. End the rail at
	# the thumb centres so its transparent outer pixels reveal no square stub.
	var track:=StyleBoxLine.new();track.color=Color("0061ad");track.thickness=5;track.grow_begin=-12;track.grow_end=-12
	var fill:=track.duplicate() as StyleBoxLine;fill.color=Color.WHITE;fill.grow_end=0
	slider.add_theme_stylebox_override("slider",track);slider.add_theme_stylebox_override("grabber_area",fill);slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	# One opaque native thumb: white at rest, cream on hover or keyboard focus.
	var knob:=GradientTexture2D.new();knob.width=24;knob.height=24;knob.fill=GradientTexture2D.FILL_RADIAL;knob.fill_from=Vector2(0.5,0.5);knob.fill_to=Vector2(1,0.5)
	var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0.0,0.86,0.96,1.0]);gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color(1,1,1,0)]);knob.gradient=gradient
	for state:String in ["grabber","grabber_highlight","grabber_disabled"]:slider.add_theme_icon_override(state,knob)
	var active_knob:=knob.duplicate() as GradientTexture2D
	var active_gradient:=gradient.duplicate() as Gradient
	active_gradient.colors=PackedColorArray([Color("fff4ba"),Color("fff4ba"),Color("fff4ba"),Color(1,0.957,0.729,0)])
	active_knob.gradient=active_gradient
	slider.add_theme_icon_override("grabber_highlight",active_knob)
	# The sensitivity row meets the diagonal postcard; keep its actual hit area
	# and visible endpoint wholly on the blue paper rather than underneath it.
	# Reserve a stable value column: the player can compare channels and restore
	# a precise level without interpreting the thumb position alone.
	var rail_width:=126.0 if key=="sensitivity" else 160.0
	UI.place(slider,self,Rect2(805,y-9,rail_width,44));controls[key]=slider
	var value_label:=_label(_slider_value_text(key,slider.value),Rect2(805+rail_width+7,y-7,65 if key=="sensitivity" else 55,40),19,Color("e2f3ff"))
	value_label.add_theme_font_override("font",NumberFont)
	value_label.name="SettingValue_"+key;value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_feedback.bind_slider(slider,value_label)
	slider.value_changed.connect(func(value:float):preferences.set_value(key,value);value_label.text=_slider_value_text(key,value);_save_timer.start())
	slider.drag_ended.connect(func(_changed:bool):_save();cue.emit("snap"))

func _slider_value_text(key:String,value:float) -> String:
	return "%.2f×"%value if key=="sensitivity" else "%d%%"%roundi(value*100.0)

func _model_changed(key:String,value:Variant) -> void:
	# F11 and external preference updates share the same source of truth as mouse input.
	if not controls.has(key):return
	if controls[key] is Slider:
		controls[key].set_value_no_signal(float(value))
		var value_label:=get_node_or_null("SettingValue_"+key) as Label
		if is_instance_valid(value_label):value_label.text=_slider_value_text(key,float(value))
	elif _option_values.has(key):
		var index:int=_option_values[key].find(value)
		if index>=0:controls[key].text=str(_option_texts[key][index])
func _save() -> bool:
	var ok:bool=preferences.save_settings()
	if is_instance_valid(_error):_error.text=_preference_error_text()
	return ok
func _preference_error_text()->String:
	return _t("设置未保存","Not saved") if preferences.dirty and not preferences.last_error.is_empty() else ""
func request_close() -> void:
	_release_held_lemon()
	if _closing:return
	# Preferences are independent from campaign custody/save guards. A failed
	# write keeps the original disk bytes and dirty in-memory values, but never
	# traps a player in Settings. Reentry shows the retained failure status.
	_save()
	_closing=true;get_viewport().set_input_as_handled();cue.emit("paper")
	_close_options()
	if is_instance_valid(_entrance):_entrance.kill()
	for control:Control in controls.values():
		control.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.focus_mode=Control.FOCUS_NONE
	var outro:=create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_method(_set_page_opacity,modulate.a,0.0,0.14)
	outro.tween_callback(func():closed.emit())
func _input(event:InputEvent) -> void:
	if _closing:
		if event is InputEventKey or event is InputEventMouseButton:get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _held_lemon>=0:
		_release_held_lemon();get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		_release_held_lemon()
		if is_instance_valid(_dropdown):_close_options();get_viewport().set_input_as_handled()
		else:request_close()
func _water_input(event:InputEvent) -> void:
	if _closing:return
	if event is InputEventMouseMotion:
		var point:Vector2=event.position
		_water.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if surface.hit_lemon(point)>=0 else Control.CURSOR_ARROW
		# Touching UI never disturbs water beneath the paper. Ignore jumps across it.
		var previous:Vector2=_last_pointer
		var elapsed:float=clampf(_time-_last_motion,1.0/120.0,0.1)
		_last_motion=_time;_last_pointer=point
		if previous.x<0 or point.distance_to(previous)>180.0 or _on_paper(point) or _on_paper(previous):return
		if surface.hit_lemon(point)>=0 or surface.hit_lemon(previous)>=0:return
		var speed:float=event.velocity.length() if event.velocity.length()>1.0 else point.distance_to(previous)/elapsed
		if speed<18.0:return
		var dragging:bool=(event.button_mask&MOUSE_BUTTON_MASK_LEFT)!=0
		# Hover no longer paints a trail across the screen: only an actual drag stirs water.
		if not dragging:return
		_last_drop=_time;_stroke_count+=1
		field.stroke(previous,point,speed,true)
		_wakes.append(Vector4(point.x,point.y,_time,(point-previous).angle()))
		if _wakes.size()>12:_wakes.pop_front()
		surface.water_swipe(previous,point,speed,dragging)
		if speed>90.0 and _time-_last_skim_audio>0.22:
			_last_skim_audio=_time;water_audio.emit(point,clampf(speed/2400.0,0.1,0.38),true)
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
	var point:Vector2=event.position
	if _on_paper(point):return
	var lemon:int=surface.hit_lemon(point)
	if lemon>=0:
		_release_held_lemon();_held_lemon=lemon;surface.press_lemon(lemon,point);_last_drop=_time;return
	if _time-_last_drop<0.075:return
	_last_drop=_time;_drops.append(Vector3(point.x,point.y,_time))
	if _drops.size()>8:_drops.pop_front()
	_add_touch(point,1.0)
	var contact_strength:=0.55
	surface.water_touch(point,contact_strength);water_audio.emit(point,contact_strength,false)
func _release_held_lemon()->void:
	_held_lemon=-1
	if is_instance_valid(surface):surface.release_all_presses()
func _lemon_press_water(_index:int,_held:bool,_point:Vector2,_depth:float)->void:
	# The actual depth change displaces water on the next physical step.
	# A held slice does not inject a fresh pulse on every frame.
	pass
func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT or what==NOTIFICATION_WM_MOUSE_EXIT:_release_held_lemon()
func _exit_tree()->void:_release_held_lemon()
func _on_paper(point:Vector2)->bool:
	# Hit the actual original layer silhouettes, including the tilted postcards and tape.
	for mask:Image in _paper_masks:
		var texel:=Vector2i(point/Vector2(1600,900)*Vector2(mask.get_size())).clamp(Vector2i.ZERO,mask.get_size()-Vector2i.ONE)
		var color:=mask.get_pixelv(texel)
		if minf(color.r,minf(color.g,color.b))<0.975:return true
	return false
func _set_page_opacity(value:float)->void:
	modulate.a=value
	# Authored matte shaders supply their own COLOR, so inherit alpha explicitly.
	for material:ShaderMaterial in _paper_materials:material.set_shader_parameter("opacity",value)

func _play_entrance()->void:
	# Opacity on the full sheet; a short slide only on non-interactive original paper.
	_set_page_opacity(0.0)
	_entrance=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance.tween_method(_set_page_opacity,0.0,1.0,0.22)
	for child:Node in get_children():
		if child is TextureRect and str(child.name).begins_with("PDF_"):
			child.position.y=7.0
			_entrance.tween_property(child,"position:y",0.0,0.30)

func _add_touch(point:Vector2,strength:float)->void:
	_tap_count+=1
	if field!=null:field.tap(point,strength)
	_touches.append(Vector4(point.x,point.y,_time,strength))
	if _touches.size()>8:_touches.pop_front()

func _process(delta:float) -> void:
	_time+=minf(delta,0.1)
	while not _drops.is_empty() and _time-_drops[0].z>2.4:_drops.pop_front()
	while not _touches.is_empty() and _time-_touches[0].z>2.4:_touches.pop_front()
	while not _wakes.is_empty() and _time-_wakes[0].z>0.8:_wakes.pop_front()
	_refresh_companion_pose()
	_update_water()

func _physics_process(delta:float)->void:
	if field==null or not is_instance_valid(surface) or surface.bodies.size()!=2:return
	field.set_obstacles(surface.bodies)
	var forces:Array[Vector2]=[]
	var currents:Array[Vector2]=[]
	var next_poses:Array[Vector3]=[]
	for i:int in 2:
		var body:RigidBody2D=surface.bodies[i]
		var depth:float=body.get("press_depth")
		var slope:=Vector2.ZERO
		for sample_index:int in 8:
			var direction:=Vector2.from_angle(float(sample_index)*TAU/8.0)
			slope+=field.sample_slope(body.position+direction*(body.radius+22.0))
		forces.append((-slope/8.0*240.0).limit_length(5.0))
		currents.append(field.current_at(body.position))
		if _last_body_poses.size()==2:
			var before:Vector3=_last_body_poses[i]
			field.disturb_body(body.position,body.radius,body.position-Vector2(before.x,before.y),depth-before.z)
		next_poses.append(Vector3(body.position.x,body.position.y,depth))
	_last_body_poses=next_poses
	surface.set_water_forces(forces);surface.set_water_currents(currents)
	field.advance(delta)

func _update_water() -> void:
	if _material==null:return
	_material.set_shader_parameter("flow_time",_time)

func _refresh_companion_pose(force:bool=false)->void:
	if not is_instance_valid(surface) or _companion_material==null or not is_instance_valid(_water_canvas):return
	if surface.bodies.size()<2:return
	var next:Array[Vector4]=[]
	var changed:=force or _companion_pose.size()!=2
	for index:int in 2:
		var body:RigidBody2D=surface.bodies[index]
		var depth:float=body.get("press_depth")
		var center:Vector2=body.position+Vector2(0,depth)
		var factor:=1.0
		var pose:=Vector4(center.x,center.y,body.rotation,factor)
		next.append(pose)
		if _companion_pose.size()==2:
			var before:Vector4=_companion_pose[index]
			if Vector2(pose.x-before.x,pose.y-before.y).length_squared()>0.000025 or absf(pose.z-before.z)>0.00001 or absf(pose.w-before.w)>0.00001:changed=true
	if not changed:return
	_companion_pose=next
	_companion_material.set_shader_parameter("pose_large",next[0]);_companion_material.set_shader_parameter("pose_small",next[1])
	_water_canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_water_canvas_updates+=1
func companion_snapshot()->Dictionary:
	return {"source":"settings_water_pattern PDF page2 unchanged pixels","shader":_companion_material.shader.resource_path if _companion_material!=null else "","poses":_companion_pose.duplicate(),"homes":COMPANION_HOME.duplicate(),"radii":COMPANION_RADII.duplicate(),"canvas_updates":_water_canvas_updates,"opacity":_companion_material.get_shader_parameter("opacity") if _companion_material!=null else 0.0}
func ripple_snapshot() -> Dictionary:
	return {"active":_drops.size(),"time":_time,"drops":_drops.duplicate(),"shader_water_only":_water.material==_material,
		"engine":"original_art_flow_v5","field":field.snapshot(),"touches":_touches.size(),"wakes":_wakes.size(),"taps":_tap_count,"strokes":_stroke_count}
