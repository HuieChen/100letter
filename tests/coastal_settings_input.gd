extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const OUT="res://test-results/ui-reference-20261016/settings/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
var water_cues:=0
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	for dims:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dims;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		game=Host.new();game.allow_display_changes=false;game.preferences_path="user://qa/coastal-settings/"+str(Time.get_ticks_usec())+".json"
		root.add_child(game);game.size=Vector2(1600,900)
		game.sound.cue_played.connect(func(kind:String,_sample:String):
			if kind=="water":water_cues+=1)
		await _click_named("OpenSettings")
		_check(game.modal.get_script().resource_path.ends_with("coastal_settings.gd"),"title opens actual supplied-reference settings")
		_check(game.modal.get_node("CloseSettings").text=="←","clear return arrow replaces the temporary generic cross")
		_check(game.modal.get_node("SettingsHeading").get_theme_font("font").get_font_name().contains("Noto"),"Chinese headline uses its own measured typeface and centered layout")
		_check(float(game.modal._font.variation_opentype.get(0x77676874,0))==600,"Chinese body uses the active 600 weight axis")
		var speed_label:Label=game.modal.get_node("SettingLabel_text_speed")
		var speed_glyph_width:=speed_label.get_theme_font("font").get_string_size(speed_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,speed_label.get_theme_font_size("font_size")).x
		var speed_glyph_end:=speed_label.position.x+(speed_label.size.x+speed_glyph_width)*0.5
		_check(speed_glyph_end+12<=game.modal.controls.text_speed.position.x,"Chinese centered speed glyphs have a real safe gap before their selector")
		await _round_menu("zh_"+str(dims.x))
		await _shot("zh_"+str(dims.x))
		if dims.x==1280:
			for child in game.modal.get_children():
				if child is Label:print("LAYOUT ",child.text," rect ",child.get_rect()," font-height ",child.get_theme_font("font").get_height(child.get_theme_font_size("font_size")))
		for key:String in ["master","music","sfx","sensitivity"]:
			var slider:Slider=game.modal.controls[key]
			var center:=slider.get_global_rect().get_center()
			await _button(center,true)
			await _motion(center+Vector2(-55,0),Vector2(-55,0))
			await _button(center+Vector2(-55,0),false)
			_check(absf(game.preferences.values[key]-slider.value)<0.001,"drag applies "+key)
			_check(slider.value>slider.min_value and slider.value<slider.max_value,"track is continuously movable "+key)
			for state:String in ["grabber","grabber_highlight","grabber_disabled"]:
				var icon:Image=slider.get_theme_icon(state).get_image();var core:=icon.get_pixelv(icon.get_size()/2)
				_check(core.a>0.999 and core.r>0.999 and core.g>0.999 and core.b>0.999,"solid opaque knob "+key+" "+state)
		var master_index:=AudioServer.get_bus_index("Master")
		_check(absf(db_to_linear(AudioServer.get_bus_volume_db(master_index))-game.preferences.values.master)<0.001,"master drives actual audio bus")
		_check(absf(game.sound.get_volumes().music-game.preferences.values.music)<0.001,"music drives dedicated bus")
		_check(absf(game.sound.get_volumes().effects-game.preferences.values.sfx)<0.001,"SFX drives dedicated bus")
		var old_cues:=water_cues
		await create_timer(0.18).timeout
		for lemon:Vector2 in [Vector2(145,65),Vector2(1420,688)]:
			await _button(lemon,true);await _button(lemon,false)
		_check(water_cues>old_cues and game.modal.ripple_snapshot().active==0,"solid lemons receive their own physical touch instead of a fake water click")
		await create_timer(1.5).timeout
		RenderingServer.force_draw(false)
		var water_before:=root.get_texture().get_image()
		await _button(Vector2(1380,340),true);await _button(Vector2(1380,340),false)
		_check(game.modal.ripple_snapshot().active==1,"water click begins a ripple at the actual location")
		_check(game.modal.ripple_snapshot().shader_water_only,"stationery text and controls stay outside water material")
		_check(water_cues>old_cues,"water click invokes a decoded licensed sample")
		await _shot("ripple_early_"+str(dims.x))
		await create_timer(0.45).timeout
		RenderingServer.force_draw(false)
		var water_after:=root.get_texture().get_image()
		_check(_pixel_changes(water_before,water_after,Rect2(1260,210,260,250))>8,"authored water texture actually refracts after a touch")
		_check(_pixel_changes(water_before,water_after,Rect2(530,260,460,350))==0,"stationery and menu pixels remain stable during water movement")
		_check(game.modal.surface.snapshot().engine=="GodotPhysics2D","lemon motion uses native rigid-body physics, not UV wobbling")
		await _shot("ripple_spread_"+str(dims.x))
		await _button(Vector2(740,385),true);await _button(Vector2(740,385),false)
		_check(game.modal.ripple_snapshot().active==1,"paper background clicks do not create water behind text")
		await _option("language",1)
		_check(game.preferences.values.language=="en","actual popup chooses English UI")
		await process_frame;await _shot("en_"+str(dims.x))
		await _round_menu("en_"+str(dims.x))
		for key:String in game.modal.controls:
			var label:Label=game.modal.find_child("SettingLabel_"+key,true,false)
			_check(label.size.y<=48,"label remains single line "+key)
			_check(label.get_rect().end.x<game.modal.controls[key].position.x,"text cannot cover actual control "+key)
		_check(game.stage.find_child("NewShift",true,false).text=="New shift","language changes real title menu")
		await _option("text_speed",0)
		_check(game.preferences.text_rate()==20.0,"text speed selects actual dialogue rate")
		await _option("resolution",1)
		_check(game.preferences.values.resolution=="1280x720","resolution selection persists; OS mode mutation tested separately")
		await _option("display_mode",2)
		_check(game.preferences.values.display_mode=="borderless","display selection persists; native behavior separate")
		game.preferences.set_value("display_mode","windowed")
		_check(game.modal.controls.display_mode.text=="Windowed","external mode updates synchronize the visible label")
		await _click_named("Setting_resolution")
		await _key(root,KEY_ESCAPE)
		_check(game.modal.find_child("SettingsDropdown",true,false)==null,"Esc dismisses only an open dropdown")
		await _click_named("Setting_display_mode")
		await _click_named("CloseSettings")
		_check(not is_instance_valid(game.modal),"visible cross returns title without Esc")
		var saved:Dictionary=game.preferences.values.duplicate(true)
		var reload_ok:bool=game.preferences.load_settings()
		if game.preferences.values!=saved:
			for key:String in saved:
				if saved[key]!=game.preferences.values[key]:print("PREFERENCE DIFFERENCE ",key," before=",str(saved[key])," after=",str(game.preferences.values[key])," delta=",float(saved[key])-float(game.preferences.values[key]))
		_check(reload_ok and game.preferences.values==saved,"slider/dropdown values survive disk reload")
		await _click_named("OpenSettings")
		_check(game.modal.controls.music.value==saved.music,"reopened slider represents saved value")
		await _key(root,KEY_ESCAPE)
		_check(not is_instance_valid(game.modal),"Esc returns after repeated entry")
		game.core.save_path="user://qa/coastal-settings/story/"+str(Time.get_ticks_usec())+".json"
		game.core.new_game();game._counter();game._settings_page()
		await _click_named("CloseSettings")
		_check(is_instance_valid(game.modal) and game.modal.find_child("SettingsWater",true,false)==null,"pause settings returns to pause")
		game._close();game._world();game._talk("community_clerk")
		# Explicit dialogue fixture, without faking an NPC encounter at the wrong location.
		game._spoken_question("这是一次真实的文字显示速度检查。",func():pass)
		await process_frame;await create_timer(0.12).timeout
		var spoken:RichTextLabel=game.modal.find_child("SpokenLine",true,false)
		_check(spoken.visible_characters>0 and spoken.visible_characters<spoken.get_total_character_count(),"slow rate actually reveals a partial line")
		await _click_named("AdvanceDialogue")
		_check(spoken.visible_characters==-1 and not game.modal._locked,"first advance completes typing without advancing")
		await _key(root,KEY_ESCAPE)
		game.queue_free();await process_frame;await process_frame
	var f:=FileAccess.open(OUT+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,"scope":"Automated own-game input/GPU/audio routing. OS fullscreen/window resolution is excluded here to avoid stealing desktop; separate native verification required. Language is UI-only, story/documents retain original text."},"\t"));f.close()
	print("COASTAL SETTINGS: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _click_named(name:String)->void:
	var c:Control=game.find_child(name,true,false);_check(c!=null,"visible control "+name)
	if c==null:return
	var point:=c.get_global_rect().get_center();await _button(point,true);await _button(point,false)
func _button(point:Vector2,down:bool)->void:
	var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func _motion(point:Vector2,relative:Vector2)->void:
	var e:=InputEventMouseMotion.new();e.position=point;e.global_position=point;e.relative=relative;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await process_frame
func _option(key:String,index:int)->void:
	await _click_named("Setting_"+key)
	_check(game.modal.find_child("SettingsDropdown",true,false)!=null,"actual dropdown opens "+key)
	await _click_named("Option_"+key+"_"+str(index));await process_frame;await process_frame
func _round_menu(label:String)->void:
	await _click_named("Setting_language")
	var box:Panel=game.modal.find_child("SettingsOptionsPanel",true,false)
	var panel_style:StyleBox=box.get_theme_stylebox("panel")
	_check(panel_style is StyleBoxFlat and panel_style.corner_radius_top_left>=8 and panel_style.corner_radius_bottom_right>=8,"dropdown exterior has rounded corners")
	for row:Control in box.get_children():
		for state:String in ["normal","hover","pressed","focus"]:
			var style:StyleBox=row.get_theme_stylebox(state)
			_check(style is StyleBoxFlat and style.corner_radius_top_left>=8 and style.corner_radius_bottom_right>=8,"option "+state+" has a rounded silhouette")
	await _shot("menu_"+label)
	await _key(root,KEY_ESCAPE)
	_check(is_instance_valid(game.modal) and game.modal.find_child("SettingsDropdown",true,false)==null,"Esc closes rounded selector while keeping Settings open")
func _key(window:Window,code:Key)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
func _shot(name:String)->void:
	await process_frame;RenderingServer.force_draw(false);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path:=OUT+name+".png";_check(root.get_texture().get_image().save_png(path)==OK,"render "+name);images.append(path)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _pixel_changes(before:Image,after:Image,rect:Rect2)->int:
	var scale:=Vector2(before.get_size())/Vector2(1600,900)
	var changed:=0
	for y:int in range(int(rect.position.y*scale.y),int(rect.end.y*scale.y),3):
		for x:int in range(int(rect.position.x*scale.x),int(rect.end.x*scale.x),3):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255.0:changed+=1
	return changed
