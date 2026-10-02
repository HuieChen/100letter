extends SceneTree
## Host-level actual routed input. No completion signals or hidden state writes.
const Host = preload("res://scripts/rebuild/final_playable.gd")
const Core = preload("res://scripts/rebuild/final_case_state.gd")
const OUT := "res://artifacts/reference_audit/final_flow/"
var host: Control
var pointer := Vector2.ZERO
var held := false
var checks := 0
var failures: Array[String] = []
var steps: Array[Dictionary] = []
var screenshots: Array[String] = []
var began := 0
var run_id := str(Time.get_ticks_usec())
var initial_hashes: Dictionary={}

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	began=Time.get_ticks_msec()
	initial_hashes=_source_hashes()
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	root.title="100letter isolated final host input regression"
	host=Host.new();root.add_child(host);host.size=Vector2(1600,900)
	# The script's unique path wins even if no command-line save override was supplied.
	host.core.save_path="user://qa/final-host/"+run_id+"/state.json"
	await process_frame
	_check(host.view=="title", "real playable title is mounted")
	await _shot("01_title")
	await _text("开始这个夏日")
	_check(host.view=="counter" and host.core.state.location=="post_office","new day starts directly at the working counter")
	await _wait(func():return _node("FinishBriefing")!=null,"brief supervisor scene appears before work")
	await _shot("01b_counter_supervisor")
	await _named("FinishBriefing")
	_check(not host.busy and not is_instance_valid(host.modal),"player finishes short briefing and receives control")
	_check(_desk_snapshot().get("waiting",[])==["case01"] and float(_desk_snapshot().get("lid_open",1))==0.0,"physical closed box contains only first teaching mail")
	await _named("CounterRegister")
	_check(not is_instance_valid(host.modal) and host.core.case_state("case01").owner=="desk_b","registry cannot bypass actually taking and inspecting the first envelope")
	await _shot("02a_counter_tray")
	await _named("CounterReferenceBook")
	await _text("查阅服务规程")
	_check(_modal_script().ends_with("field_observation.gd"),"closed counter ledger opens separate readable service manual")
	await _read_observation()
	_check(host.core.has_evidence("trusted_handoff_rule"),"reading actual manual rows supplies service rule without private mail access")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal) and float(_desk_snapshot().get("lid_open",1))==0.0,"closing manual preserves unopened physical box")
	await _click(_desk_point((_desk_snapshot().rects.letter as Rect2).get_center()))
	_check(not is_instance_valid(host.modal) and host.core.case_state("case01").owner=="desk_b","clicking where hidden mail lies cannot take it through closed lid")
	await _open_desk_box()
	_check(not host.core.case_state("case02").available and not host.core.case_state("case03").available,"later mail remains unavailable before first recorded disposition")
	await _shot("02_counter_first_mail")
	await _named("Mail_case01")
	_check(_modal_script().ends_with("mail_workbench.gd"),"counter mail click opens integrated physical workbench")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal),"immediate Escape can exit newly opened workbench")
	_check(not "case01" in _desk_snapshot().get("waiting",[]),"taken envelope is removed from the physical box")
	await _shot("02d_counter_empty_tray")
	var disk:=Core.new();disk.save_path=host.core.save_path
	_check(disk.load_game() and disk.case_state("case01").owner=="courier" and disk.case_state("case01").physical.inspected_front,"immediate workbench Escape checkpoints inspected face and custody on disk")
	disk.free()
	await _text("走回门外")
	_check(host.view=="world","counter exit returns to actual world")
	await _click(Vector2(500,790))
	_check(host.walker.walking,"ground pointer starts an actual local walk")
	await _named("OpenBook")
	_check(not host.walker.visible and not host.walker.walking and not host.walker.manual_enabled,"field book hides courier and cancels pending walk rather than moving behind closeup")
	await _key(KEY_ESCAPE)
	_check(host.walker.visible and host.walker.manual_enabled and not is_instance_valid(host.modal),"closing world notebook restores visible playable courier")
	await _named("OpenBag")
	await _named("Inspect_case01")
	_check(_modal_script().ends_with("mail_workbench.gd") and not host.walker.visible,"world bag-to-workbench route also hides courier")
	await _key(KEY_ESCAPE)
	_check(host.walker.visible and host.walker.manual_enabled,"safe world workbench close restores actor and input")
	await _travel("community_center")
	_check(_target_usable("Clue_street_renaming") and _target_usable("Clue_june_current_mailpoint"),"community evidence has visible on-screen interaction regions")
	_check(_node("MailCubby") is Button and _node("MailCubby").text.is_empty(),"approved mailpoint uses existing small wall slots rather than a floating envelope")
	await _shot("world_community_aligned")
	await _named("Clue_street_renaming")
	_check(not is_instance_valid(host.modal) and host.walker.walking,"clue first approaches before opening observation")
	await _wait(func():return is_instance_valid(host.modal),"walk to community notice opens source observation")
	_check(not host.walker.visible and not host.walker.manual_enabled and not host.actors.visible,"physical source closeup hides courier, resident feet, and world controls")
	_check(not host.core.has_evidence("street_renaming"),"entering close observation does not auto-grant evidence")
	await _shot("03_notice_closed")
	await _read_observation()
	_check(host.core.has_evidence("street_renaming"),"actual cover and row clicks acquire the public notice")
	await _key(KEY_ESCAPE)
	_check(host.walker.visible and host.actors.visible and host.walker.manual_enabled and not is_instance_valid(host.modal),"observation Escape returns visible actors and control to the world")
	await _recover_pause()
	await _named("Clue_june_current_mailpoint")
	await _wait(func():return is_instance_valid(host.modal),"reach public mailpoint register")
	await _read_observation();await _key(KEY_ESCAPE);await _recover_pause()
	_check(host.core.has_evidence("june_current_mailpoint"),"actual second source inspection enables later archive discovery")
	# Actor-depth mechanics retain their dedicated walker regression. This hosted
	# journey intentionally uses only routed input, not direct walk_to commands.
	await _travel("residential")
	_check(_target_usable("Talk_elsie_moran"),"Elsie has an on-screen conversation region")
	_check(_target_usable("Clue_current_3c_resident"),"current-resident source has an on-screen region")
	await _shot("world_residential_aligned")
	await _named("Clue_ceramic_17")
	await _wait(func():return is_instance_valid(host.modal),"reach the two physical street plates")
	if is_instance_valid(host.modal) and host.modal.has_method("interaction_regions"):
		var plate:=_region("plate")
		await _drag(plate.get_center(),plate.get_center()+Vector2(330,0))
	_check(host.core.has_evidence("ceramic_17"),"dragging upper plate reveals and records actual old plate")
	await _shot("04_plate_revealed")
	await _key(KEY_ESCAPE)
	await _recover_pause()
	await _named("Talk_elsie_moran")
	_check(not is_instance_valid(host.modal),"NPC conversation is delayed until courier reaches doorway")
	await _wait(func():return is_instance_valid(host.modal),"courier arrives for Elsie conversation")
	_check(host.core.state.encounters.has("elsie_moran"),"actual on-site conversation records encountered person")
	_check(host.walker.visible and not host.walker.manual_enabled,"in-scene dialogue keeps courier visible but stops movement")
	var conversation_minute: int=host.core.state.minute
	_check(_node("Choice_topic_elsie_address")==null and _node("SpokenLine")!=null,"greeting line appears before any response menu")
	await _named("AdvanceDialogue")
	await _named("Choice_topic_elsie_address")
	_check(_node("Speaker").text=="你" and not host.core.has_evidence("elsie_confirmation"),"choosing topic speaks full courier question before recipient answer grants source")
	await _shot("05a_courier_question")
	await _named("AdvanceDialogue")
	_check(host.core.has_evidence("elsie_confirmation") and host.core.state.minute==conversation_minute,"dialogue source is recorded without artificial time advancement")
	await _shot("05_elsie_dialogue")
	await _named("AdvanceDialogue")
	await _text("结束交谈")
	await _named("OpenBag")
	await _named("Carry_case01")
	_check(host.carried=="case01" and _node("CarriedLetter")!=null,"physical bag choice carries the first letter in world")
	await _named("Talk_elsie_moran")
	await _wait(func():return is_instance_valid(host.modal),"carried letter approaches recipient before handoff")
	await _named("AdvanceDialogue")
	await _text("交出手中的这封信")
	_check(host.core.case_state("case01").owner=="elsie_moran" and host.core.case_state("case01").disposition=="deliver","onsite handoff transfers actual custody")
	_check(not host.core.case_state("case02").available and not host.core.case_state("case03").available,"first actual delivery alone does not bypass the postal resolution slip")
	_check("处理单" in host._objective() and not "两封新邮件" in host._objective(),"delivered but unrecorded first mail correctly directs player back to postal resolution")
	_check(host.carried.is_empty(),"handoff clears logical carried item")
	await _named("AdvanceDialogue")
	await _text("结束交谈")
	_check(_node("CarriedLetter")==null,"handoff also clears visible carried letter HUD")
	_check(not _visible_text(host.stage,"已拿出第"),"handoff clears the visible carried-letter caption as well as its icon")
	await _shot("06_delivered_world")
	await _travel("post_office")
	var starting_foot: Vector2=host.walker.foot
	await _named("PostDoor")
	_check(host.view=="world" and host.walker.walking,"world door click starts walking without instant counter transition")
	await _wait(func():return host.view=="counter","return physically to Desk B")
	_check(starting_foot.distance_to(host.plan.entrance)>25,"world door approach starts sufficiently far away")
	await _named("CounterRegister")
	await _named("Resolution_case01")
	_check(_modal_script().ends_with("resolution_slip.gd"),"registry mounts actual physical resolution component")
	await _named("ReviewSlip")
	_check(not host.modal._reviewing and host.core.resolution_view("case01").is_empty(),"empty factual fields cannot advance to actual stamp")
	await _fill("Field_recipient","Elsie Moran")
	await _fill("Field_location","17 Old Quay Lane / verified current entrance")
	await _fill("Field_status","Delivered by hand after checking old street name")
	await _fill("ResolutionNote","Old ceramic plate and Elsie confirmation agree.")
	await _shot("06b_resolution_filled")
	await _named("ReviewSlip")
	_check(host.modal._reviewing and host.core.resolution_view("case01").is_empty(),"reviewing filled paper still does not record a stamp")
	await _drag(_node("DeskSeal").get_global_rect().get_center(),_region("stamp_area").get_center())
	await _wait(func():return not is_instance_valid(host.modal),"physical seal drop commits resolution then returns to counter")
	_check(host.core.resolution_view("case01").get("stamped",false),"first resolution is stored only after actual drag and stamp")
	_check(host.core.case_state("case02").available and host.core.case_state("case03").available,"first stamped resolution unlocks second and third letters")
	_check(_desk_snapshot().get("waiting",[])==["case02","case03"],"physical box now holds exactly the two newly unlocked desk-owned envelopes")
	await _shot("06c_counter_after_first_resolution")
	await _named("CounterRegister")
	await _named("Register_case02")
	_check(host.core.case_state("case02").owner=="desk_b" and "case02" in _desk_snapshot().get("waiting",[]),"registry cannot take newly unlocked mail out of the physical box")
	_check(not is_instance_valid(host.modal) and host.core.body_text("case02").is_empty(),"registry redirects to actual box without inspecting private content")
	var next_envelope_size:Vector2=(_desk_snapshot().rects.letter as Rect2).size
	for id: String in ["case02","case03"]:
		await _named("Mail_"+id)
		if not is_instance_valid(host.modal):_check(false,"missing unlocked workbench for "+id);await _finish();return
		var point: Vector2=host.modal.to_canvas(host.modal.model.object_rect("envelope").get_center())
		await _click(point,MOUSE_BUTTON_RIGHT)
		_check(host.core.case_state(id).physical.inspected_back,"real right click exposes unlocked envelope reverse for "+id)
		await _key(KEY_ESCAPE)
		_check(not is_instance_valid(host.modal) and host.core.state.active_operation.is_empty(),"focused workbench Escape returns safely for "+id)
		if is_instance_valid(host.modal):await _shot("blocked_"+id);await _finish();return
		_check(not id in _desk_snapshot().get("waiting",[]),"courier-owned envelope stays absent from box: "+id)
		if id=="case02":_check((_desk_snapshot().rects.letter as Rect2).size==next_envelope_size,"remaining envelope retains physical dimensions after taking the top one")
	await _named("CounterArchiveCabinet")
	_check(host.core.case_state("case04").available and "case04" in _desk_snapshot().get("waiting",[]),"archive discovery exposes old case in the physical box")
	await _named("CounterReferenceBook")
	await _text("翻开旧账簿")
	_check(_visible_text(host.modal,"Desk B · 旧账簿"),"same physical closed book also reaches the separate old ledger after discovery")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal),"old ledger closes back to counter without taking archive mail")
	await _key(KEY_J)
	_check(_modal_script().ends_with("field_book.gd"),"counter J shortcut opens real field archive notebook")
	await _named("Tab1")
	_check(host.modal.section==1,"notebook evidence tab responds through actual pointer")
	await _shot("07_field_archive")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal),"notebook Escape returns to counter")
	await _recover_pause()
	var saved_minute: int=host.core.state.minute
	await _key(KEY_ESCAPE)
	await _text("保存并回到封面")
	_check(host.view=="title","pause save returns to title")
	var saved_bytes:=FileAccess.get_file_as_string(host.core.save_path)
	await _named("NewShift")
	_check(host.view=="title" and is_instance_valid(host.modal) and _visible_text(host.modal,"新班次会替换此版本的工作记录"),"new game over an existing save requires a visible explicit confirmation")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(host.modal) and FileAccess.get_file_as_string(host.core.save_path)==saved_bytes,"dismissing new-game confirmation preserves saved bytes")
	await _named("NewShift")
	await _text("继续旧班次")
	_check(host.view=="world" and host.core.state.minute==saved_minute,"actual Continue reloads route time and world location")
	_check(host.core.case_state("case01").owner=="elsie_moran" and host.core.case_state("case04").available,"resume retains delivered custody and archive availability")
	_check(host.core.resolution_view("case01").get("stamped",false),"resume preserves actual stamped resolution independently of custody")
	_check(host.core.has_evidence("street_renaming") and host.core.has_evidence("elsie_confirmation"),"resume retains separately acquired public and dialogue sources")
	_check(host.core.state.privacy.violations.is_empty(),"external inspection and authorized handoff never create private-body access")
	await _shot("08_resumed_world")
	_finish()

func _travel(id: String) -> void:
	var previous: String=host.core.state.location
	var minute: int=host.core.state.minute
	await _named("OpenMap")
	await _named("Map_"+id)
	_check(host.core.state.location==previous and host.core.state.minute==minute,"map selection only previews "+id)
	await _shot("map_preview_"+id)
	await _text("沿这条路步行")
	await _wait(func():return not host.busy and host.core.state.location==id,"explicit departure reaches "+id)
	_check(host.core.state.minute==minute+15,"actual short trip charges one 15-minute event to "+id)

func _recover_pause() -> void:
	if not is_instance_valid(host.modal):return
	for button: Control in _buttons(host.modal):
		if button is Button and "回到场景" in button.text:
			_check(false,"Escape unexpectedly opened pause; visible recovery does not count as success")
			print("VISIBLE RECOVERY: dismiss unintended pause to continue investigation")
			await _click(button.get_global_rect().get_center());return

func _read_observation() -> void:
	if not is_instance_valid(host.modal) or not host.modal.has_method("interaction_regions"):
		_check(false,"observation has real hit regions");return
	var cover:=_region("open")
	if cover.has_area(): await _click(cover.get_center())
	var photo_flip:=_region("photo_flip")
	if photo_flip.has_area(): await _click(photo_flip.get_center())
	var regions: Array=host.modal.interaction_regions()
	for region: Dictionary in regions:
		if str(region.id).begins_with("row_"): await _click((region.rect as Rect2).get_center())

func _region(id: String) -> Rect2:
	for item: Dictionary in host.modal.interaction_regions():
		if item.id==id:return item.rect
	return Rect2()

func _node(node_name: String) -> Control:
	return host.find_child(node_name,true,false) as Control

func _named(node_name: String) -> void:
	if node_name.begins_with("Mail_case") and _node(node_name)==null:
		await _take_desk_mail(node_name.trim_prefix("Mail_"));return
	var desk_keys:Dictionary={"CounterRegister":"slip","CounterReferenceBook":"book","CounterArchiveCabinet":"archive"}
	if desk_keys.has(node_name) and _node(node_name)==null:
		var snapshot:=_desk_snapshot()
		if not snapshot.is_empty():
			await _click(_desk_point((snapshot.rects[desk_keys[node_name]] as Rect2).get_center()));return
	var control:=_node(node_name)
	if node_name.begins_with("Choice_"):
		for page in 4:
			if control != null: break
			var next_page: Control = _node("ChoicePageNext")
			if next_page == null: break
			await _click(next_page.get_global_rect().get_center())
			control = _node(node_name)
	_check(control!=null and control.is_visible_in_tree(),"input target exists: "+node_name)
	if control!=null: await _click(control.get_global_rect().get_center())

func _buttons(node: Node) -> Array[Control]:
	var result: Array[Control]=[]
	for child: Node in node.get_children():
		if child is BaseButton and child.is_visible_in_tree():result.append(child)
		result.append_array(_buttons(child))
	return result

func _text(fragment: String) -> void:
	if fragment=="走回门外" and not _desk_snapshot().is_empty():
		await _click(_desk_point((_desk_snapshot().rects.depart as Rect2).get_center()));return
	for page in 5:
		for button: Control in _buttons(host):
			if button is Button and fragment in button.text:
				await _click(button.get_global_rect().get_center());return
		var next_page: Control = _node("ChoicePageNext")
		if next_page == null: break
		await _click(next_page.get_global_rect().get_center())
	_check(false,"text input target missing: "+fragment)

func _caption(fragment: String) -> void:
	for button: Control in _buttons(host):
		if button.get_script()!=null and button.get_script().resource_path.ends_with("object_button.gd") and fragment in str(button.caption):
			await _click(button.get_global_rect().get_center());return
	_check(false,"physical icon missing: "+fragment)

func _modal_script() -> String:
	return host.modal.get_script().resource_path if is_instance_valid(host.modal) and host.modal.get_script()!=null else ""

func _visible_text(node: Node, fragment: String) -> bool:
	if (node is Label or node is RichTextLabel) and node.is_visible_in_tree() and fragment in node.text:return true
	for child: Node in node.get_children():
		if _visible_text(child,fragment):return true
	return false

func _wait(condition: Callable, label: String, limit: float=12.0) -> void:
	var deadline:=Time.get_ticks_msec()+int(limit*1000)
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	_check(bool(condition.call()),label)

func _move(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=point-pointer
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=point;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func _button(button: MouseButton, down: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=pointer;event.global_position=pointer;event.button_index=button;event.pressed=down
	if button==MOUSE_BUTTON_LEFT:held=down
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func _click(point: Vector2, button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	await _move(point);await _button(button,true);await _button(button,false)

func _drag(start: Vector2, finish: Vector2) -> void:
	await _move(start);await _button(MOUSE_BUTTON_LEFT,true)
	for index: int in range(1,9):await _move(start.lerp(finish,float(index)/8))
	await _button(MOUSE_BUTTON_LEFT,false)

func _fill(node_name:String, value:String) -> void:
	await _named(node_name)
	await _key(KEY_A,true)
	for character:String in value:
		var event:=InputEventKey.new();event.pressed=true;event.unicode=character.unicode_at(0)
		Input.parse_input_event(event)
	Input.flush_buffered_events();await process_frame

func _key(key: Key, control:bool=false) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=down;event.ctrl_pressed=control
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func _shot(file_name: String) -> void:
	if "--capture-input" not in OS.get_cmdline_user_args():return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	var path:=OUT+file_name+".png"
	_check(root.get_texture().get_image().save_png(path)==OK,"GPU screenshot "+file_name)
	screenshots.append(path)

func _check(condition: bool, label: String) -> void:
	checks+=1;steps.append({"check":label,"passed":condition,"elapsed_ms":Time.get_ticks_msec()-began})
	print("PASS " if condition else "FAIL ",label)
	if not condition:failures.append(label)

func _source_hashes() -> Dictionary:
	var hashes: Dictionary={}
	var paths: Array[String] = ["scripts/rebuild/final_playable.gd","scripts/rebuild/postal_desk.gd","scripts/rebuild/physical_art.gd","scripts/rebuild/mail_workbench.gd","scripts/rebuild/mail_physics_state.gd","scripts/rebuild/field_observation.gd","scripts/rebuild/field_book.gd","scripts/rebuild/final_case_state.gd","scripts/rebuild/resolution_slip.gd","scripts/rebuild/resolution_draft_store.gd","scripts/rebuild/scene_dialogue.gd","scripts/rebuild/final_walker.gd","scripts/rebuild/final_paper_map.gd","scripts/rebuild/tool_drawer.gd","scripts/ui/audio_feedback.gd","scripts/ui/paper_ui.gd","data/rebuild/final_cases.json","data/rebuild/final_dialogues.json","data/rebuild/player_amendments.json","assets/faefever_v2/manifest.json","assets/faefever_v2/characters/courier_walk_regions.json","tests/final_playable_input_smoke.gd"]
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/faefever_v2/manifest.json"))
	if manifest is Dictionary:
		for entry: Dictionary in manifest.get("assets", {}).values():
			var art_path: String = str(entry.get("path", "")).trim_prefix("res://")
			if not art_path.is_empty(): paths.append(art_path)
	for path: String in paths:
		hashes[path]=FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else "MISSING"
	return hashes

func _finish() -> void:
	var final_hashes:=_source_hashes()
	_check(initial_hashes==final_hashes,"loaded source files stay unchanged for the complete input run")
	var report:={"checks":checks,"failures":failures,"steps":steps,"screenshots":screenshots,"elapsed_ms":Time.get_ticks_msec()-began,"source_sha256":initial_hashes,"source_sha256_at_finish":final_hashes,"sources_changed_during_run":initial_hashes!=final_hashes,"save_path":host.core.save_path,"scope":"Real Input.parse_input_event routed through actual final host. No hidden state assignment, direct walk_to, or completion calls.","limits":["Independent offscreen GPU process, not native human input.","No style or motion quality approval implied by assertions.","Only case01 delivery and archive discovery covered; full five-case production loop remains separate."]}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file:=FileAccess.open("res://test-results/final_playable_input_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FINAL PLAYABLE INPUT: ",checks," checks / ",failures.size()," failures")
	host.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)






func _desk_snapshot() -> Dictionary:
	var desk:=_node("PhysicalPostalDesk")
	return desk.get_desk_snapshot() if desk!=null else {}

func _desk_point(point:Vector2) -> Vector2:
	var desk:=_node("PhysicalPostalDesk")
	return desk.global_position+point*minf(desk.size.x/1600.0,desk.size.y/900.0)

func _open_desk_box() -> void:
	var snapshot:=_desk_snapshot()
	if snapshot.is_empty():_check(false,"physical desk exists");return
	if not snapshot.latch_open:await _click(_desk_point((snapshot.rects.latch as Rect2).get_center()))
	if float(_desk_snapshot().lid_open)<0.89:
		var start:=_desk_point((_desk_snapshot().rects.lid as Rect2).get_center())
		await _drag(start,start-Vector2(0,230))
	_check(float(_desk_snapshot().lid_open)>0.88,"real hand drag opens box lid")

func _take_desk_mail(id:String) -> void:
	await _open_desk_box()
	var snapshot:=_desk_snapshot()
	if snapshot.get("waiting",[]).is_empty() or snapshot.waiting[0]!=id:
		_check(false,"expected first physical envelope "+id);return
	await _drag(_desk_point((snapshot.rects.letter as Rect2).get_center()),_desk_point(Vector2(460,450)))
	await _wait(func():return is_instance_valid(host.modal),"actual box-to-inspection movement opens "+id)
	_check(host.core.case_state(id).owner=="courier","physical take transfers custody "+id)

func _target_usable(id:String) -> bool:
	var node:=_node(id)
	return node!=null and node.is_visible_in_tree() and node.size.x>=12 and node.size.y>=12 and Rect2(0,0,1600,900).encloses(node.get_global_rect())
