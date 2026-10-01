extends SceneTree
## Pointer-driven provisional evidence test. Uses source data but no player save.

const Board = preload("res://scripts/ui/deduction_board.gd")
var board: Control
var results: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _button(at: Vector2, pressed: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = board._origin() + at * board._scale_factor()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double_click
	board._gui_input(event)


func _drag(id: String, role: String) -> void:
	var index: int = board._find_card(id)
	var start: Vector2 = board._cards[index].position
	var end: Vector2 = board._slot_center(role)
	_button(start, true)
	var event := InputEventMouseMotion.new()
	event.position = board._origin() + end * board._scale_factor()
	board._gui_input(event)
	_button(end, false)


func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var clues: Dictionary = catalog.get("clues", {})
	board = Board.new()
	board.size = Vector2(1210, 594)
	root.add_child(board)
	board.recorded.connect(func(value: Dictionary) -> void: results.append(value))
	await process_frame
	board.configure(clues, ["old_nameplate", "event_archive"])
	_check(board._cards.size() == 2 and board._find_card("handwriting_sample") == -1, "only actually known clue cards appear")
	_button(board.SEAL, true)
	_button(board.SEAL, false)
	board._process(1.0)
	_check(results.is_empty(), "seal does not register missing evidence")
	board.configure(clues, board.ORDER)
	var first: Vector2 = board._cards[0].position
	_button(first, true, true)
	_button(first, false)
	_check(board._detail_id == "old_nameplate" and str(clues.old_nameplate.text) in board._detail_view.text, "double-click exposes the complete source text without clipping it to a small card")
	_button(board.DETAIL_CLOSE.get_center(), true)
	_button(board.DETAIL_CLOSE.get_center(), false)
	_check(board._detail_id.is_empty() and board.claims.is_empty(), "reading a card never assigns or solves its role")
	# Deliberately wrong associations must remain valid provisional claims.
	_drag("old_nameplate", "sender")
	_drag("handwriting_sample", "date")
	_drag("event_archive", "address")
	_check(board.claims.get("sender") == "old_nameplate" and board.claims.get("date") == "handwriting_sample", "board accepts misplaced roles without early correctness feedback")
	_check(results.is_empty(), "placing all three cards does not auto-register the inference")
	_drag("event_archive", "sender")
	_check(board.claims.get("sender") == "event_archive" and board.claims.get("address") == "old_nameplate", "occupied slots exchange cards rather than duplicate evidence")
	_drag("old_photo", "date")
	_check(board.claims.get("date") == "old_photo" and board._role_for("handwriting_sample").is_empty(), "a fourth independent record can replace an earlier selection")
	var saved: Dictionary = board.claims.duplicate(true)
	board.configure(clues, board.ORDER, saved)
	_check(board.claims == saved and board._cards[board._find_card("old_photo")].position == board._slot_center("date"), "previous provisional arrangement restores physically onto the table")
	_button(board.SEAL, true)
	_button(board.SEAL, false)
	board._process(0.4)
	_check(results.size() == 1 and results[0] == saved, "physical seal emits the player's exact three role claims")
	board._process(2.0)
	_check(results.size() == 1, "registered arrangement emits only once")
	board.configure(clues, ["old_nameplate", "old_photo"], {"address":"old_nameplate", "date":"old_nameplate", "sender":"handwriting_sample"})
	_check(board.claims.size() == 1 and board.claims.get("address") == "old_nameplate", "resume cannot fabricate unknown cards or reuse one record twice")
	print("DEDUCTION SMOKE: %d checks, %d failures" % [checks, failures.size()])
	board.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
