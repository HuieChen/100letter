extends SceneTree
## Actual Host/GUI input chain. Focus loss is a simulated platform notification;
## this fixture does not claim native OS mouse or independent-player acceptance.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const OUT="res://test-results/lemon-press-gui_20261017/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();game.allow_display_changes=false
	game.preferences_path="user://qa/lemon-press-gui/"+str(Time.get_ticks_usec())+".json"
	root.add_child(game);game.size=Vector2(1600,900);await process_frame;await process_frame
	var story_before:Dictionary=game.core.state.duplicate(true)
	await _open()
	await _shot("before_1920")
	RenderingServer.force_draw(false);var before:Image=root.get_texture().get_image()
	var taps_before:int=game.modal.field.snapshot().taps
	await _down_fruit();await _step(12)
	var pressed:Dictionary=game.modal.surface.snapshot()
	_check(pressed.active_presses==1 and pressed.bodies[1].press.pressed,"actual fruit mouse down remains held")
	_check(pressed.bodies[1].press.depth>3.0 and pressed.bodies[1].press.depth<=6.0,"actual hold visibly submerges the source fruit")
	_check(game.modal.field.snapshot().taps>taps_before,"press displaces actual water from the rim")
	await _shot("held_1920")
	RenderingServer.force_draw(false);var held_image:Image=root.get_texture().get_image()
	_check(_pixel_changes(before,held_image,Rect2(1290,580,230,210))>12,"actual rendered fruit region changes while held")
	_check(_pixel_changes(before,held_image,Rect2(610,280,350,270))==0,"printed controls stay fixed during fruit press")
	await _motion(Vector2(740,385),Vector2(-666,-300),true)
	_check(game.modal.surface.snapshot().active_presses==1,"moving over paper does not silently drop the held fruit")
	await _button(Vector2(740,385),false)
	_check(game.modal.surface.snapshot().active_presses==0,"mouse up over paper releases fruit outside its hit area")
	_check(game.modal.field.snapshot().taps>taps_before+1,"release also displaces the actual water surface")
	await _step(18);await _shot("released_1920")
	await _step(65)
	var settled:Dictionary=game.modal.surface.snapshot().bodies[1].press
	_check(absf(settled.depth)<0.01 and absf(settled.velocity)<0.06,"GUI release settles the physical press spring")
	await _down_fruit();await _step(5)
	game.modal.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(is_instance_valid(game.modal) and game.modal.surface.snapshot().active_presses==0,"focus-out notification releases while preserving Settings")
	await _button(Vector2(740,385),false);await _step(7)
	await _down_fruit();await _step(5)
	game.modal.notification(Control.NOTIFICATION_WM_MOUSE_EXIT)
	_check(game.modal.surface.snapshot().active_presses==0,"leaving the window also clears held pointer capture")
	await _button(Vector2(740,385),false);await _step(7)
	var escaped:Array[bool]=[]
	game.modal.surface.lemon_press_changed.connect(func(_index:int,held:bool,_point:Vector2,_depth:float):escaped.append(held))
	await _down_fruit();await _step(5);await _key(KEY_ESCAPE)
	_check(not is_instance_valid(game.modal),"Esc closes Settings during an actual fruit hold")
	_check(escaped.size()==2 and escaped[0] and not escaped[1],"Esc releases before removing the physical world")
	await _button(Vector2(740,385),false)
	await _open()
	_check(game.modal.surface.snapshot().active_presses==0,"reentry cannot inherit the previous held pointer")
	# Keep the left mouse held and use the genuine visible language selector by
	# keyboard. The initial back-arrow focus and explicit focus loop make this
	# possible without calling rebuild/model/press helpers.
	await _down_fruit();await _step(12)
	var language_before:Dictionary=game.modal.surface.snapshot().bodies[1]
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().name=="Setting_language","keyboard reaches the visible language selector while fruit is held")
	await _key(KEY_ENTER)
	_check(game.modal.find_child("SettingsDropdown",true,false)!=null,"actual keyboard opens the language dropdown")
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().name=="Option_language_1","keyboard selects the real English language row")
	await _key(KEY_ENTER);await process_frame;await process_frame
	_check(game.preferences.values.language=="en","actual language selection changes the UI")
	var rebuilt:Dictionary=game.modal.surface.snapshot().bodies[1]
	_check(game.modal.surface.snapshot().active_presses==0,"language rebuild safely releases the old held pointer")
	_check(rebuilt.position.distance_to(language_before.position)<2.0,"language rebuild preserves ongoing native physical progress")
	_check(rebuilt.press.depth>0.1,"language rebuild preserves spring displacement while it relaxes")
	_check(rebuilt.press.release_count==language_before.press.release_count+1,"language rebuild releases exactly once")
	await _button(Vector2(740,385),false)
	_check(game.modal.surface.snapshot().active_presses==0,"late mouse up cannot resurrect capture after rebuild")
	await _step(12)
	var count_before:int=game.modal.surface.snapshot().bodies[1].press.press_count
	for _i:int in 80:
		var point:Vector2=game.modal.surface.bodies[1].position
		_send_button(point,true);_send_button(point,false)
	await _step(8)
	var burst:Dictionary=game.modal.surface.snapshot().bodies[1]
	_check(burst.press.press_count>count_before,"rapid actual GUI events include genuine physical presses")
	_check(game.modal.surface.snapshot().active_presses==0,"rapid alternating input leaves no stuck capture")
	_check(burst.press.depth<=6.0 and burst.press.depth>= -0.8 and burst.press.scale_factor>=0.96,"rapid GUI pressure stays visually bounded")
	_check(burst.velocity.length()<=55.01 and absf(burst.spin)<=0.1301,"rapid GUI pressure retains native momentum bounds")
	await _key(KEY_ESCAPE);await _button(Vector2(740,385),false)
	await _open()
	var arrow_events:Array[bool]=[]
	game.modal.surface.lemon_press_changed.connect(func(_index:int,held:bool,_point:Vector2,_depth:float):arrow_events.append(held))
	await _down_fruit();await _step(8)
	_check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().name=="CloseSettings","visible return arrow remains an available focused exit")
	await _key(KEY_ENTER)
	_check(not is_instance_valid(game.modal),"visible return arrow closes while fruit is held")
	_check(arrow_events.size()==2 and not arrow_events.back(),"return arrow releases before close")
	await _button(Vector2(740,385),false)
	await _open()
	_check(game.modal.surface.snapshot().active_presses==0,"second reentry is free of orphaned captures")
	await _down_fruit();await _step(5);await _button(Vector2(1400,330),false)
	_check(game.modal.surface.snapshot().active_presses==0,"reentered page accepts a full fresh press and outside-water release")
	await _click_named("CloseSettings")
	_check(game.core.state==story_before,"Settings pressure and exits preserve original game progress")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,"scope":"Automated actual Host root.push_input and GPU render. Focus/mouse-exit notification is simulated. No native OS or novice acceptance claim."},"\t"));report.close()
	game.queue_free();await process_frame;await process_frame
	print("LEMON PRESS GUI INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _open()->void:
	await _click_named("OpenSettings");await _step(6)
	_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"actual title control opens Settings")
func _down_fruit()->void:
	var point:Vector2=game.modal.surface.bodies[1].position
	await _motion(point,Vector2.ZERO,false)
	_check(game.modal.get_node("SettingsWater").mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"fruit hover advertises its real interaction")
	await _button(point,true)
func _click_named(name:String)->void:
	var control:Control=game.find_child(name,true,false)
	_check(control!=null,"visible control "+name)
	if control==null:return
	var point:=control.get_global_rect().get_center()
	await _button(point,true);await _button(point,false)
func _send_button(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down
	root.push_input(event,true)
func _button(point:Vector2,down:bool)->void:
	_send_button(point,down);await process_frame
func _motion(point:Vector2,relative:Vector2,held:bool)->void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(event,true);await process_frame
func _key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		root.push_input(event,true);await process_frame
func _step(frames:int)->void:
	for _i:int in frames:await physics_frame;await process_frame
func _shot(label:String)->void:
	await process_frame;RenderingServer.force_draw(false)
	var image:Image=root.get_texture().get_image()
	_check(image.get_size()==Vector2i(1920,1080),"native-resolution capture "+label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path:=OUT+label+".png";_check(image.save_png(path)==OK,"save actual capture "+label);images.append(path)
func _pixel_changes(before:Image,after:Image,rect:Rect2)->int:
	var scale:=Vector2(before.get_size())/Vector2(1600,900);var changed:=0
	for y:int in range(int(rect.position.y*scale.y),int(rect.end.y*scale.y),3):
		for x:int in range(int(rect.position.x*scale.x),int(rect.end.x*scale.x),3):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255.0:changed+=1
	return changed
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
