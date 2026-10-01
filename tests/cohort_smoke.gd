extends SceneTree
## 100 deterministic execution routes derived from synthetic persona scenarios.
## These are real GameSession transitions and real save/reloads, NOT human
## playtests, satisfaction ratings, or 100 visual/manual playthroughs.

const Session = preload("res://scripts/core/GameSession.gd")
const PROFILES = "res://docs/testing/SIMULATED_PERSONAS_100.json"
const REPORT = "res://test-results/cohort_results.json"
const SEED = 20261001
var game
var random = RandomNumberGenerator.new()
var results: Array[Dictionary] = []
var problems: Array[String] = []
var route: Array[String] = []
var case_times: Dictionary = {}
var active_id = ""
var damage_pending = false
var recovery_used = false
var assertions = 0
var saved_and_resumed = false
var wrong_evidence = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var started = Time.get_ticks_msec()
	var source_hashes: Dictionary = {}
	for path in ["res://scripts/core/GameSession.gd", "res://scripts/core/SaveData.gd", "res://data/game.json", "res://tests/cohort_smoke.gd", PROFILES]:
		source_hashes[path] = FileAccess.get_sha256(path)
	var file = FileAccess.open(PROFILES, FileAccess.READ)
	if file == null:
		push_error("COHORT: missing synthetic profile definitions")
		quit(1)
		return
	var catalog = JSON.parse_string(file.get_as_text())
	file.close()
	if not catalog is Dictionary or catalog.get("personas", []).size() != 100:
		push_error("COHORT: exactly 100 supplied scenario profiles are required")
		quit(1)
		return
	game = Session.new()
	root.add_child(game)
	game.save_path = "user://qa/cohort_smoke_save.json"
	var ids: Dictionary = {}
	for index in range(catalog.personas.size()):
		var profile: Dictionary = catalog.personas[index]
		active_id = str(profile.id)
		problems.clear()
		route.clear()
		case_times.clear()
		saved_and_resumed = false
		recovery_used = false
		damage_pending = bool(profile.scenario.damage_recovery)
		wrong_evidence = index % 13 == 0 and not bool(profile.scenario.wrong_identity)
		random.seed = SEED + index * 7919
		_require(not ids.has(active_id), "profile id must be unique")
		ids[active_id] = true
		game.new_game()
		_execute(profile.scenario, index)
		results.append({
			"id": active_id, "segment": profile.segment, "seed": SEED + index * 7919,
			"scenario": profile.scenario, "passed": problems.is_empty(),
			"failures": problems.duplicate(), "travel_order": route.duplicate(),
			"case_handled_minutes": case_times.duplicate(), "ending_reached": not game.state.ending.is_empty(),
			"urgent_decision_minute": game.case_state("case02").get("decision_minute", -1),
			"work_finished_minute": case_times.get("case05", -1), "closing_minute": game.state.minute,
			"urgent_late": game.case_state("case02").late,
			"case03_opened": game.case_state("case03").opened,
			"case04_choice": game.case_state("case04").choice,
			"case04_factual_correct": game.case_state("case04").factual_correct,
			"wrong_evidence_mapping": wrong_evidence, "case04_evidence_correct": game.case_state("case04").evidence_correct,
			"case05_choice": game.case_state("case05").choice,
			"save_resumed": saved_and_resumed, "damage_recovered": recovery_used,
			"reputation_label": game.reputation_label(), "remaining_materials": game.state.repair_materials
		})
		if (index + 1) % 10 == 0:
			print("COHORT PROGRESS %d/100; failed routes so far: %d" % [index + 1, _failed_count()])
		await process_frame
	var summary = _summarize()
	var changed_sources: Array[String] = []
	for path in source_hashes:
		if FileAccess.get_sha256(path) != source_hashes[path]:
			changed_sources.append(path)
	var report = {
		"scope": "100 seeded engine-state execution routes from synthetic personas; not human reviews, satisfaction measurements, or manual UI sessions",
		"source_profiles": PROFILES, "base_seed": SEED, "assertions": assertions,
		"elapsed_automation_seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"generated_utc": Time.get_datetime_string_from_system(true), "summary": summary, "routes": results,
		"runtime": Engine.get_version_info(), "source_sha256_at_start": source_hashes,
		"sources_changed_at_end": changed_sources
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	file = FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		push_error("COHORT: result report could not be saved")
	print("COHORT SMOKE: %d complete paths, %d failed paths, %d assertions" % [results.size(), _failed_count(), assertions])
	print("COHORT MEASUREMENTS " + JSON.stringify(summary))
	game.queue_free()
	await process_frame
	quit(0 if _failed_count() == 0 and file != null else 1)

func _execute(scenario: Dictionary, index: int) -> void:
	var locations = ["community_center", "bus_stop", "lookout", "residential", "chess_stall", "tarot_shop"]
	for detour in range(int(scenario.detours)):
		var destination: String = locations[random.randi_range(0, locations.size() - 1)]
		if destination == game.state.location:
			destination = "post_office"
		_travel(destination)
	var order = ["case01", "case02", "case03", "case04"]
	for position in range(order.size() - 1, 0, -1):
		var other = random.randi_range(0, position)
		var current = order[position]
		order[position] = order[other]
		order[other] = current
	for position in range(order.size()):
		var id: String = order[position]
		game.select_case(id)
		match id:
			"case01":
				if scenario.wrong_delivery:
					_travel("tarot_shop")
					game.choose(id, "deliver", "tarot_shop")
					_require(not game.is_handled(id) and not game.has_failure(), "wrong ordinary delivery remains retryable")
				_observe("community_center", "old_civic_hall_name")
				_observe("community_center", "community_center_history")
				_choose(id, "deliver", "community_center")
			"case02":
				if scenario.case02 == "delay":
					_choose(id, "delay")
				else:
					_observe("bus_stop", "bus_to_lookout")
					_ask_for("chenyuan", "chenyuan_sighting")
					if scenario.case02 == "delegate":
						_ask_for("chenyuan", "delegate_terms")
						_choose(id, "delegate", "mira_vale")
						_require(not "early_bench" in game.state.clues, "delegation does not manufacture personal observation")
					else:
						_travel("lookout")
						_choose(id, "deliver", "mira_vale")
			"case03":
				_require(game.begin_physical(id, "fragments").is_empty(), "fragment operation is available")
				game.solve_fragments(id)
				if scenario.case03 == "open":
					_open(id)
					_restore(id)
				else:
					_observe("residential", "resident_moved")
					if random.randi_range(0, 1) == 0:
						_observe("bus_stop", "lookout_schedule")
					else:
						_observe("community_center", "nora_registry")
				_travel("lookout")
				_choose(id, "deliver", "nora_vale")
				_require(game.case_state(id).opened == (scenario.case03 == "open"), "chosen privacy route is preserved")
			"case04":
				if random.randi_range(0, 1) == 0:
					_observe("residential", "old_nameplate")
				_observe("community_center", "event_archive")
				_observe("community_center", "handwriting_sample")
				_observe("residential", "old_nameplate")
				var claims = {"address": "old_nameplate", "date": "event_archive", "sender": "handwriting_sample"}
				if wrong_evidence:
					claims.address = "event_archive"
					claims.date = "old_nameplate"
				_require(game.record_deduction(claims).is_empty(), "three known unique evidence roles are recorded provisionally")
				var action: String = scenario.case04
				var recipient = "mira_vale" if scenario.wrong_identity else "june_arlen"
				var sender = "june_arlen" if scenario.wrong_identity else "mira_vale"
				if action == "remove_attachment" or index % 3 == 0:
					_open(id)
				if action != "hold":
					_travel("lookout")
					if game.case_state(id).opened:
						_require(game.can_choose(id, action, recipient, sender, true).is_empty(), "opened letter can prepare handoff at the right scene")
						if action in ["deliver", "remove_attachment"]:
							game.begin_attachment_arrangement()
						_restore(id)
				_choose(id, action, recipient, sender)
				_require(not game.has_failure(), "moral decision never triggers professional failure")
		_require(game.is_handled(id), "case entered its handled state: " + id)
		if scenario.save_resume and position == 1:
			_save_resume()
	_require(game.first_four_handled(), "all four mail decisions unlock the special letter")
	game.select_case("case05")
	_open("case05")
	_require(not damage_pending, "requested damage recovery was actually exercised")
	_require(game.begin_physical("case05", "archive").is_empty(), "historical comparison has an operation checkpoint")
	if index % 4 == 0:
		_require(not game.match_archive("S-WRONG-ROW"), "wrong archive choice remains unconfirmed")
	_require(game.match_archive(str(game.catalog.archive_target)), "correct historical serial can be matched")
	_choose("case05", str(scenario.case05), "player")
	game.end_day()
	_require(not game.state.ending.is_empty() and not game.has_failure(), "complete day reaches a saved ending")
	if scenario.wrong_identity:
		_require("寄收关系有误" in game.case_state("case04").evening_feedback, "wrong identity is corrected in evening feedback")
	elif wrong_evidence:
		_require("证据对应有误" in game.case_state("case04").evening_feedback, "wrong evidence roles receive only late factual correction")
	else:
		_require(game.case_state("case04").evening_feedback == game.letter_data("case04").outcome[scenario.case04], "selected moral consequence appears unchanged")
	_require(game.case_state("case05").evening_feedback == game.letter_data("case05").outcome[scenario.case05], "selected final-archive consequence appears")
	_require(game.state.repair_materials >= 0, "physical operations never exhaust below zero")
	if scenario.save_resume:
		_save_resume()
		_require(not game.state.ending.is_empty(), "completed ending persists across reload")

func _open(id: String) -> void:
	_require(game.begin_physical(id, "open").is_empty(), "opening permitted for " + id)
	if damage_pending:
		var before: Dictionary = game.state.checkpoint.snapshot.duplicate(true)
		game.complete_open(id, "quick", 8)
		_require(game.has_failure() and game.can_resume_failure(), "severe tool damage has an explicit resumable failure")
		_require(game.load_game() and game.has_failure(), "professional failure survives restart")
		_require(game.resume_checkpoint(), "checkpoint resumes after physical failure")
		_require(_equivalent(game.state, before), "damage recovery preserves the entire preceding route")
		damage_pending = false
		recovery_used = true
		_require(game.begin_physical(id, "open").is_empty(), "recovered operation can be retried")
	game.complete_open(id, "safe" if random.randi_range(0, 1) == 0 else "quick", random.randi_range(0, 6))
	_require(game.case_state(id).opened and not game.has_failure(), "ordinary tool execution reveals the intended letter")

func _restore(id: String) -> void:
	_require(game.begin_physical(id, "restore").is_empty(), "restoration begins before handoff")
	game.complete_restore(id, random.randf_range(0.68, 0.99))
	_require(game.case_state(id).restored, "opened letter is sealed for handoff")

func _choose(id: String, action: String, recipient: String = "", sender: String = "") -> void:
	var error: String = game.can_choose(id, action, recipient, sender)
	_require(error.is_empty(), "%s %s allowed: %s" % [id, action, error])
	if not error.is_empty():
		return
	game.choose(id, action, recipient, sender)
	case_times[id] = int(game.state.minute)

func _travel(id: String) -> void:
	if game.state.location == id:
		return
	game.travel(id)
	route.append(id)
	_require(game.state.location == id, "requested journey completes")

func _observe(location: String, clue: String) -> void:
	if clue in game.state.clues:
		return
	_travel(location)
	for hotspot in game.location_data(location).get("hotspots", []):
		if clue in hotspot.get("clues", []):
			game.inspect_hotspot(location, str(hotspot.id))
			_require(clue in game.state.clues, "world source grants " + clue)
			return
	_require(false, "world clue source absent: " + clue)

func _ask_for(npc: String, clue: String) -> void:
	if clue in game.state.clues:
		return
	for question in game.available_questions(npc):
		if clue in question.get("clues", []):
			game.ask(npc, str(question.id))
			_require(clue in game.state.clues, "spoken reply grants " + clue)
			return
	_require(false, "required conversation not available: " + clue)

func _save_resume() -> void:
	var before: Dictionary = game.state.duplicate(true)
	_require(game.save_game() and game.load_game(), "real JSON save and reload succeed")
	_require(_equivalent(game.state, before), "save and reload preserve all persistent values")
	saved_and_resumed = true

func _equivalent(a: Dictionary, b: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _require(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		problems.append(message)
		push_error("COHORT %s: %s" % [active_id, message])

func _failed_count() -> int:
	var count = 0
	for result in results:
		if not result.passed:
			count += 1
	return count

func _summarize() -> Dictionary:
	var summary = {"profiles": results.size(), "passed": results.size() - _failed_count(), "failed": _failed_count(), "segments": {}, "case02_actions": {}, "case03_routes": {}, "case04_actions": {}, "case05_actions": {}, "urgent_on_time": 0, "urgent_late": 0, "save_resume_routes": 0, "damage_recovery_routes": 0, "wrong_identity_routes": 0, "wrong_evidence_routes": 0, "wrong_delivery_routes": 0, "earliest_work_finished_minute": 99999, "latest_work_finished_minute": 0}
	for result in results:
		for pair in [["segments", result.segment], ["case02_actions", result.scenario.case02], ["case03_routes", result.scenario.case03], ["case04_actions", result.scenario.case04], ["case05_actions", result.scenario.case05]]:
			summary[pair[0]][pair[1]] = int(summary[pair[0]].get(pair[1], 0)) + 1
		summary["urgent_late" if result.urgent_late else "urgent_on_time"] += 1
		summary.save_resume_routes += 1 if result.save_resumed else 0
		summary.damage_recovery_routes += 1 if result.damage_recovered else 0
		summary.wrong_identity_routes += 1 if result.scenario.wrong_identity else 0
		summary.wrong_evidence_routes += 1 if result.wrong_evidence_mapping else 0
		summary.wrong_delivery_routes += 1 if result.scenario.wrong_delivery else 0
		summary.earliest_work_finished_minute = mini(summary.earliest_work_finished_minute, result.work_finished_minute)
		summary.latest_work_finished_minute = maxi(summary.latest_work_finished_minute, result.work_finished_minute)
	return summary
