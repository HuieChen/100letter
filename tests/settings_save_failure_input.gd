extends SceneTree
## Genuine filesystem failure and actual GUI inputs. Quit readiness and campaign
## guards are invoked directly; this fixture does not simulate an OS window close.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Core=preload("res://scripts/rebuild/final_case_state.gd")
const OUT="res://test-results/settings-save-failure_20261017/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
var sentinel_path:=""
var sentinel_bytes:PackedByteArray
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var directory:="user://qa/settings-save-failure/"+str(Time.get_ticks_usec())
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))==OK,"isolated fixture directory created")
	sentinel_path=directory+"/original-parent-file"
	sentinel_bytes="Original bytes remain intact. 原件保留。\n".to_utf8_buffer()
	var sentinel:=FileAccess.open(sentinel_path,FileAccess.WRITE)
	_check(sentinel!=null,"owned sentinel file created")
	if sentinel==null:quit(1);return
	sentinel.store_buffer(sentinel_bytes);sentinel.close()
	game=Host.new();game.allow_display_changes=false
	game.preferences_path=sentinel_path+"/preferences.json"
	root.add_child(game);game.size=Vector2(1600,900);await process_frame;await process_frame
	var valid_story_path:=directory+"/progress.json";game.core.save_path=valid_story_path
	var story_before:Dictionary=game.core.state.duplicate(true)
	await _open()
	await _drag_master(0.34)
	_check(game.preferences.dirty and not game.preferences.last_error.is_empty(),"real blocked parent path causes failed dirty preference save")
	_check(game.preferences.values.master<0.6,"actual slider value still applies in memory")
	_check_status("设置未保存")
	_check_sentinel("failed slider save")
	_check(game._prepare_quit(),"explicit title/settings quit readiness is not blocked by preference failure")
	_check(game.preferences.dirty,"quit readiness does not falsely mark failed preferences saved")
	await _shot("zh_error_1920")
	await _click_named("Setting_language");await _click_named("Option_language_1");await process_frame;await process_frame
	_check(game.preferences.values.language=="en","actual language selector changes the retained in-memory language")
	_check_status("Not saved")
	_check(game.preferences.dirty and not game.preferences.last_error.is_empty(),"language rebuild retains failed-save state")
	await _shot("en_error_after_rebuild_1920")
	await _click_named("Setting_resolution");await _key(KEY_ESCAPE)
	_check(is_instance_valid(game.modal) and game.modal.find_child("SettingsDropdown",true,false)==null,"first Esc still closes only a nested selector after failed saving")
	_check_status("Not saved")
	var unsaved:Dictionary=game.preferences.values.duplicate(true)
	await _click_named("CloseSettings")
	_check(not is_instance_valid(game.modal),"one visible return click exits despite failed saving")
	_check(game.preferences.values==unsaved and game.preferences.dirty,"return retains every dirty in-memory preference")
	var notice:Label=game.get_node_or_null("PreferencesSaveNotice")
	_check(notice!=null and notice.text=="Settings not saved","return provides a short localized system status")
	_check_sentinel("failed return save")
	await _open()
	_check_status("Not saved")
	_check(game.get_node_or_null("PreferencesSaveNotice")==null,"reentry uses one paper status instead of duplicate messages")
	_check(absf(game.modal.controls.master.value-unsaved.master)<0.001,"reentered track shows the actual unsaved in-memory value")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(game.modal),"Esc can always leave a failed-save Settings page")
	_check(game._prepare_quit(),"title quit remains available after repeated failed saves")
	_check(game.core.state==story_before,"preference failure and exits preserve existing campaign state")
	_check_sentinel("reentry and title quit readiness")
	# Enter the real first scene and its real briefing. Its existing busy guard
	# must still reject quit, regardless of the independent preference failure.
	await _click_named("NewShift")
	_check(game.view=="counter" and game.busy,"actual first-scene transition creates the campaign busy state")
	_check(not game._prepare_quit(),"campaign transition guard still rejects unsafe quit")
	await create_timer(0.72).timeout;await _click_named("FinishBriefing")
	_check(not game.busy and game.view=="counter","actual briefing advance finishes before campaign guard fixtures")
	await _key(KEY_ESCAPE);await _click_text("Settings")
	_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"actual pause control opens campaign Settings")
	_check_status("Not saved")
	_check(game._prepare_quit(),"valid campaign checkpoint can prepare quit despite failed preferences")
	_check(game.core.take_case("case01").is_empty(),"real owned mail supports the active-paper guard fixture")
	var physical:Dictionary=game.core.case_state("case01").physical.duplicate(true)
	_check(game.core.begin_operation("case01","open").is_empty(),"real Core operation begins without fabricating a completion")
	_check(not game._prepare_quit() and not game.core.state.active_operation.is_empty(),"uncheckpointed physical-paper guard remains intact")
	_check(game.core.cancel_operation(physical).is_empty(),"safe operation cancellation retains unmodified physical mail")
	var future_path:=directory+"/future-progress.json"
	var future_bytes:=JSON.stringify({"format":Core.FORMAT,"version":999,"payload_json":"future data must remain intact"}).to_utf8_buffer()
	var future:=FileAccess.open(future_path,FileAccess.WRITE);future.store_buffer(future_bytes);future.close()
	game.core.save_path=future_path
	_check(not game._prepare_quit(),"actual unknown campaign-save format still blocks unsafe overwrite/quit")
	_check(FileAccess.get_file_as_bytes(future_path)==future_bytes,"failed campaign quit preserves the original future-format bytes")
	game.core.save_path=valid_story_path
	_check(game._prepare_quit(),"restoring a valid campaign slot recovers its normal checkpoint")
	_check_sentinel("campaign and physical guard checks")
	# Recover the fixture path, then save using a real slider drag. No model
	# save helper is called to manufacture the successful UI state.
	var valid_preferences:=directory+"/recovered-preferences.json"
	game.preferences.path=valid_preferences
	await _drag_master(0.48)
	_check(not game.preferences.dirty and game.preferences.last_error.is_empty(),"actual recovered-path slider save clears the failure state")
	_check(game.modal.get_node("SettingsSaveError").text.is_empty(),"recovery removes the paper error notice")
	_check(FileAccess.file_exists(valid_preferences),"recovery writes a real preferences file")
	var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(valid_preferences))
	_check(saved is Dictionary and saved.version==1 and JSON.parse_string(JSON.stringify(saved.values))==JSON.parse_string(JSON.stringify(game.preferences.values)),"saved recovered values exactly match the retained in-memory controls")
	_check_sentinel("successful recovery")
	await _click_named("CloseSettings")
	_check(is_instance_valid(game.modal) and not game.modal.has_node("SettingsWater"),"campaign Settings returns to its existing pause mode")
	_check(game.get_node_or_null("PreferencesSaveNotice")==null,"recovery clears only the preference failure notice")
	_check(game._prepare_quit(),"recovered preferences and campaign can both safely prepare quit")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,
		"scope":"Actual Host/root.push_input sliders, language selectors, return, Esc, nested dropdown and reentry. Genuine isolated parent-sentinel filesystem failure. Direct host quit-readiness and real Core negative campaign/paper guards; no actual OS close or user-data permissions changed."},"\t"));report.close()
	game.queue_free();await process_frame;await process_frame
	print("SETTINGS SAVE FAILURE INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _check_status(expected:String)->void:
	var label:Label=game.modal.get_node("SettingsSaveError")
	_check(label.text==expected,"failed save has a localized nontechnical status "+expected)
	var glyph:Vector2=label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size"))
	_check(glyph.x<=label.size.x and glyph.y<=label.size.y,"failed-save writing fits its real status container")
	_check(not label.get_global_rect().intersects(game.modal.get_node("CloseSettings").get_global_rect()),"error status does not obstruct the available return arrow")
	_check(not label.get_global_rect().intersects(game.modal.get_node("SettingsHeading").get_global_rect()),"error status does not overlap the title lettering")
	_check(not label.text.contains("/") and not label.text.contains("ERR_") and not label.text.contains("preferences.json"),"status hides filesystem paths and technical diagnostics")
func _check_sentinel(stage:String)->void:
	_check(FileAccess.get_file_as_bytes(sentinel_path)==sentinel_bytes,"original sentinel bytes preserved after "+stage)
func _open()->void:
	await _click_named("OpenSettings");await process_frame;await process_frame
	_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"actual title control opens Settings")
func _drag_master(fraction:float)->void:
	var slider:HSlider=game.modal.controls.master
	var rectangle:=slider.get_global_rect();var from:=rectangle.get_center()
	var to:=Vector2(rectangle.position.x+rectangle.size.x*fraction,rectangle.get_center().y)
	await _button(from,true)
	var motion:=InputEventMouseMotion.new();motion.position=to;motion.global_position=to;motion.relative=to-from;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true);await process_frame;await _button(to,false)
	await create_timer(0.36).timeout
func _click_named(name:String)->void:
	var control:Control=game.find_child(name,true,false)
	_check(control!=null,"visible control "+name)
	if control==null:return
	var point:=control.get_global_rect().get_center();await _button(point,true);await _button(point,false)
func _click_text(text:String)->void:
	var control:Button=_button_text(game.modal,text)
	_check(control!=null,"actual localized pause control "+text)
	if control==null:return
	var point:=control.get_global_rect().get_center();await _button(point,true);await _button(point,false)
func _button_text(parent:Node,text:String)->Button:
	for child:Node in parent.get_children():
		if child is Button and child.text==text:return child
		var found:Button=_button_text(child,text)
		if found!=null:return found
	return null
func _button(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;root.push_input(event,true);await process_frame
func _key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true);await process_frame
func _shot(label:String)->void:
	await process_frame;RenderingServer.force_draw(false)
	var image:Image=root.get_texture().get_image();_check(image.get_size()==Vector2i(1920,1080),"full original-resolution failed-save capture "+label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path:=OUT+label+".png";_check(image.save_png(path)==OK,"save actual failed-save capture "+label);images.append(path)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
