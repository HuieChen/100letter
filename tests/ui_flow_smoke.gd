extends SceneTree
## Main-scene integration: actual views, modal callbacks, scrolling, and boards.
## Run --headless --path . --script res://tests/ui_flow_smoke.gd.
## Does not capture screenshots or modify the player's save.

const MAIN = preload("res://scenes/main.tscn")
const QA_PATH = "user://qa/ui_flow_smoke_save.json"
var main
var board
var checks = 0
var failures: Array[String] = []
var source_hashes: Dictionary = {}
var started_utc: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	started_utc = Time.get_datetime_string_from_system(true)
	_capture_sources("res://scripts")
	for path in ["res://project.godot", "res://scenes/main.tscn", "res://data/game.json", "res://tests/ui_flow_smoke.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	root.size = Vector2i(1600, 900)
	main = MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.game.save_path = QA_PATH
	_check(main.current_view == "title", "real main scene enters title")
	main._start_fresh()
	await process_frame
	_check(main.current_view == "location" and is_instance_valid(main.walker), "new day enters the post office scene with a controllable postal worker")
	_check(not is_instance_valid(main.overlay) and is_instance_valid(main.guidance) and main.guidance.descriptor.get("stage_id", "") == "first_arrival", "new day gives a contextual first action without an introductory modal")
	_check(main.guidance.mouse_filter == Control.MOUSE_FILTER_IGNORE and main.walker.manual_enabled, "the opening objective does not intercept world movement")
	main._close_overlay()
	await _check_envelopes()
	await _check_locations_and_overlays()
	await _check_transport_ui()
	await _check_empty_recipient()
	await _check_damage_recovery()
	await _play_day()
	await _check_attachment_handoffs()
	await _check_opened_return()
	print("UI FLOW SMOKE: %d checks, %d failures" % [checks, failures.size()])
	var changed_sources: Array[String] = []
	for path in source_hashes:
		if FileAccess.get_sha256(path) != source_hashes[path]:
			changed_sources.append(path)
	var report = FileAccess.open("res://test-results/ui_flow_results.json", FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"suite": "ui_flow", "runtime": Engine.get_version_info(), "started_utc": started_utc, "checks": checks, "failures": failures, "source_sha256_at_start": source_hashes, "sources_changed_at_end": changed_sources, "scope": "Scripted actual Main integration using isolated QA saves; not OS-input or human usability evidence."}, "\t"))
		report.close()
	# Let the audio server release its playback references before a headless
	# SceneTree exit. This is test teardown, not part of the gameplay assertions.
	for player in _nodes_of_class(main, "AudioStreamPlayer"):
		player.stop()
		player.stream = null
	await create_timer(0.35).timeout
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture_sources(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".gd"):
			var path = directory.path_join(filename)
			source_hashes[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory):
		_capture_sources(directory.path_join(child))

func _check_envelopes() -> void:
	for item in main.game.catalog.letters:
		_select_letter(str(item.id))
		await process_frame
		var card = main.envelope
		var text: RichTextLabel = card.text_label
		_check(text.text == str(item.front), "%s front contains complete catalog text" % item.id)
		await _check_scroll_reaches_end(text, str(item.id) + " front")
		var flip = InputEventMouseButton.new()
		flip.button_index = MOUSE_BUTTON_LEFT
		flip.pressed = true
		flip.position = Vector2(card.size.x - 10, 70)
		card._gui_input(flip)
		await process_frame
		_check(card.reverse and text.text == str(item.back), "%s edge click exposes complete reverse" % item.id)
		_check(main.game.case_state(item.id).get("flipped", false), "%s flip persists through main callback" % item.id)
		_check(str(item.id) in main.game.state.get("ui_guidance", {}).get("seen_backs", []), "%s actual card flip advances persistent guidance history" % item.id)
		await _check_scroll_reaches_end(text, str(item.id) + " reverse")

func _check_locations_and_overlays() -> void:
	var underlying_view: String = main.current_view
	main._map()
	await process_frame
	_check(main.current_view == underlying_view and is_instance_valid(main.overlay) and is_instance_valid(main.route_map), "map opens as a physical sheet over the existing scene")
	for location in main.game.catalog.locations:
		main._travel(str(location.id))
		await process_frame
		_check(main.current_view == "location" and main.game.state.location == location.id, "%s scene and authoritative location agree" % location.id)
		_check(str(location.name) in _visible_text(main.screen), "%s scene presents its name" % location.id)
		var textures = _nodes_of_class(main.screen, "TextureRect")
		_check(not textures.is_empty() and textures[0].texture != null, "%s original location texture resolves" % location.id)
		main._pause()
		await process_frame
		main._pause()
		await process_frame
		_check(_direct_controls() == 2, "%s replacing a menu leaves one screen and one overlay" % location.id)
		main._close_overlay()
		await process_frame
		_check(not is_instance_valid(main.overlay) and _direct_controls() == 1, "%s closing menu removes input overlay" % location.id)
	main._travel("post_office")
	main._desk()
	await process_frame
	main._directory("mira_vale")
	await process_frame
	_check("？" in _visible_text(main.overlay), "directory leaves undiscovered personal facts unknown")
	main._close_overlay()

func _check_transport_ui() -> void:
	# Fixture time makes both real choices available without making the test
	# wait for clock progression unrelated to the map integration under test.
	main.game.new_game()
	main._travel("bus_stop")
	main.game.state.minute = 780
	main._location()
	var before: Dictionary = main.game.state.duplicate(true)
	main._map()
	main._preview_destination("lookout")
	await process_frame
	var preview: String = _visible_text(main.map_sidebar)
	_check("预计 13:25 抵达" in preview and "含候车 10 分钟" in preview, "map bus preview exposes waiting cost and scheduled arrival")
	_check("预计 13:40 抵达" in preview, "map also displays the alternative walking arrival")
	_check(main.game.state == before, "selecting a map destination does not commit a journey")
	main._close_overlay()
	_check(main.game.state == before and main.current_view == "location", "cancelling the map preserves the current world and every game minute")
	main._map()
	main._preview_destination("lookout")
	await process_frame
	var bus = _find_button(main.map_sidebar, "搭乘 17 路 →")
	var walking = _find_button(main.map_sidebar, "步行出发 →")
	if not _check(bus != null and walking != null and not bus.disabled and not walking.disabled, "both valid transport modes have explicit departure controls"):
		return
	bus.pressed.emit()
	_check(main.traveling and main.game.state == before, "confirmed departure first animates the route without an early clock charge")
	_check(bus.disabled and walking.disabled, "departure disables both buttons to prevent accidental repeated charges")
	main._depart("lookout", "bus")
	main._close_overlay()
	_check(is_instance_valid(main.overlay), "closing a map in transit cannot destroy the active route animation")
	await create_timer(1.25).timeout
	_check(not main.traveling and main.current_view == "location" and main.game.state.location == "lookout", "animated departure arrives in the destination world")
	_check(main.game.state.minute == 805, "animation and duplicate departure request charge the bus journey only once")
	_check(not is_instance_valid(main.overlay) and is_instance_valid(main.walker), "arrival removes the map and restores the on-scene walking character")
	main.game.new_game()
	main._travel("bus_stop")
	main.game.state.minute = 1001
	main._location()
	main._map()
	main._preview_destination("lookout")
	await process_frame
	bus = _find_button(main.map_sidebar, "搭乘 17 路 →")
	walking = _find_button(main.map_sidebar, "步行出发 →")
	_check(bus != null and bus.disabled and "末班16:40已过" in _visible_text(main.map_sidebar), "map explains why the last bus can no longer be boarded")
	if walking != null:
		walking.pressed.emit()
		await create_timer(1.25).timeout
	_check(main.game.state.location == "lookout" and main.game.state.minute == 1041, "the actual walking departure remains usable after bus service ends")
	main.game.new_game()
	main._location()
	await process_frame

func _check_empty_recipient() -> void:
	main.game.add_clue("old_civic_hall_name")
	main._travel("community_center")
	_select_letter("case01")
	main._decision()
	await process_frame
	var before: Dictionary = main.game.state.duplicate(true)
	main._choose_action("deliver")
	await process_frame
	_check("先登记收件人" in _visible_text(main.overlay), "blank recipient prompts for an intentional identity selection")
	_check(main.game.case_state("case01").attempts == before.letters.case01.attempts and main.game.state.reputation == before.reputation, "blank recipient is not counted as a mistaken delivery or a reputation loss")
	_check(main.game.state.minute == before.minute and not main.game.is_handled("case01"), "blank recipient neither advances time nor handles the letter")
	main._close_overlay()
	main.game.new_game()
	main._location()
	await process_frame

func _play_day() -> void:
	# Ordinary deliveries use the actual decision sheet, with explicit candidates.
	_select_letter("case01")
	await _observe("community_center", "old_civic_hall_name")
	await _observe("community_center", "community_center_history")
	await _choose("case01", "deliver", "community_center")
	_check(main.game.is_handled("case01"), "main decision callback delivers old-name letter")
	main._travel("bus_stop")
	await process_frame
	await _observe("bus_stop", "bus_to_lookout")
	for round_index in range(4):
		var question: Dictionary = {}
		for candidate in main.game.available_questions("chenyuan"):
			if not ("chenyuan:" + str(candidate.id)) in main.game.state.asked:
				question = candidate
				break
		if question.is_empty():
			break
		var scene_id: int = main.world.get_instance_id()
		var walker_id: int = main.walker.get_instance_id()
		var conversation_minute: int = int(main.game.state.minute)
		main._talk("chenyuan")
		await create_timer(0.46).timeout
		_check(main.world.get_instance_id() == scene_id and main.walker.get_instance_id() == walker_id, "conversation retains the existing world and player actor")
		_check(_find_script(main.world, "res://scripts/ui/resident_portrait.gd") != null and main.walker.get_parent() == main.actor_layer and main.world.is_ancestor_of(main.walker), "conversation keeps the resident and postal worker together in the sorted scene actor layer")
		_check(_nodes_of_class(main.overlay, "TextureRect").is_empty(), "conversation ribbon does not replace the scene with an enlarged portrait")
		_check(not main.world_hud.visible and not main.walker.manual_enabled and absf(main.world.position.y + 132.0) < 1.0, "conversation frames the existing stage and disables incidental movement")
		_check(main.game.state.minute == conversation_minute, "reading the animated conversation does not consume game time")
		var question_button = _find_button(main.overlay, "— " + str(question.question))
		_check(question_button != null, "courier question appears in real conversation")
		if question_button == null:
			continue
		question_button.pressed.emit()
		await process_frame
		_check(str(question.answer) in _visible_text(main.overlay), "question click displays its actual answer")
		var used = _find_button(main.overlay, "· " + str(question.question))
		_check(used != null and used.has_theme_color_override("font_color"), "asked question is marked read after main rebuild")
	_check("delegate_terms" in main.game.state.clues, "progressively unlocked conversation includes explicit delegation agreement")
	main._close_overlay()
	await create_timer(0.36).timeout
	_check(main.world_hud.visible and main.walker.manual_enabled and absf(main.world.position.y) < 1.0, "closing conversation restores the world framing, HUD and manual movement")
	await _choose("case02", "delegate", "mira_vale")
	_check(main.game.case_state("case02").status == "delegated", "main decision hands urgent letter to courier")
	# Main owns board configuration, save callbacks, and completion forwarding.
	_select_letter("case03")
	main._physical("fragments")
	await process_frame
	board = _find_board(main.overlay)
	if not _check(board != null, "main opens the actual fragment interaction board"):
		return
	var saved_position: Vector2 = Vector2(431, 188)
	_drag(board._pieces[0].position, saved_position)
	main._close_overlay()
	await process_frame
	_check(main.game.case_state("case03").get("physical_progress", {}).has("fragments"), "closing main modal saves unfinished physical progress")
	main._physical("fragments")
	await process_frame
	board = _find_board(main.overlay)
	_check(board != null and board._pieces[0].position.is_equal_approx(saved_position), "main reopens board at the saved paper position")
	if board == null:
		return
	for index in range(6):
		var piece: Dictionary = board._pieces[index]
		for rotation in range((4 - int(piece.turn)) % 4):
			_pointer_button(piece.position, true, MOUSE_BUTTON_RIGHT)
		_drag(piece.position, piece.target)
	board._process(1.3)
	await process_frame
	_check(main.game.case_state("case03").repair_solved, "fragment completion reaches GameSession through main signal")
	_check(not main.game.case_state("case03").get("physical_progress", {}).has("fragments"), "completed fragment progress is not re-saved by modal cleanup")
	main._close_overlay()
	await _observe("residential", "resident_moved")
	await _observe("bus_stop", "lookout_schedule")
	main._travel("lookout")
	await _choose("case03", "deliver", "nora_vale")
	_check(main.game.is_handled("case03"), "main can deliver repaired-address letter without opening")
	await _observe("residential", "old_nameplate")
	await _observe("community_center", "event_archive")
	await _observe("community_center", "handwriting_sample")
	await _record_deduction()
	await _choose("case04", "hold", "june_arlen", "mira_vale")
	_check(main.game.is_handled("case04") and main.game.state.ending.is_empty(), "case04 confirmation registers choice without ending early")
	_check("没有发生的冲突" not in _visible_text(main.overlay), "moral branch consequence remains hidden before evening")
	main._close_overlay()
	main._evening()
	await process_frame
	_check(main.selected == "case05", "evening transition selects special letter")
	main._close_overlay()
	main._physical("open")
	await process_frame
	board = _find_board(main.overlay)
	if not _check(board != null, "special letter opens through actual main physical modal"):
		return
	_pointer_button(Vector2(130, 125), true)
	_pointer_button(Vector2(130, 125), false)
	_pointer_button(board._path[0], true)
	for point in board._path:
		_pointer_motion(point)
		board._process(0.11)
	_drag(board._moving, Vector2(520, 130))
	board._process(0.5)
	await process_frame
	_check(main.game.case_state("case05").opened and "old_mail_log" in main.game.state.clues, "unfold completion reaches state and grants old-mail record")
	_check(str(main.game.letter_data("case05").body) in _visible_text(main.overlay), "actual opening callback displays the full special-letter body")
	main._close_overlay()
	main._physical("archive")
	await process_frame
	board = _find_board(main.overlay)
	if not _check(board != null, "main opens actual historical archive board"):
		return
	var correct_row = -1
	for index in range(board._records.size()):
		if str(board._records[index].serial) == str(main.game.catalog.archive_target):
			correct_row = index
	_check(correct_row >= 0, "live archive contains the target serial")
	if correct_row < 0:
		return
	_check(str(board._records[correct_row].date) == board._match_date, "main archive target date uses the live catalog format")
	var wrong_row = (correct_row + 1) % board._records.size()
	_drag(board._moving, board._archive_row_rect(wrong_row).get_center())
	_check(not main.game.state.archive_matched, "wrong historical row does not reach core match callback")
	_drag(board._moving, board._archive_row_rect(correct_row).get_center())
	board._process(1.3)
	await process_frame
	_check(main.game.state.archive_matched, "real archive drag and completion signal unlock final choice")
	_check(not main.game.case_state("case05").get("physical_progress", {}).has("archive"), "archive completion leaves no stale active-board progress")
	main._close_overlay()
	await _choose("case05", "file", "player")
	_check(main.current_view == "ending" and not main.game.state.ending.is_empty(), "final choice callback invokes end_day and renders summary")
	var summary = _visible_text(main.screen)
	_check("没有发生的冲突，也是一种被我制造的结果。" in summary, "summary includes the selected hold branch's specific evening scene")
	_check("你把旧清单与短笺一并放进正式档案" in summary, "summary includes the selected archive-file ending")
	_check("我不知道她当时等过" not in summary, "summary does not mix the unselected delivery consequence")
	var rich_bodies = _nodes_of_class(main.screen, "RichTextLabel")
	_check(not rich_bodies.is_empty(), "evening scenes use a scrollable text control")
	if not rich_bodies.is_empty():
		await _check_scroll_reaches_end(rich_bodies[0], "evening summary")
	main._title()
	await process_frame
	var continue_button = _find_button(main.screen, "继续工作  →")
	_check(continue_button != null and not continue_button.disabled, "completed day remains available via Continue")
	if continue_button != null:
		continue_button.pressed.emit()
	await process_frame
	_check(main.current_view == "ending", "Continue restores the ending view rather than reopening work")
	_check("没有发生的冲突，也是一种被我制造的结果。" in _visible_text(main.screen), "Continue reconstructs saved branch-specific evening feedback")
	_check(not is_instance_valid(main.overlay) and _direct_controls() == 1, "complete day and Continue leave no blocking stale modal")

func _check_damage_recovery() -> void:
	_select_letter("case04")
	main._physical("open")
	await process_frame
	board = _find_board(main.overlay)
	if not _check(board != null, "main starts a recoverable physical opening"):
		return
	var checkpoint: Dictionary = main.game.state.checkpoint.snapshot.duplicate(true)
	_pointer_button(Vector2(130, 125), true)
	_pointer_button(Vector2(130, 125), false)
	_pointer_button(board._path[0], true)
	for mistake in range(8):
		_pointer_motion(Vector2(200, 455))
		board._process(0.02)
		if mistake == 2:
			_check(not board._message.is_empty() and not main.game.has_failure(), "third pointer slip gives a warning while recovery remains possible")
		if mistake == 5:
			_check(not board._message.is_empty() and not main.game.has_failure(), "sixth pointer slip warns before professional failure")
		_pointer_motion(board._point_on_path(board._trace_distance))
		board._process(0.02)
	_check(board._mistakes == 8, "eight real off-path pointer slips accumulate physical damage")
	for point in board._path:
		_pointer_motion(point)
		board._process(0.11)
	_check(not main.game.case_state("case04").opened, "damaged trace alone still cannot expose the private letter")
	_drag(board._moving, Vector2(520, 130))
	board._process(0.5)
	await process_frame
	_check(main.current_view == "failure" and main.game.has_failure(), "completed damaged opening reaches the dedicated failure screen")
	_check(not main.game.case_state("case04").opened and "old_photo" not in main.game.state.clues, "failure callback never grants the opened letter or hidden photo")
	_check(str(main.game.letter_data("case04").body) not in _visible_text(main.screen), "failure screen does not leak the letter body")
	var chapter = _find_script(main.screen, "res://scripts/ui/chapter_screen.gd")
	if not _check(chapter != null, "failure is rendered by the chapter screen"):
		return
	chapter.secondary_button.pressed.emit()
	await process_frame
	_check(main.current_view == "title", "failure secondary action returns to title")
	chapter = _find_script(main.screen, "res://scripts/ui/chapter_screen.gd")
	chapter.secondary_button.pressed.emit()
	await process_frame
	_check(main.current_view == "failure" and main.game.can_resume_failure(), "Continue restores the saved failure with a usable checkpoint")
	chapter = _find_script(main.screen, "res://scripts/ui/chapter_screen.gd")
	chapter.primary_button.pressed.emit()
	await process_frame
	_check(main.current_view == "desk" and not main.game.has_failure(), "failure primary action resumes actual gameplay")
	_check(JSON.parse_string(JSON.stringify(main.game.state)) == JSON.parse_string(JSON.stringify(checkpoint)), "main checkpoint recovery restores every pre-opening fact and minute exactly")
	_check(not is_instance_valid(main.overlay) and _direct_controls() == 1, "checkpoint recovery leaves no stale physical or failure overlay")

func _record_deduction() -> void:
	_select_letter("case04")
	main._decision()
	await process_frame
	board = _find_script(main.overlay, "res://scripts/ui/deduction_board.gd")
	if not _check(board != null, "case04 decision opens the real three-role deduction board"):
		return
	_check(board._cards.size() == 3 and board._find_card("old_photo") == -1, "main deduction board shows only discovered evidence")
	_pointer_button(board.SEAL, true)
	_pointer_button(board.SEAL, false)
	board._process(0.4)
	_check(main.game.case_state("case04").deduction_claims.is_empty(), "premature seal cannot bypass physical evidence placement")
	var mapping = {"address":"old_nameplate", "date":"event_archive", "sender":"handwriting_sample"}
	for role in mapping:
		var card_index: int = board._find_card(mapping[role])
		_drag(board._cards[card_index].position, board._slot_center(role))
	_check(board.claims == mapping and main.game.case_state("case04").deduction_claims.is_empty(), "three physical evidence placements remain provisional until stamped")
	_pointer_button(board.SEAL, true)
	_pointer_button(board.SEAL, false)
	board._process(0.4)
	await process_frame
	_check(main.game.case_state("case04").deduction_claims == mapping, "real deduction seal forwards exact role claims to the core")
	_check(is_instance_valid(main.recipient_select) and _find_script(main.overlay, "res://scripts/ui/deduction_board.gd") == null, "successful provisional registration reaches the final identity and moral decision")
	_check("正确" not in _visible_text(main.overlay), "deduction registration does not reveal objective correctness early")
	main._close_overlay()

func _check_attachment_handoffs() -> void:
	for with_photo in [true, false]:
		main._start_fresh()
		main._close_overlay()

		await _observe("residential", "old_nameplate")
		await _observe("community_center", "event_archive")
		await _observe("community_center", "handwriting_sample")
		await _record_deduction()
		main._travel("lookout")
		_select_letter("case04")
		main._physical("open")
		await process_frame
		board = _find_board(main.overlay)
		if not _check(board != null, "opened-photo handoff begins with an actual opening board"):
			return
		_pointer_button(Vector2(130, 125), true)
		_pointer_button(Vector2(130, 125), false)
		_pointer_button(board._path[0], true)
		for point in board._path:
			_pointer_motion(point)
			board._process(0.11)
		_drag(board._moving, Vector2(520, 130))
		board._process(0.5)
		await process_frame
		_check(main.game.case_state("case04").opened and not main.game.case_state("case04").restored, "opened photo is available while envelope is still unsealed")
		main._close_overlay()
		main._decision()
		await process_frame
		_select_metadata(main.recipient_select, "june_arlen")
		_select_metadata(main.sender_select, "mira_vale")
		main._choose_action("deliver")
		await process_frame
		var prepare = _find_button(main.overlay, "展开信与照片")
		if not _check(prepare != null, "opened delivery prepares the photograph before requiring resealing"):
			return
		prepare.pressed.emit()
		await process_frame
		board = _find_script(main.overlay, "res://scripts/ui/attachment_board.gd")
		if not _check(board != null, "main handoff confirmation opens the physical photograph board"):
			return
		_drag(board._photo_position, board.ENVELOPE_START if with_photo else board.DRAWER_PHOTO)
		_check(not main.game.is_handled("case04"), "arranging the photograph does not prematurely dispatch the letter")
		_drag(board._envelope_position + Vector2(0, 65), board.OUTGOING.get_center() + Vector2(0, 65))
		board._process(0.6)
		await process_frame
		board = _find_board(main.overlay)
		if not _check(board != null and board.mode == "restore", "photograph arrangement advances to the real resealing board"):
			return
		_check(not main.game.is_handled("case04") and not main.game.case_state("case04").restored, "letter remains in custody until physical restoration finishes")
		_drag(board._moving, board.PAGE_TARGET)
		_drag(board._moving, board.EDGE_TARGET)
		_drag(board._moving, board.TAPE_TARGET)
		_pointer_button(board._moving, true)
		_pointer_motion(board.STAMP_TARGET)
		board._process(0.7)
		_pointer_button(board.STAMP_TARGET, false)
		board._process(0.8)
		await process_frame
		var expected = "deliver" if with_photo else "remove_attachment"
		_check(main.game.case_state("case04").choice == expected and main.game.case_state("case04").restored, "physical arrangement and restoration commit exactly " + expected)
		_check(main.game.case_state("case04").removed_attachment == (not with_photo) and main.game.state.repair_materials == 2, "photograph destination and one repair allocation persist together")
		_check(not main.game.has_failure(), "completed physical handoff remains in ordinary gameplay")
		_assert_handoff("june_arlen", "physical photo handoff")
		main._close_overlay()

func _check_opened_return() -> void:
	# Preconditions use the already-tested authoritative API. The regression is
	# specifically the Main confirmation -> actual repair -> return callback.
	main.game.new_game()
	for id in ["old_nameplate", "event_archive", "handwriting_sample"]:
		main.game.add_clue(id)
	main.game.record_deduction({"address":"old_nameplate", "date":"event_archive", "sender":"handwriting_sample"})
	main.game.complete_open("case04", "safe", 0)
	main._travel("lookout")
	_select_letter("case04")
	main._tools()
	await process_frame
	var reseal = _find_button(main.overlay, "保留全部内容，先封回信件")
	if not _check(reseal != null and not reseal.disabled, "opened old letter exposes a general resealing tool independent of recipient delivery"):
		return
	reseal.pressed.emit()
	await process_frame
	board = _find_board(main.overlay)
	_check(board != null and board.mode == "restore", "general resealing tool opens the actual restoration board")
	main._close_overlay()
	await _choose("case04", "return_to_sender", "june_arlen", "mira_vale")
	board = _find_board(main.overlay)
	if not _check(board != null and board.mode == "restore", "opened return confirmation automatically routes through restoration"):
		return
	_check(not main.game.is_handled("case04") and not main.game.case_state("case04").restored, "return is still provisional until the envelope is sealed")
	_drag(board._moving, board.PAGE_TARGET)
	_drag(board._moving, board.EDGE_TARGET)
	_drag(board._moving, board.TAPE_TARGET)
	_pointer_button(board._moving, true)
	_pointer_motion(board.STAMP_TARGET)
	board._process(0.7)
	_pointer_button(board.STAMP_TARGET, false)
	board._process(0.8)
	await process_frame
	var returned: Dictionary = main.game.case_state("case04")
	_check(main.game.is_handled("case04") and returned.choice == "return_to_sender" and returned.restored, "physical resealing completion actually returns the opened letter to its sender")
	_check(not returned.removed_attachment and main.game.state.repair_materials == 2, "return preserves the photograph and consumes exactly one repair allocation")
	_check(not main.game.has_failure(), "opened return exits the repair modal into normal gameplay")
	_assert_handoff("mira_vale", "opened return")
	main._close_overlay()

func _select_letter(id: String) -> void:
	main.game.select_case(id)
	main.selected = id
	main._desk()

func _observe(location_id: String, clue_id: String) -> void:
	if main.game.state.location != location_id:
		main._travel(location_id)
	else:
		main._location()
	await process_frame
	for hotspot in main.game.location_data(location_id).hotspots:
		if clue_id in hotspot.get("clues", []):
			var minute_before: int = int(main.game.state.minute)
			main._inspect(location_id, hotspot)
			await process_frame
			var evidence = _find_script(main.overlay, "res://scripts/ui/visual_evidence.gd")
			var was_visual: bool = evidence != null
			if was_visual:
				_check(not clue_id in main.game.state.clues, "opening the visual observation does not grant " + clue_id)
				board = evidence
				_pointer_button(Vector2(1040, 624), true)
				_pointer_button(Vector2(1040, 624), false)
				_check(not clue_id in main.game.state.clues, "premature recording cannot bypass observing " + clue_id)
				_complete_visual_observation()
				_check(board.ready_to_record, "physical evidence observations enable recording " + clue_id)
				_pointer_button(Vector2(1040, 624), true)
				_pointer_button(Vector2(1040, 624), false)
				await process_frame
			_check(clue_id in main.game.state.clues, "main observation callback records " + clue_id)
			_check(int(main.game.state.minute) == minute_before, "examining and reading " + clue_id + " never advances the shift clock")
			if was_visual:
				_check(not is_instance_valid(main.overlay) and main.current_view == "location" and main.walker.manual_enabled, "recorded visual evidence returns directly to the controllable scene")
			else:
				_check(str(hotspot.text) in _visible_text(main.overlay), "main observation displays the actual clue source")
			main._close_overlay()
			return
	_check(false, "missing observation source " + clue_id)

func _visual_tap(point: Vector2) -> void:
	_pointer_button(point, true)
	_pointer_button(point, false)

func _complete_visual_observation() -> void:
	match board.mode:
		"plaque":
			_drag(Vector2(450, 350), Vector2(450, 180))
			_visual_tap(Vector2(430, 391))
		"resident":
			_drag(Vector2(460, 323), Vector2(800, 323))
			_visual_tap(Vector2(359, 343))
			_visual_tap(Vector2(950, 294))
		"registry":
			_drag(Vector2(360, 349), Vector2(150, 349))
			_visual_tap(Vector2(714, 323))
			_visual_tap(Vector2(685, 379))
		"archive":
			_drag(Vector2(603, 340), Vector2(893, 340))
			_visual_tap(Vector2(353, 391))
			_visual_tap(Vector2(650, 405))
		"handwriting":
			_drag(Vector2(805, 220), Vector2(255, 214))
			_visual_tap(Vector2(161, 255))
			_visual_tap(Vector2(236, 369))
		"timetable":
			_visual_tap(Vector2(588, 242))
			var departures: Array = board.payload.get("departures", [790, 910, 1000])
			var feasible: int = -1
			for i in range(departures.size()):
				if int(departures[i]) >= int(main.game.state.minute) and int(departures[i]) + 15 <= 1080:
					feasible = i
					break
			_visual_tap(Vector2(820, 180 + 86 * feasible) if feasible >= 0 else Vector2(958, 536))
		"envelope":
			_visual_tap(Vector2(360, 300))
			_visual_tap(Vector2(821, 250))
		"photo":
			_visual_tap(Vector2(770, 350))
			_visual_tap(Vector2(850, 517))
			_visual_tap(Vector2(400, 500))
		_:
			_check(false, "unknown visual evidence mode " + str(board.mode))

func _choose(id: String, action: String, recipient: String = "", sender: String = "") -> void:
	_select_letter(id)
	main._decision()
	await process_frame
	_select_metadata(main.recipient_select, recipient)
	if not sender.is_empty():
		_select_metadata(main.sender_select, sender)
	main._choose_action(action)
	await process_frame
	if id in ["case04", "case05"]:
		var commit_button = _find_button(main.overlay, "照这样处理")
		_check(commit_button != null, id + " presents its in-world final decision wording")
		if commit_button != null:
			commit_button.pressed.emit()
		await process_frame
	if main.game.is_handled(id) and action in ["deliver", "delegate"] and id in ["case01", "case02", "case03"]:
		_assert_handoff("chenyuan" if action == "delegate" or id == "case01" else recipient, id + " handoff")

func _assert_handoff(receiver: String, context: String) -> void:
	_check(main.current_view == "location" and main.dialogue_npc == receiver, context + " presents the outcome beside the actual receiver")
	_check(is_instance_valid(main.world) and is_instance_valid(main.walker) and main.walker._gesture_name == "handoff", context + " starts the postal worker's on-scene handing gesture")
	_check(_nodes_of_class(main.overlay, "TextureRect").is_empty() and not main.walker.manual_enabled, context + " keeps the world figures visible during the handoff conversation")

func _select_metadata(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	_check(false, "candidate absent from main selector: " + value)

func _check_scroll_reaches_end(text: RichTextLabel, context: String) -> void:
	await process_frame
	_check(text.scroll_active and text.size.y > 0, context + " enables bounded readable scrolling")
	text.scroll_to_line(maxi(0, text.get_line_count() - 1))
	await process_frame
	var scrollbar = text.get_v_scroll_bar()
	var end = maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	_check(scrollbar.value >= end - 2.0, context + " last line is reachable without clipping")

func _pointer_button(point: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new()
	var origin: Vector2 = board._canvas_origin() if board.has_method("_canvas_origin") else board._origin()
	event.position = origin + point * (board._scale_factor() if board.has_method("_scale_factor") else board._factor())
	event.button_index = button
	event.pressed = pressed
	board._gui_input(event)

func _pointer_motion(point: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	var origin: Vector2 = board._canvas_origin() if board.has_method("_canvas_origin") else board._origin()
	event.position = origin + point * (board._scale_factor() if board.has_method("_scale_factor") else board._factor())
	board._gui_input(event)

func _drag(from: Vector2, to: Vector2) -> void:
	_pointer_button(from, true)
	_pointer_motion(to)
	_pointer_button(to, false)

func _find_board(node: Node):
	return _find_script(node, "res://scripts/ui/physical_board.gd")

func _find_script(node: Node, path: String):
	if not is_instance_valid(node):
		return null
	if node.get_script() != null and node.get_script().resource_path == path:
		return node
	for child in node.get_children():
		var found = _find_script(child, path)
		if found != null:
			return found
	return null

func _find_button(node: Node, text: String):
	if not is_instance_valid(node):
		return null
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = _find_button(child, text)
		if found != null:
			return found
	return null

func _nodes_of_class(node: Node, type_name: String) -> Array:
	var result: Array = []
	if node.is_class(type_name):
		result.append(node)
	for child in node.get_children():
		result.append_array(_nodes_of_class(child, type_name))
	return result

func _visible_text(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	var content: Array[String] = []
	if node is Label or node is RichTextLabel:
		content.append(str(node.text))
	for child in node.get_children():
		content.append(_visible_text(child))
	return "\n".join(content)

func _direct_controls() -> int:
	var count = 0
	for child in main.get_children():
		if child is Control:
			count += 1
	return count

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
	return condition
