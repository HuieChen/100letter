extends Control
signal closed
signal cue(kind:String)
signal recording_saved(path:String)
const UI=preload("res://scripts/ui/paper_ui.gd")
const FONT=preload("res://assets/fonts/DearRounded.tres")
const BUS:="SolmereAmbience"
const MAX_SECONDS:=120.0
var locale:="zh"
var location_caption:=""
var location_provider:Callable
var visited_locations:Array[String]=[]
var mode_label:Label
var _wave_history:Array[float]=[]
var _wave_clock:=0.0
var _meter_peak:=Vector2.ZERO
var directory:="user://recordings"
var road:Control
var sound:Node
var recording:=false
var elapsed:=0.0
var last_path:=""
var selected_path:=""
var paths:Array[String]=[]
var effect:AudioEffectRecord
var meter:AudioEffectCapture
var playback:AudioStreamPlayer
var pending_audio:AudioStreamWAV
var record_button:Button
var play_button:Button
var clock_label:Label
var status:Label
var library:ItemList
var title_edit:LineEdit
var visual_hint:CheckButton
var levels:=Vector2.ZERO
var aim_point:=Vector2(800,420)
var _held:Dictionary={}
var _closing:=false
var _page:Control
var _ink:Control
var library_button:Button
func t(zh:String,en:String)->String:return en if locale=="en" else zh
func _ready()->void:
	name="FieldRecorder";mouse_filter=Control.MOUSE_FILTER_STOP
	# The recorder is a field tool, not a modal pause screen. Keep the courier
	# input route alive while its library is closed; the library itself pauses it.
	if is_instance_valid(road) and is_instance_valid(road.courier):road.courier.manual_enabled=true
	_page=Control.new();UI.place(_page,self,Rect2(0,0,1600,900));_page.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var surface:=Control.new();surface.name="RecordingWalkSurface";UI.place(surface,_page,Rect2(0,0,1600,900));surface.mouse_default_cursor_shape=Control.CURSOR_CROSS;surface.gui_input.connect(_aim_input)
	var instrument:=Control.new();instrument.name="StereoDisplay";UI.place(instrument,_page,Rect2(32,28,352,134));instrument.mouse_filter=Control.MOUSE_FILTER_IGNORE
	instrument.draw.connect(func():
		var body:=StyleBoxFlat.new();body.bg_color=Color("f3ead6");body.set_corner_radius_all(16);body.set_border_width_all(1);body.border_color=Color("b9b09b");body.shadow_color=Color(0,0,0,.16);body.shadow_size=4;body.shadow_offset=Vector2(0,3);instrument.draw_style_box(body,Rect2(Vector2.ZERO,instrument.size)))
	# SEASON reference: monitor the scene through sparse edge HUD, browse separately.
	var style:=StyleBoxFlat.new();style.bg_color=Color("f7edd9");style.set_corner_radius_all(14)
	label(t("录音机 · 双声道","RECORDER · STEREO"),Rect2(54,39,215,27),17)
	clock_label=label("00:00",Rect2(278,38,90,30),23)
	mode_label=label(t("监听","MONITOR"),Rect2(70,67,105,22),15)
	label("L",Rect2(54,91,22,20),14);label("R",Rect2(54,111,22,20),14)
	record_button=button(t("R  录音","R  Record"),Rect2(1224,814,176,48),toggle_recording);record_button.name="RecordToggle"
	play_button=button(t("P  回听","P  Play"),Rect2(1040,814,170,48),toggle_playback);play_button.name="PlaybackToggle"
	button("×",Rect2(1500,28,56,48),request_close).name="CloseRecorder"
	button(t("Esc  收起","Esc  Put away"),Rect2(1405,814,175,48),request_close).name="PutAwayRecorder"
	visual_hint=CheckButton.new();visual_hint.text=t("方向提示","Direction hints");visual_hint.add_theme_font_override("font",FONT);visual_hint.add_theme_font_size_override("font_size",18)
	for state:String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:visual_hint.add_theme_color_override(state,Color("fff4db"))
	visual_hint.add_theme_color_override("font_outline_color",Color(.12,.16,.17,.75));visual_hint.add_theme_constant_override("outline_size",4)
	UI.place(visual_hint,_page,Rect2(1288,32,205,40));visual_hint.tooltip_text=t("H · 方向提示","H · Direction hints")
	library_button=button(t("录音列表","Recordings"),Rect2(36,814,194,48),_toggle_library);library_button.name="RecordingLibrary"
	status=label("",Rect2(40,171,350,34),18)
	status.add_theme_color_override("font_color",Color("fff4db"));status.add_theme_color_override("font_outline_color",Color(.12,.16,.17,.8));status.add_theme_constant_override("outline_size",3)
	var movement:=label(t("WASD / 方向键移动 · 鼠标收音","WASD / Arrows to walk · Mouse to aim"),Rect2(270,824,650,30),18)
	movement.add_theme_color_override("font_color",Color("fff4db"));movement.add_theme_color_override("font_outline_color",Color(.12,.16,.17,.8));movement.add_theme_constant_override("outline_size",3)
	var list_panel:=Panel.new();list_panel.add_theme_stylebox_override("panel",style);UI.place(list_panel,_page,Rect2(1030,150,510,550));list_panel.hide()
	library=ItemList.new();library.add_theme_font_override("font",FONT);library.add_theme_font_size_override("font_size",21);UI.place(library,list_panel,Rect2(18,22,474,415));library.item_selected.connect(_select)
	title_edit=LineEdit.new();title_edit.placeholder_text=t("名称","Name");title_edit.max_length=60;title_edit.add_theme_font_override("font",FONT);title_edit.add_theme_font_size_override("font_size",21);UI.place(title_edit,list_panel,Rect2(18,458,474,48));title_edit.text_submitted.connect(func(_v:String):_save_name());title_edit.focus_exited.connect(_save_name)
	var list_style:=StyleBoxFlat.new();list_style.bg_color=Color("eee2cc");list_style.set_corner_radius_all(8)
	library.add_theme_stylebox_override("panel",list_style);library.add_theme_color_override("font_color",Color("514b43"));library.add_theme_color_override("font_selected_color",Color("332f29"))
	var selected_style:=StyleBoxFlat.new();selected_style.bg_color=Color("c9d8cc");selected_style.set_corner_radius_all(5)
	library.add_theme_stylebox_override("selected",selected_style);library.add_theme_stylebox_override("selected_focus",selected_style)
	title_edit.add_theme_stylebox_override("normal",list_style);title_edit.add_theme_color_override("font_color",Color("514b43"));title_edit.add_theme_color_override("font_placeholder_color",Color("776f61"))
	_ink=Control.new();UI.place(_ink,self,Rect2(0,0,1600,900));_ink.mouse_filter=Control.MOUSE_FILTER_IGNORE;_ink.draw.connect(_draw_feedback)
	playback=AudioStreamPlayer.new();playback.bus="SolmereFoley";add_child(playback);playback.finished.connect(_playback_finished)
	effect=AudioEffectRecord.new();effect.format=AudioStreamWAV.FORMAT_16_BITS
	meter=AudioEffectCapture.new();meter.buffer_length=.5
	var bus:=AudioServer.get_bus_index(BUS)
	if bus<0:record_button.disabled=true;status.text=t("声音暂不可用","Audio unavailable")
	else:AudioServer.add_bus_effect(bus,effect);AudioServer.add_bus_effect(bus,meter)
	sound.recorder_focus=true
	if is_instance_valid(road):road.field_sound.set_focus(true,_world_aim())
	_refresh_library();get_window().focus_exited.connect(_focus_lost)
	record_button.grab_focus()
func label(text:String,rect:Rect2,px:int)->Label:
	var value:=UI.label(_page,text,rect,px,Color("47534b"));value.mouse_filter=Control.MOUSE_FILTER_IGNORE;return value
func button(text:String,rect:Rect2,callback:Callable)->Button:
	var value:=UI.button(_page,text,rect,callback);value.flat=false;value.add_theme_font_override("font",FONT);value.add_theme_font_size_override("font_size",21)
	for state:String in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("f3ead6") if state=="normal" else (Color("c4d7c5") if state!="disabled" else Color("d6d4c5"));style.set_corner_radius_all(12)
		style.set_border_width_all(1);style.border_color=Color("afa994");style.shadow_size=2;style.shadow_offset=Vector2(0,2);style.shadow_color=Color(0,0,0,.16)
		value.add_theme_stylebox_override(state,style);value.add_theme_color_override("font_"+state+"_color",Color("46544a") if state!="disabled" else Color("8d927e"))
	value.add_theme_color_override("font_color",Color("46544a"))
	var focus:=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.set_corner_radius_all(12);focus.set_border_width_all(3);focus.border_color=Color("728d77");value.add_theme_stylebox_override("focus",focus)
	return value
func allows_world_walk()->bool:
	return not _closing and is_instance_valid(road) and not library.get_parent().visible
func _world_aim()->Vector2:return road.world.get_global_transform().affine_inverse()*get_global_transform()*aim_point if is_instance_valid(road) else aim_point
func _aim_input(event:InputEvent)->void:
	if event is InputEventMouseMotion:
		aim_point=(get_global_transform().affine_inverse()*get_global_mouse_position()).clamp(Vector2(20,20),Vector2(1580,800))
	elif event is InputEventMouseButton and allows_world_walk():
		var ground:InputEventMouseButton=event.duplicate()
		# The world receives its own 1600x900 design-space input. Passing the
		# recorder's screen-space point directly keeps the lower walking strip
		# consistent with the normal road hit area at every window scale.
		ground.position=event.position
		road.world.get_node("WalkTarget")._ground_input(ground)
func _input(event:InputEvent)->void:
	if not event is InputEventKey:return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus==title_edit or focus==library or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
	var key:int=event.physical_keycode if event.physical_keycode else event.keycode
	# The walker reads these physical keys. Prevent buttons from also navigating.
	if key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_W,KEY_A,KEY_S,KEY_D,KEY_E]:get_viewport().set_input_as_handled()
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
	if get_viewport().gui_get_focus_owner()==title_edit:return
	var key:int=event.physical_keycode if event.physical_keycode else event.keycode
	if event.pressed and not event.echo:
		if key==KEY_ESCAPE:request_close();get_viewport().set_input_as_handled()
		elif key==KEY_R:toggle_recording();get_viewport().set_input_as_handled()
		elif key==KEY_P:toggle_playback();get_viewport().set_input_as_handled()
		elif key==KEY_H:visual_hint.button_pressed=not visual_hint.button_pressed;get_viewport().set_input_as_handled()
func _process(delta:float)->void:
	if _closing:return
	if location_provider.is_valid():location_caption=location_provider.call()
	if recording and location_caption not in visited_locations:visited_locations.append(location_caption)
	if is_instance_valid(road):road.field_sound.set_focus(true,_world_aim())
	var peak:=Vector2.ZERO
	if meter!=null:
		var available:=meter.get_frames_available()
		if available>0:
			for frame:Vector2 in meter.get_buffer(available):peak=Vector2(maxf(peak.x,absf(frame.x)),maxf(peak.y,absf(frame.y)))
	levels=Vector2(maxf(peak.x,levels.x*exp(-delta*4.0)),maxf(peak.y,levels.y*exp(-delta*4.0)))
	_meter_peak=Vector2(maxf(levels.x,_meter_peak.x*exp(-delta*.6)),maxf(levels.y,_meter_peak.y*exp(-delta*.6)))
	_wave_clock+=delta
	if _wave_clock>=.05:
		_wave_clock=0.0;_wave_history.append(clampf((linear_to_db(maxf(peak.length(),.00001))+60.0)/60.0,0.0,1.0))
		if _wave_history.size()>55:_wave_history.pop_front()
	mode_label.text=t("录制","REC") if recording else (t("回听","PLAY") if playback.playing else t("监听","MONITOR"))
	if recording:
		elapsed+=delta
		if elapsed>=MAX_SECONDS:stop_recording()
	var seconds:=elapsed if recording else (playback.get_playback_position() if playback.playing else 0.0)
	clock_label.text="%02d:%02d"%[int(seconds)/60,int(seconds)%60]
	library_button.disabled=recording
	play_button.disabled=recording or (selected_path.is_empty() and last_path.is_empty())
	_ink.queue_redraw()
func _draw_feedback()->void:
	_ink.draw_circle(Vector2(58,77),4,Color("b25949") if recording else Color("91a78c"))
	for channel in 2:
		var normalized:=clampf((linear_to_db(maxf(levels[channel],.00001))+60.0)/60.0,0.0,1.0)
		var held:=clampf((linear_to_db(maxf(_meter_peak[channel],.00001))+60.0)/60.0,0.0,1.0)
		for i in 35:
			var color:=Color("739781") if i<28 else Color("bf9560")
			if float(i)/35.0>=normalized:color=Color("d8d8c5")
			_ink.draw_rect(Rect2(80+i*8,96+channel*20,6,8),color)
		_ink.draw_line(Vector2(80+held*280,95+channel*20),Vector2(80+held*280,105+channel*20),Color("667455"),1.5)
	for i in _wave_history.size():
		var height:=_wave_history[i]*7.0
		_ink.draw_line(Vector2(80+i*5,145-height),Vector2(80+i*5,145+height),Color("829580"),2.0)

	if visual_hint.button_pressed:
		_ink.draw_arc(aim_point,16,0,TAU,24,Color("fff3d5"),2,true)
		if is_instance_valid(road):
			var source:Dictionary=road.field_sound.strongest()
			if not source.is_empty():
				var screen:Vector2=get_global_transform().affine_inverse()*road.world.get_global_transform()*source.at
				var delta:Vector2=(screen-aim_point).normalized()
				_ink.draw_line(aim_point+delta*22,aim_point+delta*42,Color("fff3d5"),2,true)
func _toggle_library()->void:
	if recording:return
	if library.get_parent().visible and not _save_name():return
	library.get_parent().visible=not library.get_parent().visible
	if is_instance_valid(road) and is_instance_valid(road.courier):
		road.courier.manual_enabled=not library.get_parent().visible
	if library.get_parent().visible:
		library.grab_focus()
		if is_instance_valid(road):road.courier.cancel()
func toggle_recording()->void:
	if recording:stop_recording();return
	if effect==null or AudioServer.get_bus_index(BUS)<0:return
	if pending_audio!=null and not _persist_pending():return
	if not _save_name():return
	library.get_parent().hide();stop_playback();library.mouse_filter=Control.MOUSE_FILTER_IGNORE;library.focus_mode=Control.FOCUS_NONE;title_edit.editable=false;effect.set_recording_active(true);elapsed=0;visited_locations=[location_caption];recording=true;status.text="";record_button.text=t("R  停止","R  Stop");cue.emit("recorder_start")
func stop_recording()->bool:
	if not recording:return _persist_pending()
	effect.set_recording_active(false);recording=false;library.mouse_filter=Control.MOUSE_FILTER_STOP;library.focus_mode=Control.FOCUS_ALL;title_edit.editable=true;record_button.text=t("R  录音","R  Record")
	pending_audio=effect.get_recording()
	if pending_audio==null or pending_audio.data.is_empty():pending_audio=null;status.text=t("录音太短","Recording too short");return true
	var saved:=_persist_pending();cue.emit("recorder_stop");return saved
func _persist_pending()->bool:
	if pending_audio==null:return true
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:status.text=t("未保存，请重试","Not saved. Retry.");return false
	var stamp:=Time.get_datetime_string_from_system().replace(":","").replace("-","")
	var path:=directory.path_join("Recording_"+stamp+"_"+str(Time.get_ticks_usec())+".wav")
	var temp:=path+".pending.wav"
	if pending_audio.save_to_wav(temp)!=OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path))!=OK:
		status.text=t("未保存，请重试","Not saved. Retry.");return false
	var data:={"version":2,"name":"","location":location_caption,"locations":visited_locations.duplicate(),"seconds":pending_audio.get_length(),"captured_bus":BUS}
	var metadata_saved:=_write_metadata(path,data)
	last_path=path;selected_path=path;pending_audio=null;status.text=t("已保存","Saved") if metadata_saved else t("录音已保存，名称未保存","Audio saved; name not saved");_refresh_library();recording_saved.emit(path);return true
func _refresh_library()->void:
	paths.clear();library.clear()
	var dir:=DirAccess.open(directory)
	if dir!=null:
		for file:String in dir.get_files():
			if file.begins_with("Recording_") and file.ends_with(".wav") and not file.ends_with(".pending.wav"):paths.append(directory.path_join(file))
	paths.sort();paths.reverse()
	for i in paths.size():
		var data:=_metadata(paths[i]);var name:String=data.get("name","")
		if name.is_empty():name=t("录音 ","Recording ")+str(paths.size()-i)
		library.add_item(name+" · "+str(data.get("location",""))+" · %ds"%maxi(1,ceili(float(data.get("seconds",0)))))
	if not paths.is_empty():
		if selected_path not in paths:selected_path=paths[0]
		library.select(paths.find(selected_path));title_edit.text=str(_metadata(selected_path).get("name",""))
func _select(index:int)->void:
	if recording or not _save_name():
		if selected_path in paths:library.select(paths.find(selected_path))
		return
	stop_playback();selected_path=paths[index];title_edit.text=str(_metadata(selected_path).get("name",""))
func toggle_playback()->void:
	if recording:return
	if playback.playing:stop_playback();return
	var path:=selected_path if not selected_path.is_empty() else last_path
	if path.is_empty():return
	playback.stream=AudioStreamWAV.load_from_file(path)
	if playback.stream==null:status.text=t("无法打开录音","Recording unavailable");return
	# Playback bypasses the recorded environment bus: never records itself.
	sound.recorder_playback=true;playback.volume_db=_replay_gain(playback.stream);playback.play();play_button.text=t("P  停止","P  Stop")
func _replay_gain(stream:AudioStreamWAV)->float:
	# A fixed gain per clip preserves its dynamics; limit boost and leave 6 dB headroom.
	if stream.format!=AudioStreamWAV.FORMAT_16_BITS:return 0.0
	var bytes:=stream.data
	var peak:=0.0
	for i in range(0,bytes.size()-1,2):peak=maxf(peak,absf(float(bytes.decode_s16(i)))/32768.0)
	return clampf(-6.0-linear_to_db(maxf(peak,.00001)),0.0,12.0)
func stop_playback()->void:
	if playback!=null:playback.stop()
	_playback_finished()
func _playback_finished()->void:
	if is_instance_valid(sound):sound.recorder_playback=false
	if is_instance_valid(play_button):play_button.text=t("P  回听","P  Play")
func _metadata(path:String)->Dictionary:
	if not FileAccess.file_exists(path+".json"):return {}
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path+".json"));return data if data is Dictionary else {}
func _write_metadata(path:String,data:Dictionary)->bool:
	var temp:=path+".json.tmp";var file:=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(data));file.flush();var error:=file.get_error();file.close()
	return error==OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path+".json"))==OK
func _save_name()->bool:
	if selected_path.is_empty():return true
	var data:=_metadata(selected_path)
	if str(data.get("name",""))==title_edit.text:return true
	data.name=title_edit.text
	if not _write_metadata(selected_path,data):status.text=t("名称未保存","Name not saved");return false
	var i:=paths.find(selected_path)
	if i>=0:library.set_item_text(i,(title_edit.text if not title_edit.text.is_empty() else t("录音","Recording"))+" · "+str(data.get("location",""))+" · %ds"%maxi(1,ceili(float(data.get("seconds",0)))))
	return true
func _focus_lost()->void:
	_held.clear()
	if recording:stop_recording()
	stop_playback()
func checkpoint_for_quit()->bool:return stop_recording() and _save_name()
func request_close()->void:
	if _closing or not checkpoint_for_quit():return
	_closing=true;stop_playback();closed.emit()
func _exit_tree()->void:
	if effect!=null:effect.set_recording_active(false)
	if is_instance_valid(sound):sound.recorder_focus=false;sound.recorder_playback=false
	if is_instance_valid(road) and is_instance_valid(road.field_sound):road.field_sound.set_focus(false)
	if playback!=null:playback.stop();playback.stream=null
	var bus:=AudioServer.get_bus_index(BUS)
	if bus>=0:
		for i in range(AudioServer.get_bus_effect_count(bus)-1,-1,-1):
			if AudioServer.get_bus_effect(bus,i) in [effect,meter]:AudioServer.remove_bus_effect(bus,i)
