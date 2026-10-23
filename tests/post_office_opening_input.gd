extends "res://tests/core_review_input.gd"
const POSTAL_OUT := "res://test-results/post-office-layout-20261019/"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-12000,-12000)
	root.content_scale_size = Vector2i(1600,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	initial_hashes = _source_hashes()
	DirAccess.make_dir_recursive_absolute(POSTAL_OUT)
	for locale: String in ["zh","en"]:
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size = dimensions
			host = Host.new()
			host.allow_display_changes = false
			root.add_child(host)
			host.size = Vector2(1600,900)
			host.core.save_path = "user://qa/postal-opening/" + run_id + locale + str(dimensions.x) + ".json"
			host.preferences.set_value("language",locale)
			host._title()
			await process_frame
			await _named("NewShift")
			_check(host.view == "post_office_room" and host.post_office_room_index == 0,"Start enters supplied left counter room")
			await _wait(func(): return _node("CloseDialogue") != null,"supervisor appears over actual room")
			await _named("ToWorkroom")
			_check(host.post_office_room_index == 0,"briefing blocks underlying arrow")
			await _named("CloseDialogue")
			_check(not host.busy and not is_instance_valid(host.modal),"visible dialogue cross gives control")
			_check(not _node("PostOfficeInterior").close_button.visible,"room has no preview-only close control")
			var minute: int = host.core.state.minute
			var initial_evidence: Dictionary = host.core.state.evidence.duplicate(true)
			await _room_shot("opening_counter_" + locale + "_" + str(dimensions.x))
			await _named("CounterReferenceBook")
			_check(_modal_script().ends_with("field_book.gd"),"painted book opens actual archive directly")
			await _key(KEY_ESCAPE)
			_check(not is_instance_valid(host.modal) and host.view == "post_office_room","book Esc returns to same room rather than leaving building")
			await _named("ToWorkroom")
			await create_timer(0.23).timeout
			_check(host.post_office_room_index == 1,"right arrow enters right workroom")
			await _room_shot("opening_workroom_" + locale + "_" + str(dimensions.x))
			await _key(KEY_ESCAPE)
			_check(is_instance_valid(host.modal),"room Esc opens host pause")
			await _key(KEY_SPACE)
			await _key(KEY_ENTER)
			_check(host.post_office_room_index == 1,"retained arrow focus cannot navigate behind pause")
			if is_instance_valid(host.modal): await _key(KEY_ESCAPE)
			_check(not is_instance_valid(host.modal),"pause dismisses without exiting room")
			await _named("OpenPostalDesk")
			_check(host.view == "counter" and not _desk_snapshot().is_empty(),"painted worktable reaches real mail handling")
			if dimensions.x == 1920 and locale == "zh":
				await _open_desk_box()
				await _named("Mail_case01")
				_check(_modal_script().ends_with("mail_workbench.gd"),"mail still lifts into working physical inspection")
				await _click(Vector2(1495,60))
				_check(not is_instance_valid(host.modal) and host.core.case_state("case01").owner == "courier","real letter closes and retains custody")
			await _click(_desk_point((_desk_snapshot().rects.depart as Rect2).get_center()))
			_check(host.view == "post_office_room" and host.post_office_room_index == 1,"desk return restores right room without left flash")
			_check(host.core.state.minute == minute and host.core.state.evidence == initial_evidence,"room navigation grants no evidence or travel charge")
			await _named("ToCounter")
			await create_timer(0.23).timeout
			_check(host.post_office_room_index == 0,"left arrow returns to counter")
			await _named("PostOfficeExit")
			_check(host.view == "world" and host.core.state.location == "post_office","painted door returns to existing exterior")
			await _named("PostDoor")
			await _wait(func(): return host.view == "post_office_room","exterior door walks back into left room")
			_check(host.post_office_room_index == 0,"outside reentry uses supplied left interior")
			await _key(KEY_ESCAPE)
			await _text("Save and title" if locale == "en" else "保存并回到封面")
			await _named("ContinueShift")
			_check(host.view == "post_office_room" and host.post_office_room_index == 0,"continue at postal location restores new interior")
			_check(host.core.state.minute == minute,"continue preserves time")
			host.queue_free()
			await process_frame
			await process_frame
	_check(initial_hashes == _source_hashes(),"opening input source stayed frozen")
	var file := FileAccess.open(POSTAL_OUT + "opening-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite":"post_office_opening_input","checks":checks,"failures":failures,"screenshots":screenshots,"source_sha256":initial_hashes,"scope":"Actual main Host Start, rooms, painted book/table/door, mail inspection, pause and save/resume via routed GPU input. Not novice or audio listening acceptance."},"\t"))
	file.close()
	print("POST OFFICE OPENING: %d checks, %d failures" % [checks,failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _room_shot(label: String) -> void:
	for i: int in 5: await process_frame
	RenderingServer.force_draw(false)
	var path := POSTAL_OUT + label + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK,"saved " + label)
	screenshots.append(path)
