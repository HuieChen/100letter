extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const SETTLE_FRAME_LIMIT:=30
const RESOLUTIONS:=["auto","1280x720","1600x900","1920x1080"]
# Count the real inherited application method, rather than replacing its behavior.
class DisplayProbe:
	extends Host
	var display_apply_count:=0
	func _apply_display_preferences()->void:
		display_apply_count+=1
		super._apply_display_preferences()
var game:Control
var checks:=0
var failures:Array[String]=[]
var input_diagnostics:Array[Dictionary]=[]
var window_diagnostics:Array[Dictionary]=[]
var settle_diagnostics:Array[Dictionary]=[]
var _pending_render_diagnostics:Array[Dictionary]=[]
var _render_serial:=0
var _input_serial:=0
var _observed_button_capture_id:=0
var _context:="initial setup"
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# Passive diagnostics preserve the original first-click timing. The draw
	# observer never injects input, retries a click or adds a settling delay.
	RenderingServer.frame_post_draw.connect(_record_render_boundary)
	for event_name:String in ["focus_entered","focus_exited","mouse_entered","mouse_exited","size_changed"]:
		if root.has_signal(event_name):root.connect(event_name,_record_window_event.bind(event_name))
	game=DisplayProbe.new();game.preferences_path="user://qa/display/"+str(Time.get_ticks_usec())+".json";root.add_child(game);game.size=Vector2(1600,900)
	game._settings_page();await process_frame
	game.preferences.changed.connect(_observe_display_request)
	var startup_flag:bool=bool(ProjectSettings.get_setting("display/window/size/no_focus",false)) and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id()) and root.unfocusable
	_check(startup_flag,"QA startup override created the actual native pointer-only Window before input")
	if not startup_flag:
		await _finish_fixture();return
	if not await _wait_display("startup native pointer-only state before first pointer input"):
		await _finish_fixture();return
	for item:int in [1,2,3,0]:
		_context="initial resolution "+str(item)
		await _choose("resolution",item,4);await _wait_display("initial resolution "+str(item))
		var resolution:String=RESOLUTIONS[item]
		_check(game.preferences.values.resolution==resolution,"actual selection "+resolution)
		_check(root.content_scale_mode==(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if item==0 else Window.CONTENT_SCALE_MODE_VIEWPORT),"real viewport mode "+resolution)
		if item>0:
			var parts:=resolution.split("x");var pixels:=Vector2i(int(parts[0]),int(parts[1]))
			_check(root.get_texture().get_size()==Vector2(pixels),"actual rendered resolution "+resolution)
		else:_check(game.scale==Vector2.ONE,"Auto restores authored canvas without doubled scaling")
	# The first click after a completed native transition must work. There are no
	# click retries, direct popup calls or fixed-duration sleeps in this regression.
	for cycle:int in 12:
		_context="cycle %d resolution"%cycle
		await _choose("resolution",cycle%4,4);await _wait_display("cycle %d resolution"%cycle)
		_context="cycle %d language"%cycle
		await _choose("language",cycle%2,2);await _wait_display("cycle %d localized rebuild"%cycle)
		var borderless:bool=cycle%2==0
		_context="cycle %d decoration selection"%cycle
		await _choose("display_mode",2 if borderless else 0,3)
		await _wait_display("cycle %d decoration"%cycle)
		_check(root.borderless==borderless and root.mode==Window.MODE_WINDOWED,"actual borderless window flag" if borderless else "actual windowed restores border")
		var parser:=JSON.new();var parse_error:int=parser.parse(FileAccess.get_file_as_string(game.preferences.path))
		_check(parse_error==OK and parser.data is Dictionary and parser.data.get("values",{}).get("display_mode","")==("borderless" if borderless else "windowed"),"cycle %d displayed mode agrees with saved preference"%cycle)
		# Reopen on the first settled frame, then dismiss with the visible outside
		# area. The next cycle must not inherit an invisible dropdown blocker.
		_context="cycle %d first reopen after decoration"%cycle
		await _click("Setting_display_mode");_check_dropdown("display_mode",3)
		_context="cycle %d outside dismissal"%cycle
		await _click_point(Vector2(80,450)*game.scale)
		_check(_dropdown_count()==0,"cycle %d outside click removes the dropdown"%cycle)
	# Multiple changes in one input turn must use the final model once. This is
	# separate from the 12 genuine pointer-operated transitions above.
	_context="coalescing baseline"
	await _choose("resolution",0,4);await _wait_display("coalescing baseline")
	var applied_before:int=game.display_apply_count
	var size_before:Vector2i=root.size
	game.preferences.set_value("display_mode","borderless")
	game.preferences.set_value("resolution","1280x720")
	game.preferences.set_value("display_mode","windowed")
	game.preferences.set_value("resolution","1920x1080")
	game.preferences.set_value("display_mode","borderless")
	_check(game._display_apply_queued and game.display_apply_count==applied_before,"same-turn display changes queue one deferred application")
	_check(not root.borderless and root.size==size_before,"native decoration and size stay intact during the requesting turn")
	await _wait_display("coalesced latest state")
	_check(game.display_apply_count==applied_before+1,"coalesced changes apply the actual native method exactly once")
	_check(root.borderless and root.content_scale_size==Vector2i(1920,1080),"coalesced application reads the latest display and resolution")
	_context="first reopen after coalesced display"
	await _click("Setting_display_mode");_check_dropdown("display_mode",3)
	await _click("Option_display_mode_0");await _wait_display("final bordered window")
	await _click("CloseSettings")
	_check(not is_instance_valid(game.modal),"visible close survives repeated render-resolution changes")
	await _finish_fixture()
func _finish_fixture()->void:
	if is_instance_valid(game):game.queue_free()
	await process_frame;await process_frame
	RenderingServer.frame_post_draw.disconnect(_record_render_boundary)
	var diagnostic_path:="res://test-results/display-diagnostics_20261017/run-"+str(Time.get_ticks_usec())+".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/display-diagnostics_20261017"))
	var diagnostic_file:=FileAccess.open(diagnostic_path,FileAccess.WRITE)
	diagnostic_file.store_string(JSON.stringify({"scope":"One-shot input in an explicitly pointer-only GPU fixture; startup and transitions require the actual native unfocused state within the original 30-frame bound. No click retries, OS input injection or production focus changes. Viewport mouse capture is private, so observed_button_capture_id is inferred solely from actual button_down/up signals, never asserted as native capture.","startup_method":"Owned temporary QA override.cfg sets display/window/size/no_focus before native root Window creation; production project.godot is unchanged.","startup_no_focus_setting":ProjectSettings.get_setting("display/window/size/no_focus",false),"checks":checks,"failures":failures,"clicks":input_diagnostics,"window_events":window_diagnostics,"settles":settle_diagnostics,"pending_render_observations":_pending_render_diagnostics.size()}));diagnostic_file.close()
	print("DISPLAY_INPUT_DIAGNOSTICS saved ",diagnostic_path)
	print("DISPLAY PREFERENCES: ",checks," checks / ",failures.size()," failures; fullscreen remains native-only")
	quit(0 if failures.is_empty() else 1)
func _click(name:String)->void:
	var c:Control=game.find_child(name,true,false);_check(c!=null,"actual control "+name)
	if c==null:return
	var emitted:Array[bool]=[false]
	var point:Vector2=c.get_global_rect().get_center()
	var target_ref:WeakRef=weakref(c)
	var trace:Dictionary=_new_click_trace(name,point)
	var observer:Callable=func():emitted[0]=true;_record_button_signal(trace,target_ref,point,"pressed")
	var down_observer:Callable=_record_button_signal.bind(trace,target_ref,point,"button_down")
	var up_observer:Callable=_record_button_signal.bind(trace,target_ref,point,"button_up")
	var enter_observer:Callable=_record_button_signal.bind(trace,target_ref,point,"mouse_entered")
	var exit_observer:Callable=_record_button_signal.bind(trace,target_ref,point,"mouse_exited")
	var gui_observer:Callable=_record_gui_event.bind(trace,target_ref,point)
	if c is Button:
		c.pressed.connect(observer);c.button_down.connect(down_observer);c.button_up.connect(up_observer)
	c.mouse_entered.connect(enter_observer);c.mouse_exited.connect(exit_observer);c.gui_input.connect(gui_observer)
	await _click_point(point,target_ref,trace)
	if is_instance_valid(c):
		if c is Button:
			if c.pressed.is_connected(observer):c.pressed.disconnect(observer)
			if c.button_down.is_connected(down_observer):c.button_down.disconnect(down_observer)
			if c.button_up.is_connected(up_observer):c.button_up.disconnect(up_observer)
		if c.mouse_entered.is_connected(enter_observer):c.mouse_entered.disconnect(enter_observer)
		if c.mouse_exited.is_connected(exit_observer):c.mouse_exited.disconnect(exit_observer)
		if c.gui_input.is_connected(gui_observer):c.gui_input.disconnect(gui_observer)
	_check(emitted[0],"first pointer release dispatches "+name)
	print("DISPLAY_BUTTON_SIGNALS ",JSON.stringify({"control":name,"context":_context,"signals":trace.signals,"first_release_emitted":emitted[0],"render_serial":_render_serial}))
	if not emitted[0]:print("DISPLAY_INPUT_MISS control=",name," geometry=",str(_geometry_state())," trace=",JSON.stringify(trace))
func _click_point(point:Vector2,target_ref:WeakRef=null,trace:Dictionary={})->void:
	if trace.is_empty():trace=_new_click_trace("outside point",point)
	for down:bool in [true,false]:
		_input_serial+=1
		var phase:="down" if down else "up"
		_record_input_snapshot(trace,target_ref,point,"before_"+phase,_input_serial)
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
		_record_input_snapshot(trace,target_ref,point,"after_dispatch_"+phase,_input_serial)
		_pending_render_diagnostics.append({"trace":trace,"target_ref":target_ref,"point":point,"phase":phase,"input_serial":_input_serial})
		await process_frame
		_record_input_snapshot(trace,target_ref,point,"after_process_frame_"+phase,_input_serial)
func _new_click_trace(name:String,point:Vector2)->Dictionary:
	var trace:={"control":name,"context":_context,"input_point":str(point),"signals":{"button_down":0,"button_up":0,"pressed":0,"mouse_entered":0,"mouse_exited":0},"observations":[]}
	input_diagnostics.append(trace);return trace
func _record_button_signal(trace:Dictionary,target_ref:WeakRef,point:Vector2,event_name:String)->void:
	trace.signals[event_name]+=1
	var target:Control=target_ref.get_ref() as Control
	if event_name=="button_down" and is_instance_valid(target):_observed_button_capture_id=target.get_instance_id()
	elif event_name=="button_up" and is_instance_valid(target) and _observed_button_capture_id==target.get_instance_id():_observed_button_capture_id=0
	_record_input_snapshot(trace,target_ref,point,"signal_"+event_name,_input_serial)
func _record_gui_event(event:InputEvent,trace:Dictionary,target_ref:WeakRef,point:Vector2)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var snapshot:Dictionary=_input_snapshot(target_ref,point)
		snapshot.phase="target_gui_input_down" if event.pressed else "target_gui_input_up"
		snapshot.input_serial=_input_serial;snapshot.delivered_local_position=str(event.position)
		trace.observations.append(snapshot)
func _record_input_snapshot(trace:Dictionary,target_ref:WeakRef,point:Vector2,phase:String,serial:int)->void:
	var snapshot:Dictionary=_input_snapshot(target_ref,point)
	snapshot.phase=phase;snapshot.input_serial=serial;trace.observations.append(snapshot)
func _control_identity(control:Control)->Dictionary:
	if not is_instance_valid(control):return {}
	var state:={"name":str(control.name),"instance":control.get_instance_id(),"inside_tree":control.is_inside_tree(),"queued_for_deletion":control.is_queued_for_deletion(),"rect":str(control.get_global_rect()),"mouse_filter":control.mouse_filter}
	if control.is_inside_tree():state.path=str(control.get_path());state.visible=control.is_visible_in_tree()
	if control is BaseButton:state.button_live_pressed=control.is_pressed();state.button_hovered=control.is_hovered();state.disabled=control.disabled;state.draw_mode=control.get_draw_mode()
	return state
func _input_snapshot(target_ref:WeakRef,point:Vector2)->Dictionary:
	var target:Control=target_ref.get_ref() as Control if target_ref!=null else null
	return {"wall_us":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames(),"render_serial":_render_serial,"latest_dispatched_input":_input_serial,"target":_control_identity(target),"input_inside_current_rect":target.get_global_rect().has_point(point) if is_instance_valid(target) else false,"hovered":_control_identity(root.gui_get_hovered_control()),"keyboard_focus":_control_identity(root.gui_get_focus_owner()),"observed_button_capture_id":_observed_button_capture_id,"mouse_capture_scope":"button_down/up observation only; no public Viewport mouse-capture getter","viewport_mouse":str(root.get_mouse_position()),"window_focus":root.has_focus(),"unfocusable":root.unfocusable,"mouse_button_global_state":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"client":str(DisplayServer.window_get_size(root.get_window_id())),"window":str(root.size),"canvas":str(root.content_scale_size),"final_transform":str(root.get_final_transform()),"stretch_transform":str(root.get_stretch_transform()),"game_scale":str(game.scale) if is_instance_valid(game) else "freed","display_apply_pending":game._display_apply_queued if is_instance_valid(game) else false,"dropdowns":_dropdown_count() if is_instance_valid(game) else 0}
func _record_render_boundary()->void:
	_render_serial+=1
	var pending:Array[Dictionary]=_pending_render_diagnostics
	_pending_render_diagnostics=[]
	for observation:Dictionary in pending:
		_record_input_snapshot(observation.trace,observation.target_ref,observation.point,"after_frame_post_draw_"+str(observation.phase),observation.input_serial)
func _record_window_event(event_name:String)->void:
	var state:Dictionary=_input_snapshot(null,root.get_mouse_position());state.window_event=event_name;state.context=_context
	window_diagnostics.append(state)
func _choose(key:String,index:int,option_count:int)->void:
	await _click("Setting_"+key)
	_check_dropdown(key,option_count)
	await _click("Option_"+key+"_"+str(index))
func _dropdown_count()->int:
	return game.find_children("SettingsDropdown","",true,false).size()
func _check_dropdown(key:String,option_count:int)->void:
	_check(_dropdown_count()==1,"first click opens exactly one "+key+" dropdown")
	if _dropdown_count()!=1:print("DISPLAY_DROPDOWN_MISS key=",key," geometry=",str(_geometry_state()))
	for index:int in option_count:
		var row:Button=game.find_child("Option_"+key+"_"+str(index),true,false)
		_check(row!=null and row.is_visible_in_tree() and not row.disabled,"first-click dropdown exposes usable "+key+" option "+str(index))
func _observe_display_request(key:String,_value:Variant)->void:
	if key in ["display_mode","resolution"]:
		_check(_dropdown_count()==0,"dropdown teardown precedes the "+key+" preference signal")
func _geometry_state()->Dictionary:
	var choice:Control=game.find_child("Setting_display_mode",true,false)
	# Texture metadata is affected by canvas stretch in this engine; inspect the
	# actual decoded render target pixels, not its logical get_size() dimensions.
	return {"mode":root.mode,"borderless":root.borderless,"client":DisplayServer.window_get_size(root.get_window_id()),"window":root.size,"canvas_mode":root.content_scale_mode,"canvas":root.content_scale_size,"render":Vector2(root.get_texture().get_image().get_size()),"reported_texture_size":root.get_texture().get_size(),"scale":game.scale,"button":choice.get_global_rect() if choice!=null else Rect2(),"button_instance":choice.get_instance_id() if choice!=null else 0,"pending":game._display_apply_queued,"window_focused":root.has_focus(),"pointer_only":root.unfocusable}
func _geometry_matches(state:Dictionary)->bool:
	var mode:String=game.preferences.values.display_mode
	var resolution:String=game.preferences.values.resolution
	# This fixture declares a pointer-only native Window. No-focus flags alone
	# do not prove its startup focus has actually left: wait for the observable
	# state, so a delayed native focus-out cannot invalidate the next click.
	# Ordinary focusable gameplay must still cancel input on real focus loss.
	if not state.pointer_only or state.window_focused:return false
	if state.pending or _dropdown_count()!=0 or state.mode!=Window.MODE_WINDOWED or state.borderless!=(mode=="borderless"):return false
	var rect:Rect2=state.button
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<=0 or rect.size.y<=0:return false
	var area:Vector2i=DisplayServer.screen_get_usable_rect(root.current_screen).size
	var expected_window:Vector2i
	var expected_canvas:Vector2i
	var expected_render:Vector2
	var expected_scale:Vector2
	if resolution=="auto":
		var width:int=mini(1280,maxi(960,area.x-40));expected_window=Vector2i(width,int(width*9.0/16.0))
		expected_canvas=Vector2i(1600,900);expected_render=Vector2(expected_window);expected_scale=Vector2.ONE
		if state.canvas_mode!=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:return false
	else:
		var parts:PackedStringArray=resolution.split("x");expected_canvas=Vector2i(int(parts[0]),int(parts[1]))
		var factor:float=minf(1.0,minf(float(area.x-40)/expected_canvas.x,float(area.y-60)/expected_canvas.y))
		expected_window=Vector2i(Vector2(expected_canvas)*factor);expected_render=Vector2(expected_canvas);expected_scale=Vector2(expected_canvas)/Vector2(1600,900)
		if state.canvas_mode!=Window.CONTENT_SCALE_MODE_VIEWPORT:return false
	return state.client==expected_window and state.window==expected_window and state.canvas==expected_canvas and state.render==expected_render and state.scale==expected_scale
func _wait_display(label:String)->bool:
	# Wait for actual requested geometry and a stable rendered control transform;
	# a bounded failure reports evidence rather than silently sleeping longer.
	var previous:Dictionary={}
	var latest:Dictionary={}
	for frame:int in SETTLE_FRAME_LIMIT:
		await process_frame
		latest=_geometry_state()
		settle_diagnostics.append({"context":label,"attempt_frame":frame,"process_frame":Engine.get_process_frames(),"render_serial":_render_serial,"wall_us":Time.get_ticks_usec(),"geometry_matches":_geometry_matches(latest),"geometry_equals_previous":latest==previous,"pointer_only_native_ready":latest.pointer_only and not latest.window_focused,"readiness_reason":"pointer-only fixture still has native startup focus" if latest.pointer_only and latest.window_focused else ("fixture is not a pointer-only native Window" if not latest.pointer_only else "native pointer-only focus precondition satisfied; geometry gate applies"),"input_state":_input_snapshot(null,root.get_mouse_position())})
		if _geometry_matches(latest) and latest==previous:
			_check(true,"bounded native/render geometry settles: "+label)
			return true
		previous=latest
	_check(false,"display did not settle within %d frames: %s; last=%s"%[SETTLE_FRAME_LIMIT,label,str(latest)])
	print("DISPLAY_RENDER_DIAGNOSTIC image=",root.get_texture().get_image().get_size()," visible=",root.get_visible_rect()," factor=",root.content_scale_factor," stretch=",root.get_stretch_transform()," screen=",root.get_screen_transform())
	return false
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
