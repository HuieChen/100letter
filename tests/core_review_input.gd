extends "res://tests/final_playable_input_smoke.gd"
## Isolated routed GUI events. GPU images are real; this is not native/manual QA.
var phase := "all"
const REVIEW_OUT := "res://test-results/core-review/"

func _run() -> void:
	root.unfocusable=true
	began=Time.get_ticks_msec()
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
	initial_hashes=_source_hashes()
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		host=Host.new();root.add_child(host);host.size=Vector2(1600,900)
		host.core.save_path="user://qa/core-review/"+run_id+"-"+str(dimensions.x)+".json"
		host._title() # Render the fixture's isolated slot, not the default slot.
		await process_frame
		_check(_node("TitleArtwork")==null and _node("TitleGround")!=null,"plain title has no illustration")
		_check(_node("GameTitle").text=="一百信","game name is the cover")
		_check(_node("ContinueShift").disabled,"empty save cannot pretend to continue")
		await _shot("title_"+str(dimensions.x))
		await _named("NewShift")
		await _wait(func():return _node("FinishBriefing")!=null,"supervisor starts after title")
		await _named("FinishBriefing")
		_check(host.view=="counter" and not host.busy,"visible dialogue advance starts playable counter")
		if phase!="title":await _remaining_checks()
		host.queue_free();await process_frame;await process_frame
	_check(initial_hashes==_source_hashes(),"source frozen during phase")
	DirAccess.make_dir_recursive_absolute(REVIEW_OUT)
	var report:={"phase":phase,"checks":checks,"failures":failures,"steps":steps,"screenshots":screenshots,"source_sha256":initial_hashes,"scope":"Godot routed GUI events and actual GPU capture; isolated saves; not native input, listening or novice acceptance"}
	var f:=FileAccess.open(REVIEW_OUT+phase+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close()
	print("CORE REVIEW ",phase,": ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _remaining_checks() -> void:
	await _open_desk_box()
	await _named("Mail_case01")
	_check(_modal_script().ends_with("mail_workbench.gd"),"physical take opens one envelope")
	await _click(Vector2(1495,60))
	_check(not is_instance_valid(host.modal),"inspector visible cross closes without Esc")
	await _named("OpenBag")
	_check(_node("Inspect_case01")==null and _node("Envelope_case01")!=null,"bag contains directly interactive envelope, no details button")
	var close_style:StyleBox=_node("CloseBag").get_theme_stylebox("normal")
	_check(close_style is StyleBoxFlat and close_style.bg_color.a>0.9,"bag cross stays readable against a dark scene")
	await _shot("bag_"+str(root.size.x))
	await _named("Envelope_case01")
	_check(_modal_script().ends_with("mail_workbench.gd") and host.carried=="case01","envelope click lifts and selects the same object")
	_check(_node("CarriedLetter")!=null and not _node("CarriedLetter").visible,"inspection does not show a duplicate carried envelope")
	var bench:Control=host.modal
	await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()),MOUSE_BUTTON_RIGHT)
	_check(bench.model.export_state().face=="back","direct flip exposes reverse")
	var before:Vector2=bench.model.object_rect("envelope").position
	await _drag(bench.to_canvas(bench.model.object_rect("envelope").get_center()),bench.to_canvas(bench.model.object_rect("envelope").get_center()+Vector2(35,20)))
	_check(bench.model.object_rect("envelope").position.distance_to(before)>20,"envelope really moves under drag")
	await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()),MOUSE_BUTTON_WHEEL_UP)
	_check(bench.model.export_state().zoom>1.0,"wheel enlarges actual paper")
	await _shot("inspect_"+str(root.size.x))
	var physical:Dictionary=bench.model.export_state()
	await _click(Vector2(1495,60))
	_check(not is_instance_valid(host.modal) and host.core.state.active_operation.is_empty(),"cross puts paper down safely")
	_check(_node("CarriedLetter").visible,"returned envelope restores its scene affordance")
	await _named("OpenBag");await _named("Envelope_case01")
	_check(host.modal.model.export_state().face==physical.face,"reentry keeps the observed face")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal),"Esc is the second safe exit")
	await _named("OpenBag");await _named("CloseBag")
	_check(not is_instance_valid(host.modal),"bag closes without keyboard knowledge")
	if phase=="bag":return
	host._world();await process_frame
	var minute:int=host.core.state.minute
	await _named("OpenMap")
	_check(_node("DepartWalking")==null,"map has no second walking confirmation")
	await _shot("map_"+str(root.size.x))
	await _named("Map_residential")
	_check(host.busy and not is_instance_valid(host.modal),"destination immediately folds map and starts transition")
	# The HUD is still present while the departure starts. These real pointer
	# presses must not cancel its walking callback or mount a second focus mode.
	await _named("OpenBag")
	_check(not is_instance_valid(host.modal),"bag cannot interrupt a committed transition")
	await _named("OpenBook")
	_check(not is_instance_valid(host.modal),"book cannot interrupt a committed transition")
	# Rapid repeated pointer input cannot book the same journey twice.
	await _click(Vector2(800,450));await _click(Vector2(800,450))
	await _wait(func():return not host.busy,"arrival completes under rapid input",3.0)
	_check(host.core.state.location=="residential" and host.core.state.minute==minute+15,"one destination click charges exactly one journey")
	_check(host.walker.visible and host.walker.manual_enabled,"arrival restores visible controlled actor")
	await _named("OpenMap");await _named("Map_residential")
	_check(not host.busy and not is_instance_valid(host.modal) and host.core.state.minute==minute+15,"current-place click closes map without journey cost")
	await _named("OpenMap");await _named("CloseMap")
	_check(not is_instance_valid(host.modal),"map visible cross closes")
	await _named("OpenMap");await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal),"map Escape closes without pause leakage")
	if phase=="map":return
	await _named("Talk_elsie_moran")
	await _wait(func():return _node("CloseDialogue")!=null,"walk reaches resident and exposes visible conversation exit")
	_check(host.walker.visible and not host.walker.manual_enabled,"dialogue retains scene actors but stops walking")
	await _shot("dialogue_"+str(root.size.x))
	await _named("CloseDialogue")
	_check(not is_instance_valid(host.modal) and host.walker.manual_enabled,"conversation cross returns full control without Esc")
	await _named("Talk_elsie_moran")
	await _wait(func():return _node("CloseDialogue")!=null,"repeat conversation is available")
	await _named("AdvanceDialogue")
	_check(_node("CloseDialogue")!=null,"response topics also have visible cross")
	await _named("CloseDialogue")
	_check(not is_instance_valid(host.modal),"topic cancel leaves no selected answer")

func _source_hashes() -> Dictionary:
	var result:=super._source_hashes()
	result["tests/core_review_input.gd"]=FileAccess.get_sha256("res://tests/core_review_input.gd")
	return result

func _move(point:Vector2) -> void:
	var e:=InputEventMouseMotion.new();e.position=point;e.global_position=point;e.relative=point-pointer
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=point;root.push_input(e,true);await process_frame

func _button(button:MouseButton,down:bool) -> void:
	var e:=InputEventMouseButton.new();e.position=pointer;e.global_position=pointer;e.button_index=button;e.pressed=down
	if button==MOUSE_BUTTON_LEFT:held=down
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(e,true);await process_frame

func _key(code:Key,control:bool=false) -> void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;e.ctrl_pressed=control
		root.push_input(e,true);await process_frame
	await _settle_material_motion()

func _shot(label:String) -> void:
	if _modal_script().ends_with("mail_workbench.gd"):
		await _wait(func():return float(host.modal.get_workbench_snapshot().presentation)>=1.0,"visible envelope finishes its lift before capture",2.0)
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(REVIEW_OUT)
	var path:=REVIEW_OUT+phase+"_"+label+".png"
	_check(root.get_texture().get_image().save_png(path)==OK,"actual GPU capture "+label)
	screenshots.append(path)
