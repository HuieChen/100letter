extends SceneTree
## Run: Godot --headless --path . --script res://tests/core_smoke.gd
## Uses an isolated QA save. Does not touch the player's solmere_save.json.

const Session = preload("res://scripts/core/GameSession.gd")
const QA_PATH = "user://qa/core_smoke_save.json"
var failures: Array[String] = []
var checks = 0
var game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game = Session.new()
	root.add_child(game)
	game.save_path = QA_PATH
	_check(game.catalog.get("letters", []).size() == 5, "all five catalog letters load")
	_check(game.catalog.get("locations", []).size() == 7, "seven map stages load")
	if not failures.is_empty():
		_finish()
		return
	_test_delivery_and_custody()
	_test_no_open_route_and_recovery()
	_test_open_route()
	_test_late_day()
	_test_moral_branches()
	_test_factual_error_is_delayed()
	_test_attachment_preparation()
	_test_physical_failure_checkpoint()
	_test_provisional_evidence_roles()
	_test_shift_pacing()
	_finish()

func _test_delivery_and_custody() -> void:
	game.new_game()
	var start = game.state.minute
	game.complete_open("case05", "safe", 0)
	_check(not game.case_state("case05").opened, "case05 cannot open before four case decisions")
	_check(not game.match_archive(str(game.catalog.archive_target)), "archive cannot be matched before reading special letter")
	game.end_day()
	_check(game.state.ending.is_empty(), "unfinished cases cannot silently end the day")
	game.select_case("case01")
	_check(game.state.minute == start, "reading and case selection do not advance time")
	_check(not game.can_open("case01").is_empty(), "ordinary letter opening forbidden")
	game.complete_open("case01", "safe", 0)
	_check(not game.case_state("case01").opened, "opening guard prevents illegal mutation")
	game.choose("case01", "deliver", "residential")
	_check(not game.is_handled("case01"), "wrong delivery remains recoverable")
	game.travel("community_center")
	_observe("community_center", "old_civic_hall_name")
	_observe("community_center", "community_center_history")
	game.choose("case01", "deliver", "community_center")
	_check(game.is_handled("case01"), "corrected old-name delivery completes")
	_check(not game.can_choose("case02", "delegate").is_empty(), "delegation requires meeting courier")
	game.travel("bus_stop")
	_check(not game.can_choose("case02", "delegate").is_empty(), "arrival alone does not count as meeting courier")
	_meet_chenyuan()
	_check(not game.can_choose("case02", "delegate").is_empty(), "meeting courier alone does not grant consent to delegate")
	_agree_to_delegate()
	_check(game.can_choose("case02", "delegate").is_empty(), "courier can receive letter after explicit agreement")
	game.choose("case02", "delegate")
	_check(game.case_state("case02").status == "delegated", "delegated custody persists")
	_check(not game.can_choose("case02", "deliver", "mira_vale").is_empty(), "delegated letter cannot be recalled")
	_check(not "early_bench" in game.state.clues, "delegation does not grant personal lookout clue")
	game.travel("lookout")
	_check(not "early_bench" in game.state.clues, "later visit cannot manufacture delegated delivery observation")
	_check(game.load_game() and game.case_state("case02").status == "delegated", "save reload preserves delegated lock")

func _test_no_open_route_and_recovery() -> void:
	game.new_game()
	_check(not game.can_choose("case03", "deliver", "nora_vale").is_empty(), "six-fragment completion gates delivery")
	game.solve_fragments("case03")
	_observe("residential", "resident_moved")
	_observe("bus_stop", "lookout_schedule")
	game.travel("lookout")
	game.choose("case03", "deliver", "nora_vale")
	_check(game.is_handled("case03") and not game.case_state("case03").opened, "case03 completes through world evidence without opening")
	game.save_game()
	game.save_game()
	var file = FileAccess.open(QA_PATH, FileAccess.WRITE)
	file.store_string("{interrupted write")
	file.close()
	_check(game.load_game() and game.recovered_backup, "corrupt primary falls back to valid backup")
	_check(game.is_handled("case03"), "backup recovery retains completed case")
	_check(game.save_game() and game.load_game() and not game.recovered_backup, "recovery can produce a new valid primary")

func _test_open_route() -> void:
	game.new_game()
	game.complete_open("case03", "quick", 2)
	_check(not game.case_state("case03").opened, "opening cannot bypass fragment puzzle")
	game.solve_fragments("case03")
	game.complete_open("case03", "quick", 2)
	_check(game.case_state("case03").opened and "case03_body" in game.state.clues, "opening reveals strong invitation clue")
	_check(game.case_state("case03").tamper > 0, "tool mistakes leave tamper state")
	game.travel("lookout")
	_check(not game.can_choose("case03", "deliver", "nora_vale").is_empty(), "opened letter requires physical restoration")
	game.complete_restore("case03", 0.92)
	_check(game.state.repair_materials == 2, "restoration consumes one fictional material")
	game.complete_restore("case03", 0.92)
	_check(game.state.repair_materials == 2, "repeated completion cannot waste more materials")
	game.choose("case03", "deliver", "nora_vale")
	_check(game.is_handled("case03"), "opened and restored invitation can be delivered")
	_check(game.load_game() and game.case_state("case03").restored, "restoration appearance persists")

func _test_late_day() -> void:
	game.new_game()
	for index in range(8):
		game.travel("lookout")
		game.travel("post_office")
	_check(game.state.minute >= 1080, "journeys can pass urgent deadline")
	game.travel("lookout")
	game.choose("case02", "deliver", "mira_vale")
	_check(game.is_handled("case02") and game.case_state("case02").late, "late urgent delivery continues instead of deadlocking")
	_check(not "early_bench" in game.state.clues, "late arrival does not award earlier personal meeting clue")
	game.travel("bus_stop")
	_check(game.state.location == "bus_stop", "investigation remains possible after deadline")
	game.new_game()
	game.state.minute = 1040
	game.travel("bus_stop")
	_meet_chenyuan()
	_agree_to_delegate()
	game.choose("case02", "delegate")
	_check(game.case_state("case02").late, "delegation deadline includes courier journey")
	_check(game.state.minute == 1060, "delegation saves the player's onward journey time")

func _test_moral_branches() -> void:
	var results: Array[String] = []
	for action in ["deliver", "hold", "return_to_sender"]:
		game.new_game()
		_check(not game.can_choose("case04", action, "june_arlen", "mira_vale").is_empty(), "case04 decision requires independent evidence")
		_prove_case04()
		_check(not game.case_state("case04").opened, "three independent proofs exist without opening case04")
		if action != "hold":
			_check(not game.can_choose("case04", action, "june_arlen", "mira_vale").is_empty(), "case04 %s cannot transfer letter while target is absent" % action)
			game.travel("lookout")
			_check(game.can_choose("case04", action, "june_arlen", "mira_vale").is_empty(), "case04 %s can be handed over at the actual scene" % action)
		else:
			_check(game.can_choose("case04", action, "june_arlen", "mira_vale").is_empty(), "holding a letter can be registered without a handoff journey")
		var before = game.state.reputation
		var response = game.choose("case04", action, "june_arlen", "mira_vale")
		_check(game.case_state("case04").feedback == response, "immediate receipt persists for UI continuation")
		_check(game.is_handled("case04"), "case04 %s decision registered" % action)
		_check(game.state.reputation == before, "case04 %s has no moral reputation score" % action)
		_check(not game.has_failure(), "case04 %s is a moral choice, never a professional failure" % action)
		_check(not "正确" in response and not "错误" in response, "case04 confirmation withheld until evening")
		_delay_ordinary_cases()
		_finish_archive("file")
		var ending = game.end_day()
		_check(not game.case_state("case04").evening_feedback.is_empty(), "case04 evening scene is available separately to summary UI")
		_check(game.state.ending == ending and not ending.is_empty(), "case04 %s reaches saved evening outcome" % action)
		_check(game.load_game() and game.state.ending == ending, "evening ending survives reload")
		results.append(ending)
	_check(results[0] != results[1] and results[1] != results[2] and results[0] != results[2], "deliver/hold/return produce distinct same-day outcomes")
	game.new_game()
	_prove_case04()
	_check(not game.can_choose("case04", "remove_attachment", "june_arlen", "mira_vale").is_empty(), "photo removal requires opening")
	game.complete_open("case04", "safe", 0)
	game.complete_restore("case04", 1.0)
	_check(not game.can_choose("case04", "remove_attachment", "june_arlen", "mira_vale").is_empty(), "photo-omitted delivery also requires actual handoff location")
	game.travel("lookout")
	game.choose("case04", "remove_attachment", "june_arlen", "mira_vale")
	_check(game.case_state("case04").removed_attachment, "photo intervention stored separately from delivery")
	_delay_ordinary_cases()
	_finish_archive("keep")
	_check(not game.end_day().is_empty(), "photo branch and private archive ending complete")

func _test_factual_error_is_delayed() -> void:
	game.new_game()
	_prove_case04()
	game.travel("lookout")
	var response = game.choose("case04", "deliver", "mira_vale", "june_arlen")
	_check(game.is_handled("case04") and not "有误" in response, "incorrect deduction is still a registered reversible next-day dispatch")
	_delay_ordinary_cases()
	_finish_archive("destroy")
	_check("寄收关系有误" in game.end_day(), "evening distinguishes incorrect facts from ethical decision")
	_check(not game.has_failure(), "incorrect inference is not a physical-operation game over")

func _test_attachment_preparation() -> void:
	game.new_game()
	_prove_case04()
	game.travel("lookout")
	game.complete_open("case04", "safe", 0)
	_check(game.can_choose("case04", "deliver", "june_arlen", "mira_vale", true).is_empty(), "handoff preparation permits arranging an unsealed letter")
	_check(not game.can_choose("case04", "deliver", "june_arlen", "mira_vale").is_empty(), "actual handoff still requires the seal restored")
	game.begin_attachment_arrangement()
	game.complete_restore("case04", 0.95)
	var materials: int = game.state.repair_materials
	var tamper: int = game.case_state("case04").tamper
	game.begin_attachment_arrangement()
	_check(not game.case_state("case04").restored, "rearranging a previously sealed letter explicitly opens its work state")
	game.complete_restore("case04", 0.95)
	_check(game.state.repair_materials == materials, "rearrangement reuses that envelope's allocated fictional material")
	_check(game.case_state("case04").tamper == tamper, "repeat restoration does not erase tool damage by arithmetic stacking")
	_check(game.can_choose("case04", "deliver", "june_arlen", "mira_vale").is_empty(), "rearranged and resealed letter can complete handoff")

func _test_physical_failure_checkpoint() -> void:
	game.new_game()
	game.travel("community_center")
	game.choose("case01", "deliver", "community_center")
	game.solve_fragments("case03")
	game.select_case("case03")
	var before: Dictionary = game.state.duplicate(true)
	_check(game.begin_physical("case03", "open").is_empty(), "physical opening creates an authorized checkpoint")
	_check(game.state.checkpoint.snapshot.checkpoint.is_empty(), "checkpoint snapshot contains no nested prior checkpoint")
	game.complete_open("case03", "quick", 8)
	_check(game.has_failure() and game.state.failure.kind == "damaged_letter", "eight physical mistakes trigger the specified professional failure")
	_check(not game.case_state("case03").opened and not "case03_body" in game.state.clues, "failed operation never reveals private body or strong clue")
	_check(game.can_resume_failure(), "failed operation offers a valid local recovery checkpoint")
	var failed_location: String = game.state.location
	var failed_minute: int = game.state.minute
	var failed_clues: Array = game.state.clues.duplicate()
	game.travel("lookout")
	game.inspect_hotspot("community_center", "unknown")
	game.add_clue("old_photo")
	_check(game.state.location == failed_location and game.state.minute == failed_minute and game.state.clues == failed_clues, "failure blocks travel and evidence mutation until resumed")
	_check(not game.can_choose("case02", "delay").is_empty(), "failure blocks further mail decisions")
	_check(game.load_game() and game.has_failure() and game.can_resume_failure(), "failure and recovery checkpoint both survive restart")
	_check(game.resume_checkpoint(), "checkpoint resumes successfully")
	_check(not game.has_failure() and not game.can_resume_failure(), "recovery clears the failure card and consumes the old checkpoint")
	# JSON reload represents numeric values as floats; compare the persistent
	# values after applying that same serialization to both sides.
	_check(JSON.parse_string(JSON.stringify(game.state)) == JSON.parse_string(JSON.stringify(before)), "recovery restores exact pre-operation time, mail, clues, location, and prior journal")
	game.begin_physical("case03", "open")
	game.complete_open("case03", "quick", 7)
	_check(not game.has_failure() and game.case_state("case03").opened, "seven mistakes retain the ordinary recoverable tamper outcome")
	game.begin_physical("case04", "open")
	var stable_size: int = JSON.stringify(game.state.checkpoint).length()
	for attempt in range(12):
		game.begin_physical("case04", "open")
	_check(game.state.checkpoint.snapshot.checkpoint.is_empty() and JSON.stringify(game.state.checkpoint).length() == stable_size, "repeated checkpoints never grow a recursive snapshot chain")

func _prove_case04() -> void:
	_observe("residential", "old_nameplate")
	_observe("community_center", "event_archive")
	_observe("community_center", "handwriting_sample")
	_check(game.evidence_count("case04") >= 3, "independent clue sources satisfy deduction threshold")
	_check(not game.can_choose("case04", "hold", "june_arlen", "mira_vale").is_empty(), "collecting facts alone does not replace arranging their roles")
	_check(game.record_deduction({"address": "old_nameplate", "date": "event_archive", "sender": "handwriting_sample"}).is_empty(), "three independent facts can be recorded as provisional roles")

func _test_provisional_evidence_roles() -> void:
	game.new_game()
	_prove_case04()
	_check(not game.record_deduction({"address": "old_nameplate", "date": "old_nameplate", "sender": "handwriting_sample"}).is_empty(), "one evidence card cannot fill multiple independent roles")
	_check(not game.record_deduction({"address": "old_nameplate", "date": "old_photo", "sender": "handwriting_sample"}).is_empty(), "an unopened private photo cannot be claimed as known evidence")
	var response: String = game.record_deduction({"address": "event_archive", "date": "old_nameplate", "sender": "handwriting_sample"})
	_check(response.is_empty(), "wrong role mapping remains an accepted provisional inference")
	_check(game.can_choose("case04", "hold", "june_arlen", "mira_vale").is_empty(), "provisional evidence mapping permits a moral choice without early grading")
	game.choose("case04", "hold", "june_arlen", "mira_vale")
	_check(game.case_state("case04").identity_correct and not game.case_state("case04").evidence_correct, "identity and supporting evidence are recorded separately")
	_delay_ordinary_cases()
	_finish_archive("keep")
	game.end_day()
	_check("证据对应有误" in game.case_state("case04").evening_feedback and not game.has_failure(), "evidence error receives late factual feedback without a moral game over")
	game.new_game()
	_prove_case04()
	game.complete_open("case04", "safe", 0)
	_check(game.record_deduction({"address": "old_nameplate", "date": "old_photo", "sender": "handwriting_sample"}).is_empty(), "opened dated photograph can independently support the date role")
	game.choose("case04", "hold", "june_arlen", "mira_vale")
	_check(game.case_state("case04").factual_correct, "date-photo alternative retains valid objective deduction")

func _test_shift_pacing() -> void:
	game.new_game()
	game.choose("case01", "delay")
	_check(game.state.minute == 540, "first routine decision does not skip the morning")
	game.choose("case03", "delay")
	_check(game.state.minute == 780 and not game.case_state("case03").handoff_note.is_empty(), "second completed case announces the afternoon batch handoff")
	var clock: int = game.state.minute
	game.select_case("case02")
	game.letter_data("case02")
	_check(game.state.minute == clock, "batch pacing never advances while reading or changing letters")
	game.travel("lookout")
	var actual_handoff: int = game.state.minute
	game.choose("case02", "deliver", "mira_vale")
	_check(game.state.minute == 930, "third completed case eases the workday into late afternoon")
	_check(game.case_state("case02").decision_minute == actual_handoff and not game.case_state("case02").late, "urgent deadline uses actual delivery time before the batch pause")
	_prove_case04()
	game.choose("case04", "hold", "june_arlen", "mira_vale")
	_check(game.state.minute >= 1050 and game.first_four_handled(), "four handled cases lead naturally to the17:30 special-letter shift")
	# An urgent letter left until last remains sensitive to actual detours. The
	# batch floor must neither automatically fail it nor erase late delivery.
	game.new_game()
	game.choose("case01", "delay")
	game.choose("case03", "delay")
	_prove_case04()
	game.choose("case04", "hold", "june_arlen", "mira_vale")
	_check(game.state.minute == 930 and not game.is_handled("case02"), "urgent letter may legitimately remain last at15:30")
	for detour in range(2):
		game.travel("lookout")
		game.travel("post_office")
	game.travel("lookout")
	var late_handoff: int = game.state.minute
	game.choose("case02", "deliver", "mira_vale")
	_check(late_handoff > 1080 and game.case_state("case02").late, "two late-afternoon return trips produce an actual late final urgent delivery")
	_check(game.case_state("case02").decision_minute == late_handoff and game.first_four_handled(), "late fourth delivery preserves actual handoff time and unlocks final case")
	game.complete_open("case05", "safe", 0)
	game.match_archive(str(game.catalog.archive_target))
	game.choose("case05", "file", "player")
	game.end_day()
	_check(not game.state.ending.is_empty() and not game.has_failure(), "late final urgent delivery still reaches a complete evening ending")

func _delay_ordinary_cases() -> void:
	for id in ["case01", "case02", "case03"]:
		game.choose(id, "delay")
	_check(game.first_four_handled(), "delayed ordinary mail counts as handled for current workday")

func _finish_archive(action: String) -> void:
	_check(game.can_open("case05").is_empty(), "case05 unlocks after four decisions")
	game.complete_open("case05", "safe", 0)
	_check(not game.can_choose("case05", action).is_empty(), "archive choice requires matching evidence")
	_check(not game.match_archive("WRONG-NUMBER"), "wrong archive row leaves puzzle incomplete")
	_check(game.match_archive(str(game.catalog.archive_target)), "matching correct historical row completes archive puzzle")
	game.choose("case05", action)
	_check(game.is_handled("case05"), "case05 %s registered" % action)

func _observe(location: String, clue: String) -> void:
	if game.state.location != location:
		game.travel(location)
	for hotspot in game.location_data(location).get("hotspots", []):
		if clue in hotspot.get("clues", []):
			game.inspect_hotspot(location, hotspot.id)
			_check(clue in game.state.clues, "world observation exposes " + clue)
			return
	_check(false, "missing environmental source for " + clue)

func _meet_chenyuan() -> void:
	var questions = game.available_questions("chenyuan")
	_check(not questions.is_empty(), "courier has available bus-stop dialogue")
	if not questions.is_empty():
		game.ask("chenyuan", str(questions[0].id))

func _agree_to_delegate() -> void:
	_observe("bus_stop", "bus_to_lookout")
	for question in game.available_questions("chenyuan"):
		if "delegate_terms" in question.get("clues", []):
			game.ask("chenyuan", str(question.id))
			_check("delegate_terms" in game.state.clues, "courier explicitly agrees after sighting and route discussion")
			return
	_check(false, "delegation agreement question must become available")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func _finish() -> void:
	print("CORE SMOKE: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
