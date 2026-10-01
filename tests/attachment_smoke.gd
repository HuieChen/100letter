extends SceneTree
## Run: Godot --headless --path . --script res://tests/attachment_smoke.gd
## Pointer-driven physical choice regression; no session, save, or screenshot.

const Board = preload("res://scripts/ui/attachment_board.gd")
var board: Control
var decisions: Array[bool] = []
var failures: Array[String] = []
var checks: int = 0
var dismissals: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _button(at: Vector2, pressed: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = board._canvas_origin() + at * board._scale_factor()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double_click
	board._gui_input(event)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = board._canvas_origin() + at * board._scale_factor()
	board._gui_input(event)


func _drag(from: Vector2, to: Vector2) -> void:
	_button(from, true)
	_move(to)
	_button(to, false)


func _run() -> void:
	board = Board.new()
	board.size = Vector2(1210, 594)
	root.add_child(board)
	board.decided.connect(func(value: bool) -> void: decisions.append(value))
	board.dismissed.connect(func() -> void: dismissals += 1)
	await process_frame
	board.configure("We said we’d come back every summer.")
	board._process(60.0)
	_check(decisions.is_empty(), "idle time cannot decide the photograph's destination")
	_button(board._photo_position, true, true)
	_button(board._photo_position, false)
	_check(board.reversed, "double-click turns the photo over to its supplied caption")
	_check(board.photo_text == "We said we’d come back every summer.", "original back caption is preserved")
	_button(board._photo_position, true, true)
	_button(board._photo_position, false)
	_check(not board.reversed, "second double-click returns to the lookout picture")
	_drag(board._photo_position, Vector2(555, 440))
	_check(board.stage == 0 and decisions.is_empty(), "a photo dropped between destinations does not commit")
	_drag(board.ENVELOPE_START + Vector2(0, 65), board.OUTGOING.get_center())
	_check(board.stage == 0 and decisions.is_empty(), "the envelope cannot bypass the initial photograph placement")
	_drag(board._photo_position, board.ENVELOPE_START)
	_check(board.stage == 1 and board.with_photo and decisions.is_empty(), "photo placement in envelope only stages the decision")
	_drag(board._envelope_position + Vector2(0, 65), Vector2(543, 461))
	_check(not board._finishing and decisions.is_empty(), "letter dropped away from the outgoing slot remains in hand")
	_drag(board._envelope_position + Vector2(0, 65), board.OUTGOING.get_center() + Vector2(0, 65))
	board._process(0.6)
	_check(decisions.size() == 1 and decisions[-1], "final physical handoff sends the letter with its photograph")
	board._process(1.0)
	_check(decisions.size() == 1, "a completed handoff emits only once")
	board.configure("每年夏天，我们都会回来。")
	_drag(board._photo_position, board.DRAWER_PHOTO)
	_check(board.stage == 1 and not board.with_photo and decisions.size() == 1, "placing photo in drawer remains provisional")
	_drag(board._photo_position, board.ENVELOPE_START)
	_check(board.with_photo and decisions.size() == 1, "photo can be moved back into the envelope before handoff")
	_drag(board._photo_position, board.DRAWER_PHOTO)
	_check(not board.with_photo and decisions.size() == 1, "photo can still be moved to the drawer before handoff")
	_button(board.CLOSE.get_center(), true)
	_check(dismissals == 1 and decisions.size() == 1, "closing a staged arrangement does not register a choice")
	_drag(board._envelope_position + Vector2(0, 65), board.OUTGOING.get_center() + Vector2(0, 65))
	board._process(0.6)
	_check(decisions.size() == 2 and not decisions[-1], "final handoff sends only the text while the photo remains")
	print("ATTACHMENT SMOKE: %d checks, %d failures" % [checks, failures.size()])
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
