extends SceneTree
## Real InputEvent dispatch to an isolated UI; no Core, no automatic disposition.
const Slip = preload("res://scripts/rebuild/resolution_slip.gd")
var slip: Control
var checks := 0
var failures: Array[String] = []
var submissions: Array[Dictionary] = []
var closures: Array[Dictionary] = []
var cues: Array[String] = []
var captures: Array[String] = []
var render := false


func _initialize() -> void:
	_run.call_deferred()


func _fixture() -> Dictionary:
	return {"case_id":"case01", "case_label":"01 · 当班记录", "locale":"zh",
		"known_facts":[{"label":"信封正面", "text":"Elsie Moran\n17 Old Quay Lane", "source":"已查看的信封"}, {"label":"瓷质门牌", "text":"旧牌上保留数字 17。", "source":"居民楼 · 09:15"}, {"label":"邮局收件", "text":"信封尚未拆开。", "source":"柜台"}],
		"determination_fields":[{"id":"recipient","label":"收件人"},{"id":"location","label":"现行地点／待核实处"},{"id":"status","label":"邮件现状"}],
		"dispositions":[{"id":"deliver","label":"交付"},{"id":"hold_for_verification","label":"留待核实","requires_note":true},{"id":"return_to_sender","label":"退回寄件人","requires_note":true}]}


func _run() -> void:
	root.size = Vector2i(1600,900)
	root.content_scale_size = Vector2i(1600,900)
	root.title = "Solmere isolated postal resolution slip"
	render = "--render-resolution" in OS.get_cmdline_user_args()
	slip = Slip.new()
	slip.size = Vector2(1600,900)
	root.add_child(slip)
	slip.submitted.connect(func(result: Dictionary): submissions.append(result.duplicate(true)))
	slip.closed.connect(func(draft: Dictionary): closures.append(draft.duplicate(true)))
	slip.cue.connect(func(name: String): cues.append(name))
	await process_frame
	_check(slip.configure({}) == "missing_case_id", "invalid payload rejected")
	var fixture := _fixture()
	_check(slip.configure(fixture).is_empty(), "valid known-only payload")
	await process_frame
	_check(submissions.is_empty(), "configure does not submit")
	fixture.known_facts[0].text = "external mutation"
	_check(slip._payload.known_facts[0].text != "external mutation", "payload is copied")
	await _capture("resolution_blank")
	await _drag(Slip.SEAL_HOME.get_center(),Slip.SEAL_AREA.get_center())
	_check(submissions.is_empty(), "seal cannot submit unreviewed slip")
	await _click_node("ReviewSlip")
	_check(not slip._reviewing, "missing fields prevent review")
	await _fill("Field_recipient", "Elsie Moran")
	await _fill("Field_location", "9 Bay Steps")
	await _fill("Field_status", "Sealed; old address")
	_check(slip.export_draft().determination.recipient == "Elsie Moran", "real keyboard fills recipient")
	_check(slip.export_draft().determination.location == "9 Bay Steps", "real keyboard fills location")
	await _click_node("ReviewSlip")
	_check(not slip._reviewing, "no disposition prevents review")
	await _click_node("Disposition_hold_for_verification")
	await _click_node("ReviewSlip")
	_check(not slip._reviewing, "hold requires actual note")
	await _fill("ResolutionNote", "Address needs confirmation.")
	await _click_node("ReviewSlip")
	_check(slip._reviewing, "completed slip enters review")
	_check(not slip._fields.recipient.editable and not slip._note.editable, "review freezes editable text")
	await _capture("resolution_review")
	await create_timer(3.15).timeout
	_check(submissions.is_empty(), "review does not auto-stamp after three seconds")
	await _click(Slip.SEAL_AREA.get_center())
	_check(submissions.is_empty(), "clicking empty stamp area cannot submit")
	await _drag(Slip.SEAL_HOME.get_center(), Vector2(965,445))
	_check(submissions.is_empty() and not slip._holding, "wrong drop returns seal without submission")
	await _click_node("ReviewSlip")
	_check(not slip._reviewing, "review can return to edit")
	_check(slip.export_draft().note == "Address needs confirmation.", "review cancellation retains draft")
	await _click_node("Disposition_deliver")
	await _click_node("ReviewSlip")
	await _mouse(Slip.SEAL_HOME.get_center(),true)
	await _motion(Slip.SEAL_AREA.get_center())
	_check(submissions.is_empty(), "holding seal above paper has no effect")
	await _capture("resolution_held")
	await _mouse(Slip.SEAL_AREA.get_center(),false)
	await create_timer(0.25).timeout
	_check(submissions.size() == 1, "actual seal release submits once")
	_check(cues.count("stamp") == 1, "one physical drop emits one stamp cue")
	_check(submissions[0].stamped and submissions[0].disposition == "deliver", "submitted result is selected disposition")
	_check(submissions[0].determination.status == "Sealed; old address", "factual determination is not auto-corrected")
	_check(submissions[0].case_id == "case01", "result identifies its case")
	await _capture("resolution_stamped")
	await _drag(Slip.SEAL_HOME.get_center(),Slip.SEAL_AREA.get_center())
	_check(submissions.size() == 1, "a stamped slip cannot submit twice")
	slip.show_error("Host validation: please review this record.")
	_check(not slip._stamped and not slip._reviewing, "host rejection makes retained draft editable")
	_check(slip.export_draft().determination.recipient == "Elsie Moran", "host rejection preserves entered determination")
	await _key(KEY_ESCAPE)
	_check(closures.size() == 1 and closures[0].note == "Address needs confirmation.", "close emits retained draft")
	await _key(KEY_ESCAPE)
	_check(closures.size() == 1, "close is idempotent")
	await _keyboard_and_resize()
	await _scrolling_records()
	await _schema_boundaries()
	await _synchronous_host_close()
	var report := {"suite":"resolution_slip", "checks":checks, "failures":failures, "scope":"Isolated real Godot InputEvent dispatch, keyboard, resize, stamp and draft boundaries; no core disposal, no host playthrough, no human or reference fidelity claim.","source_sha256":FileAccess.get_sha256("res://scripts/rebuild/resolution_slip.gd"),"test_sha256":FileAccess.get_sha256("res://tests/resolution_slip_smoke.gd"),"screenshots":captures,"renderer":RenderingServer.get_current_rendering_method()}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file := FileAccess.open("res://test-results/resolution_slip_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RESOLUTION SLIP: %d checks, %d failures" % [checks,failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _keyboard_and_resize() -> void:
	var payload := _fixture()
	payload.locale = "en"
	payload.case_label = "01 · Shift record"
	payload.known_facts = [{"label":"Envelope front","text":"Elsie Moran\n17 Old Quay Lane","source":"Inspected envelope"},{"label":"Ceramic number plate","text":"The old plate retains the number 17.","source":"Residential building · 09:15"}]
	payload.determination_fields = [{"id":"recipient","label":"Recipient"},{"id":"location","label":"Current location / pending check"},{"id":"status","label":"Condition of the mail"}]
	payload.dispositions = [{"id":"deliver","label":"Delivered"}]
	payload.default_disposition = "deliver"
	payload.draft = {"determination":{"recipient":"Elsie Moran","location":"9 Bay Steps","status":"Already delivered"},"note":"Recorded after handoff."}
	_check(slip.configure(payload).is_empty(), "completed handoff can preselect single actual disposition")
	await process_frame
	_check(slip.export_draft().disposition == "deliver", "actual action preserved without automatic stamp")
	var before := submissions.size()
	await _click_node("ReviewSlip")
	# Real keyboard focus traversal to the seal, rather than calling its callback.
	await _key(KEY_TAB)
	_check(slip._seal_button.has_focus(), "Tab reaches unique physical seal")
	await _key(KEY_ENTER)
	_check(slip._holding, "Enter picks up seal for accessible movement")
	await _key(KEY_ESCAPE)
	_check(not slip._holding and closures.size() == 1, "Escape returns held seal without closing slip")
	await _key(KEY_ENTER)
	for index: int in range(5): await _key(KEY_LEFT)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await create_timer(0.25).timeout
	_check(submissions.size() == before+1, "keyboard movement and drop submits via same physical target")
	for dimensions: Vector2 in [Vector2(1280,720),Vector2(1920,1080),Vector2(1200,900)]:
		root.content_scale_size = Vector2i(dimensions)
		root.size = Vector2i(dimensions)
		slip.size = dimensions
		_check(slip.configure(payload).is_empty(), "scaled slip configures")
		await process_frame
		await _click_node("ReviewSlip")
		_check(slip._reviewing, "scaled real pointer reaches review")
		var count := submissions.size()
		await _drag(Slip.SEAL_HOME.get_center(),Slip.SEAL_AREA.get_center())
		await create_timer(0.25).timeout
		_check(submissions.size() == count+1, "scaled real drag hits stamp area")
		await _capture("resolution_%dx%d" % [int(dimensions.x),int(dimensions.y)])
	root.content_scale_size = Vector2i(1600,900)
	root.size = Vector2i(1600,900)
	slip.size = Vector2(1600,900)


func _scrolling_records() -> void:
	var payload := _fixture()
	payload.dispositions = []
	for index: int in range(9): payload.dispositions.append({"id":"route_%d" % index,"label":"待复核处置 %d" % index})
	for index: int in range(12): payload.known_facts.append({"label":"现场记录 %d" % index,"text":"已观察纸面上的独立内容。记录来自实际查看，不提供事实判断的答案。","source":"现场"})
	_check(slip.configure(payload).is_empty(), "many evidence slips and nine permitted actions configure")
	await process_frame
	await process_frame
	var actions: ScrollContainer = slip.find_child("DispositionChoices",true,false)
	var facts: ScrollContainer = slip.find_child("ObservedFacts",true,false)
	for index: int in range(24): await _wheel(actions.get_global_rect().get_center())
	_check(actions.scroll_vertical > 0, "real wheel reaches actions beyond the first three")
	var last_action: Control = slip.find_child("Disposition_route_8",true,false)
	_check(actions.get_global_rect().has_point(last_action.get_global_rect().get_center()), "last allowed action is visible after scrolling")
	await _click_node("Disposition_route_8")
	_check(slip.export_draft().disposition == "route_8", "last action can be selected by real pointer")
	for index: int in range(26): await _wheel(facts.get_global_rect().get_center())
	_check(facts.scroll_vertical > 0, "long factual records remain reachable by real wheel")
	_check(slip.export_draft().determination.recipient.is_empty(), "scrolling evidence does not fill player judgement")
	await _capture("resolution_scrolled_evidence")


func _wheel(at: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_WHEEL_DOWN;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
		await process_frame


func _schema_boundaries() -> void:
	var payload := _fixture()
	payload.dispositions.append(payload.dispositions[0].duplicate())
	_check(slip.configure(payload) == "duplicate_dispositions_id", "duplicate dispositions rejected")
	payload = _fixture();payload.known_facts=[{"text":42}]
	_check(slip.configure(payload) == "invalid_fact", "malformed fact rejected")
	payload = _fixture();payload.draft={"determination":"secret"}
	_check(slip.configure(payload) == "invalid_draft_fields", "malformed draft rejected")
	payload = _fixture();payload.default_disposition="unlisted_action"
	_check(slip.configure(payload).is_empty() and slip.export_draft().disposition.is_empty(), "unlisted action cannot enter draft")
	await process_frame
	await _fill("Field_recipient", "x".repeat(95))
	_check(slip.export_draft().determination.recipient.length() == 80, "real field input bounded to core limit")
	var copied: Dictionary = slip.export_draft()
	copied.determination.recipient="mutated"
	_check(slip.export_draft().determination.recipient != "mutated", "exported draft is isolated copy")
	await _key(KEY_ESCAPE)


func _synchronous_host_close() -> void:
	var other: Control = Slip.new()
	other.size = Vector2(1600,900)
	root.add_child(other)
	await process_frame
	_check(other.configure(_fixture()).is_empty(), "temporary host-mounted slip configures")
	other.closed.connect(func(_draft: Dictionary):root.remove_child(other))
	await _key(KEY_ESCAPE)
	_check(other.get_parent() == null, "Escape tolerates host synchronously removing the component")
	other.free()


func _point(design: Vector2) -> Vector2:
	return slip.global_position + slip._origin + design * slip._factor


func _click_node(id: String) -> void:
	var node: Control = slip.find_child(id,true,false)
	_check(is_instance_valid(node), "input node exists: "+id)
	if not is_instance_valid(node): return
	var at: Vector2 = node.get_global_rect().get_center()
	await _raw_mouse(at,true)
	await _raw_mouse(at,false)


func _fill(id: String, text: String) -> void:
	await _click_node(id)
	await _key(KEY_A,true)
	for character: String in text:
		var event := InputEventKey.new()
		event.pressed=true;event.unicode=character.unicode_at(0)
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _key(code: int, control: bool=false) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code;event.pressed=down;event.ctrl_pressed=control
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _raw_mouse(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame


func _mouse(at: Vector2, down: bool) -> void:
	await _raw_mouse(_point(at),down)


func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=_point(at);event.global_position=event.position;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame


func _click(at: Vector2) -> void:
	await _mouse(at,true);await _mouse(at,false)


func _drag(from: Vector2, to: Vector2) -> void:
	await _mouse(from,true)
	for index: int in range(1,7): await _motion(from.lerp(to,float(index)/6.0))
	await _mouse(to,false)


func _capture(name: String) -> void:
	if not render: return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://test-results/resolution_slip/"+name+".png"
	DirAccess.make_dir_recursive_absolute("res://test-results/resolution_slip")
	_check(root.get_texture().get_image().save_png(path) == OK, "GPU capture "+name)
	captures.append(path.trim_prefix("res://"))


func _check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message);printerr("FAIL: "+message)
