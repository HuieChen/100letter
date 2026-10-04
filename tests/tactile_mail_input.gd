extends "res://tests/core_review_input.gd"
## Raw viewport events deliberately interrupt motion; no settle helper hides races.
const EVIDENCE := "res://test-results/tactile-mail/"
var frame_times: Array[float] = []
var idle_draws := {"count":0}
var diagnostics: Dictionary = {}

func _run() -> void:
	root.unfocusable=true
	began=Time.get_ticks_msec();initial_hashes=_source_hashes()
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await process_frame;await process_frame
	host=Host.new();root.add_child(host);host.size=Vector2(1600,900)
	host.core.save_path="user://qa/tactile-mail/"+run_id+".json"
	host.core.new_game();host._counter();await process_frame
	var desk:Control=_node("PhysicalPostalDesk")
	var lid_draws:={"count":0}
	desk.draw.connect(func():lid_draws.count+=1)
	await _click(_desk_point((_desk_snapshot().rects.latch as Rect2).get_center()))
	await _click(_desk_point((_desk_snapshot().rects.lid as Rect2).get_center()))
	lid_draws.count=0
	await create_timer(0.36).timeout
	_check(lid_draws.count>2 and desk.lid_open==1.0,"clicked lid visibly redraws its hinge without more mouse input")
	await _capture("01_open_box")
	var start:Vector2=_desk_point((_desk_snapshot().rects.letter as Rect2).get_center())
	await _move(start);await _button(MOUSE_BUTTON_LEFT,true)
	await _move(start+Vector2(42,-18));await _button(MOUSE_BUTTON_LEFT,false)
	_check(desk._returning_letter,"short unplaced drag settles back instead of teleporting")
	_check(desk.letter_rect.position.distance_to(desk.LETTER.position)>1.0,"invalid drop retains intermediate visible paper position")
	await create_timer(0.19).timeout
	_check(desk.letter_rect==desk.LETTER and not desk._returning_letter,"settling completes at the same physical stack")
	desk.draw.connect(func():idle_draws.count+=1)
	await process_frame;idle_draws.count=0
	var last_tick:=Time.get_ticks_usec()
	for i:int in range(90):
		await process_frame
		var now:=Time.get_ticks_usec();frame_times.append(float(now-last_tick)/1000.0);last_tick=now
	_check(idle_draws.count==0,"idle box does not redraw its entire surface every frame")
	var sampled_idle_draws:int=idle_draws.count
	await _move(start);await _button(MOUSE_BUTTON_LEFT,true)
	await _move(Vector2(710,390));await _button(MOUSE_BUTTON_LEFT,false)
	_check(_modal_script().ends_with("mail_workbench.gd"),"physical extraction opens the owned envelope")
	var bench:Control=host.modal
	diagnostics["fit"]=bench._fit;diagnostics["bench_size"]=str(bench.size);diagnostics["host_size"]=str(host.size)
	_check(bench.retain_counter_surface and desk.is_visible_in_tree(),"inspection retains the actual opened box and original desk")
	await create_timer(0.27).timeout
	await _capture("02_inspect_same_counter")
	for i:int in range(4):await process_frame
	var center:Vector2=bench.to_canvas(bench.model.object_rect("envelope").get_center())
	# Independent edge coordinates on the actual paper, no right-click shortcut.
	var paper_rect:Rect2=bench.model.object_rect("envelope")
	var edge:Vector2=bench.to_canvas(Vector2(paper_rect.end.x-15,paper_rect.get_center().y))
	await _move(edge);await create_timer(0.12).timeout
	_check(bench._edge_hover and bench._lift>0.0,"physical right edge offers a small lift without a text label")
	await _button(MOUSE_BUTTON_LEFT,true);await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench.model.export_state().face=="back","left click on paper edge turns the actual envelope")
	for repeat:int in range(3):await _button(MOUSE_BUTTON_LEFT,true);await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench.model.export_state().face=="back","repeat left clicks during turn cannot toggle back or capture paper")
	await create_timer(0.24).timeout
	await _move(edge);await _button(MOUSE_BUTTON_LEFT,true);await _button(MOUSE_BUTTON_LEFT,false)
	await create_timer(0.24).timeout
	_check(bench.model.export_state().face=="front","same paper edge turns back without a shortcut")
	var anchor:Vector2=bench._to_table(center)
	await _move(center);await _button(MOUSE_BUTTON_WHEEL_UP,true);await _button(MOUSE_BUTTON_WHEEL_UP,false)
	var intermediate_zoom:=false
	var zoom_samples:Array[float]=[]
	for i:int in range(6):
		await process_frame
		var visible_zoom:float=bench.model.export_state().zoom
		zoom_samples.append(visible_zoom)
		intermediate_zoom=intermediate_zoom or (visible_zoom>1.0 and visible_zoom<1.2)
	diagnostics["first_zoom_samples"]=zoom_samples
	_check(intermediate_zoom,"wheel traverses intermediate zoom instead of jumping")
	_check(bench.to_canvas(anchor).distance_to(center)<0.1,"zoom keeps the pointed paper detail anchored")
	await create_timer(0.15).timeout
	_check(is_equal_approx(float(bench.model.export_state().zoom),1.2),"wheel ends at exact intended zoom")
	# Six fast wheel notches accumulate in one controlled motion, never six fighting tweens.
	for i:int in range(6):
		await _button(MOUSE_BUTTON_WHEEL_UP,true);await _button(MOUSE_BUTTON_WHEEL_UP,false)
	_check(is_equal_approx(bench._zoom_goal,2.4),"rapid wheel input preserves every requested notch")
	await create_timer(0.15).timeout
	_check(is_equal_approx(float(bench.model.export_state().zoom),2.4),"rapid zoom settles without overshoot")
	await _button(MOUSE_BUTTON_WHEEL_DOWN,true);await _button(MOUSE_BUTTON_WHEEL_DOWN,false)
	center=bench.to_canvas(bench.model.object_rect("envelope").get_center())
	await _move(center);await _button(MOUSE_BUTTON_LEFT,true)
	var frozen_zoom:float=bench.model.export_state().zoom
	_check(bench._drag=="envelope","visible moving paper can be grabbed during zoom")
	var before:Vector2=bench.model.object_rect("envelope").position
	var grabbed_detail:Vector2=bench._to_table(pointer)-before
	for i:int in range(1,9):await _move(center+Vector2(i*7,i*2))
	var after:Vector2=bench.model.object_rect("envelope").position
	_check(bench.to_canvas(after+grabbed_detail).distance_to(pointer)<0.1,"held envelope follows each pointer position without delayed interpolation")
	diagnostics["grip_error"]=bench.to_canvas(after+grabbed_detail).distance_to(pointer)
	_check(after.distance_to(before)>15.0,"interrupted zoom leaves real object draggable")
	await _button(MOUSE_BUTTON_LEFT,false);await create_timer(0.16).timeout
	_check(is_equal_approx(float(bench.model.export_state().zoom),frozen_zoom),"cancelled zoom cannot move the paper after release")
	_check(bench._lift==0.0 and bench._drag.is_empty(),"paper settles and releases input after drop")
	center=bench.to_canvas(bench.model.object_rect("envelope").get_center())
	await _move(center);await _button(MOUSE_BUTTON_RIGHT,true);await _button(MOUSE_BUTTON_RIGHT,false)
	_check(bench._flip_progress>0.0 and bench._flip_progress<1.0 and bench._previous_face=="front","flip presents the old face before crossing the hinge")
	for i:int in range(2):await _button(MOUSE_BUTTON_RIGHT,true);await _button(MOUSE_BUTTON_RIGHT,false)
	_check(bench.model.export_state().face=="back","fast repeated clicks do not queue delayed contradictory flips")
	await create_timer(0.24).timeout
	_check(bench._flip_progress==1.0 and bench.model.export_state().inspected_back,"reverse finishes physically and records observation")
	await _capture("03_reverse_after_interrupted_zoom")
	for cycle:int in range(40):
		center=bench.to_canvas(bench.model.object_rect("envelope").get_center())
		await _move(center);await _button(MOUSE_BUTTON_LEFT,true)
		for step:int in range(1,9):await _move(center+Vector2(float(step)*1.73,-float(step)*0.87))
		await _button(MOUSE_BUTTON_LEFT,false)
		_check(bench.core.accept_inspection("case01",bench.model.export_state()).is_empty(),"fractional re-grab "+str(cycle)+" passes unchanged strict material replay")
	var layouts:int=bench._text_layout_builds
	for i:int in range(32):await _move(Vector2(80+i,170))
	_check(bench._text_layout_builds==layouts,"mouse motion reuses envelope typography instead of rebuilding glyphs")
	var expected_return:Rect2=bench.return_rect
	await _move(Vector2(1495,60)*bench._fit);await _button(MOUSE_BUTTON_LEFT,true);await _button(MOUSE_BUTTON_LEFT,false)
	diagnostics["close_pointer"]=str(bench._pointer);diagnostics["injected_pointer"]=str(pointer);diagnostics["close_flags"]={"save_problem":bench._save_problem,"message":bench._message,"reading":bench._reading,"amending":bench._amending,"closing":bench._closing}
	_check(is_instance_valid(host.modal) and bench._returning,"cross settles the actual object before releasing the surface")
	for i:int in range(2):await _button(MOUSE_BUTTON_LEFT,true);await _button(MOUSE_BUTTON_LEFT,false)
	await _wait(func():return not is_instance_valid(host.modal),"rapid cross input closes exactly once",1.0)
	_check(host.view=="counter" and not host.busy and host.core.state.active_operation.is_empty(),"return leaves a playable desk without pause or captured input")
	await _capture("04_returned_counter")
	var resting:Control=_node("CarriedLetter")
	_check(resting.visible and resting.position==Vector2(150,280),"returned envelope rests on the actual clear tabletop, not a HUD corner")
	_check(resting.face=="back" and resting.fields==host.core.case_view("case01").back,"resting letter preserves its actual observed face without inventing reverse writing")
	_check(expected_return==Rect2(resting.position,resting.size),"closing flight ends exactly where the same scene envelope appears")
	var probe:=Core.new();probe.save_path=host.core.save_path
	_check(probe.load_game() and probe.case_state("case01").physical.inspected_back,"settled return persists the same observed envelope")
	probe.free()
	await _named("OpenBag");await _named("Envelope_case01");await create_timer(0.27).timeout
	bench=host.modal
	_check(not _node("CarriedLetter").visible,"bag reentry has one focused envelope without duplicate scene icon")
	_check(bench.model.export_state().face=="back","reentry restores the same physical face")
	center=bench.to_canvas(bench.model.object_rect("envelope").get_center())
	await _move(center);await _button(MOUSE_BUTTON_WHEEL_UP,true);await _button(MOUSE_BUTTON_WHEEL_UP,false)
	bench.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var focused_zoom:float=bench.model.export_state().zoom
	await create_timer(0.16).timeout
	_check(is_equal_approx(float(bench.model.export_state().zoom),focused_zoom) and not bench.model.input_is_captured(),"focus-loss checkpoint stops animation and releases material capture")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal),"Escape returns paper and never opens a second pause page")
	_check(_node("CarriedLetter").visible,"Escape restores the returned envelope's actual scene affordance")
	await _named("CarriedLetter");await create_timer(0.27).timeout
	_check(_modal_script().ends_with("mail_workbench.gd") and not _node("CarriedLetter").visible,"clicking the actual resting envelope picks up one object directly")
	await _key(KEY_ESCAPE)
	_check(initial_hashes==_source_hashes(),"runtime source stays frozen during tactile input review")
	frame_times.sort()
	var report:={"suite":"tactile_mail_input","checks":checks,"failures":failures,"steps":steps,"screenshots":screenshots,"diagnostics":diagnostics,"source_sha256":initial_hashes,"idle_redraws":sampled_idle_draws,"idle_frames":90,"frame_wall_ms":{"median":frame_times[45],"p95":frame_times[85],"max":frame_times[-1]},"scope":"Actual routed viewport input with live GPU frames. Interruptions, rapid clicks and save recovery are checked. Wall frame timing belongs to this machine/offscreen process, not a promised player FPS. Native input and audio listening are separate."}
	var f:=FileAccess.open(EVIDENCE+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("TACTILE MAIL: ",checks," checks / ",failures.size()," failures")
	host.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture(label:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	var path:=EVIDENCE+label+".png"
	_check(root.get_texture().get_image().save_png(path)==OK,"1920x1080 GPU capture "+label)
	screenshots.append(path)

func _source_hashes() -> Dictionary:
	var hashes:=super._source_hashes()
	hashes["tests/tactile_mail_input.gd"]=FileAccess.get_sha256("res://tests/tactile_mail_input.gd")
	return hashes
