extends SceneTree
## Repeatable, visible UI playthrough. This is a controlled demonstration,
## not a human play session. No game facts, clocks, or outcomes are injected.
## Godot --path . --script res://tools/playthrough.gd -- --demo-speed=8
## Default pacing is for a readable film. Movie recording is a separate command.

const Main = preload("res://scripts/main.gd")
var main: Control
var cursor: DemoPointer
var speed: float = 1.0
var elapsed: float = 0.0
var failed: bool = false
var events: Array[Dictionary] = []
var save_file: String = ""
var report_file: String = "res://test-results/playthrough_plan.json"
var source_hashes: Dictionary = {}
var asset_hashes: Dictionary = {}
var started_utc: String = ""
var started_ticks: int = 0
var sample_jpeg: bool = false
var jpeg_samples: Array[int] = []
var next_sample_at: float = 5.0
var sample_pending: bool = false


class DemoPointer extends Control:
	var point := Vector2(802, 786)
	var down: bool = false
	var subtitle: String = ""
	var font: Font

	func _draw() -> void:
		if not subtitle.is_empty():
			draw_string(font, Vector2(466, 48), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 566, 19, Color("567971"))
		if down:
			draw_circle(point, 19, Color(0.72, 0.47, 0.34, 0.2))
			draw_arc(point, 18, 0, TAU, 32, Color("b7785e"), 1.4, true)
		var arrow := PackedVector2Array([point, point + Vector2(3, 22), point + Vector2(9, 15), point + Vector2(17, 14)])
		draw_colored_polygon(arrow, Color("fffdf4"))
		arrow.append(point)
		draw_polyline(arrow, Color("355753"), 1.7, true)


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--demo-speed="):
			speed = clampf(argument.get_slice("=", 1).to_float(), 0.5, 16.0)
		elif argument.begins_with("--demo-report="):
			report_file = argument.get_slice("=", 1)
		elif argument == "--demo-sample-jpeg":
			sample_jpeg = true
	Engine.time_scale = speed
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if sample_jpeg and elapsed >= next_sample_at and not sample_pending and is_instance_valid(main):
		next_sample_at = elapsed + 10.0
		sample_pending = true
		_sample_viewport.call_deferred()
	if elapsed > 1200.0 and not failed:
		_stop("The UI playthrough exceeded its 20 minute watchdog.")
	return false


func _sample_viewport() -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(main):
		var frame := root.get_texture().get_image()
		if frame != null and not frame.is_empty():
			frame.convert(Image.FORMAT_RGB8)
			jpeg_samples.append(frame.save_jpg_to_buffer(0.55).size())
	sample_pending = false


func _run() -> void:
	started_ticks = Time.get_ticks_msec()
	started_utc = Time.get_datetime_string_from_system(true)
	_capture_source_hashes("res://scripts")
	_capture_asset_hashes("res://assets")
	for path in ["res://project.godot", "res://data/game.json", "res://tools/playthrough.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	root.content_scale_size = Vector2i(1600, 900)
	main = Main.new()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# This is the only non-UI session setting: isolate the demonstration's save.
	# A fresh filename preserves prior QA runs as well as every player save.
	save_file = "user://qa/video_save_%d.json" % Time.get_ticks_usec()
	main.game.save_path = save_file
	main._title()
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	cursor = DemoPointer.new()
	cursor.size = Vector2(1600, 900)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.font = load("res://assets/fonts/SolmereSans.ttf")
	layer.add_child(cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_step("title", "")
	await _pause(4.0)
	await _click("开始这一天")
	await _pause(3.0)
	_check(main.current_view == "location" and not is_instance_valid(main.overlay) and main.guidance.descriptor.get("stage_id", "") == "first_arrival", "The opening begins in the walkable scene with a contextual door objective.")
	_step("post_office_entrance", "09:00 · 先走到邮局门前")
	await _click_tooltip("走进邮局，拿起今日来信")
	await _wait_view("desk")
	await _pause(4.0)
	await _read_envelope()
	# A wrong ordinary delivery returns the intact letter and remains recoverable.
	_step("returned_delivery", "一个旧名字，仍需要核对")
	await _object("deliver")
	await _select(main.recipient_select, "post_office")
	await _click("亲手投递")
	await _read_message(5.0)
	_check(not main.game.is_handled("case01"), "Wrong ordinary delivery remains open for investigation.")
	await _travel("community_center")
	_step("case01_evidence", "核对石牌与翻修记录")
	await _inspect("门侧旧石牌", 6.0)
	await _inspect("翻修与茶会告示", 6.0)
	await _object("bag")
	await _object("deliver")
	await _select(main.recipient_select, "community_center")
	await _click("亲手投递")
	await _read_message(8.0)
	_check(main.game.is_handled("case01"), "Old Civic Hall letter delivered through the UI.")
	# Take independent original records while the community archive is nearby.
	await _object_caption("回到现场")
	await _inspect("公开转寄登记夹", 5.5)
	await _inspect("2020 夏季活动档案", 6.5)
	await _inspect("志愿者活动卡", 6.5)
	await _travel("bus_stop")
	_step("case02_consent", "先问清今日行程，再托付急件")
	await _inspect("17 路时刻表", 5.5)
	await _inspect("志愿活动公告", 5.0)
	await _talk("尘缘")
	await _question("你今天见过 Mira 吗？", 6.0)
	await _question("如果你正好过去，能替我送这封急件吗？", 8.0)
	await _click("把急件郑重交给尘缘 →")
	await _select(main.recipient_select, "mira_vale")
	await _click("请尘缘代送")
	await _read_message(8.0)
	_check(main.game.case_state("case02").choice == "delegate", "Agreed delegation registered at the bus stop.")
	_check(not "early_bench" in main.game.state.clues, "Delegation did not grant an unseen lookout clue.")
	await _travel("chess_stall")
	_step("town_chess", "街角留下的旧称呼")
	await _inspect("借棋登记簿", 5.5)
	await _travel("tarot_shop")
	_step("town_guestbook", "有些话留在公开的那一页")
	await _inspect("公开留言册", 5.5)
	await _travel("residential")
	_step("residential_records", "旧门牌与现在的去向")
	await _inspect("302 门牌", 5.5)
	await _inspect("旧门牌底册", 7.0)
	await _talk("June Arlen")
	await _question("我在核对旧邮路，可以确认你的姓名吗？", 6.0)
	await _close_overlay()
	await _object("bag")
	await _letter("case03")
	await _read_envelope()
	await _tool("拼合雨损标签")
	_step("six_fragments", "六片纸，先把地址接起来")
	await _fragments()
	await _read_message(5.5)
	_check(main.game.case_state("case03").repair_solved, "Six rotated fragments reconstructed the old address.")
	# Show that repeated damage has a real failure and a recoverable checkpoint.
	await _tool("检查封口，取出内页")
	_step("damage_warning", "封边起毛时，工具会留下提醒")
	await _opening(true)
	await _wait_view("failure")
	_check(main.game.has_failure(), "Eight distinct deviations reached the damaged-letter ending.")
	_check(not "case03_body" in main.game.state.clues, "Damaged opening did not reveal the inner letter.")
	_step("checkpoint", "保留此前的调查，回到拆封前")
	await _pause(8.0)
	await _click("从拆封前继续")
	await _wait_view("desk")
	_check(not main.game.has_failure() and main.game.case_state("case03").repair_solved, "Checkpoint preserved the finished address puzzle.")
	await _tool("检查封口，取出内页")
	_step("safe_opening", "沿封线慢慢走，再取出内页")
	await _opening(false)
	await _read_message(12.0, "收好内页")
	await _tool("折回内页，修复封边")
	_step("repair", "折回、接边、贴带、压印")
	await _restore()
	await _read_message(4.5)
	await _travel("bus_stop")
	_step("route_seventeen", "看清候车与抵达时间，再决定出发")
	await _travel("lookout", "bus")
	_step("nora", "搬走以后，仍有人知道在哪里找到她")
	await _talk("Nora Vale")
	await _question("你是 Nora Vale 吗？", 7.0)
	await _question("今天的星空聚会照常吗？", 6.0)
	await _close_overlay()
	await _object("deliver")
	await _select(main.recipient_select, "nora_vale")
	await _click("亲手投递")
	await _read_message(8.0)
	_check(main.game.is_handled("case03"), "Repaired invitation delivered to Nora at the lookout.")
	await _letter("case04")
	await _read_envelope()
	await _object_caption("回到现场")
	await _talk("June Arlen")
	await _question("你和 Mira 现在还有来往吗？", 7.0)
	await _close_overlay()
	await _talk("Mira Vale")
	await _question("六年前的 7 月 18 日，你还记得吗？", 7.0)
	await _close_overlay()
	await _object("bag")
	await _object("deliver")
	_step("independent_inference", "把住址、日期与寄件笔迹分别联系起来")
	await _deduction()
	await _close_overlay()
	await _tool("检查封口，取出内页")
	_step("old_letter", "六年前没有寄到的那句话")
	await _opening(false)
	await _read_message(14.0, "收好内页")
	await _object("deliver")
	await _select(main.recipient_select, "june_arlen")
	await _select(main.sender_select, "mira_vale")
	await _click("整理信与照片，交付")
	await _pause(5.0)
	await _click("展开信与照片")
	_step("photo_choice", "照片留下，正文继续上路")
	await _attachment()
	await _wait_board("physical_board.gd")
	await _restore()
	await _read_message(8.0)
	_check(main.game.case_state("case04").choice == "remove_attachment", "Photo withheld through physical placement and final repaired handoff.")
	_check(main.game.case_state("case04").factual_correct, "Identities and the three independent records agree.")
	_step("last_envelope", "抽屉最下面，写给下一位的人")
	await _click("看看托盘最下面那封信 →")
	await _read_message(6.0)
	await _read_envelope()
	await _tool("检查封口，取出内页")
	await _opening(false)
	await _read_message(12.0, "收好内页")
	await _tool("比对旧异常件清单")
	_step("archive", "同一枚编号，同一天邮戳")
	await _archive()
	await _read_message(7.0)
	await _object("deliver")
	await _click("交入正式档案")
	await _pause(6.0)
	await _click("照这样处理")
	await _wait_view("ending")
	_step("evening", "")
	await _pause(6.0)
	var chapter = _script_node("chapter_screen.gd")
	await _scroll_read(chapter.story_view, 26.0)
	await _pause(7.0)
	_check(main.game.first_four_handled() and main.game.is_handled("case05"), "All five letters have final UI-registered outcomes.")
	_check(main.game.state.visited.size() == 7, "All seven locations were reached through the town map.")
	_check(main.game.state.archive_matched, "Archive stamp matched the original serial and date.")
	_check(not str(main.game.state.ending).is_empty(), "Actual evening state was produced.")
	_check(not main.game.case_state("case02").late, "Agreed urgent delegation arrived before sunset.")
	_step("complete", "")
	_write_report(true)
	print("PLAYTHROUGH PASS: %.1f simulated seconds, %d UI milestones, QA save %s" % [elapsed, events.size(), save_file])
	# Playback references are released by the audio server on real time, even
	# when this automated demonstration accelerates the scene clock.
	for node in _all_nodes(main):
		if node is AudioStreamPlayer:
			node.stop()
			node.stream = null
	await create_timer(0.35, true, false, true).timeout
	main.queue_free()
	cursor.get_parent().queue_free()
	await process_frame
	await process_frame
	quit(0)


func _pause(seconds: float) -> void:
	await create_timer(seconds).timeout


func _step(id: String, subtitle: String) -> void:
	if is_instance_valid(cursor):
		cursor.subtitle = subtitle
		cursor.queue_redraw()
	events.append({"event": id, "second": snappedf(elapsed, 0.01), "game_time": main.game.time_text() if not main.game.state.is_empty() else ""})
	print("PLAYTHROUGH %s @ %.1fs" % [id, elapsed])


func _all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_all_nodes(child))
	return result


func _script_node(filename: String) -> Node:
	for node in _all_nodes(main):
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("/" + filename):
			return node
	return null


func _button(text_value: String) -> Button:
	for node in _all_nodes(main):
		if node is Button and node.is_visible_in_tree() and not node is OptionButton and (node.text == text_value or node.text.trim_suffix("→").strip_edges() == text_value):
			return node
	return null


func _click(text_value: String) -> void:
	var button := _button(text_value)
	if button == null:
		_stop("Cannot find visible button: " + text_value)
		await process_frame
		return
	await _activate(button)


func _activate(control: Control) -> void:
	if control is BaseButton and control.disabled:
		_stop("Control is disabled: " + str(control.tooltip_text))
		return
	await _cursor_to(control.get_global_rect().get_center(), 0.42)
	cursor.down = true
	cursor.queue_redraw()
	await _pause(0.12)
	# Emit the widget's existing input callback, never call a GameSession action.
	control.emit_signal("pressed")
	cursor.down = false
	cursor.queue_redraw()
	await _pause(0.3)


func _click_tooltip(value: String) -> void:
	for node in _all_nodes(main):
		if node is Control and node.is_visible_in_tree() and node.tooltip_text == value and node.has_signal("pressed"):
			await _activate(node)
			return
	_stop("Cannot find visible prop: " + value)
	await process_frame


func _object(kind: String) -> void:
	for node in _all_nodes(main):
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("/object_button.gd") and node.kind == kind and node.is_visible_in_tree():
			await _activate(node)
			if kind == "deliver":
				var wait: float = 0.0
				while not is_instance_valid(main.overlay) and wait < 15.0:
					await _pause(0.1)
					wait += 0.1
			return
	_stop("Cannot find desk/scene object: " + kind)
	await process_frame


func _object_caption(caption: String) -> void:
	await _click_tooltip(caption)


func _cursor_to(destination: Vector2, duration: float = 0.5) -> void:
	var start: Vector2 = cursor.point
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float):
		cursor.point = start.lerp(destination, value)
		cursor.queue_redraw(), 0.0, 1.0, duration)
	await tween.finished


func _select(control: OptionButton, id: String) -> void:
	if not is_instance_valid(control):
		_stop("Missing recipient/sender dropdown for " + id)
		return
	var index: int = -1
	for item in range(control.item_count):
		if str(control.get_item_metadata(item)) == id:
			index = item
	if index < 0:
		_stop("Dropdown has no identity: " + id)
		return
	await _cursor_to(control.get_global_rect().get_center())
	control.show_popup()
	await _pause(1.1)
	control.select(index)
	control.item_selected.emit(index)
	control.get_popup().hide()
	await _pause(1.0)


func _close_overlay() -> void:
	if is_instance_valid(main.overlay):
		await _click("结束交谈  ×" if _button("结束交谈  ×") != null else "×")


func _read_message(seconds: float, close_text: String = "收好这页") -> void:
	var on_scene_handoff: bool = not main.dialogue_npc.is_empty() and _button("结束交谈  ×") != null
	# Keep the longer private letters readable; trim only repeated brief notes.
	if seconds <= 8.0:
		seconds *= 0.85
	await _pause(seconds * 0.6)
	var rich: RichTextLabel
	if is_instance_valid(main.overlay):
		for node in _all_nodes(main.overlay):
			if node is RichTextLabel:
				rich = node
				break
	if is_instance_valid(rich):
		await _scroll_read(rich, seconds * 0.4)
	else:
		await _pause(seconds * 0.4)
	if on_scene_handoff:
		await _click("结束交谈  ×")
		# Continue through the visible bag control, keeping the subsequent letter
		# work at the same desk state as an ordinary paper notification.
		await _object("bag")
	else:
		await _click(close_text)


func _scroll_read(rich: RichTextLabel, duration: float) -> void:
	var bar := rich.get_v_scroll_bar()
	var distance := maxf(0.0, bar.max_value - bar.page)
	if distance < 1.0:
		await _pause(duration)
		return
	await _cursor_to(rich.get_global_rect().end - Vector2(15, 72), 0.5)
	var steps := maxi(1, ceili(distance / 125.0))
	for index in range(steps):
		# The scrollbar is itself a user control; no game state is changed.
		var tween := create_tween()
		tween.tween_property(bar, "value", minf(distance, (index + 1) * 125.0), 0.4)
		await tween.finished
		await _pause(maxf(0.4, duration / steps - 0.4))


func _wait_view(view: String) -> void:
	var wait: float = 0.0
	while main.current_view != view and wait < 15.0:
		await _pause(0.1)
		wait += 0.1
	_check(main.current_view == view, "Arrived at " + view + " view.")
	await _pause(0.5)


func _wait_board(filename: String) -> void:
	var wait: float = 0.0
	while _script_node(filename) == null and wait < 10.0:
		await _pause(0.1)
		wait += 0.1
	_check(_script_node(filename) != null, "Opened " + filename + " through the interface.")


func _travel(id: String, mode: String = "walk") -> void:
	await _object("map")
	await _pause(1.8)
	var name_value: String = main.game.location_data(id).name
	var origin: String = str(main.game.state.location)
	var before: int = int(main.game.state.minute)
	var expected_minutes: int = -1
	for option in main.game.travel_options(id):
		if option.mode == mode and option.available:
			expected_minutes = int(option.minutes)
	if expected_minutes < 0:
		_stop("No available " + mode + " route to " + id + " at " + main.game.time_text())
		return
	await _click_tooltip("查看前往 " + name_value + " 的路线")
	await _pause(2.8)
	_check(main.game.state.location == origin and main.game.state.minute == before, "Map selection previews " + id + " without spending time.")
	await _click("搭乘 17 路 →" if mode == "bus" else "步行出发 →")
	var wait: float = 0.0
	while (main.traveling or main.game.state.location != id) and wait < 15.0:
		await _pause(0.1)
		wait += 0.1
	await _pause(1.3)
	_check(main.game.state.location == id and main.current_view == "location", "Traveled to " + id + " using the physical map and " + mode + " departure.")
	_check(main.game.state.minute == before + expected_minutes, "Confirmed " + mode + " journey charged its previewed cost exactly once.")


func _inspect(label: String, seconds: float = 5.0) -> void:
	await _click_tooltip(label)
	var wait: float = 0.0
	while not is_instance_valid(main.overlay) and wait < 15.0:
		await _pause(0.1)
		wait += 0.1
	_check(is_instance_valid(main.overlay), "Walked to and examined " + label + ".")
	var evidence = _script_node("visual_evidence.gd")
	if evidence != null:
		await _visual_observation(evidence, seconds)
	else:
		await _read_message(seconds)


func _visual_observation(evidence: Control, seconds: float) -> void:
	var clue: String = evidence.clue_id
	var minute_before: int = int(main.game.state.minute)
	var was_known: bool = clue in main.game.state.clues
	_check(not was_known, "Visual clue " + clue + " requires direct observation before recording.")
	await _pause(1.1)
	match evidence.mode:
		"plaque":
			await _drag(evidence, Vector2(450, 350), Vector2(450, 180))
			await _tap(evidence, Vector2(430, 391))
		"resident":
			await _drag(evidence, Vector2(460, 323), Vector2(800, 323))
			await _tap(evidence, Vector2(359, 343))
			await _tap(evidence, Vector2(950, 294))
		"registry":
			await _drag(evidence, Vector2(360, 349), Vector2(150, 349))
			await _tap(evidence, Vector2(714, 323))
			await _tap(evidence, Vector2(685, 379))
		"archive":
			await _drag(evidence, Vector2(603, 340), Vector2(893, 340))
			await _tap(evidence, Vector2(353, 391))
			await _tap(evidence, Vector2(650, 405))
		"handwriting":
			await _drag(evidence, Vector2(805, 220), Vector2(255, 214))
			await _tap(evidence, Vector2(161, 255))
			await _tap(evidence, Vector2(236, 369))
		"timetable":
			await _tap(evidence, Vector2(588, 242))
			var departures: Array = evidence.payload.get("departures", [790, 910, 1000])
			var feasible: int = -1
			for index in range(departures.size()):
				if int(departures[index]) >= int(main.game.state.minute) and int(departures[index]) + 15 <= 1080:
					feasible = index
					break
			await _tap(evidence, Vector2(820, 180 + 86 * feasible) if feasible >= 0 else Vector2(958, 536))
		_:
			_stop("Unsupported visible evidence route: " + str(evidence.mode))
			return
	_check(evidence.ready_to_record and not clue in main.game.state.clues, "Examined " + clue + " physically; recording is still an explicit action.")
	await _pause(maxf(1.5, seconds * 0.45))
	await _tap(evidence, Vector2(1040, 624))
	_check(clue in main.game.state.clues, "The observation stamp records " + clue + " through Main.")
	_check(int(main.game.state.minute) == minute_before, "Time spent observing " + clue + " does not consume the shift clock.")
	await _pause(0.6)
	if _button("收好这页") != null:
		await _read_message(2.0)


func _talk(npc: String) -> void:
	await _click_tooltip("与 " + npc + " 交谈")
	var wait: float = 0.0
	while not is_instance_valid(main.overlay) and wait < 15.0:
		await _pause(0.1)
		wait += 0.1
	_check(is_instance_valid(main.overlay), "Walked to " + npc + " before conversation.")
	await _pause(1.5)


func _question(text_value: String, seconds: float) -> void:
	await _click(("— " if _button("— " + text_value) != null else "· ") + text_value)
	await _pause(seconds)


func _letter(id: String) -> void:
	await _object_caption(str(main.game.letter_data(id).title))
	_check(main.selected == id, "Selected " + id + " from its envelope tab.")
	await _pause(0.8)


func _read_envelope() -> void:
	await _pause(4.0)
	var card: Control = main.envelope
	var at := Vector2(card.size.x - 11, card.size.y * 0.5)
	await _cursor_to(card.global_position + at * card.scale)
	_gui_button(card, at, true)
	_gui_button(card, at, false)
	await _pause(4.5)
	_gui_button(card, at, true)
	_gui_button(card, at, false)
	await _pause(0.7)


func _tool(label: String) -> void:
	await _object("tools")
	await _pause(0.65)
	await _click(label)
	await _wait_board("physical_board.gd")
	await _pause(0.8)


func _local(board: Control, at: Vector2) -> Vector2:
	var origin: Vector2 = board._canvas_origin() if board.has_method("_canvas_origin") else board._origin()
	return origin + at * float(board._scale_factor() if board.has_method("_scale_factor") else board._factor())


func _gui_button(control: Control, at: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = pressed
	event.double_click = double
	control._gui_input(event)
	cursor.down = pressed
	cursor.queue_redraw()


func _tap(board: Control, at: Vector2, button: int = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var local := _local(board, at)
	await _cursor_to(board.global_position + local, 0.4)
	_gui_button(board, local, true, button, double)
	await _pause(0.15)
	if is_instance_valid(board):
		_gui_button(board, local, false, button)
	else:
		cursor.down = false
		cursor.queue_redraw()
	await _pause(0.35)


func _motion(board: Control, from: Vector2, to: Vector2, duration: float) -> void:
	var spent: float = 0.0
	while spent < duration:
		await process_frame
		spent += main.get_process_delta_time()
		var amount: float = smoothstep(0.0, 1.0, minf(1.0, spent / duration))
		var local := _local(board, from.lerp(to, amount))
		var event := InputEventMouseMotion.new()
		event.position = local
		board._gui_input(event)
		cursor.point = board.global_position + local
		cursor.queue_redraw()
	await process_frame


func _drag(board: Control, from: Vector2, to: Vector2, duration: float = 1.3, hold: float = 0.0) -> void:
	await _cursor_to(board.global_position + _local(board, from), 0.35)
	_gui_button(board, _local(board, from), true)
	await _pause(0.18)
	await _motion(board, from, to, duration)
	await _pause(hold)
	_gui_button(board, _local(board, to), false)
	await _pause(0.3)


func _fragments() -> void:
	var board = _script_node("physical_board.gd")
	for index in range(6):
		var part: Dictionary = board._pieces[index]
		for turn in range((4 - int(part.turn)) % 4):
			await _tap(board, part.position, MOUSE_BUTTON_RIGHT)
		await _drag(board, part.position, part.target)
		_check(part.locked, "Fragment %d snapped after physical alignment." % [index + 1])
	await _pause(1.6)


func _opening(damage: bool) -> void:
	var board = _script_node("physical_board.gd")
	await _tap(board, Vector2(430 if damage else 130, 125))
	var start: Vector2 = board._point_on_path(board._trace_distance)
	await _cursor_to(board.global_position + _local(board, start))
	_gui_button(board, _local(board, start), true)
	if damage:
		for slip in range(8):
			await _motion(board, start, start + Vector2(0, 74), 0.3)
			await _pause(0.15)
			await _motion(board, start + Vector2(0, 74), start, 0.3)
			await _pause(0.15)
			if slip == 2 or slip == 5:
				await _pause(3.0)
		_check(board._mistakes >= 8, "Separate off-path slips recorded actual damage warnings.")
	var counter: int = 0
	while board.stage == 0 and counter < 240:
		var old: Vector2 = board._point_on_path(board._trace_distance)
		var next: Vector2 = board._point_on_path(board._trace_distance + 12.0)
		await _motion(board, old, next, 0.12)
		counter += 1
	_check(board.stage == 1, "Held pointer traversed the entire seal path.")
	_gui_button(board, _local(board, board._path[-1]), false)
	await _pause(1.1)
	await _drag(board, board._moving, Vector2(520, 125), 1.4)
	await _pause(0.8)


func _restore() -> void:
	var board = _script_node("physical_board.gd")
	var targets: Array[Vector2] = [board.PAGE_TARGET, board.EDGE_TARGET, board.TAPE_TARGET, board.STAMP_TARGET]
	for stage in range(4):
		_check(board.stage == stage, "Repair stage %d is available in sequence." % stage)
		await _drag(board, board._moving, targets[stage], 1.4, 0.8 if stage == 3 else 0.0)
		if stage < 3: await _pause(0.55)
	await _pause(1.0)


func _deduction() -> void:
	await _wait_board("deduction_board.gd")
	var board = _script_node("deduction_board.gd")
	await _pause(3.0)
	var first: Vector2 = board._cards[board._find_card("old_nameplate")].position
	await _tap(board, first, MOUSE_BUTTON_LEFT, true)
	await _pause(5.0)
	await _tap(board, board.DETAIL_CLOSE.get_center())
	for pair in [["old_nameplate", "address"], ["event_archive", "date"], ["handwriting_sample", "sender"]]:
		var card: Dictionary = board._cards[board._find_card(pair[0])]
		await _drag(board, card.position, board._slot_center(pair[1]), 1.4)
		await _pause(1.0)
	await _pause(3.0)
	await _tap(board, board.SEAL)
	await _pause(0.8)
	_check(main.game.case_state("case04").deduction_claims.size() == 3, "Three independent evidence claims recorded by the inference seal.")


func _attachment() -> void:
	await _wait_board("attachment_board.gd")
	var board = _script_node("attachment_board.gd")
	await _pause(3.0)
	await _tap(board, board._photo_position, MOUSE_BUTTON_LEFT, true)
	await _pause(5.0)
	await _tap(board, board._photo_position, MOUSE_BUTTON_LEFT, true)
	await _drag(board, board._photo_position, board.DRAWER_PHOTO, 1.8)
	await _pause(3.0)
	_check(board.stage == 1 and not board.with_photo, "Photo is physically inside the kept drawer before handoff.")
	await _drag(board, board._envelope_position + Vector2(0, 65), board.OUTGOING.get_center() + Vector2(0, 65), 1.8)
	await _pause(1.0)


func _archive() -> void:
	var board = _script_node("physical_board.gd")
	await _pause(6.0)
	var matched: int = -1
	for index in range(board._records.size()):
		var record: Dictionary = board._records[index]
		if str(record.serial) == str(board._match_serial) and str(record.date) == str(board._match_date):
			matched = index
	_check(matched >= 0, "The full archive contains the case's original serial and date.")
	await _drag(board, board._moving, board._archive_row_rect(matched).get_center(), 2.0)
	await _pause(1.6)


func _check(condition: bool, message: String) -> void:
	if condition:
		events.append({"check": message, "passed": true, "second": snappedf(elapsed, 0.01)})
	else:
		_stop(message)


func _stop(message: String) -> void:
	if failed: return
	failed = true
	events.append({"error": message, "second": snappedf(elapsed, 0.01)})
	push_error("PLAYTHROUGH FAIL: " + message)
	_write_report(false)
	quit(1)


func _capture_source_hashes(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".gd"):
			var path: String = directory.path_join(filename)
			source_hashes[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory):
		_capture_source_hashes(directory.path_join(child))

func _capture_asset_hashes(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_lower() in ["png", "svg", "ttf", "wav", "ogg"]:
			var path: String = directory.path_join(filename)
			asset_hashes[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory):
		_capture_asset_hashes(directory.path_join(child))

func _write_report(passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_file).get_base_dir())
	var file := FileAccess.open(report_file, FileAccess.WRITE)
	if file != null:
		var changed_sources: Array[String] = []
		for path in source_hashes:
			if FileAccess.get_sha256(path) != source_hashes[path]:
				changed_sources.append(path)
		var changed_assets: Array[String] = []
		for path in asset_hashes:
			if FileAccess.get_sha256(path) != asset_hashes[path]:
				changed_assets.append(path)
		var frame_budget: Dictionary = {"enabled": sample_jpeg, "sample_count": jpeg_samples.size(), "quality": 0.55, "fps": 24, "viewport": [root.size.x, root.size.y]}
		if not jpeg_samples.is_empty():
			var sorted: Array[int] = jpeg_samples.duplicate()
			sorted.sort()
			var total: int = 0
			for value in sorted:
				total += value
			var mean: float = float(total) / sorted.size()
			frame_budget["mean_jpeg_bytes"] = snappedf(mean, 0.1)
			frame_budget["p95_jpeg_bytes"] = sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.95) - 1)]
			frame_budget["max_jpeg_bytes"] = sorted[-1]
			frame_budget["projected_24fps_avi_bytes"] = int(mean * elapsed * 24 + elapsed * 48000 * 2 * 2)
			frame_budget["projected_900_seconds_bytes"] = int(mean * 900 * 24 + 900 * 48000 * 2 * 2)
			frame_budget["p95_900_seconds_bytes"] = int(float(frame_budget.p95_jpeg_bytes) * 900 * 24 + 900 * 48000 * 2 * 2)
			frame_budget["projection_note"] = "Actual rendered viewport sampled roughly every 10 simulated seconds; includes estimated 48kHz stereo 16-bit PCM, excludes small container/index overhead. Not a recorded movie."
		file.store_string(JSON.stringify({
			"passed": passed, "controlled_ui_demonstration": true,
			"demo_speed": speed, "elapsed_game_seconds": snappedf(elapsed, 0.01),
			"elapsed_wall_seconds": (Time.get_ticks_msec() - started_ticks) / 1000.0,
			"started_utc": started_utc, "engine": Engine.get_version_info(),
			"source_sha256_at_start": source_hashes,
			"sources_changed_at_end": changed_sources,
			"asset_sha256_at_start": asset_hashes,
			"assets_changed_at_end": changed_assets,
			"movie_budget": frame_budget,
			"source_scope": "All scripts, project settings, data, driver and raw PNG/SVG/TTF/WAV/OGG assets present at start. Does not identify an exported executable or prove human usability.",
			"save_path": save_file, "events": events
		}, "\t"))
