extends Control
signal closed
signal cue(kind:String)
signal water_audio(point:Vector2,strength:float,body_contact:bool)
const UI=preload("res://scripts/ui/paper_ui.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const WaterShader=preload("res://scripts/ui/settings_water.gdshader")
const MatteShader=preload("res://scripts/ui/pdf_white_matte.gdshader")
const PhysicsSurface=preload("res://scripts/ui/coastal_physics.gd")
const WaterField=preload("res://scripts/ui/water_field.gd")
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
var _option_values:Dictionary={}
var _option_texts:Dictionary={}
var surface:Node2D
var _headline:Font
var _paper_masks:Array[Image]=[]
var field:RefCounted
var _last_motion:=-1.0
var _last_skim_audio:=-1.0
var _last_pointer:=Vector2(-1,-1)
func configure(model:Node) -> void:
	preferences=model
	if not preferences.changed.is_connected(_model_changed):preferences.changed.connect(_model_changed)
	_build()
func _configure_fonts()->void:
	_font=FontVariation.new()
	_font.base_font=load("res://assets/fonts/NotoSansSC.ttf") if preferences.values.language=="zh" else load("res://assets/fonts/DynaPuff.ttf")
	# FontVariation uses integer OpenType axis tags; string keys silently leave the font thin.
	_font.variation_opentype={0x77676874:600.0} if preferences.values.language=="zh" else {0x77676874:700.0,0x77647468:100.0}
	_font.fallbacks=[load("res://assets/fonts/ZCOOLKuaiLe.ttf"),load("res://assets/fonts/SolmereSans.ttf")]
	if preferences.values.language=="zh":
		var title:=FontVariation.new();title.base_font=load("res://assets/fonts/NotoSansSC.ttf");title.variation_opentype={0x77676874:700.0};_headline=title
	else:_headline=load("res://assets/fonts/LilitaOne.ttf").duplicate()
	_headline.fallbacks=_font.fallbacks
func _t(zh:String,en:String) -> String:return en if preferences.values.language=="en" else zh
func _image(key:String,rect:Rect2) -> TextureRect:
	var image:=TextureRect.new();image.texture=Art.texture(key);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(image,self,rect);return image
func _build() -> void:
	_configure_fonts()
	var previous:Dictionary=surface.snapshot() if is_instance_valid(surface) else {}
	for child in get_children():remove_child(child);child.queue_free()
	_dropdown=null
	controls.clear();_option_values.clear();_option_texts.clear();mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	# Compose original PDF layers at their actual native resolution, not a resized AI redraw.
	var water_canvas:=SubViewport.new();water_canvas.size=Vector2i(1920,1080);water_canvas.transparent_bg=false
	water_canvas.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(water_canvas)
	for spec:Array in [["settings_water_base",1.0,false],["settings_water_pattern",0.52,true],["settings_water",0.44,false]]:
		var image:=TextureRect.new();image.texture=Art.texture(spec[0]);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.size=Vector2(1920,1080);image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if spec[2]:var matte:=ShaderMaterial.new();matte.shader=MatteShader;matte.set_shader_parameter("opacity",spec[1]);image.material=matte
		else:image.modulate.a=spec[1]
		water_canvas.add_child(image)
	_water=TextureRect.new();_water.texture=water_canvas.get_texture();_water.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_water.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(_water,self,Rect2(0,0,1600,900));_water.name="SettingsWater"
	_material=ShaderMaterial.new();_material.shader=WaterShader;_water.material=_material
	if field==null:field=WaterField.new()
	_material.set_shader_parameter("height_field",field.texture)
	_water.mouse_filter=Control.MOUSE_FILTER_STOP;_water.gui_input.connect(_water_input)
	var physics_view:=SubViewport.new();physics_view.size=Vector2i(1920,1080);physics_view.transparent_bg=true;physics_view.world_2d=World2D.new();add_child(physics_view)
	physics_view.canvas_transform=Transform2D(Vector2(1.2,0),Vector2(0,1.2),Vector2.ZERO)
	surface=PhysicsSurface.new();physics_view.add_child(surface)
	if not previous.is_empty():surface.restore_state(previous)
	surface.contact_audio.connect(func(point:Vector2,strength:float):water_audio.emit(point,strength,true))
	var lemon_layer:=TextureRect.new();lemon_layer.texture=physics_view.get_texture();lemon_layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lemon_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(lemon_layer,self,Rect2(0,0,1600,900))
	lemon_layer.name="FloatingLemons"
	_paper_masks.clear()
	for key:String in ["settings_paper_shadow","settings_papers","settings_tape","settings_stationery","settings_postcards"]:
		var paper:=_image(key,Rect2(0,0,1600,900));var matte:=ShaderMaterial.new();matte.shader=MatteShader;paper.material=matte;paper.name="PDF_"+key
		_paper_masks.append(paper.texture.get_image())
	var heading:=_label(_t("设置","Settings"),Rect2(510,18,534,109),66 if preferences.values.language=="zh" else 94,Color("0059ae"))
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font",_headline);heading.name="SettingsHeading"
	heading.add_theme_color_override("font_outline_color",Color.WHITE);heading.add_theme_constant_override("outline_size",7)
	var cross:=Button.new();cross.name="CloseSettings";cross.text="←";cross.flat=true
	cross.tooltip_text=_t("返回","Back")
	cross.add_theme_font_size_override("font_size",32);cross.add_theme_color_override("font_color",Color.WHITE)
	cross.add_theme_stylebox_override("focus",StyleBoxEmpty.new());cross.add_theme_color_override("font_focus_color",Color("fff4ba"));cross.add_theme_color_override("font_hover_color",Color("fff4ba"))
	UI.place(cross,self,Rect2(1008,117,43,43));cross.pressed.connect(request_close)
	_option("language",_t("语言","Language"),Rect2(636,165,217,40),Rect2(864,169,159,40),["zh","en"],[_t("中文 · 界面","中文 · UI"),"English · UI"])
	_option("display_mode",_t("显示模式","Display Mode"),Rect2(526,252,297,40),Rect2(864,252,159,40),["windowed","fullscreen","borderless"],[_t("窗口","Windowed"),_t("全屏","Full Screen"),_t("无边框","Borderless")])
	_option("resolution",_t("分辨率","Resolution"),Rect2(526,310,295,40),Rect2(864,310,159,40),["auto","1280x720","1600x900","1920x1080"],["AUTO","1280 × 720","1600 × 900","1920 × 1080"])
	_separator(389)
	_slider("master",_t("总音量","Master Volume"),428,0.0,1.0)
	_slider("music",_t("音乐音量","Music Volume"),486,0.0,1.0)
	_slider("sfx",_t("音效音量","SFX Volume"),544,0.0,1.0)
	_separator(615)
	_slider("sensitivity",_t("鼠标灵敏度","Mouse Sensitivity"),658,0.5,2.0)
	controls.sensitivity.tooltip_text=_t("纸面缩放与平移；物件仍紧随指针。","Paper zoom and pan; held objects remain attached to the pointer.")
	_option("text_speed",_t("文字速度","Text Speed"),Rect2(526,718,274,40),Rect2(804,715,161,42),["slow","normal","fast","instant"],[_t("慢","Slow"),_t("中","Normal"),_t("快","Fast"),_t("即时","Instant")])
	_error=UI.label(self,"",Rect2(504,788,491,73),17,Color("723328"));_error.name="SettingsSaveError"
	_save_timer=Timer.new();_save_timer.one_shot=true;_save_timer.wait_time=0.3;add_child(_save_timer);_save_timer.timeout.connect(_save)
	_update_water()
	_focus_page()
	cross.grab_focus()

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
	if preferences.values.language=="zh" and key!="language":label_rect.position.x=548;label_rect.size.x=262
	if preferences.values.language=="zh" and key=="text_speed":label_rect.size.x=230
	var caption:=_label(label,label_rect,26 if preferences.values.language=="zh" else 29);caption.name="SettingLabel_"+key
	if preferences.values.language=="zh":caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var choice:=Button.new();choice.name="Setting_"+key
	choice.text=str(texts[values.find(preferences.values[key])]);choice.alignment=HORIZONTAL_ALIGNMENT_LEFT
	choice.add_theme_font_override("font",_font);choice.add_theme_font_size_override("font_size",19)
	choice.add_theme_color_override("font_color",Color("c7e8ff"))
	var style:=UI.style(Color("0059ae"),Color.TRANSPARENT,7);style.content_margin_left=7;style.content_margin_right=24;style.content_margin_top=2;style.content_margin_bottom=2
	for state in ["normal","hover","pressed","focus"]:choice.add_theme_stylebox_override(state,style)
	UI.place(choice,self,rect);controls[key]=choice
	var arrow:=Label.new();arrow.text="▾";arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_color_override("font_color",Color.WHITE);arrow.add_theme_font_size_override("font_size",20)
	UI.place(arrow,choice,Rect2(rect.size.x-25,1,22,rect.size.y-2))
	choice.pressed.connect(func():_open_options(key,choice,values,texts))

func _open_options(key:String,choice:Button,values:Array,texts:Array) -> void:
	_close_options()
	_dropdown=Control.new();_dropdown.name="SettingsDropdown";UI.place(_dropdown,self,Rect2(0,0,1600,900))
	var blocker:=ColorRect.new();blocker.color=Color.TRANSPARENT;UI.place(blocker,_dropdown,Rect2(0,0,1600,900))
	blocker.gui_input.connect(func(event:InputEvent):
		if event is InputEventMouseButton and event.pressed:_close_options();get_viewport().set_input_as_handled())
	var height:=values.size()*46.0+12.0
	var top:=choice.position.y+choice.size.y+4.0
	if top+height>785.0:top=choice.position.y-height-4.0
	var box:=UI.panel(_dropdown,Rect2(choice.position.x,top,maxf(choice.size.x,196.0),height),Color("0059ae"))
	box.mouse_filter=Control.MOUSE_FILTER_STOP
	var rows:Array=[]
	for index:int in values.size():
		var row:=Button.new();row.name="Option_"+key+"_"+str(index);row.text=str(texts[index])
		row.add_theme_font_override("font",_font);row.add_theme_font_size_override("font_size",19)
		row.add_theme_color_override("font_color",Color.WHITE);row.add_theme_color_override("font_hover_color",Color("fff4b7"))
		row.flat=true;UI.place(row,box,Rect2(6,6+index*46,box.size.x-12,44))
		rows.append(row)
		row.pressed.connect(func():
			preferences.set_value(key,values[index]);choice.text=str(texts[index]);cue.emit("paper");_save();_close_options()
			if key=="language":_build.call_deferred())
		if values[index]==preferences.values[key]:row.grab_focus()
	# The visible cross remains usable in one click even while a dropdown is open.
	move_child(get_node("CloseSettings"),get_child_count()-1)
	rows.append(get_node("CloseSettings"));_focus_loop(rows)

func _close_options() -> void:
	if is_instance_valid(_dropdown):remove_child(_dropdown);_dropdown.queue_free()
	_dropdown=null
	if is_instance_valid(get_node_or_null("CloseSettings")) and not controls.is_empty():_focus_page()
func _separator(y:float) -> void:
	var line:=ColorRect.new();line.color=Color(0.7,0.91,1.0,0.18);line.mouse_filter=Control.MOUSE_FILTER_IGNORE;UI.place(line,self,Rect2(560,y,470,3))
func _slider(key:String,text:String,y:float,minimum:float,maximum:float) -> void:
	var chinese:bool=preferences.values.language=="zh"
	if chinese and key=="sensitivity":text="操作灵敏度"
	var caption:=_label(text,Rect2(548,y-6,237,40) if chinese else Rect2(526,y-10,271,46),26 if chinese else 29);caption.name="SettingLabel_"+key
	if chinese:caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var slider:=HSlider.new();slider.name="Setting_"+key
	slider.min_value=minimum;slider.max_value=maximum;slider.step=0.01;slider.value=preferences.values[key]
	var track:=StyleBoxLine.new();track.color=Color("0061ad");track.thickness=5
	var fill:=track.duplicate() as StyleBoxLine;fill.color=Color.WHITE
	slider.add_theme_stylebox_override("slider",track);slider.add_theme_stylebox_override("grabber_area",fill);slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	# Native system-control icon: fully opaque white core in every drag/focus state.
	var knob:=GradientTexture2D.new();knob.width=24;knob.height=24;knob.fill=GradientTexture2D.FILL_RADIAL;knob.fill_from=Vector2(0.5,0.5);knob.fill_to=Vector2(1,0.5)
	var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0.0,0.86,0.96,1.0]);gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color(1,1,1,0)]);knob.gradient=gradient
	for state:String in ["grabber","grabber_highlight","grabber_disabled"]:slider.add_theme_icon_override(state,knob)
	UI.place(slider,self,Rect2(805,y-9,221,44));controls[key]=slider
	slider.value_changed.connect(func(value:float):preferences.set_value(key,value);_save_timer.start())
	slider.drag_ended.connect(func(_changed:bool):_save();cue.emit("snap"))

func _model_changed(key:String,value:Variant) -> void:
	# F11 and external preference updates share the same source of truth as mouse input.
	if not controls.has(key):return
	if controls[key] is Slider:controls[key].set_value_no_signal(float(value))
	elif _option_values.has(key):
		var index:int=_option_values[key].find(value)
		if index>=0:controls[key].text=str(_option_texts[key][index])
func _save() -> bool:
	var ok:bool=preferences.save_settings()
	if is_instance_valid(_error):_error.text="" if ok else _t("设置未保存：","Settings could not be saved: ")+preferences.last_error
	return ok
func request_close() -> void:
	if _closing or not _save():return
	_closing=true;get_viewport().set_input_as_handled();cue.emit("paper");closed.emit()
func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if is_instance_valid(_dropdown):_close_options();get_viewport().set_input_as_handled()
		else:request_close()
func _water_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion:
		var point:Vector2=event.position
		# Touching UI never disturbs water beneath the paper. Ignore jumps across it.
		var previous:Vector2=_last_pointer
		var elapsed:float=clampf(_time-_last_motion,1.0/120.0,0.1)
		_last_motion=_time;_last_pointer=point
		if previous.x<0 or point.distance_to(previous)>180.0 or _on_paper(point) or _on_paper(previous):return
		if surface.hit_lemon(point)>=0 or surface.hit_lemon(previous)>=0:return
		if _time-_last_drop<0.065:return
		var speed:float=event.velocity.length() if event.velocity.length()>1.0 else point.distance_to(previous)/elapsed
		if speed<18.0:return
		var dragging:bool=(event.button_mask&MOUSE_BUTTON_MASK_LEFT)!=0
		field.stroke(previous,point,speed,dragging)
		surface.water_swipe(previous,point,speed,dragging)
		if speed>90.0 and _time-_last_skim_audio>0.22:
			_last_skim_audio=_time;water_audio.emit(point,clampf(speed/2400.0,0.1,0.38),true)
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
	var point:Vector2=event.position
	if _on_paper(point) or _time-_last_drop<0.075:return
	var lemon:int=surface.hit_lemon(point)
	if lemon>=0:surface.tap_lemon(lemon,point);_last_drop=_time;return
	_last_drop=_time;_drops.append(Vector3(point.x,point.y,_time))
	if _drops.size()>8:_drops.pop_front()
	field.tap(point);surface.water_touch(point);water_audio.emit(point,1.0,false)
func _on_paper(point:Vector2)->bool:
	# Hit the actual original layer silhouettes, including the tilted postcards and tape.
	for mask:Image in _paper_masks:
		var texel:=Vector2i(point/Vector2(1600,900)*Vector2(mask.get_size())).clamp(Vector2i.ZERO,mask.get_size()-Vector2i.ONE)
		var color:=mask.get_pixelv(texel)
		if minf(color.r,minf(color.g,color.b))<0.975:return true
	return false
func _process(delta:float) -> void:
	_time+=minf(delta,0.1)
	while not _drops.is_empty() and _time-_drops[0].z>3.1:_drops.pop_front()
	# Pointer time remains real, while wave integration is fixed-step and deterministic.
func _physics_process(_delta:float)->void:
	if field==null or not is_instance_valid(surface):return
	field.set_obstacles(surface.bodies);field.advance()
func _update_water() -> void:
	if field!=null:_material.set_shader_parameter("height_field",field.texture)
func ripple_snapshot() -> Dictionary:return {"active":_drops.size(),"time":_time,"drops":_drops.duplicate(),"shader_water_only":_water.material==_material,"field":field.snapshot()}
