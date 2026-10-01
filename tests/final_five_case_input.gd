extends "res://tests/final_playable_input_smoke.gd"
## Extends the routed first-case journey with the remaining four real cases.
## No core mutations or host completion methods are used by this continuation.
const FIVE_OUT := "res://artifacts/final_five_case/"
var continuation_started := false
var route := "sealed"
var input_events: Array[Dictionary] = []
var report_written := false
var visited_locations: Array[String] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--route="): route = argument.trim_prefix("--route=")
	_run.call_deferred()
	create_timer(360.0).timeout.connect(func():
		if not report_written:
			_check(false, "six-minute automated route watchdog")
			_finish_five())

func _finish() -> void:
	if continuation_started: return
	continuation_started = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--route="): route = argument.trim_prefix("--route=")
	if failures.is_empty():
		await _continue_five()
	await _finish_five()

func _continue_five() -> void:
	_check(route in ["sealed", "delegate"], "supported complete-route name")
	await _travel("bus_stop" if route == "delegate" else "lookout")
	await _carry_case("case02")
	var person := "chenyuan" if route == "delegate" else "mira_vale"
	await _named("Talk_" + person)
	await _wait(func(): return is_instance_valid(host.modal), "arrive for urgent-mail recipient conversation")
	await _named("AdvanceDialogue")
	if route == "delegate":
		await _text("确认顺路上山送件")
		await _named("AdvanceDialogue")
		await _named("AdvanceDialogue")
	await _text("交出手中的这封信")
	_check(host.core.case_state("case02").disposition == ("delegate" if route == "delegate" else "deliver"), "urgent item actually changes custody")
	await _named("AdvanceDialogue")
	await _text("结束交谈")
	await _return_counter()
	if route == "delegate" and not host.core.state.world_flags.get("delegated_delivery", {}).get("arrived", false):
		await _named("CounterRegister")
		await _text("等待受托交付回执")
		await _key(KEY_ESCAPE)
	_check(host.core.case_state("case02").owner == "mira_vale", "actual arrival receipt precedes urgent-case completion")
	await _record_case("case02", "Mira Vale", "Lookout", "Delivered within the agreed service route")
	await _inspect_bag_case("case03")
	await _repair_exterior()
	await _key(KEY_ESCAPE)
	await _leave_counter()
	await _travel("residential")
	await _named("Clue_current_3c_resident")
	await _wait(func(): return is_instance_valid(host.modal), "reach current-resident record")
	await _read_observation()
	await _key(KEY_ESCAPE)
	await _travel("community_center")
	await _carry_case("case03")
	await _named("MailCubby")
	await _wait(func(): return str(host.core.case_state("case03").disposition) == "forward", "actual corrected mail enters approved cubby")
	_check(host.core.body_text("case03").is_empty() and host.core.case_state("case03").physical.exterior_repaired, "authorized exterior repair and forwarding preserve private body")
	await _return_counter()
	await _record_case("case03", "June Arlen", "Community approved cubby", "Exterior address repaired; forwarded unopened")
	await _named("Mail_case04")
	await _wait(func(): return is_instance_valid(host.modal), "take old case from actual archive tray")
	await _click(host.modal.to_canvas(host.modal.model.object_rect("envelope").get_center()), MOUSE_BUTTON_RIGHT)
	_check(host.core.has_evidence("case04_archive_mark"), "actual reverse supplies old HV mark")
	await _key(KEY_ESCAPE)
	await _leave_counter()
	await _travel("community_center")
	await _carry_case("case04")
	await _named("MailCubby")
	await _wait(func(): return not host.walker.walking and not host.busy, "courier reaches approved forwarding cubby with the old letter")
	_check(host.core.case_state("case04").owner=="courier" and host.core.case_state("case04").disposition.is_empty(), "forwarding cubby cannot pretend to be June receiving a different mail item")
	await _named("Talk_june_arlen")
	await _wait(func(): return is_instance_valid(host.modal), "courier approaches June for actual old-letter handoff")
	await _named("AdvanceDialogue")
	await _named("Choice_deliver")
	_check(host.core.case_state("case04").owner=="june_arlen" and host.core.case_state("case04").disposition=="deliver", "old letter is actually handed to June on site")
	await _named("AdvanceDialogue")
	await _named("Choice_leave")
	await _return_counter()
	await _record_case("case04", "June Arlen", "Community center; handed to June", "Old letter delivered sealed by hand; original marking retained")
	for evidence: Array in [["翻到账簿夹袋", "ledger_hv_repeat"], ["查看值班人表", "helena_rota"], ["服务代码", "procedure_codes"], ["回案记录", "ledger_returns"]]:
		await _named("CounterReferenceBook")
		await _text("翻开旧账簿")
		await _text(str(evidence[0]))
		await _read_observation()
		_check(host.core.has_evidence(str(evidence[1])), "real ledger row inspected: " + str(evidence[1]))
		await _key(KEY_ESCAPE)
	_check(host.core.case_state("case05").available, "handled old case plus repeated record actually reveals staff sleeve")
	await _named("Mail_case05")
	await _wait(func(): return is_instance_valid(host.modal), "take discovered staff sleeve")
	if not is_instance_valid(host.modal) or host.core.case_state("case05").owner != "courier": return
	await _key(KEY_ESCAPE)
	await _register_staff()
	if host.core.case_state("case05").disposition != "file_officially" or _modal_script() != "res://scripts/rebuild/resolution_slip.gd": return
	await _fill_and_stamp("case05", "Desk B staff record", "Official archive", "Filed without opening")
	for id: String in host.core.CASE_IDS:
		_check(not str(host.core.case_state(id).disposition).is_empty(), id + " has an actual completed disposition")
		_check(host.core.resolution_view(id).get("stamped", false), id + " has a physically submitted resolution")
		_check(host.core.body_text(id).is_empty(), id + " full route never revealed private body")
	_check(host.core.state.opening_history.is_empty(), "all five cases complete without spending any opening")
	await _shot("five_cases_recorded")
	# Free exploration remains available after mail work; these are real journeys.
	# Visit the two optional scenes and the alternate urgent-mail route as well.
	for destination: String in ["chess_stall", "tarot_shop", "lookout" if route == "delegate" else "bus_stop"]:
		await _travel(destination)
	await _return_counter()
	_check(visited_locations.size() == 7, "all seven actual world scenes reached through map and travel input")
	await _named("CounterRegister")
	await _text("签下今天的交班记录")
	_check(not host.core.state.ending.is_empty(), "actual handover control reaches full five-case ending")
	await _shot("complete_ending")

func _leave_counter() -> void:
	if host.view == "counter": await _text("走回门外")

func _return_counter() -> void:
	if host.core.state.location != "post_office": await _travel("post_office")
	if host.view != "counter":
		await _named("PostDoor")
		await _wait(func(): return host.view == "counter", "courier walks back to counter")

func _bag_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in host.core.CASE_IDS:
		var item: Dictionary = host.core.case_state(id)
		if item.available and item.owner == "courier" and str(item.disposition).is_empty(): result.append(id)
	return result

func _carry_case(id: String) -> void:
	await _named("OpenBag")
	var named := _node("Carry_" + id)
	if named != null: await _click(named.get_global_rect().get_center())
	else:
		var icons: Array[Control] = []
		for candidate: Control in _buttons(host):
			if candidate.get_script() != null and candidate.get_script().resource_path.ends_with("object_button.gd") and str(candidate.caption) == "拿在手中": icons.append(candidate)
		var index := _bag_ids().find(id)
		if not _assert_target(index >= 0 and index < icons.size(), "visible bag item for " + id): return
		await _click(icons[index].get_global_rect().get_center())
	_check(host.carried == id, "real bag interaction carries " + id)

func _inspect_bag_case(id: String) -> void:
	await _named("OpenBag")
	var named := _node("Inspect_" + id)
	if named != null: await _click(named.get_global_rect().get_center())
	else:
		var choices: Array[Control] = []
		for candidate: Control in _buttons(host):
			if candidate is Button and candidate.text == "放桌上查看": choices.append(candidate)
		var index := _bag_ids().find(id)
		if not _assert_target(index >= 0 and index < choices.size(), "visible inspection choice for " + id): return
		await _click(choices[index].get_global_rect().get_center())
	_check(_modal_script().ends_with("mail_workbench.gd"), "physical workbench mounts for " + id)

func _record_case(id: String, recipient: String, place: String, status: String) -> void:
	await _named("CounterRegister")
	await _named("Resolution_" + id)
	await _fill_and_stamp(id, recipient, place, status)

func _fill_and_stamp(id: String, recipient: String, place: String, status: String) -> void:
	await _fill("Field_recipient", recipient)
	await _fill("Field_location", place)
	await _fill("Field_status", status)
	await _fill("ResolutionNote", "Observed sources and actual custody are recorded separately.")
	await _named("ReviewSlip")
	_check(host.core.resolution_view(id).is_empty(), "review alone does not stamp " + id)
	await _shot(id + "_review")
	var seal: Control = _node("DeskSeal")
	if not _assert_target(seal != null, "real seal is available after reviewing " + id): return
	await _drag(seal.get_global_rect().get_center(), _region("stamp_area").get_center())
	await _wait(func(): return not is_instance_valid(host.modal), "physical seal finishes " + id)
	_check(host.core.resolution_view(id).get("stamped", false), "actual seal records " + id)

func _register_staff() -> void:
	await _named("CounterRegister")
	var named := _node("Register_case05")
	if named != null: await _click(named.get_global_rect().get_center())
	else: await _text("写下去向与原因")
	await _text(str(host.DISPOSITION.file_officially))
	_check(host.core.case_state("case05").disposition == "file_officially", "actual archive disposition precedes staff resolution")

func _repair_exterior() -> void:
	var bench: Control = host.modal
	if not bench.get_workbench_snapshot().drawer.opened:
		var handle: Rect2 = bench.drawer_handle_rect()
		await _drag(handle.get_center(), handle.get_center() + Vector2(0,44))
	_check(bench.get_workbench_snapshot().drawer.opened, "physical drawer is opened before taking exterior repair tools")
	await _click(bench.tool_rect("restorer").get_center())
	await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()), MOUSE_BUTTON_RIGHT)
	await _move_material("envelope", Vector2(30,0))
	if str(bench.model.export_state().face) != "back":
		await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()), MOUSE_BUTTON_RIGHT)
	_check(bench.model.export_state().inspected_front and bench.model.export_state().inspected_back, "both actual envelope faces are inspected before exterior work")
	await _click(bench.tool_rect("restorer").get_center())
	await _click(bench.to_canvas(bench.model.object_rect("label").get_center()))
	var start: Vector2 = bench.to_canvas(bench.model.object_rect("label").get_center())
	var goal: Vector2 = bench.model.object_rect("envelope").position + Vector2(190,130)
	var shift: Vector2 = goal - bench.model.object_rect("label").position
	await _move(start); await _button(MOUSE_BUTTON_LEFT,true); await _key(KEY_R)
	await _move(start + shift); await _button(MOUSE_BUTTON_LEFT,false)
	await _move_material("protector", goal - Vector2(10,10) - bench.model.object_rect("protector").position)
	await _click(bench.tool_rect("press").get_center())
	await _click(bench.to_canvas(goal + Vector2(20,20)))
	await _move_material("exterior_fold", Vector2(0,70))
	await _click(bench.to_canvas(bench.model.object_rect("envelope").position + Vector2(25,25)), MOUSE_BUTTON_RIGHT)
	await _click(bench.to_canvas(bench.model.object_rect("envelope").position + Vector2(25,25)), MOUSE_BUTTON_RIGHT)
	_check(host.core.case_state("case03").physical.exterior_repaired and host.core.has_evidence("label_reconstructed"), "actual lift/rotate/place/protect/press/refold reveals repaired exterior")
	await _shot("case03_authorized_repair")

func _move_material(id: String, delta: Vector2) -> void:
	var bench: Control = host.modal
	var start: Vector2 = bench.model.object_rect(id).get_center()
	await _drag(bench.to_canvas(start), bench.to_canvas(start + delta))

func _travel(id: String) -> void:
	await _leave_counter()
	if host.core.state.location == id: return
	var before: int = host.core.state.minute
	await _named("OpenMap")
	await _named("Map_" + id)
	_check(host.core.state.minute == before, "route preview does not advance time")
	await _text("沿这条路步行")
	await _wait(func(): return not host.busy and host.core.state.location == id, "real route arrives at " + id)
	_check(int(host.core.state.minute) - before in [15,30], "one previewed journey charges 15 or 30 minutes")
	if host.core.state.location == id and id not in visited_locations:
		visited_locations.append(id)
		await _shot("world_" + id)

func _assert_target(condition: bool, label: String) -> bool:
	_check(condition, label)
	return condition

func _shot(file_name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(FIVE_OUT + route)
	var path := FIVE_OUT + route + "/" + file_name + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "GPU capture " + file_name)
	screenshots.append(path)

func _finish_five() -> void:
	if report_written: return
	report_written = true
	var final_hashes := _source_hashes()
	_check(initial_hashes == final_hashes, "sources stayed unchanged throughout complete route")
	var report := {"suite":"final_five_case_input", "route":route, "checks":checks, "failures":failures, "steps":steps, "screenshots":screenshots, "elapsed_ms":Time.get_ticks_msec()-began, "source_sha256":initial_hashes, "source_sha256_at_finish":final_hashes, "dispositions":{}, "resolution_count":0, "ending_reached":not host.core.state.ending.is_empty(), "scope":"Actual routed GPU InputEvent journey through hosted five-case game; no core state injection or completion method calls.", "limits":["Automated synthetic input, not human usability or reference-fidelity approval.", "No audio listening result.", "This sealed route does not replace independent physical opening/amendment tests."]}
	for id: String in host.core.CASE_IDS:
		report.dispositions[id] = str(host.core.case_state(id).disposition)
		if host.core.resolution_view(id).get("stamped",false): report.resolution_count += 1
	report.input_events = input_events
	report.visited_locations = visited_locations
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var file := FileAccess.open("res://test-results/final_five_case_" + route + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FINAL FIVE CASE INPUT ", route, ": ", checks, " checks / ", failures.size(), " failures")
	for player: Node in host.find_children("*", "AudioStreamPlayer", true, false):
		player.stop(); player.stream = null
	await create_timer(0.15).timeout
	host.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)

func _source_hashes() -> Dictionary:
	var result: Dictionary = super._source_hashes()
	result["tests/final_five_case_input.gd"] = FileAccess.get_sha256("res://tests/final_five_case_input.gd")
	return result

func _event(kind: String, detail: Dictionary) -> void:
	input_events.append({"kind":kind, "detail":detail, "elapsed_ms":Time.get_ticks_msec()-began,
		"view":host.view, "modal":_modal_script(), "location":host.core.state.get("location", ""),
		"minute":host.core.state.get("minute", -1), "carried":host.carried})

func _move(point: Vector2) -> void:
	await super._move(point)
	_event("pointer_motion", {"x":point.x, "y":point.y, "held":held})

func _button(button: MouseButton, down: bool) -> void:
	await super._button(button, down)
	_event("pointer_button", {"button":button, "pressed":down, "x":pointer.x, "y":pointer.y})

func _key(key: Key, control: bool = false) -> void:
	await super._key(key, control)
	_event("key_press_release", {"key":key, "control":control})

func _fill(node_name: String, value: String) -> void:
	await super._fill(node_name, value)
	_event("typed_unicode_sequence", {"target":node_name, "characters":value.length(), "text":value})
