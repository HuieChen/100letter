extends SceneTree
## GPU/native-Window component regression. The headless backend ignores native
## FLAG_NO_FOCUS; it cannot prove this behavior. Pointer events and late focus
## notifications below are synthetic, not a human Alt-Tab or usability result.
const Walker=preload("res://scripts/rebuild/final_walker.gd")
var walker:Control
var hotspot:Button
var callbacks:Array[String]=[]
var arrivals:=0
var pointer_requests:=0
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var original_unfocusable:bool=root.unfocusable
	root.unfocusable=true;root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_check(DisplayServer.get_name()!="headless","a real display backend is required for native Window focus flags")
	_check(root.unfocusable,"actual root Window retains FLAG_NO_FOCUS")
	_check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id()),"native display server confirms the no-focus Window flag")
	walker=Walker.new();root.add_child(walker);walker.size=Vector2(1600,900)
	_check(walker._window_focused==root.has_focus(),"new courier reads actual native Window focus rather than assuming it")
	walker.arrived.connect(func():arrivals+=1)
	hotspot=Button.new();hotspot.name="PointerSource";hotspot.text="Source";root.add_child(hotspot);hotspot.position=Vector2(820,250);hotspot.size=Vector2(100,80)
	hotspot.pressed.connect(func():
		pointer_requests+=1
		walker.walk_to(Vector2(500,310),func():callbacks.append("pointer_without_focus")))
	await _test_unfocusable_pointer()
	root.unfocusable=original_unfocusable
	_check(root.unfocusable==original_unfocusable,"fixture restores the original Window focus policy")
	walker.queue_free();hotspot.queue_free();await process_frame
	print("POINTER WINDOW FOCUS: %d checks / %d failures; native flags, routed synthetic pointer, simulated late notifications"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func _test_unfocusable_pointer()->void:
	var previous_unfocusable:bool=root.unfocusable
	var previous_manual_enabled:bool=walker.manual_enabled
	root.unfocusable=true
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	walker.configure(null,Rect2(40,170,900,230),Vector2(120,300))
	walker.manual_enabled=true
	var completed_before:int=callbacks.count("pointer_without_focus")
	var arrivals_before:int=arrivals
	var point:Vector2=hotspot.get_global_rect().get_center()
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
	_check(pointer_requests==1,"one actual hotspot click dispatches exactly one mouse approach")
	for index:int in 8:walker._process(1.0/60.0)
	var moving_foot:Vector2=walker.foot
	_check(root.unfocusable and walker.walking and moving_foot.x>120.0,"actual non-focusable Window accepts an ordinary pending pointer approach")
	# This delayed notification must preserve the original routed action. Never
	# retry the hotspot or substitute a new callback after focus loss.
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not walker._window_focused and walker.walking and walker._pending_action.is_valid() and walker.target==Vector2(500,310),"late focus-out preserves the mouse destination and original action")
	_key(KEY_D,true);walker._process(0.1)
	_check(walker.walking and not walker._manual_active and walker._pending_action.is_valid(),"keys held in another application cannot interrupt a non-focusable pointer route")
	_key(KEY_D,false)
	_finish_walk()
	_check(callbacks.count("pointer_without_focus")==completed_before+1 and arrivals==arrivals_before+1 and walker.foot==Vector2(500,310),"unfocused pointer approach reaches the requested place and invokes its original action once")
	walker._process(0.5)
	_check(callbacks.count("pointer_without_focus")==completed_before+1 and not walker._pending_action.is_valid(),"extra unfocused frames do not repeat a finished source action")
	# A real keyboard move remains cancellable if native Window policy changes.
	root.unfocusable=false
	_check(not root.unfocusable and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id()),"native display server actually changes back to a focusable Window")
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_key(KEY_D,true);walker._process(0.1)
	_check(walker._manual_active and walker.velocity.length()>0.0,"manual movement is active before switching Window focus policy")
	root.unfocusable=true
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var stopped:Vector2=walker.foot
	walker._process(0.2)
	_check(not walker._manual_active and not walker.walking and walker.foot==stopped and walker.velocity==Vector2.ZERO,"focus-out always cancels active keyboard movement, including a non-focusable Window")
	_key(KEY_D,false)
	root.unfocusable=previous_unfocusable
	walker.manual_enabled=previous_manual_enabled
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
func _key(code:Key,pressed:bool)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func _finish_walk()->void:
	for index:int in 1200:
		walker._process(1.0/60.0)
		if not walker.walking:break
	_check(not walker.walking,"single accepted pointer journey converges without a stuck target")
func _check(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS "+label)
	else:failures.append(label);push_error(label)
