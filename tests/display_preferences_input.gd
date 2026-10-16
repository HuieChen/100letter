extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();game.preferences_path="user://qa/display/"+str(Time.get_ticks_usec())+".json";root.add_child(game);game.size=Vector2(1600,900)
	game._settings_page();await process_frame
	for item:int in [1,2,3,0]:
		await _click("Setting_resolution");await _click("Option_resolution_"+str(item));await process_frame;await process_frame
		var resolution:String=["auto","1280x720","1600x900","1920x1080"][item]
		_check(game.preferences.values.resolution==resolution,"actual selection "+resolution)
		_check(root.content_scale_mode==(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if item==0 else Window.CONTENT_SCALE_MODE_VIEWPORT),"real viewport mode "+resolution)
		if item>0:
			var parts:=resolution.split("x");var pixels:=Vector2i(int(parts[0]),int(parts[1]))
			_check(root.get_texture().get_size()==Vector2(pixels),"actual rendered resolution "+resolution)
		else:_check(game.scale==Vector2.ONE,"Auto restores authored canvas without doubled scaling")
	await _click("Setting_display_mode");await _click("Option_display_mode_2")
	_check(root.borderless and root.mode==Window.MODE_WINDOWED,"actual borderless window flag")
	await _click("Setting_display_mode");await _click("Option_display_mode_0")
	_check(not root.borderless and root.mode==Window.MODE_WINDOWED,"actual windowed restores border")
	await _click("CloseSettings")
	_check(not is_instance_valid(game.modal),"visible close survives repeated render-resolution changes")
	game.queue_free();await process_frame;await process_frame
	print("DISPLAY PREFERENCES: ",checks," checks / ",failures.size()," failures; fullscreen remains native-only")
	quit(0 if failures.is_empty() else 1)
func _click(name:String)->void:
	var c:Control=game.find_child(name,true,false);_check(c!=null,"actual control "+name)
	if c==null:return
	var point:=c.get_global_rect().get_center()
	for down:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
