extends SceneTree
## Run: Godot --headless --path . --script res://tests/physical_smoke.gd
## Drives the same local pointer/key handlers as the playable board. The test
## creates no GameSession and never loads, changes, or writes a player save.

const Board = preload("res://scripts/ui/physical_board.gd")
var board: Control
var completions: Array[Dictionary] = []
var latest_progress: Dictionary = {}
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _button(at: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = board._canvas_origin() + at * board._scale_factor()
	event.button_index = button
	event.pressed = pressed
	board._gui_input(event)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = board._canvas_origin() + at * board._scale_factor()
	board._gui_input(event)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	board._gui_input(event)


func _drag(from: Vector2, to: Vector2, hold: float = 0.0) -> void:
	_button(from, true)
	_move(to)
	if hold > 0.0:
		board._process(hold)
	_button(to, false)


func _run() -> void:
	board = Board.new()
	# Same non-square scale/centering constraints as the main modal.
	board.size = Vector2(1300, 618)
	root.add_child(board)
	board.completed.connect(func(which: String, result: Dictionary) -> void: completions.append({"mode": which, "result": result}))
	board.progress.connect(func(data: Dictionary) -> void: latest_progress = data)
	await process_frame
	_test_fragments()
	_test_open()
	_test_restore()
	_test_archive()
	print("PHYSICAL SMOKE: %d checks, %d failures" % [checks, failures.size()])
	board.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_fragments() -> void:
	board.configure("fragments", {})
	_drag(board._pieces[1].position, board._pieces[1].target)
	_check(not board._pieces[1].locked, "wrong fragment orientation cannot snap")
	_drag(board._pieces[0].position, Vector2(450, 220))
	_check(not board._pieces[0].locked, "fragment outside the mild snap radius remains loose")
	for index: int in range(6):
		var piece: Dictionary = board._pieces[index]
		for turn: int in range((4 - int(piece.turn)) % 4):
			_button(piece.position, true, MOUSE_BUTTON_RIGHT)
		_drag(piece.position, piece.target)
		_check(piece.locked, "fragment %d joins only after rotation and placement" % (index + 1))
	_check(latest_progress.get("pieces", []).size() == 6, "progress contains all six fragment positions")
	board._process(1.3)
	_check(_last_mode() == "fragments", "joined address emits a single completion")
	var completion_count: int = completions.size()
	board._process(1.0)
	_check(completions.size() == completion_count, "completed board cannot emit a second completion")
	board.configure("fragments", {}, latest_progress)
	board._process(0.5)
	_check(_last_result().get("pieces", 0) == 6, "saved joined board resumes without a dead end")
	# Keyboard rotation also uses the public GUI event handler.
	board.configure("fragments", {})
	_button(board._pieces[0].position, true)
	_button(board._pieces[0].position, false)
	_key(KEY_R)
	_check(board._pieces[0].turn == 1, "R rotates the selected fragment")


func _test_open() -> void:
	board.configure("open", {})
	board._process(60.0)
	_check(board._trace_distance == 0.0, "idle time never opens a letter")
	_button(board._path[0], true)
	_check(not board._dragging, "a fictional tool must be selected before tracing")
	_button(Vector2(130, 125), true)
	_button(Vector2(130, 125), false)
	_button(board._path[0], true)
	_move(board._path[-1])
	board._process(0.1)
	_check(board.stage == 0 and board._trace_distance == 0.0, "jumping directly to the endpoint cannot open the seal")
	_check(board._mistakes > 0, "a tool jump leaves a visible mistake record")
	for index: int in range(26):
		_move(board._path[index])
		board._process(0.11)
	_button(board._path[25], false)
	var saved_trace: float = board._trace_distance
	_check(saved_trace > 100.0 and board.stage == 0, "continuous held tracing makes partial progress")
	board.configure("open", {}, latest_progress)
	_check(is_equal_approx(board._trace_distance, saved_trace), "partial seal progress survives reopening the board")
	_button(board._point_on_path(board._trace_distance), true)
	for index: int in range(26, board._path.size()):
		_move(board._path[index])
		board._process(0.11)
	_check(board.stage == 1, "following the whole curved path exposes the folded page")
	_check(_last_mode() != "open", "seal traversal alone does not reveal the body")
	_drag(Vector2(520, 294), Vector2(520, 235))
	_check(not board._finishing, "a tiny page movement does not count as unfolding")
	_drag(board._moving, Vector2(520, 130))
	board._process(0.5)
	_check(_last_mode() == "open" and _last_result().get("tool", "") == "safe", "manual extraction completes opening with the chosen tool")
	board.configure("open", {})
	_button(Vector2(430, 125), true)
	_button(Vector2(430, 125), false)
	_button(board._path[0], true)
	_move(board._path[0] + Vector2(0, 25))
	board._process(0.1)
	_check(board._mistakes == 1, "quick tool records a deviation outside its narrow tolerance")
	_button(board._path[0], false)
	board.configure("open", {})
	_button(Vector2(130, 125), true)
	_button(Vector2(130, 125), false)
	_button(board._path[0], true)
	_move(board._path[0] + Vector2(0, 25))
	board._process(0.1)
	_check(board._mistakes == 0, "safe tool tolerates the same small deviation")
	_button(board._path[0], false)
	board.configure("open", {})
	_button(Vector2(430, 125), true)
	_button(Vector2(430, 125), false)
	_button(board._path[0], true)
	for slip: int in range(6):
		_move(board._path[0] + Vector2(0, 60))
		board._process(0.1)
		_move(board._path[0])
		board._process(0.1)
		if slip == 2:
			_check("起毛" in board._message, "third separate slip visibly warns that the paper is fraying")
	_check(board._mistakes == 6 and "损坏" in board._message, "sixth slip warns of damage before the failure threshold")
	_button(board._path[0], false)
	_button(board._path[0], true)
	_check("损坏" in board._message, "damage warning survives releasing and regripping the tool")
	_button(board._path[0], false)


func _test_restore() -> void:
	board.configure("restore", {})
	_drag(board._moving, Vector2(440, 325))
	_check(board.stage == 0, "bad alignment cannot skip the fold step")
	_drag(board._moving, board.PAGE_TARGET)
	_check(board.stage == 1, "page placed on fold silhouette unlocks the torn edge")
	_drag(board._moving, board.EDGE_TARGET)
	_check(board.stage == 2, "fitted edge unlocks repair tape")
	board.configure("restore", {}, latest_progress)
	_check(board.stage == 2, "restoration resumes at the completed physical stage")
	_drag(board._moving, board.TAPE_TARGET)
	_check(board.stage == 3, "positioned repair tape unlocks the stamp")
	_drag(board._moving, board.STAMP_TARGET, 0.1)
	_check(not board._finishing, "a tap cannot replace the held repair stamp")
	_drag(board._moving, board.STAMP_TARGET, 0.7)
	board._process(0.8)
	_check(_last_mode() == "restore", "held stamp finishes the physical repair")
	_check(float(_last_result().get("quality", 1.0)) < 0.99, "misalignment changes concealed repair quality")


func _test_archive() -> void:
	var records: Array[Dictionary] = []
	for index: int in range(11):
		records.append({"serial": "S-%02d" % index, "date": "2020-07-18", "status": "HOLD"})
	records[4]["serial"] = "S-07"
	records[4]["date"] = "2020-07-17"
	board.configure("archive", {"records": records, "match_serial": "S-07", "match_date": "2020-07-18"})
	_check(board._records.size() == 11, "archive board loads all eleven original records")
	_drag(board._moving, board._archive_row_rect(3).get_center())
	_check(not board._finishing, "archive rejects the correct date with a different serial")
	_drag(board._moving, board._archive_row_rect(4).get_center())
	_check(not board._finishing, "archive rejects the correct serial with a different date")
	_drag(board._moving, board._archive_row_rect(7).get_center())
	board._process(1.3)
	_check(_last_mode() == "archive" and _last_result().get("serial", "") == "S-07", "physically placed stamp matches both serial and date")


func _last_mode() -> String:
	return str(completions[-1].get("mode", "")) if not completions.is_empty() else ""


func _last_result() -> Dictionary:
	return completions[-1].get("result", {}) if not completions.is_empty() else {}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
