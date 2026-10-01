extends SceneTree
## Actual Godot input dispatch to isolated Control + actual final state.
## --render-observation additionally captures GPU pixels, not a Main playthrough.
const Board = preload("res://scripts/rebuild/field_observation.gd")
const Core = preload("res://scripts/rebuild/final_case_state.gd")
var core: Node
var board: Control
var checks := 0
var failures: Array[String] = []
var images: Array[String] = []
var close_count := 0
var render := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	root.title = "Solmere isolated field observation test"
	render = "--render-observation" in OS.get_cmdline_user_args()
	core = Core.new()
	core.save_path = "user://qa/field_observation/state.json"
	root.add_child(core)
	await process_frame
	for id: String in Board.PUBLIC_IDS:
		await _prepare(id)
		var before: Dictionary = core.state.evidence.duplicate(true)
		var minute: int = core.state.minute
		_check(board.configure(core, id).is_empty(), id + " configures")
		await process_frame
		_check(core.state.evidence == before, id + " configure grants nothing")
		await _click(Vector2(190, 235))
		_check(core.state.evidence == before, id + " irrelevant click grants nothing")
		match str(board._spec.kind):
			"plate":
				await _capture("ceramic_before")
				await _drag(Board.NEW_PLATE.get_center(), Vector2(160, 0))
				_check(not core.has_evidence(id), "partial plate movement does not register unseen old number")
				await _drag(Board.NEW_PLATE.get_center() + Vector2(160, 0), Vector2(210, 0))
				await _capture("ceramic_after")
			"door":
				await _click_region("knock")
				await create_timer(0.55).timeout
			"photo":
				_check(not board.get_observation_snapshot().photo_back,"music photograph starts on actual image face")
				_check(board.interaction_regions().filter(func(entry:Dictionary):return str(entry.id).begins_with("row_")).is_empty(),"photo front exposes no hidden caption read targets")
				await _capture("music_photo_front")
				await _photo_button(MOUSE_BUTTON_WHEEL_UP)
				_check(board.get_observation_snapshot().photo_zoom>1.0 and core.state.evidence==before,"actual wheel magnifies photograph without granting its caption")
				await _capture("music_photo_zoom")
				await _photo_button(MOUSE_BUTTON_RIGHT)
				_check(board.get_observation_snapshot().photo_back and core.state.evidence==before,"actual right click reveals back caption but does not auto-record it")
				await _click_region("row_0")
				_check(not core.has_evidence(id),"reading event caption alone does not register unseen participant names")
				await _click_region("row_1")
				await _key(KEY_F)
				_check(not board.get_observation_snapshot().photo_back,"keyboard F returns from caption to image")
				await _click_region("photo_flip")
			_:
				await _click_region("open")
				_check(core.state.evidence == before, id + " turning cover grants nothing")
				var required: Array = board._spec.required
				for index: int in range(required.size()):
					await _click_region("row_%d" % int(required[index]))
					if index < required.size() - 1:
						_check(core.state.evidence == before, id + " partial reading does not grant full source")
		_check(core.has_evidence(board.effective_clue_id), id + " actual source gesture records evidence")
		_check(core.state.minute == minute, id + " reading costs no game time")
		if id in ["telescope_checkout", "telescope_returned", "street_renaming", "ledger_hv_repeat", "old_music_photo", "shuttle_timetable"]:
			await _capture(id)
		var observed: Dictionary = core.state.evidence.duplicate(true)
		await _click_region("close")
		_check(close_count == 1, id + " actual close emits once")
		_check(core.state.evidence == observed, id + " close does not add or remove facts")
	await _boundaries()
	await _keyboard()
	var report := {"suite": "field_observation", "checks": checks, "failures": failures,
		"scope": "Real Godot InputEvent dispatch to isolated field Control and actual FinalCaseState; boundary clock fixtures are explicit. Not OS/human/reference-flow acceptance.",
		"source_sha256": FileAccess.get_sha256("res://scripts/rebuild/field_observation.gd"),
		"core_sha256": FileAccess.get_sha256("res://scripts/rebuild/final_case_state.gd"),
		"catalog_sha256": FileAccess.get_sha256("res://data/rebuild/final_cases.json"),
		"screenshots": images, "renderer": RenderingServer.get_current_rendering_method()}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file := FileAccess.open("res://test-results/field_observation_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("FIELD OBSERVATION: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _prepare(id: String) -> void:
	if is_instance_valid(board):
		board.queue_free()
		await process_frame
	core.new_game()
	if id in ["case04_manual_hold", "ledger_hv_repeat", "helena_rota", "procedure_codes", "ledger_returns"]:
		# Explicit component fixture uses the public first-mail workflow.  This is
		# not a claim that the whole hosted UI route was played in this suite.
		_check(core.take_case("case01").is_empty(), "fixture takes first teaching mail")
		_check(core.inspect_envelope("case01", "front").is_empty(), "fixture reads first envelope")
		_check(core.dispose("case01", "hold_for_verification", "", "Address is retained for verification.").is_empty(), "fixture records legitimate unresolved disposition")
		_check(core.record_resolution("case01", {"determination":{"recipient":"Elsie Moran", "location":"Old address awaiting verification", "status":"Held at Desk B"}, "disposition":"hold_for_verification", "note":"Component setup through public record API.", "stamped":true}).is_empty(), "fixture records required first resolution")
		_check(core.travel("community_center", 15).is_empty(), "fixture visit volunteer register")
		_check(core.observe("june_current_mailpoint").is_empty(), "fixture knows legal mailpoint")
		core.travel("post_office", 15)
		_check(core.discover_archive_box().is_empty(), "fixture old box available")
		if id == "ledger_hv_repeat":
			core.take_case("case04")
			core.observe("case04_manual_hold")
			_check(core.dispose("case04", "archive_review", "", "旧件转档案复核").is_empty(), "fixture handled old item")
	var location: String = str(core.clue_data(id).get("location", "post_office"))
	if location != core.state.location: core.travel(location, 15)
	# Explicit clock fixture tests the 15:05 record, not time advancement gameplay.
	if id == "telescope_returned": core.state.minute = 905
	board = Board.new()
	root.add_child(board)
	close_count = 0
	board.closed.connect(func() -> void: close_count += 1)
	await process_frame


func _boundaries() -> void:
	await _prepare("telescope_checkout")
	core.state.minute = 904
	_check(board.configure(core, "telescope_returned") != "", "future return record rejected before paper appears")
	_check(board._spec.is_empty(), "future return no author fact shown")
	_check(board.configure(core, "telescope_checkout").is_empty(), "pre-return sheet configures")
	_check("归还：________" in board._spec.rows, "15:04 shows empty return field")
	_check(not "归还：15:05" in board._spec.rows, "15:04 hides future timestamp")
	core.state.minute = 905
	_check(board.configure(core, "telescope_checkout").is_empty(), "15:05 checkout resolves current sheet")
	_check(board.effective_clue_id == "telescope_returned", "post-return sheet uses returned evidence")
	await _click_region("open")
	for row: int in [0, 1, 2]: await _click_region("row_%d" % row)
	_check(core.has_evidence("telescope_returned") and not core.has_evidence("telescope_checkout"), "15:05 input records only actual returned record")
	await _prepare("mira_absent")
	board.configure(core, "mira_absent")
	await _click_region("knock")
	await _key(KEY_ESCAPE)
	await create_timer(0.55).timeout
	_check(not core.has_evidence("mira_absent"), "leaving during knock wait cannot grant late evidence")
	_check(close_count == 1, "escape closes once")
	await _prepare("street_renaming")
	board.configure(core, "street_renaming")
	core.travel("bus_stop", 15)
	await _click_region("open")
	await _click_region("row_0")
	_check(not core.has_evidence("street_renaming"), "stale open view cannot bypass location gate")
	core.new_game()
	for id: String in ["elsie_confirmation", "label_reconstructed", "case04_archive_mark", "not_a_clue", "ledger_hv_repeat", "helena_rota"]:
		_check(not board.configure(core, id).is_empty(), id + " unavailable source rejected")
		_check(board._spec.is_empty(), id + " no hidden source leaked")


func _keyboard() -> void:
	await _prepare("ceramic_17")
	board.configure(core, "ceramic_17")
	for index: int in range(3): await _key(KEY_RIGHT)
	_check(core.has_evidence("ceramic_17"), "keyboard plate motion reveals and records original number")
	await _prepare("moran_entry")
	board.configure(core, "moran_entry")
	await _key(KEY_TAB)
	await _key(KEY_ENTER)
	_check(board._page == 1 and not core.has_evidence("moran_entry"), "keyboard opens source without grant")
	await _key(KEY_ENTER)
	_check(core.has_evidence("moran_entry"), "keyboard reads source row")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await _capture("resident_1280")
	await _click_region("close")
	_check(close_count == 1, "1280 input transforms to same close region")


func _click_region(id: String) -> void:
	for region: Dictionary in board.interaction_regions():
		if str(region.id) == id:
			await _click((region.rect as Rect2).get_center())
			return
	_check(false, "missing interactive region " + id)


func _click(point: Vector2) -> void:
	await _mouse(point, true)
	await _mouse(point, false)


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = board._origin + point * board._factor
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _drag(point: Vector2, delta: Vector2) -> void:
	await _mouse(point, true)
	for index: int in range(1, 7):
		var event := InputEventMouseMotion.new()
		event.position = board._origin + (point + delta * index / 6.0) * board._factor
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _mouse(point + delta, false)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _photo_button(button:MouseButton) -> void:
	for pressed:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
		event.position=board._origin+Board.PHOTO.get_center()*board._factor;event.global_position=event.position
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func _capture(name: String) -> void:
	if not render: return
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	_check(not pixels.is_empty(), name + " GPU image exists")
	var path := "res://test-results/field_observation/" + name + ".png"
	DirAccess.make_dir_recursive_absolute("res://test-results/field_observation")
	_check(pixels.save_png(path) == OK, name + " screenshot saved")
	images.append(path)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
