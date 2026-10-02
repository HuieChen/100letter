extends SceneTree
## Real routed InputEvents. Model geometry is observed, never completed directly.
const Core = preload("res://scripts/rebuild/final_case_state.gd")
const Bench = preload("res://scripts/rebuild/mail_workbench.gd")
var core: Node
var bench: Control
var checks := 0
var failures: Array[String] = []
var completed: Array[String] = []
var close_count := 0
var screenshot_paths: Array[String] = []
var pointer:=Vector2.ZERO
var held:=false
var run_id:=str(Time.get_ticks_usec())
const OUT := "res://artifacts/reference_audit/mail_workbench/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	root.title="100letter independent workbench input test"
	core=Core.new();core.save_path="user://qa/mail-workbench/"+run_id+"/input.json";core.new_game()
	await _show("case01")
	_check(not bench.drawer.opened,"tool drawer begins closed")
	await _click(bench.tool_rect("opener").get_center())
	_check(bench._tool.is_empty() and core.remaining_openings()==3,"closed drawer prevents taking the opener through wood")
	await _drawer_open()
	await _move(bench.tool_rect("opener").get_center())
	_check(bench._hover_tool=="opener","drawer exposes the physically present opener on pointer hover")
	await _move(Vector2(800,780))
	_check(bench._hover_tool.is_empty(),"leaving physical tools clears contextual name")
	await _move(bench.tool_rect("magnifier").get_center());await _button(MOUSE_BUTTON_LEFT,true)
	await _move(bench.to_canvas(bench.model.object_rect("envelope").position+Vector2(93,55)));await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench._magnifier,"actual drawer pickup enables a local magnifying glass")
	await _shot("00_actual_magnifying_glass")
	await _click(Vector2(400,400),MOUSE_BUTTON_RIGHT)
	_check(not bench._magnifier,"right click returns magnifier without changing mail")
	await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()),MOUSE_BUTTON_WHEEL_UP)
	_check(is_equal_approx(float(bench.model.export_state().zoom),1.2),"actual wheel zooms inspected object without opening")
	await _tool("opener")
	await _shot("00_case01_held_opener")
	_check(not bench.model.export_state().opened,"tool choice alone leaves sealed mail intact")
	_check(core.remaining_openings()==3,"selecting the physical opening tool does not consume the three-opening budget")
	await _click(bench.to_canvas(bench.model.seam_point(0)))
	_check(bench.model.export_state().seam_count==1 and core.body_text("case01").is_empty(),"one contact breaches but does not reveal body")
	_check(core.remaining_openings()==2 and core.state.opening_history.size()==1,"first actual pointer breach immediately commits one opening before completion")
	_assert_quit_checkpoint("partly cut seal")
	bench.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(core.state.active_operation.is_empty() and not bench.model.input_is_captured() and not bench._closing,"simulated window-focus loss safely stores progress without dismissing workbench")
	_check(core.case_state("case01").physical.seam_count==1,"focus loss retains actual seam work before later exit")
	await _key(KEY_ESCAPE)
	_check(core.case_state("case01").physical.privacy_violation and core.case_state("case01").physical.seam_count==1,"physical cancellation retains partial seam and privacy history")
	var saved_trace: float=core.case_state("case01").physical.tamper_trace
	await _destroy_bench()
	var loaded:=Core.new();loaded.save_path=core.save_path
	_check(loaded.load_game(),"real cancellation save reloads in a new core")
	core.free();core=loaded
	await _show("case01")
	_check(bench.model.export_state().seam_count==1 and bench.model.export_state().tamper_trace==saved_trace,"reopened workbench restores physical progress without erasing trace")
	_check(core.remaining_openings()==2,"cancel and disk reload retain consumed opening without charging twice")
	_check(is_equal_approx(float(bench.model.export_state().zoom),1.2),"view zoom also survives operation cancellation and reload")
	await _open_paper()
	_check(not core.body_text("case01").is_empty() and completed.count("open")==1,"full real pointer operation exposes private body once")
	await _click(bench.to_canvas(bench.model.object_rect("paper").get_center()),MOUSE_BUTTON_LEFT,true)
	_check(bench.body_reader.visible and bench.body_reader.text==core.body_text("case01"),"double click opens readable original body only after unfolding")
	_check(Bench.READING_PAPER.encloses(bench.body_reader.get_rect()),"real body text lies inside the enlarged painted letter")
	_assert_quit_checkpoint("expanded reader")
	_check(bench.body_reader.visible,"quit checkpoint preserves reader when host has not yet closed")
	await _shot("03_private_body_reading")
	await _drawer_open()
	await _move(bench.tool_rect("magnifier").get_center());await _button(MOUSE_BUTTON_LEFT,true)
	await _move(Vector2(720,345));await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench._magnifier and not bench._magnifier_held,"glass releases correctly over scrollable letter instead of losing captured pointer")
	_check((bench._magnifier_at+Vector2(53.55,55.15)).distance_to(Vector2(720,345))<0.1,"lens follows real pointer above body-text child Control")
	await _shot("03a_actual_body_magnification")
	await _click(Vector2(720,345),MOUSE_BUTTON_RIGHT)
	await _key(KEY_ESCAPE)
	_check(not bench.body_reader.visible,"Escape closes paper reading without discarding object")
	await _reseal()
	_check(core.case_state("case01").physical.resealed and core.case_state("case01").read_body,"actual folding/insertion/flap/tool reseals without erasing knowledge")
	await _key(KEY_ESCAPE);await _destroy_bench()
	_ok(core.dispose("case01","hold_for_verification","","QA setup: first physical mail inspected and restored; address still needs verification."),"legitimate first-case disposition preserves unresolved mail")
	_record_fixture_resolution()
	var before_repair_close:=close_count
	await _show("case03")
	await _shot("01_case03_front")
	await _tool("restorer")
	await _tool("hand")
	await _drag_object("envelope",Vector2(30,0))
	await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()),MOUSE_BUTTON_RIGHT)
	_check(bench.model.export_state().inspected_front and bench.model.export_state().inspected_back,"real right click inspects both faces")
	await _tool("restorer")
	await _click(bench.to_canvas(bench.model.object_rect("label").get_center()))
	_check(bench.model.export_state().label_lifted,"tool contact lifts actual label")
	var start: Vector2=bench.to_canvas(bench.model.object_rect("label").get_center())
	var goal: Vector2=bench.model.object_rect("envelope").position+Vector2(190,130)
	var shift: Vector2=goal-bench.model.object_rect("label").position
	await _move(start);await _button(MOUSE_BUTTON_LEFT,true)
	await _key(KEY_R)
	await _move(start+shift)
	await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench.model.export_state().label_aligned,"held label rotates with R and aligns through actual pointer drop")
	await _drag_to("protector",goal-Vector2(10,10))
	await _shot("02a_case03_protected_label")
	await _tool("press");await _click(bench.to_canvas(goal+Vector2(20,20)))
	_check(bench.model.export_state().label_pressed,"protected label requires actual pressing contact")
	await _drag_object("exterior_fold",Vector2(0,70))
	await _click(bench.to_canvas(bench.model.object_rect("envelope").position+Vector2(25,25)),MOUSE_BUTTON_RIGHT)
	_check(core.case_state("case03").physical.exterior_repaired,"Case03 completes after fold and physical reinspection")
	_check(core.body_text("case03").is_empty() and "case03" not in core.state.privacy.violations,"authorized repair does not open or read private contents")
	await _click(bench.to_canvas(bench.model.object_rect("envelope").position+Vector2(25,25)),MOUSE_BUTTON_RIGHT)
	_check(core.has_evidence("label_reconstructed"),"recovered fact is observed only when the repaired reverse is actually shown")
	await _shot("02_case03_repaired_reverse")
	await _key(KEY_ESCAPE)
	_check(close_count==before_repair_close+1 and core.state.active_operation.is_empty(),"Escape releases material operation and closes once")
	await _destroy_bench()
	# Legal public route setup; no flags or completed physical states are assigned.
	_ok(core.travel("community_center",15),"visit current public mail record")
	_ok(core.observe("june_current_mailpoint"),"observe June legitimate present mailpoint")
	_ok(core.travel("post_office",15),"return to archive box")
	_ok(core.discover_archive_box(),"discover old case through normal core rule")
	await _show("case04")
	await _click(bench.to_canvas(bench.model.object_rect("envelope").position+Vector2(25,25)),MOUSE_BUTTON_RIGHT)
	_check(core.has_evidence("case04_archive_mark"),"actual old-envelope reverse records visible HV marking")
	await _open_paper()
	_check(not core.body_text("case04").is_empty() and "case04" in core.state.privacy.violations,"optional Case04 physical opening records real private-body knowledge")
	_check(core.remaining_openings()==1,"second envelope consumes exactly one additional opening")
	await _click(bench.to_canvas(bench.model.object_rect("paper").get_center()),MOUSE_BUTTON_LEFT,true)
	var scroll: VScrollBar=bench.body_reader.get_v_scroll_bar()
	_check(scroll.max_value>scroll.page,"long Case04 original body has a scrollable paper viewport")
	var scroll_before: float=scroll.value
	await _click(bench.body_reader.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
	_check(scroll.value>scroll_before,"actual wheel scroll reveals later original paragraphs")
	await _shot("03b_case04_original_body_scroll")
	await _key(KEY_ESCAPE)
	await _reseal()
	_check(core.case_state("case04").physical.resealed,"Case04 is physically refolded and sealed before archival disposition")
	await _key(KEY_ESCAPE);await _destroy_bench()
	_ok(core.dispose("case04","archive_review","","记录保留待复核。"),"lawfully route old case to review")
	_ok(core.observe("ledger_hv_repeat"),"ledger observation reveals internal staff sleeve")
	await _show("case05")
	await _open_paper()
	_check(not core.body_text("case05").is_empty() and "case05" not in core.state.privacy.violations,"internal staff note uses physical opening without customer privacy violation")
	_check(core.remaining_openings()==0,"legal internal note is the allowed third opening")
	await _shot("04_staff_unfolded")
	var working_save: String=core.save_path
	core.save_path="user://qa/mail-workbench/"+run_id+"/blocked_directory"
	DirAccess.make_dir_recursive_absolute(core.save_path)
	var before_close:=close_count
	_check(not bench.checkpoint_for_quit() and not bench._closing,"failed window-close checkpoint refuses to dismiss current material")
	await _key(KEY_ESCAPE)
	_check(close_count==before_close and not core.last_save_error.is_empty(),"failed save keeps real workbench and material state open")
	core.save_path=working_save
	await _key(KEY_ESCAPE)
	_check(close_count==before_close+1,"retrying successful save closes exactly once")
	await _destroy_bench()
	await _show("case02")
	await _tool("opener")
	_check(core.remaining_openings()==0 and bench.model.export_state().opened_count==0 and bench.model.export_state().seal_condition=="intact","a fourth envelope cannot start an effective physical breach")
	_check(core.state.active_operation.is_empty() and bench._message.contains("三次"),"fourth attempt supplies a clear limit explanation before any tool touches paper")
	await _key(KEY_ESCAPE);await _destroy_bench()
	core.free()
	await _amendment_inputs()
	core.free()
	var report: Dictionary={"suite":"mail_workbench_input","checks":checks,"failures":failures,"completed_operations":completed,"closed_events":close_count,"screenshots":screenshot_paths,"engine":Engine.get_version_info(),"scope":"Routed Input.parse_input_event + actual Control GUI/model/core, isolated save. Focus loss uses a simulated notification. No operating-system mouse or human-player claim.","board_sha256":FileAccess.get_sha256("res://scripts/rebuild/mail_workbench.gd"),"art_readiness":Bench.Art.readiness(["BG_workroom","envelope_front","envelope_back","letter_paper","drawer_open","drawer_front","magnifier","opener","restorer","press","eraser","sealer","repair_label","protector","envelope_flap","attachment_photo","replacement_strip"]),"test_sha256":FileAccess.get_sha256("res://tests/mail_workbench_input_smoke.gd"),"physical_sha256":FileAccess.get_sha256("res://scripts/rebuild/mail_physics_state.gd"),"core_sha256":FileAccess.get_sha256("res://scripts/rebuild/final_case_state.gd"),"review":{"A":"Actual routed input chains and negative boundaries tested.","B":"Final package sequence implemented; reference full-flow and tactile comparison remain NEEDS_REFERENCE_REVIEW.","C":"Cancellation, focus loss, transformed input rounding and save failure tested; no game-over shortcuts.","D":"GPU screenshots inspected separately; no audio listening or keyboard-only accessibility pass claimed.","E":"Independent component only; not the full playable-host or release verification."}}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file:=FileAccess.open("res://test-results/mail_workbench_input_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MAIL WORKBENCH INPUT: %d checks, %d failures"%[checks,failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _show(id: String) -> void:
	_ok(core.take_case(id),"take "+id)
	bench=Bench.new();bench.size=Vector2(1600,900)
	var theme:=Theme.new();theme.default_font=load("res://assets/fonts/SolmereSans.ttf");bench.theme=theme
	root.add_child(bench)
	bench.closed.connect(func() -> void: close_count+=1)
	bench.inspection_completed.connect(func(mode: String) -> void: completed.append(mode))
	_ok(bench.configure(core,id),"configure actual workbench "+id)
	await process_frame

func _assert_quit_checkpoint(context: String) -> void:
	var physical: Dictionary=bench.model.export_state()
	var budget: int=core.remaining_openings()
	var closes: int=close_count
	_check(bench.checkpoint_for_quit(),"window-close checkpoint saves "+context)
	_check(close_count==closes and not bench._closing,"window-close checkpoint leaves host in control for "+context)
	var probe:=Core.new();probe.save_path=core.save_path
	_check(probe.load_game(),"independent load after window-close checkpoint for "+context)
	var stored: Dictionary=probe.case_state(bench.case_id).physical
	for field: String in ["opened_count","seam_count","body_unfolded","tamper_trace","erase_mask","replacement_placed","attachment_location"]:
		_check(stored.get(field)==physical.get(field),"window-close checkpoint retains "+field+" for "+context)
	_check(probe.remaining_openings()==budget,"window-close checkpoint retains shift-wide opening budget for "+context)
	probe.free()
func _amendment_inputs() -> void:
	core=Core.new();core.save_path="user://qa/mail-workbench/"+run_id+"/amendments.json";core.new_game()
	_ok(core.take_case("case01"),"amendment fixture takes initial teaching mail")
	_ok(core.inspect_envelope("case01","front"),"amendment fixture actually inspects first envelope")
	_ok(core.dispose("case01","hold_for_verification","","QA setup: preserve this first envelope while its address is verified."),"amendment fixture uses legitimate first-case record")
	_record_fixture_resolution()
	var catalog_hash:=FileAccess.get_sha256("res://data/rebuild/final_cases.json")
	var choices: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rebuild/player_amendments.json"))
	await _show("case02")
	await _tool("eraser")
	_check(not bench._amending and bench.model.export_state().erase_mask==0 and core.amendment_options("case02").is_empty(),"sealed letter reveals no selected sentence or edit controls")
	await _open_paper()
	var source: String=core.source_body_text("case02")
	var original: String=choices.cases.case02.slots[0].original
	await _tool("eraser")
	_check(bench._amending,"real tool selection enters the actual unfolded sentence surface")
	await _shot("04b_case02_original_selected_phrase")
	var phrase: Rect2=bench.model.object_rect("phrase")
	await _click(bench.to_canvas(phrase.position+Vector2(8,12)))
	_check(bench.model.export_state().erase_mask>0 and bench.model.export_state().erase_mask<255,"one physical eraser spot cannot clear the whole selected sentence")
	_check(core.body_text("case02")==source,"partial material erasure has not silently rewritten the source body")
	_assert_quit_checkpoint("partly erased selected sentence")
	_check(bench._amending,"window-close checkpoint works without silently leaving amendment view")
	await _key(KEY_ESCAPE);await _key(KEY_ESCAPE);await _destroy_bench()
	var loaded:=Core.new();loaded.save_path=core.save_path
	_check(loaded.load_game(),"partial selected-sentence work survives real disk reload")
	core.free();core=loaded
	await _show("case02")
	_check(bench.model.export_state().erase_mask>0 and core.remaining_openings()==2,"partial erasure restores without consuming another opening")
	await _erase_selected()
	_check(not original in core.body_text("case02") and original in core.source_body_text("case02"),"complete real erasure changes only player version while immutable source remains")
	await _shot("05_case02_erased_phrase")
	await _drag_to("replacement",bench.model.object_rect("phrase").position)
	var replacement: String=choices.cases.case02.slots[0].options[1].text
	_check(bench.model.export_state().replacement_placed and replacement in core.body_text("case02"),"actual aligned replacement strip publishes only the allowed sentence")
	_check(core.source_body_text("case02")==source,"source text remains byte-for-byte available after replacement")
	await _shot("06_case02_replacement")
	await _key(KEY_ESCAPE)
	await _click(bench.to_canvas(bench.model.object_rect("paper").get_center()),MOUSE_BUTTON_LEFT,true)
	await _click(bench.reader_toggle_rect().get_center())
	_check(bench.body_reader.visible and bench.body_reader.text==source,"actual reading toggle shows preserved original body after replacement")
	await _click(bench.reader_toggle_rect().get_center())
	_check(bench.body_reader.text==core.body_text("case02"),"actual reading toggle returns to the altered paper version")
	await _key(KEY_ESCAPE)
	await _reseal();await _key(KEY_ESCAPE);await _destroy_bench()
	_check(core.case_state("case02").physical.replacement_placed and core.remaining_openings()==2,"resealing keeps replacement and preserves one-opening cost")
	await _show("case03");await _open_paper();await _tool("amend")
	var slot: Vector2=bench.model.object_rect("attachment_slot").position
	await _drag_to("attachment",slot+Vector2(-30,0))
	_check(bench.model.export_state().attachment_location=="with_letter","invalid actual photo drop does not remove the original attachment")
	var tray: Vector2=bench.model.object_rect("attachment_tray").position+Vector2(8,8)
	await _drag_to("attachment",tray)
	_check(core.case_state("case03").physical.attachment_location=="desk","photo is physically outside the letter after valid tray drop")
	await _shot("07_case03_photo_removed")
	await _key(KEY_ESCAPE);await _key(KEY_ESCAPE);await _destroy_bench()
	loaded=Core.new();loaded.save_path=core.save_path
	_check(loaded.load_game(),"detached original photograph survives actual close and reload")
	core.free();core=loaded
	await _show("case03");await _tool("amend")
	_check(bench.model.export_state().attachment_location=="desk","reopening the table does not silently put photo back")
	await _drag_to("attachment",bench.model.object_rect("attachment_slot").position)
	_check(core.case_state("case03").physical.attachment_location=="with_letter" and core.case_state("case03").physical.attachment_moved,"actual photo return restores attachment while retaining handling history")
	await _shot("08_case03_photo_returned")
	await _reseal();await _key(KEY_ESCAPE);await _destroy_bench()
	_ok(core.travel("community_center",15),"amendment route reaches public mailpoint")
	_ok(core.observe("june_current_mailpoint"),"amendment route observes legitimate archive prerequisite")
	_ok(core.travel("post_office",15),"amendment route returns to archive")
	_ok(core.discover_archive_box(),"amendment route discovers case04")
	await _show("case04");await _open_paper();await _erase_selected()
	var departure: String=choices.cases.case04.slots[0].original
	_check(not departure in core.body_text("case04") and departure in core.source_body_text("case04"),"second allowed case supports physical erase-only choice without source overwrite")
	await _reseal();await _key(KEY_ESCAPE);await _destroy_bench()
	_check(core.remaining_openings()==0 and core.state.opening_history.size()==3,"all rewriting and attachment handling use only the three original breaches")
	_check(FileAccess.get_sha256("res://data/rebuild/final_cases.json")==catalog_hash,"actual UI editing never mutates author catalog file")

func _record_fixture_resolution() -> void:
	_ok(core.record_resolution("case01",{"determination":{"recipient":"未核实","location":"原地址待核实","status":"待核实"},"disposition":"hold_for_verification","note":"QA fixture retained for verification.","stamped":true}),"public core setup records explicit first-case resolution before later component fixtures")

func _erase_selected() -> void:
	await _tool("eraser")
	var phrase: Rect2=bench.model.object_rect("phrase")
	await _move(bench.to_canvas(phrase.position+Vector2(3,12)));await _button(MOUSE_BUTTON_LEFT,true)
	await _move(bench.to_canvas(phrase.position+Vector2(phrase.size.x-3,12)));await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench.model.export_state().erase_mask==255,"real held eraser stroke crosses every selected text segment")

func _destroy_bench() -> void:
	bench.queue_free();await process_frame;await process_frame

func _open_paper() -> void:
	await _tool("opener")
	var index: int=bench.model.export_state().seam_count
	await _move(bench.to_canvas(bench.model.seam_point(index)))
	await _button(MOUSE_BUTTON_LEFT,true)
	await _move(bench.to_canvas(bench.model.seam_point(8)))
	await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench.model.export_state().seam_count==9 and core.body_text(bench.case_id).is_empty(),"real held stroke opens seam without instant body")
	await _drag_object("paper",Vector2(220,0))
	_check(core.body_text(bench.case_id).is_empty(),"extracted folded paper still withholds full body")
	await _drag_object("fold_0",Vector2(120,0))
	_check(core.body_text(bench.case_id).is_empty(),"one unfolded panel does not grant all body")
	await _drag_object("fold_1",Vector2(0,120))

func _drawer_open() -> void:
	if bench.drawer.opened:return
	var start:Vector2=bench.drawer_handle_rect().get_center()
	await _move(start);await _button(MOUSE_BUTTON_LEFT,true)
	await _move(start+Vector2(0,44));await _button(MOUSE_BUTTON_LEFT,false)
	_check(bench.drawer.opened,"drawer opens only after real downward movement")

func _tool(id:String) -> void:
	if id=="hand":await _click(Vector2(330,110),MOUSE_BUTTON_RIGHT);return
	if id=="reseal":
		if bench._amending:await _key(KEY_ESCAPE)
		await _click(bench.to_canvas(bench.model.object_rect("fold_0").get_center()))
		return
	if id=="amend":
		await _click(bench.to_canvas(bench.model.object_rect("attachment").get_center()))
		return
	await _drawer_open()
	await _click(bench.tool_rect(id).get_center())

func _reseal() -> void:
	await _tool("reseal")
	await _drag_object("fold_0",Vector2(120,0));await _drag_object("fold_1",Vector2(0,120))
	var mouth: Vector2=bench.model.object_rect("envelope").position+Vector2(420,65)
	await _drag_to("paper",mouth)
	await _drag_object("flap",Vector2(0,90))
	await _tool("sealer");await _click(bench.to_canvas(bench.model.object_rect("flap").get_center()))

func _drag_to(id: String, destination: Vector2) -> void:
	await _drag_object(id,destination-bench.model.object_rect(id).position)

func _drag_object(id: String, delta: Vector2) -> void:
	var start: Vector2=bench.model.object_rect(id).get_center()
	await _move(bench.to_canvas(start));await _button(MOUSE_BUTTON_LEFT,true)
	await _move(bench.to_canvas(start+delta));await _button(MOUSE_BUTTON_LEFT,false)

func _move(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=point-pointer
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=point;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func _button(button: MouseButton, pressed: bool, double_click: bool=false) -> void:
	var event:=InputEventMouseButton.new();event.position=pointer;event.global_position=pointer;event.button_index=button;event.pressed=pressed;event.double_click=double_click
	if button==MOUSE_BUTTON_LEFT: held=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func _click(point: Vector2, button: MouseButton=MOUSE_BUTTON_LEFT, twice: bool=false) -> void:
	await _move(point);await _button(button,true,twice);await _button(button,false)

func _key(key: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func _shot(name: String) -> void:
	if "--capture-input" not in OS.get_cmdline_user_args(): return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	var path:=OUT+name+".png"
	_check(root.get_texture().get_image().save_png(path)==OK,"actual GPU screenshot "+name)
	screenshot_paths.append(path)

func _ok(error: String, message: String) -> void: _check(error.is_empty(),message+(": "+error if not error.is_empty() else ""))
func _check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message);push_error(message)
