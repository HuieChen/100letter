extends "res://tests/field_observation_smoke.gd"
## Real CanvasItem presentation + routed input, with explicit component setup.
## This verifies document boundaries, not human comprehension or reading time.
const PROOF := "res://test-results/fullflow-20261018/notices/"
var geometry: Array[Dictionary] = []

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-12000, -12000)
	root.title = "Dear Somewhere posted notice boundary QA"
	core = Core.new()
	core.save_path = "user://qa/posted-notice/state.json"
	root.add_child(core)
	await process_frame
	for id: String in Board.PUBLIC_IDS:
		if id in ["ceramic_17", "mira_absent", "old_music_photo"]: continue
		await _prepare(id)
		board.hide()
		board.configure(core, id)
		await _settle()
		_check(not core.has_evidence(id), id + " hidden source cannot be recorded")
		board.show()
		await _settle()
		_check(core.has_evidence(id), id + " showing the actual document supplies visible source")
		_check(core.save_game(), id + " can checkpoint observed fact")
		var recovered := Core.new()
		recovered.save_path = core.save_path
		_check(recovered.load_game() and recovered.has_evidence(id), id + " checkpoint restores observation")
		recovered.free()
		await _prepare(id)
		board.configure(core, id)
		board._leave() # Same-frame close boundary; no fabricated reading gesture.
		await _settle()
		_check(not core.has_evidence(id), id + " close before first presentation grants nothing")
		_check(close_count == 1, id + " closes once before presentation")
		for locale: String in ["zh", "en"]:
			for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1440)]:
				root.size = dimensions
				root.content_scale_size = Vector2i(1600,900)
				await _prepare(id)
				board.configure(core, id, locale)
				await _settle()
				_check(core.has_evidence(id), id + " " + locale + " presented")
				var inner := Rect2(board._origin + Vector2(365,195) * board._factor, Vector2(865,505) * board._factor)
				for label: Label in _labels(board._notice):
					var rect := label.get_global_rect()
					_check(inner.encloses(rect), id + " " + locale + " text remains within paper: " + label.text.left(24))
					_check(label.get_line_count() * label.get_line_height() <= label.size.y + 2, id + " text lines fit their container")
					geometry.append({"id":id,"locale":locale,"viewport":str(dimensions),"text":label.text,"rect":str(rect)})
				if id in ["street_renaming", "moran_entry", "procedure_codes", "telescope_checkout"]:
					RenderingServer.force_draw(false)
					var path := PROOF + id + "_" + locale + "_" + str(dimensions.x) + ".png"
					DirAccess.make_dir_recursive_absolute(PROOF)
					_check(root.get_texture().get_image().save_png(path) == OK, "render saved " + path)
					images.append(path)
				for n in 6: await _click_region("close")
				_check(close_count == 1, "rapid close emits once")
				_check(core.has_evidence(id), "close preserves actual observation")
	var file := FileAccess.open(PROOF + "results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite":"posted_notice_input","checks":checks,"failures":failures,"geometry":geometry,"screenshots":images,"scope":"GPU component presentation and routed input. No human/OS/novice acceptance."}, "\t"))
	file.close()
	print("POSTED NOTICE: %d checks, %d failures" % [checks,failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	for n in 5: await process_frame

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	# Input.parse_input_event receives window pixels; the viewport then applies
	# content scaling. Do not send design pixels twice at non-1600 sizes.
	event.position = (board._origin + point * board._factor) * Vector2(root.size) / Vector2(root.content_scale_size)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in node.get_children():
		if child is Label: found.append(child)
		found.append_array(_labels(child))
	return found
