extends SceneTree
## Isolated public-API fixtures plus genuine GUI clicks; not a complete player route.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Core=preload("res://scripts/rebuild/final_case_state.gd")
const OUT="res://test-results/final-host-boundary/"
var dimensions:=Vector2i(1280,720)
var observations:Array[Dictionary]=[]
var screen_rects:Array[Rect2i]=[]
var dispatch_depth:=0
var audit_armed:=false
var input_audit:Array[Dictionary]=[]
var input_audit_dropped:=0
var unrouted_presses:=0
var unrouted_pair_motions:=0
var active_pair:=""
var active_button:BaseButton
var initial_hashes:Dictionary={}
class InputAudit:
	extends Node
	var fixture:SceneTree
	func _input(event:InputEvent)->void:fixture.call("_audit_input",event)
var game:Control
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	initial_hashes=_hashes()
	var startup:bool=bool(ProjectSettings.get_setting("display/window/size/no_focus",false)) and root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,root.get_window_id())
	_check(startup,"actual boundary fixture starts with QA no-focus flag before Host/input")
	if not startup:await _finish();return
	var audit:=InputAudit.new();audit.fixture=self;root.add_child(audit)
	for screen:int in DisplayServer.get_screen_count():screen_rects.append(Rect2i(DisplayServer.screen_get_position(screen),DisplayServer.screen_get_size(screen)))
	_check(not screen_rects.is_empty(),"actual DisplayServer supplies screen rectangles for boundary QA")
	if screen_rects.is_empty():await _finish();return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	observations.append({"phase":"native_window_before_host","window":_window_snapshot()})
	game=Host.new();game.allow_display_changes=false
	# This fixture tests custody/host boundaries, not saved display settings.
	# Never inherit another suite's shared preferences into its logical canvas.
	game.preferences_path="user://qa/host-boundary-"+str(Time.get_ticks_usec())+"/preferences.json"
	root.add_child(game);game.size=Vector2(1600,900)
	await process_frame;await process_frame;await process_frame
	observations.append({"phase":"native_window_after_host_before_position","window":_window_snapshot()})
	if not await _position_after_host():await _finish();return
	audit_armed=true
	var slot:="user://qa/host-boundary-"+str(Time.get_ticks_usec())+".json"
	game.core.save_path=slot;game.core.new_game()
	_ok(game.core.take_case("case01"),"fixture physically owned first letter")
	_ok(game.core.inspect_envelope("case01","front"),"fixture read first envelope")
	_ok(game.core.dispose("case01","hold_for_verification","","未核实旧地址，留待当班查证。"),"fixture legitimate first disposition")
	var record:={"determination":{"recipient":"待核实","location":"邮局","status":"留待核实"},"disposition":"hold_for_verification","note":"保留原记录","stamped":true}
	_ok(game.core.record_resolution("case01",record),"fixture real first resolution unlocks next mail")
	game._counter();game._registry();await process_frame
	var before:=JSON.stringify(game.core.state)
	await _click("Register_case02")
	_check(game.core.case_state("case02").owner=="desk_b","registry cannot take a letter through text")
	_check(JSON.stringify(game.core.state)==before,"blocked registry leaves custody and all core progress unchanged")
	_check(game.view=="counter" and not is_instance_valid(game.modal),"blocked registration returns to actual physical box")
	game._workbench("case02")
	_check(not is_instance_valid(game.modal) and game.core.case_state("case02").owner=="desk_b","direct workbench entry cannot substitute for real box pickup")
	game._bag();await process_frame
	_check(game.find_child("Envelope_case02",true,false)==null,"bag has no uncollected letter")
	game._close();game._registry();await process_frame
	await _click("RecordedResolution_case01")
	_check(_count_editors(game.modal)==0,"completed resolution is a read-only paper")
	_check(game.core.resolution_view("case01").note=="保留原记录","reading cannot overwrite stamped content")
	game._close()
	_ok(game.core.take_case("case02"),"fixture courier owns a second actual object")
	game._bag();await process_frame;await _click("Envelope_case02")
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=Vector2(1495,60);e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		dispatch_depth+=1;root.push_input(e,true);dispatch_depth-=1;await process_frame
	await create_timer(0.22).timeout
	_check(not is_instance_valid(game.modal),"actual envelope inspection closes before onward journey")
	_ok(game.core.travel("community_center",15),"fixture reaches real cubby location")
	game._world();await process_frame
	await _click("MailCubby")
	for i in range(700):
		if not game.walker.walking:break
		await process_frame
	_check(game.core.case_state("case02").disposition=="" and game.core.case_state("case02").owner=="courier","cubby never impersonates a person for another mail type")
	_check(game.carried=="case02","rejected cubby leaves the same physical letter in hand")
	game._title()
	var future_path:=slot+".future"
	var future:=JSON.stringify({"format":Core.FORMAT,"version":999,"payload_json":"future data retained"})
	var f:=FileAccess.open(future_path,FileAccess.WRITE);f.store_string(future);f.close()
	game.core.save_path=future_path
	await _click("NewShift")
	_check(game.view=="title" and not game._briefing_pending,"unwritable future slot does not start an unsavable shift")
	_check(is_instance_valid(game.modal) and _text(game.modal).contains("暂时无法开始"),"new-shift save failure is visibly explained")
	_check(FileAccess.get_file_as_string(future_path)==future,"future save bytes are preserved exactly")
	game._close();game.core.save_path=slot;game.core.new_game()
	_ok(game.core.take_case("case01"),"fixture owned paper for exit integration")
	game._counter();game._workbench("case01");await process_frame
	var bench:Control=game.modal
	_check(bench.has_method("checkpoint_for_quit"),"hosted workbench exposes stable quit checkpoint")
	_check(game._prepare_quit(),"host quit preparation persists actual physical component")
	var loaded:=Core.new();root.add_child(loaded);loaded.save_path=slot
	_check(loaded.load_game() and loaded.case_state("case01").owner=="courier","quit preparation can resume the same object from disk")
	game.core.save_path=future_path
	_check(not game._prepare_quit(),"window close is blocked when safe checkpoint cannot write")
	_check(game.modal==bench and is_instance_valid(bench),"failed close keeps the current workbench visible")
	_check(game.find_child("SaveFailureNotice",true,false)!=null,"failed close has a visible persistent explanation")
	_check(FileAccess.get_file_as_string(future_path)==future,"failed quit never downgrades an unknown save")
	await _finish(loaded)
func _click(name:String)->void:
	var c:Control=game.find_child(name,true,false);_check(c!=null,"real input target "+name)
	if c==null:return
	var window:=_window_snapshot()
	var isolated:bool=window.offscreen and window.expected_client_size and window.no_focus and not window.mouse_passthrough
	_check(isolated,"actual native client remains outside every screen before "+name)
	if not isolated:observations.append({"phase":"blocked_by_window_geometry","name":name,"window":window});return
	var button:=c as BaseButton
	_check(button!=null,"named GUI target is an actual BaseButton "+name)
	if button==null:return
	var counts:Dictionary={"down":0,"up":0,"pressed":0,"focus_out":0}
	var trace:Array[Dictionary]=[{"event":"before_first_pair","button":_button_state(button if is_instance_valid(button) else null)}]
	var down_signal:Callable=func():counts.down+=1;trace.append({"event":"button_down","button":_button_state(button if is_instance_valid(button) else null)})
	var up_signal:Callable=func():counts.up+=1;trace.append({"event":"button_up","button":_button_state(button if is_instance_valid(button) else null)})
	var pressed_signal:Callable=func():counts.pressed+=1;trace.append({"event":"pressed","button":_button_state(button if is_instance_valid(button) else null)})
	var focus_signal:Callable=func():counts.focus_out+=1;trace.append({"event":"native_focus_out","button":_button_state(button if is_instance_valid(button) else null)})
	var entered:Callable=func():trace.append({"event":"mouse_entered","button":_button_state(button if is_instance_valid(button) else null)})
	var exited:Callable=func():trace.append({"event":"mouse_exited","button":_button_state(button if is_instance_valid(button) else null)})
	button.button_down.connect(down_signal);button.button_up.connect(up_signal);button.pressed.connect(pressed_signal);root.focus_exited.connect(focus_signal)
	button.mouse_entered.connect(entered);button.mouse_exited.connect(exited)
	var point:=c.get_global_rect().get_center();var before:=_host_snapshot()
	active_pair=name;active_button=button
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		dispatch_depth+=1;root.push_input(e,true);dispatch_depth-=1;await process_frame
	trace.append({"event":"after_first_pair","button":_button_state(button if is_instance_valid(button) else null)})
	active_pair="";active_button=null
	observations.append({"phase":"actual_named_button","name":name,"point":point,"counts":counts.duplicate(),"trace":trace,"host_before":before,"host_after":_host_snapshot(),"window_after":_window_snapshot()})
	if is_instance_valid(button):
		button.button_down.disconnect(down_signal);button.button_up.disconnect(up_signal);button.pressed.disconnect(pressed_signal);button.mouse_entered.disconnect(entered);button.mouse_exited.disconnect(exited)
	root.focus_exited.disconnect(focus_signal)
	_check(counts.pressed==1,"original first down/up pair activates actual "+name+" once: "+JSON.stringify(counts))
func _count_editors(node:Node)->int:
	var n:=1 if node is LineEdit or node is TextEdit else 0
	for child in node.get_children():n+=_count_editors(child)
	return n
func _text(node:Node)->String:
	var s:=str(node.text) if node is Label or node is RichTextLabel else ""
	for child in node.get_children():s+=_text(child)
	return s
func _ok(error:String,label:String)->void:_check(error.is_empty(),label+": "+error)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _window_snapshot()->Dictionary:
	var id:int=root.get_window_id();var position:Vector2i=DisplayServer.window_get_position(id);var size:Vector2i=DisplayServer.window_get_size(id)
	var rectangle:=Rect2i(position,size);var outside:bool=not screen_rects.is_empty()
	for screen:Rect2i in screen_rects:
		if rectangle.intersects(screen):outside=false
	return {"native_position":[position.x,position.y],"native_size":[size.x,size.y],"root_position":[root.position.x,root.position.y],"root_size":[root.size.x,root.size.y],"offscreen":outside,"expected_client_size":size==dimensions,"root_mode":root.mode,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,id),"mouse_passthrough":root.mouse_passthrough}

func _position_after_host()->bool:
	var west:int=screen_rects[0].position.x
	for screen:Rect2i in screen_rects:west=mini(west,screen.position.x)
	# Host startup/resizing may replace a launcher's requested native position.
	# Move this fixture's own Window only after that setup; audit the actual
	# client rectangle rather than assuming root.position is applied already.
	root.position=Vector2i(west-dimensions.x-512,0)
	observations.append({"phase":"window_position_after_host_resize","width":dimensions.x,"screens":screen_rects,"window":_window_snapshot()})
	await process_frame
	var waited:=1;var snapshot:=_window_snapshot()
	while (not snapshot.offscreen or not snapshot.expected_client_size) and waited<30:
		await process_frame;waited+=1;snapshot=_window_snapshot()
	var ready:bool=snapshot.offscreen and snapshot.expected_client_size and snapshot.no_focus and not snapshot.mouse_passthrough
	_check(ready,"actual post-Host native client remains outside every screen at "+str(dimensions.x))
	observations.append({"phase":"window_post_host_geometry_ready","width":dimensions.x,"waited_process_frames":waited,"window":snapshot})
	return ready

func _button_state(target:BaseButton)->Dictionary:
	# Call sites must validate BEFORE typed argument binding: this function's
	# own guard cannot run when a freed BaseButton is rejected at that boundary.
	# A null snapshot is expected after an actual successful page close.
	var hovered:Control=root.gui_get_hovered_control()
	var state:Dictionary={"wall_us":Time.get_ticks_usec(),"engine_frame":Engine.get_process_frames(),"root_mouse_position":root.get_mouse_position(),"gui_hovered":str(hovered.name) if is_instance_valid(hovered) else "","window_focused":root.has_focus()}
	if is_instance_valid(target):
		state.target_rect=target.get_global_rect();state.hovered=target.is_hovered();state.b_pressed=target.is_pressed();state.button_pressed=target.button_pressed;state.disabled=target.disabled;state.visible=target.is_visible_in_tree()
	else:state.target_freed=true
	return state

func _audit_input(event:InputEvent)->void:
	if not event is InputEventMouseButton and not event is InputEventMouseMotion and not event is InputEventKey:return
	var row:Dictionary={"wall_us":Time.get_ticks_usec(),"engine_frame":Engine.get_process_frames(),"width":dimensions.x,"audit_armed":audit_armed,"routed_dispatch_active":dispatch_depth>0,"class":event.get_class(),"active_named_pair":active_pair,"window":_window_snapshot()}
	if event is InputEventMouseButton:row.position=event.position;row.button=event.button_index;row.pressed=event.pressed
	if event is InputEventMouseMotion:row.position=event.position;row.relative=event.relative;row.button_mask=event.button_mask
	if event is InputEventKey:row.keycode=event.keycode;row.pressed=event.pressed
	if not active_pair.is_empty():row.button_state_before_gui=_button_state(active_button if is_instance_valid(active_button) else null)
	if input_audit.size()<4096:input_audit.append(row)
	else:input_audit_dropped+=1
	if not audit_armed or dispatch_depth>0:return
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		unrouted_presses+=1;_check(false,"unrouted press reached the armed offscreen QA Window")
	if event is InputEventMouseMotion and not active_pair.is_empty():unrouted_pair_motions+=1
	# Observer only. A depth-zero event is explicitly unrouted, not automatically
	# attributed to an OS device; its timing/coordinates show possible interference.

func _host_snapshot()->Dictionary:
	if not is_instance_valid(game):return {"host_freed":true}
	return {"view":game.view,"busy":game.busy,"host_scale":game.scale,"modal_alive":is_instance_valid(game.modal),"modal_script":game.modal.get_script().resource_path if is_instance_valid(game.modal) and game.modal.get_script()!=null else "","last_context_event":game.get_meta("last_context_event",""),"case02":game.core.case_state("case02").duplicate(true),"active_operation":game.core.state.active_operation.duplicate(true)}
func _hashes()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://tests/final_host_boundary_smoke.gd","res://scripts/rebuild/final_playable.gd","res://scripts/rebuild/final_case_state.gd","res://scripts/ui/paper_ui.gd","res://scripts/rebuild/mail_workbench.gd","res://scripts/rebuild/final_walker.gd","res://assets/faefever_v2/manifest.json"]:result[path]=FileAccess.get_sha256(path)
	return result
func _finish(loaded:Node=null)->void:
	_check(unrouted_presses==0,"no unrouted press contaminates the armed boundary schedule")
	_check(unrouted_pair_motions==0,"no unrouted motion intervenes in named first down/up pairs")
	_check(input_audit_dropped==0,"bounded passive input audit retains all observed events")
	var final_hashes:=_hashes();_check(final_hashes==initial_hashes,"boundary source dependencies are unchanged during the fixture")
	var host_state:=_host_snapshot()
	if is_instance_valid(game) and is_instance_valid(game.sound):
		game.sound.shutdown();var deadline:=Time.get_ticks_msec()+1000
		while game.sound.has_pending_playbacks() and Time.get_ticks_msec()<deadline:await process_frame
		_check(not game.sound.has_pending_playbacks(),"owned fixture audio retires before node/engine deletion")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var f:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"input_audit":input_audit,"screen_rectangles":screen_rects,"unrouted_presses":unrouted_presses,"unrouted_named_pair_motions":unrouted_pair_motions,"input_audit_dropped":input_audit_dropped,"source_sha256":initial_hashes,"source_sha256_at_finish":final_hashes,"host_at_finish":host_state,"scope":"Isolated public Core API fixture setup and actual original first-pair GUI inputs, not a complete player route. Unchanged custody/read-only/slot/quit checks. QA-only unique preferences and display-change isolation preserve its declared1280client/1600canvas. Native client geometry is observed after Host startup outside all returned screens. Passive dispatch-depth/hover/Button traces never swallow or retry input; unrouted events are not automatically attributed to an OS device. No production modification, native OS click, FPS, listening or whole-game usability claim."},"\t"));f.close()
	print("FINAL HOST BOUNDARY: %d checks, %d failures"%[checks,failures.size()])
	if is_instance_valid(loaded):loaded.queue_free()
	if is_instance_valid(game):game.queue_free()
	await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
