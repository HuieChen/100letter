extends SceneTree
const Review = preload("res://scripts/rebuild/post_office_layout_review.gd")
const PROOF := "res://test-results/post-office-layout-20261019/"
var room: Control
var checks := 0
var failures: Array[String] = []
var screenshots: Array[String] = []
var closes := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-12000,-12000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	room = Review.new()
	root.add_child(room)
	room.close_requested.connect(func(): closes += 1)
	DirAccess.make_dir_recursive_absolute(PROOF)
	_check(Review.SOURCE.get_size() == Vector2(3840,1080), "native source resolution retained")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		room.size = Vector2(dimensions)
		await _settle()
		if room.room_index == 1:
			await _click(room.previous_arrow)
			await create_timer(0.23).timeout
		_check(room.room_index == 0 and room.next_arrow.visible and not room.previous_arrow.visible, "starts at counter with right passage")
		_check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(room.next_arrow.get_global_rect()), "right passage remains in frame")
		await _shot("counter_" + str(dimensions.x))
		for i: int in 6: await _click(room.next_arrow)
		await create_timer(0.23).timeout
		_check(room.room_index == 1 and not room.transitioning, "rapid pointer clicks settle in right workroom")
		_check(room.previous_arrow.visible and not room.next_arrow.visible, "right room has visible return")
		_check(room.image.texture.region == Review.REGIONS[1], "right view samples only right source half")
		await _shot("workroom_" + str(dimensions.x))
		await _click(room.previous_arrow)
		await create_timer(0.23).timeout
		_check(room.room_index == 0 and room.image.texture.region == Review.REGIONS[0], "return restores left half")
		room.show_room(-1)
		room.show_room(2)
		_check(room.room_index == 0, "invalid destinations preserve room")
		await _click(room.close_button)
		_check(closes > 0, "visible cross emits close without Esc")
	var before := closes
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await process_frame
	_check(closes == before + 1, "Esc also closes")
	room.show_room(1)
	room._request_close()
	_check(not room.transitioning, "close interrupts transition safely")
	room.queue_free()
	await _settle()
	room = Review.new()
	root.add_child(room)
	room.size = Vector2(root.size)
	await _settle()
	_check(room.room_index == 0 and not room.transitioning, "fresh preview reopens at counter")
	room.queue_free()
	await _settle()
	var result := {"suite":"post_office_layout_input","checks":checks,"failures":failures,"screenshots":screenshots,"scope":"Isolated two-room layout with routed GPU input, no campaign or object-interaction acceptance."}
	var file := FileAccess.open(PROOF + "results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("POST OFFICE LAYOUT: %d checks, %d failures" % [checks,failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _click(button: Control) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func _settle() -> void:
	for i: int in 5: await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _shot(label: String) -> void:
	await _settle()
	RenderingServer.force_draw(false)
	var path := PROOF + label + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "saved " + label)
	screenshots.append(path)
