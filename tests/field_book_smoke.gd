extends SceneTree
## Real Godot GUI input. Fixtures use public core APIs; no author catalog bindings.
const Core = preload("res://scripts/rebuild/final_case_state.gd")
const Book = preload("res://scripts/rebuild/field_book.gd")
var checks := 0
var failures: Array[String] = []
var game: Node
var book: Control
var host: Control
var closed_count := 0
var artifacts: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.gui_embed_subwindows = true
	root.title = "Field book isolated input QA"
	game = Core.new()
	game.save_path = "user://qa/field-book-" + str(Time.get_ticks_usec()) + ".json"
	root.add_child(game)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var scene := TextureRect.new()
	scene.texture = load("res://assets/generated/post_office_interior.png")
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book = Book.new()
	host.add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.closed.connect(func() -> void: closed_count += 1)
	book.configure(game)
	await process_frame
	await process_frame
	_check(book.section == 0, "initial physical book opens people chapter")
	var painted: Image = Book.Art.texture("handbook_open").get_image()
	_check(painted.get_format() == Image.FORMAT_RGBA8, "painted book base carries real alpha")
	_check(painted.get_pixel(0,0).a == 0.0 and painted.get_pixel(painted.get_width()/2,painted.get_height()/2).a > 0.95, "scene remains visible outside opaque paper silhouette")
	var opaque_height: float = painted.get_used_rect().size.y * Book.BOOK_RECT.size.y / painted.get_height()
	_check(opaque_height / Book.CANVAS.y >= 0.88 and opaque_height / Book.CANVAS.y <= 0.95, "book silhouette occupies about ninety percent of game area height")
	for tab_index: int in range(4):
		var tab: Button = _find("Tab" + str(tab_index))
		_check(tab.text==Book.SECTIONS[tab_index] and not tab.tooltip_text.is_empty(), "chapter uses labelled physical upper paper tab " + str(tab_index))
	_check(not _all_text(book).contains("Helena") and not _all_text(book).contains("Mira") and not _all_text(book).contains("Leonie"), "fresh displayed book does not enumerate hidden people")
	_check(book.find_child("KnownPortrait", true, false) == null, "unmet identity does not show author portrait")
	await _click("Tab2")
	_check(book._items.is_empty() and not _all_text(book).contains("blue bowl"), "uninspected mail is absent from records")
	await _click("Tab3")
	var people: OptionButton = _find("PersonSelect")
	_check(people == null and not _all_text(book).contains("HV"), "fresh conclusion leaf does not leak an unseen archive mark")
	_check(_find("DeskEntry") == null, "desk answer not offered before actual archival evidence")
	_check(_find("CodeSelect") == null, "no formal-code solution options before relevant observation")
	await _shot("field_book_unknown")
	var start_minute: int = game.state.minute
	await _click("Close")
	_check(closed_count == 1 and not book.visible, "actual close button emits once and releases overlay")
	_check(game.state.minute == start_minute, "book inspection and cancel cost no time")
	_prepare_records()
	book.configure(game)
	await process_frame
	await _click("Tab0")
	await _select_id("chenyuan")
	_check(book.find_child("KnownPortrait", true, false) != null, "actual encountered Chenyuan uses generated gameplay portrait")
	_check(_all_text(book).contains("首次交谈") and _all_text(book).contains("公交站"), "person record displays real encounter source")
	await _shot("field_book_person")
	await _click("Tab2")
	await _select_id("case01")
	var mail: RichTextLabel = _find("LetterText")
	_check(mail.text.contains("Elsie Moran") and mail.text.contains("正文没有记录") and not mail.text.contains("blue bowl"), "letter chapter exposes only inspected front and no private body")
	await _click("Tab1")
	_check(book._items.size() > Book.PAGE_SIZE, "fixture requires real source pagination")
	var before_minute: int = game.state.minute
	var before_score: int = game.state.work_reliability
	var before_privacy: Dictionary = game.state.privacy.duplicate(true)
	await _click("NextPage")
	_check(book.page == 1, "corner page control navigates actual sources")
	_check(book._turn_progress > 0.0 and book._turn_progress < 1.0, "real next-page input starts a bound leaf transition")
	_check(book._canvas.modulate.a == 1.0, "turning a leaf does not fade the entire book or the background")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://test-results/field_book_turning.png") == OK, "capture actual intermediate turning leaf")
		artifacts.append("res://test-results/field_book_turning.png")
	await _click("PreviousPage")
	_check(book.page == 0, "previous corner returns to first leaf")
	await _select_id("helena_rota")
	_check((_find("EvidenceText") as RichTextLabel).text == "Helena Voss — Desk B.", "source text shown verbatim, no synthesized conclusion")
	_check(_all_text(book).contains("旧值班表") and _all_text(book).contains("邮局"), "source origin and location visible beside quote")
	await _click("IncludeSource")
	_check("helena_rota" in book.selected_sources and game.state.archive_draft.is_empty(), "source insertion remains editable until write")
	await _select_id("procedure_codes")
	await _click("IncludeSource")
	await _select_id("ledger_returns")
	await _click("IncludeSource")
	await _shot("field_book_evidence")
	await _click("Tab3")
	people = _find("PersonSelect")
	var known_options: Array[String] = []
	for i: int in range(people.item_count): known_options.append(people.get_item_text(i))
	_check("Helena Voss" in known_options and "Leonie" not in known_options and known_options.size() == game.dossier_view().known_people.size()+1, "dropdown draws only current known names")
	await _choose_option("PersonSelect", "尘缘") # Deliberately wrong, but known identity.
	await _click("DeskEntry")
	await _type_ascii("Desk B")
	await _choose_option("CodeSelect", "是正式处置码") # Deliberately wrong factual draft.
	await _click("RecordDraft")
	_check(game.state.archive_draft.get("claims", {}).get("hv_person") == "chenyuan" and game.state.archive_draft.get("claims", {}).get("formal_code") == true, "actual keyboard options submit player's wrong provisional claim")
	_check(game.state.archive_draft.claims.desk == "desk_b", "typed desk text stored without auto-solving")
	_check(game.state.archive_draft.sources.size() == 3 and not game.state.archive_draft.confirmed, "selected independent sources are stored and remain unconfirmed")
	_check(_all_text(book).contains("暂定") and not _all_text(book).contains("答案错误") and book.find_child("ConfirmedRecord", true, false) == null, "wrong draft receives no instant correctness feedback")
	_check(game.state.minute == before_minute and game.state.work_reliability == before_score and game.state.privacy == before_privacy, "book does not advance time, reward guesses or mutate privacy")
	await _shot("field_book_draft")
	await _choose_option("PersonSelect", "Helena Voss")
	await _choose_option("CodeSelect", "不是正式处置码")
	await _click("RecordDraft")
	_check(game.state.archive_draft.get("claims", {}).get("hv_person") == "helena_voss" and game.state.archive_draft.get("claims", {}).get("formal_code") == false, "real controls allow revising draft")
	_check(game.save_game(), "written draft can persist with normal core save")
	var restored := Core.new()
	restored.save_path = game.save_path
	restored.new_game()
	_check(restored.load_game(), "draft reload uses isolated final schema")
	book.configure(restored)
	await process_frame
	await _click("Tab3")
	_check((_find("PersonSelect") as OptionButton).get_item_text((_find("PersonSelect") as OptionButton).selected) == "Helena Voss", "reopened book restores selected person")
	_check((_find("DeskEntry") as LineEdit).text == "Desk B" and book.selected_sources.size() == 3, "reopened book restores writing and cited sources")
	# A larger real canvas changes the transform; clicks still route through viewport input.
	root.content_scale_size = Vector2i(2000, 1125)
	root.size = Vector2i(1600, 900)
	await process_frame
	await _click("Tab1")
	await _select_id("helena_rota")
	await _click("IncludeSource")
	_check("helena_rota" not in book.selected_sources, "2000x1125 layout preserves actual source hit testing")
	await _click("IncludeSource")
	await _shot("field_book_2000")
	await _key(KEY_ESCAPE)
	_check(closed_count == 2 and not book.visible, "actual Escape closes and emits signal at scaled canvas")
	_check(restored.state.minute == before_minute, "reading at larger resolution stays time-free")
	book.configure(restored)
	await process_frame
	_complete_held_cases(restored)
	book.configure(restored)
	await _click("Tab3")
	_check(book.find_child("ConfirmedRecord", true, false) != null, "only actual completed factual reconstruction displays confirmed area")
	_check(_find("RecordDraft") == null, "confirmed final record is read-only and cannot pretend to write into ended shift")
	await _shot("field_book_confirmed")
	book.queue_free(); host.queue_free(); game.queue_free(); restored.free()
	await process_frame
	var report := {"suite": "field_book", "checks": checks, "failures": failures, "runtime": Engine.get_version_info(), "screenshots": artifacts,
		"scope": "Standalone book, actual Godot viewport mouse/keyboard GUI input, public core fixture setup. Not OS-input validation, whole-game reference parity, player testing or final art acceptance.",
		"source_sha256": FileAccess.get_sha256("res://scripts/rebuild/field_book.gd"), "core_sha256": FileAccess.get_sha256("res://scripts/rebuild/final_case_state.gd"), "test_sha256": FileAccess.get_sha256("res://tests/field_book_smoke.gd"), "painted_asset_sha256": FileAccess.get_sha256("res://assets/faefever_v2/props/handbook_open.png")}
	var file := FileAccess.open("res://test-results/field_book_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("FIELD BOOK UI: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _prepare_records() -> void:
	_ok(game.take_case("case01"), "fixture take first")
	_ok(game.inspect_envelope("case01", "front"), "fixture addressed names")
	_ok(game.observe("trusted_handoff_rule"), "fixture public guide")
	_ok(game.travel("community_center", 15), "fixture community")
	for id: String in ["street_renaming", "june_current_mailpoint", "telescope_checkout"]: _ok(game.observe(id), "fixture source " + id)
	_ok(game.travel("bus_stop", 15), "fixture bus")
	_ok(game.meet("chenyuan"), "fixture real known encounter")
	_ok(game.observe("chenyuan_june_history"), "fixture personal answer")
	_ok(game.travel("post_office", 15), "fixture return")
	_ok(game.dispose("case01", "hold_for_verification", "", "Retain first item until its address has another verified source."), "fixture finishes actual first-letter tutorial before archive")
	_record_slip(game, "case01")
	_check(game.state.tutorial_first_case_completed, "book fixture uses recorded tutorial progress")
	_ok(game.discover_archive_box(), "fixture available archive")
	_ok(game.take_case("case04"), "fixture take old item")
	_ok(game.inspect_envelope("case04", "back"), "fixture actual old mark")
	_ok(game.observe("case04_archive_mark"), "fixture record mark")
	_ok(game.dispose("case04", "archive_review", "", "Compare the recovered archive hold."), "fixture legal review")
	for id: String in ["ledger_hv_repeat", "helena_rota", "procedure_codes", "ledger_returns"]: _ok(game.observe(id), "fixture source " + id)


func _complete_held_cases(session: Node) -> void:
	for id: String in ["case02", "case03"]:
		_ok(session.take_case(id), "take remaining legal hold " + id)
		_ok(session.dispose(id, "hold_for_verification", "", "Need next-shift review."), "lawful hold " + id)
	_ok(session.take_case("case05"), "take discovered staff note")
	_ok(session.dispose("case05", "file_officially"), "lawful unread archive")
	for id: String in Core.CASE_IDS:
		if session.resolution_view(id).is_empty(): _record_slip(session, id)
	_ok(session.end_shift(), "actual final confirmation event")


func _record_slip(session: Node, id: String) -> void:
	# Public fixture API: the book suite does not claim to exercise the stamp UI.
	_ok(session.record_resolution(id, {
		"determination": {"recipient": "Not yet fully verified", "location": "Recorded for postal review", "status": "Keep judgment provisional"},
		"disposition": session.case_state(id).disposition,
		"note": "Fixture records the already completed route; no hidden factual answer is supplied.",
		"stamped": true
	}), "fixture records actual postal resolution " + id)


func _find(node_name: String):
	return book.find_child(node_name, true, false)


func _click(node_name: String) -> void:
	var control: Control = _find(node_name)
	_check(control != null, "input target exists " + node_name)
	if control == null: return
	var point := control.get_global_rect().get_center()
	await _mouse(point, true)
	await _mouse(point, false)
	await process_frame


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	var target: Viewport = root
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	target.push_input(event, true)
	await process_frame
	event = InputEventKey.new(); event.keycode = code; event.pressed = false
	target.push_input(event, true)
	await process_frame


func _type_ascii(text: String) -> void:
	for character: String in text:
		var event := InputEventKey.new(); event.unicode = character.unicode_at(0); event.pressed = true
		root.push_input(event, true)
		await process_frame


func _choose_option(node_name: String, text: String) -> void:
	var select: OptionButton = _find(node_name)
	var index := -1
	for i: int in range(select.item_count):
		if select.get_item_text(i) == text: index = i
	_check(index >= 0, "known option exists " + text)
	if index < 0: return
	await _click(node_name)
	_check(select.get_popup().visible, "real option popup opens")
	var focused: int = select.get_popup().get_focused_item()
	for step: int in range(absi(index-focused)): await _key(KEY_DOWN if index > focused else KEY_UP)
	await _key(KEY_ENTER)
	_check(select.selected == index, "real popup keyboard selected " + text)


func _select_id(id: String) -> void:
	var index: int = book._items.find(id)
	_check(index >= 0, "visible record exists " + id)
	if index < 0: return
	var target_page := index / Book.PAGE_SIZE
	while book.page < target_page: await _click("NextPage")
	while book.page > target_page: await _click("PreviousPage")
	await _click("Entry" + str(index))
	_check(book.selected_id == id, "pointer opens selected record " + id)


func _all_text(node: Node) -> String:
	var result := ""
	if node is Label or node is RichTextLabel or node is Button or node is LineEdit: result = str(node.text)
	for child: Node in node.get_children(): result += "\n" + _all_text(child)
	return result


func _shot(name: String) -> void:
	await create_timer(0.36).timeout
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := "res://test-results/" + name + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "actual viewport screenshot " + name)
	artifacts.append(path)


func _ok(error: String, label: String) -> void:
	_check(error.is_empty(), label + (" — " + error if not error.is_empty() else ""))


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
