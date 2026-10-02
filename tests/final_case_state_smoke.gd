extends SceneTree
## Final-v1 foundation tests. Model APIs and explicit boundary fixtures, not UI play.
const Core = preload("res://scripts/rebuild/final_case_state.gd")
const Paper = preload("res://scripts/rebuild/mail_physics_state.gd")
var checks := 0
var failures: Array[String] = []
var nodes: Array[Node] = []
var run_id := str(Time.get_ticks_usec())


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_tutorial_rules()
	var tutorial_checks := checks
	_resolution_rules()
	var resolution_checks := checks - tutorial_checks
	var before_narrative := checks
	_dialogue_contract()
	_handoff_exact_arrival()
	_full_narrative_route()
	var narrative_checks := checks - before_narrative
	_initial_and_time()
	_inspection_bridge()
	_physical_and_privacy()
	_routing_and_deadline()
	_detected_tampering()
	_archive_and_endings()
	_save_recovery()
	_failure_recovery()
	var previous_checks := checks
	_opening_budget()
	_internal_opening_budget()
	_three_detections(false)
	_three_detections(true)
	_pending_handoff_end_shift()
	_opening_integrity()
	var override_checks := checks - previous_checks
	previous_checks = checks
	_amendment_permissions_and_text()
	_amendment_attachment_and_receipts()
	_amendment_delegation_and_storage()
	_amendment_save_integrity()
	_three_detections(false, true)
	_three_detections(true, true)
	var amendment_checks := checks - previous_checks
	for node: Node in nodes: node.free()
	var report := {"suite": "final_case_state", "checks": checks, "failures": failures,
		"runtime": Engine.get_version_info(), "finished_utc": Time.get_datetime_string_from_system(true),
		"scope": "Independent final-production state, limited immutable-source amendments, witnessed reading, user-rule saves and MailPhysicsState API integration. Physical gestures use model public methods. Explicit time and corrupt-save fixtures test boundaries; no Main/UI, OS input, human players, reference fidelity or legacy v1 save migration is claimed.",
		"save_isolation": "Per-run user://qa/final-case-state slot; production final_v2, final_v1 and legacy saves are never selected.",
		"rules_version": Core.RULES_VERSION, "override_checks": override_checks, "tutorial_checks": tutorial_checks,
		"resolution_checks": resolution_checks,
		"narrative_checks": narrative_checks, "dialogues_sha256": FileAccess.get_sha256(Core.DIALOGUES_PATH),
		"amendment_checks": amendment_checks, "amendments_sha256": FileAccess.get_sha256(Core.AMENDMENTS_PATH),
		"source_sha256": FileAccess.get_sha256("res://scripts/rebuild/final_case_state.gd"),
		"physical_sha256": FileAccess.get_sha256("res://scripts/rebuild/mail_physics_state.gd"),
		"catalog_sha256": FileAccess.get_sha256("res://data/rebuild/final_cases.json"),
		"test_sha256": FileAccess.get_sha256("res://tests/final_case_state_smoke.gd")}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	_write("res://test-results/final_case_state_results.json", JSON.stringify(report, "\t"))
	print("FINAL CASE STATE: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _new(label: String):
	var game = Core.new()
	game.save_path = "user://qa/final-case-state/" + run_id + "/" + label + ".json"
	game.new_game()
	nodes.append(game)
	return game


func _finish_tutorial(game) -> void:
	_ok(game.take_case("case01"), "tutorial fixture takes actual first mail")
	_ok(game.dispose("case01", "hold_for_verification", "", "The first address needs another verified source; retain at Desk B."), "tutorial fixture records a legitimate unresolved first case")
	_stamp(game, "case01")


func _topic_ids(game, person: String) -> Array[String]:
	var result: Array[String] = []
	for topic: Dictionary in game.dialogue_topics(person):
		_check(topic.keys().size() == 3 and not topic.has("answer") and not topic.has("evidence"), "question view contains no hidden reply or clue grants")
		result.append(topic.id)
	return result


func _dialogue_contract() -> void:
	var game = _new("onsite-dialogues")
	_check(game.dialogue_topics("elsie_moran").is_empty() and game.dialogue_greeting("elsie_moran").is_empty(), "remote NPC cannot provide on-site topics or greeting")
	_check(not game.speak("elsie_moran", "elsie_address").error.is_empty(), "remote answer cannot inject address fact")
	_ok(game.take_case("case01"), "dialogue takes first real envelope")
	_ok(game.travel("residential", 15), "travel to household before inquiry")
	_check(game.dialogue_topics("elsie_moran").is_empty(), "presence alone does not count as greeting")
	_ok(game.meet("elsie_moran"), "first actual greeting")
	_check(not game.dialogue_greeting("elsie_moran").is_empty(), "met on-site NPC has greeting")
	_check("elsie_address" not in _topic_ids(game, "elsie_moran"), "unread envelope cannot seed exact-address question")
	_ok(game.inspect_envelope("case01", "front"), "actually inspect the question's address source")
	var before: Dictionary = game.state.duplicate(true)
	_check("elsie_address" in _topic_ids(game, "elsie_moran"), "read external address enables its question")
	_check(game.state == before and not game.has_evidence("elsie_confirmation"), "listing questions and greeting is side-effect free")
	var reply: Dictionary = game.speak("elsie_moran", "elsie_address")
	_check(reply.error.is_empty() and reply.answer.contains("Bay Steps") and reply.evidence == ["elsie_confirmation"], "only actual reply provides this NPC's address confirmation")
	_check(game.has_evidence("elsie_confirmation") and game.state.minute == before.minute, "free reading and conversation preserve clock")
	var after: Dictionary = game.state.duplicate(true)
	_check(game.speak("elsie_moran", "elsie_address").error.is_empty() and game.state == after, "repeat answer is idempotent and does not farm time or trust")
	_check("elsie_after_mail" not in _topic_ids(game, "elsie_moran"), "recipient cannot acknowledge unreceived mail")
	_ok(game.dispose("case01", "deliver", "elsie_moran"), "identity confirmed through actual answer permits handoff")
	_check("elsie_after_mail" in _topic_ids(game, "elsie_moran"), "physical delivery enables receipt conversation")
	_ok(game.travel("post_office", 15), "bring actual first receipt to counter")
	_stamp(game, "case01")
	_ok(game.take_case("case02"), "take available priority mail")
	_ok(game.travel("bus_stop", 15), "visit carrier on-site")
	_ok(game.meet("chenyuan"), "greet carrier")
	_check("chenyuan_mira" not in _topic_ids(game, "chenyuan"), "unread priority envelope does not leak named question")
	_ok(game.inspect_envelope("case02", "front"), "read priority addressee")
	_check("chenyuan_mira" in _topic_ids(game, "chenyuan"), "known addressee enables local sighting question")
	_check("chenyuan_music" not in _topic_ids(game, "chenyuan") and "chenyuan_june" not in _topic_ids(game, "chenyuan"), "late archive relationship and unknown old address remain hidden")
	_check(game.speak("chenyuan", "chenyuan_mira").error.is_empty() and game.has_evidence("chenyuan_sighting"), "reply commits genuine carrier sighting")
	_check(not game.has_evidence("telescope_checkout") and not game.has_evidence("telescope_returned"), "carrier points to equipment sheet without reading it remotely")
	_ok(game.travel("community_center", 15), "follow public-record lead")
	_check(not game.speak("chenyuan", "chenyuan_mira").error.is_empty(), "previous encounter cannot enable remote conversation")
	_ok(game.meet("community_clerk"), "ask clerk where records are")
	before = game.state.duplicate(true)
	reply = game.speak("community_clerk", "clerk_equipment")
	_check(reply.error.is_empty() and reply.evidence.is_empty() and game.state == before, "clerk gives a direction without granting observed document")
	_ok(game.observe("telescope_checkout"), "read actual current borrowing record")
	_check(not game.has_evidence("telescope_returned"), "morning record does not turn future return into fact")
	_ok(game.observe("june_current_mailpoint"), "read current public mail arrangement")
	_ok(game.travel("post_office", 15), "return for archive object")
	_ok(game.discover_archive_box(), "discover old physical envelope")
	_ok(game.take_case("case04"), "take old item")
	_ok(game.inspect_envelope("case04", "front"), "read old addressee")
	_ok(game.inspect_envelope("case04", "back"), "read archive-side marks")
	_ok(game.observe("case04_archive_mark"), "observe actual old mark")
	_ok(game.travel("bus_stop", 15), "ask carrier with actual old-address context")
	_check("chenyuan_june" in _topic_ids(game, "chenyuan"), "old external item supports address-history question")
	_check(game.speak("chenyuan", "chenyuan_june").error.is_empty() and game.has_evidence("chenyuan_june_history"), "actual testimony supports old occupancy history")
	_check("chenyuan_music" not in _topic_ids(game, "chenyuan"), "old letter alone does not expose relationship question")
	_ok(game.travel("community_center", 15), "inspect public historical photo")
	_ok(game.observe("old_music_photo"), "names acquired from real public photo")
	_ok(game.travel("bus_stop", 15), "bring photo context to carrier")
	_check("chenyuan_music" in _topic_ids(game, "chenyuan"), "seen photo supports relationship inquiry")
	_check(game.speak("chenyuan", "chenyuan_music").error.is_empty() and game.has_evidence("chenyuan_reconnection"), "only on-site reply records reconnection testimony")
	_check(game.body_text("case04").is_empty() and game.state.privacy.violations.is_empty(), "public dialogue never reveals or opens private source letter")
	var stable: Dictionary = game.state.duplicate(true)
	_check(not game.speak("chenyuan", "forged_topic").error.is_empty() and game.state == stable, "unknown conversation identifier is rejected without side effects")
	_check(game.save_game(), "dialogue facts save in existing evidence schema")
	var loaded = _new("onsite-dialogue-load"); loaded.save_path = game.save_path
	_check(loaded.load_game() and JSON.parse_string(JSON.stringify(loaded.state)) == JSON.parse_string(JSON.stringify(game.state)), "existing save format restores acquired dialogue facts exactly")
	_check("chenyuan_music" in _topic_ids(loaded, "chenyuan"), "contextual questions reconstruct from persisted known sources")


func _handoff_exact_arrival() -> void:
	var game = _new("handoff-exact-arrival")
	_finish_tutorial(game)
	_ok(game.take_case("case02"), "take exact-boundary relay mail")
	_ok(game.observe("trusted_handoff_rule"), "read relay service rule")
	_ok(game.travel("bus_stop", 15), "go to carrier")
	_ok(game.meet("chenyuan"), "meet carrier for timed arrangement")
	_ok(game.agree_handoff(int(game.state.minute) + 30, true, true), "agree future arrival before movement")
	_ok(game.travel("chess_stall", 30), "actual travel reaches old promise exactly")
	var before: Dictionary = game.state.duplicate(true)
	_reject(game.dispose("case02", "delegate", "chenyuan"), "cannot hand over at the already reached promised arrival minute")
	_check(game.state == before and game.case_state("case02").owner == "courier" and not game.state.world_flags.has("delegated_delivery"), "expired promise creates neither teleport nor stuck pending receipt")
	_ok(game.agree_handoff(int(game.state.minute) + 30, true, true), "on-site carrier can make a fresh future agreement")
	_ok(game.dispose("case02", "delegate", "chenyuan"), "fresh agreement accepts actual handoff")
	_ok(game.travel("post_office", 15), "return to wait for actual receipt")
	_ok(game.wait_for_handoff(), "explicit waiting reaches renewed event without deadlock")
	_check(game.case_state("case02").owner == "mira_vale" and game.state.world_flags.delegated_delivery.arrived, "renewed promised time really transfers custody")


func _full_narrative_route() -> void:
	var game = _new("five-case-connected-route")
	_ok(game.take_case("case01"), "connected route takes first item from desk")
	_ok(game.inspect_envelope("case01", "front"), "read first external address")
	_ok(game.travel("community_center", 15), "seek street record")
	_ok(game.meet("community_clerk"), "ask on-site clerk for public source")
	_check(game.speak("community_clerk", "clerk_old_street").error.is_empty(), "clerk directs to actual renaming notice")
	_ok(game.observe("street_renaming"), "observe renamed street at real notice")
	_ok(game.travel("residential", 15), "visit candidate building")
	for clue: String in ["ceramic_17", "moran_entry"]: _ok(game.observe(clue), "read actual building source " + clue)
	_ok(game.meet("elsie_moran"), "greet current resident")
	_check(game.speak("elsie_moran", "elsie_address").error.is_empty(), "resident confirms named first envelope")
	_ok(game.dispose("case01", "deliver", "elsie_moran"), "first delivery is actual on-site custody transfer")
	_ok(game.travel("post_office", 15), "return first work record")
	_stamp(game, "case01")
	for id: String in ["case02", "case03"]:
		_ok(game.take_case(id), "take released object " + id)
		_ok(game.inspect_envelope(id, "front"), "read released envelope " + id)
	_repair(game)
	_ok(game.observe("label_reconstructed"), "read real aligned label including actual validity dates")
	_ok(game.travel("residential", 15), "check old homes")
	_ok(game.observe("mira_absent"), "home visit shows priority recipient absent")
	_ok(game.observe("current_3c_resident"), "current occupant contradicts using old June address")
	_ok(game.travel("bus_stop", 15), "follow route to local witness")
	_ok(game.meet("chenyuan"), "greet local carrier")
	_check(game.speak("chenyuan", "chenyuan_mira").error.is_empty(), "witness points to telescope borrowing")
	_ok(game.observe("shuttle_timetable"), "actually inspect onward travel timetable")
	_ok(game.travel("community_center", 15), "follow telescope record rather than private body")
	_check(game.speak("community_clerk", "clerk_equipment").error.is_empty(), "clerk points to record status")
	_ok(game.observe("telescope_checkout"), "public borrowing record gives plausible next destination")
	_check(game.speak("community_clerk", "clerk_forwarding").error.is_empty(), "clerk points to current mail arrangement without deciding validity")
	_ok(game.observe("june_current_mailpoint"), "actually read approved current mail cubby")
	_ok(game.meet("june_arlen"), "meet named volunteer without inventing sender")
	_check(game.speak("june_arlen", "june_mailpoint").error.is_empty(), "June explains distinct activity and mail columns")
	_ok(game.dispose("case03", "forward", "community_center_cubby"), "third mail enters genuinely approved current receiving point")
	_ok(game.travel("lookout", 30), "walk physically to priority recipient")
	_ok(game.meet("mira_vale"), "find named Mira before departure")
	_check(game.speak("mira_vale", "mira_departure").error.is_empty(), "actual recipient states time constraint on-site")
	_ok(game.dispose("case02", "deliver", "mira_vale"), "second mail reaches recipient on time")
	_check(game.speak("mira_vale", "mira_received").error.is_empty(), "recipient acknowledgment follows real receipt")
	_ok(game.travel("post_office", 30), "return actual second and third dispositions")
	_stamp(game, "case02"); _stamp(game, "case03")
	_ok(game.discover_archive_box(), "current June mail route supports old archive discovery")
	_ok(game.take_case("case04"), "physically take recovered old envelope")
	_ok(game.inspect_envelope("case04", "front"), "external old item names June")
	_ok(game.inspect_envelope("case04", "back"), "turn old envelope to handwritten mark")
	_ok(game.observe("case04_archive_mark"), "record the actually seen mark")
	_ok(game.observe("case04_manual_hold"), "compare manual hold with its original ledger entry")
	_ok(game.travel("community_center", 15), "seek public history instead of private letter")
	for clue: String in ["old_music_photo", "sea_watch_roster"]: _ok(game.observe(clue), "read dated relationship context " + clue)
	_check(game.speak("june_arlen", "june_photo").error.is_empty(), "known photo supports non-invasive conversation")
	_ok(game.travel("bus_stop", 15), "ask actual witness about observed public photo")
	_check(game.speak("chenyuan", "chenyuan_music").error.is_empty(), "on-site testimony adds current context without proving reconciliation")
	_ok(game.travel("community_center", 15), "return to actual old-mail recipient")
	_ok(game.dispose("case04", "deliver", "june_arlen"), "fourth deliberate handoff preserves recipient agency")
	_check(game.speak("june_arlen", "june_old_mail").error.is_empty(), "recipient chooses when to read old mail")
	_ok(game.travel("post_office", 15), "file old-mail work record")
	_stamp(game, "case04")
	_ok(game.observe("ledger_hv_repeat"), "actual repeat comparison exposes ledger sleeve")
	_ok(game.take_case("case05"), "take physical staff paper revealed by ledger work")
	_ok(game.inspect_envelope("case05", "front"), "visible staff sender is not falsely hidden")
	for clue: String in ["helena_rota", "procedure_codes", "ledger_returns"]: _ok(game.observe(clue), "read independent desk archive source " + clue)
	_ok(game.record_archive_draft({"hv_person":"helena_voss", "desk":"desk_b", "formal_code":false}, ["helena_rota", "procedure_codes", "ledger_returns"]), "record sourced draft without premature truth feedback")
	_ok(game.dispose("case05", "file_officially"), "internal staff note can lawfully be filed without compulsory opening")
	_stamp(game, "case05")
	_check(game.state.privacy.violations.is_empty() and game.remaining_openings() == 3, "entire actual five-case route needs no private opening")
	for id: String in Core.CASE_IDS: _check(not game.case_state(id).read_body and not game.resolution_view(id).is_empty(), "complete external professional outcome and stamped work record " + id)
	_ok(game.end_shift(), "all five connected routes finish through public APIs only")
	_check(game.state.ending.archive_context == "recorded" and game.state.ending.dispositions.size() == 5, "completed ending retains sourced reconstruction and five real dispositions")
	var resumed = _new("connected-route-resume"); resumed.save_path = game.save_path
	_check(resumed.load_game() and resumed.state.ending == game.state.ending, "full route ending survives continue")


func _slip(game, id: String) -> Dictionary:
	return {"determination": {"recipient": "Unverified recipient", "location": "Address requires verification", "status": "Recorded professional judgment"}, "disposition": game.case_state(id).disposition, "note": "QA fixture records the chosen route without asserting hidden answers.", "stamped": true}


func _stamp(game, id: String) -> void:
	_ok(game.record_resolution(id, _slip(game, id)), "explicit post-office resolution stamp " + id)


func _stamp_all(game) -> void:
	if game.state.location != "post_office": _ok(game.travel("post_office", 15), "return to physical stamp counter")
	for id: String in Core.CASE_IDS:
		if game.resolution_view(id).is_empty(): _stamp(game, id)


func _tutorial_rules() -> void:
	var fresh = _new("tutorial-fresh")
	_check(not fresh.state.tutorial_first_case_completed, "tutorial starts incomplete")
	_check(Core.CASE_IDS.filter(func(id: String) -> bool: return fresh.case_state(id).available) == ["case01"], "only first actual mail is available in a new shift")
	for id: String in ["case02", "case03", "case04", "case05"]:
		_reject(fresh.take_case(id), "cannot take later mail before first disposition " + id)
		_check(fresh.case_view(id).is_empty(), "later envelope view stays unavailable " + id)
	_ok(fresh.travel("community_center", 15), "free exploration during first lesson")
	_ok(fresh.observe("june_current_mailpoint"), "public knowledge is not artificially hidden by tutorial")
	_ok(fresh.travel("post_office", 15), "return with genuine public fact")
	_reject(fresh.discover_archive_box(), "public June clue cannot bypass first-letter teaching into case04")
	_check(fresh.save_game() and fresh.save_game(), "tutorial lock persists with valid backup")
	var locked: Dictionary = fresh.state.duplicate(true)
	for kind: String in ["fake_completed", "fake_released"]:
		var bad: Dictionary = locked.duplicate(true)
		if kind == "fake_completed": bad.tutorial_first_case_completed = true
		else: bad.cases.case02.available = true
		_write_envelope(fresh.save_path, bad)
		_check(fresh.load_game() and fresh.last_load_source == "backup" and not fresh.state.tutorial_first_case_completed, "checksum cannot forge tutorial progression " + kind)
	for action: String in ["deliver", "return_to_sender", "hold_for_verification", "unresolved_with_note"]:
		var game = _new("tutorial-" + action)
		var second_before: Dictionary = game.case_state("case02").physical.duplicate(true)
		_ok(game.take_case("case01"), "tutorial hands over actual first object")
		_ok(game.inspect_envelope("case01", "front"), "tutorial reads first envelope")
		_check(not game.state.tutorial_first_case_completed and not game.case_state("case02").available, "merely taking or reading first envelope never finishes tutorial")
		if action == "deliver":
			_ok(game.travel("residential", 15), "teaching delivery walks to actual address")
			_ok(game.meet("elsie_moran"), "teaching delivery asks actual recipient")
			_ok(game.observe("elsie_confirmation"), "teaching address verified")
			_reject(game.dispose("case01", "deliver", "june_arlen"), "wrong deduction remains recoverable within first lesson")
			_check(not game.state.tutorial_first_case_completed and not game.case_state("case03").available, "failed delivery cannot unlock next mail")
		_ok(game.dispose("case01", action, "elsie_moran" if action == "deliver" else "", "The first address is still unverified; record the chosen professional route."), "real first disposition completes teaching " + action)
		_check(not game.state.tutorial_first_case_completed and not game.case_state("case02").available, "actual disposition alone does not bypass physical resolution stamp")
		if game.state.location != "post_office": _ok(game.travel("post_office", 15), "bring first disposition record back to counter")
		_stamp(game, "case01")
		_check(game.state.tutorial_first_case_completed and game.case_state("case02").available and game.case_state("case03").available, "valid first outcome releases both next envelopes " + action)
		_check(game.case_state("case02").physical == second_before and not game.case_state("case04").available, "release does not fabricate inspection, repairs, or archive discovery")
		var clone = _new("tutorial-resume-" + action); clone.save_path = game.save_path
		_check(clone.load_game() and clone.state.tutorial_first_case_completed and clone.case_state("case03").available, "completed lesson resumes through saved actual disposition")
		_reject(game.dispose("case01", action, "elsie_moran", "repeat"), "same first disposition cannot be re-credited")
	# The previous same-day v2 format had no tutorial field; only provable states migrate.
	var legacy_game = _new("tutorial-legacy-pristine")
	var legacy: Dictionary = _legacy_tutorial_snapshot(legacy_game.state)
	_write_envelope(legacy_game.save_path, legacy)
	var original := FileAccess.get_file_as_string(legacy_game.save_path)
	_check(legacy_game.load_game() and not legacy_game.state.tutorial_first_case_completed and not legacy_game.case_state("case02").available, "same-day untouched v2 can safely adopt first-letter lock")
	_check(FileAccess.get_file_as_string(legacy_game.save_path) == original, "loading compatible old v2 never rewrites original bytes")
	_check(legacy_game.save_game(), "explicit save publishes safely migrated tutorial state")
	var completed_game = _new("tutorial-legacy-completed")
	_finish_tutorial(completed_game)
	legacy = _legacy_tutorial_snapshot(completed_game.state)
	_write_envelope(completed_game.save_path, legacy)
	_check(completed_game.load_game() and completed_game.state.tutorial_first_case_completed and completed_game.case_state("case02").available, "same-day v2 completion inferred only from actual first disposition")
	_check(completed_game.save_game(), "migrated pre-disposition checkpoint remains valid")
	legacy = _legacy_tutorial_snapshot(_new("tutorial-unsafe-source").state)
	legacy.cases.case02.owner = "courier" # Historical out-of-order v2 fixture, never a gameplay shortcut.
	_write_envelope(legacy_game.save_path, legacy)
	original = FileAccess.get_file_as_string(legacy_game.save_path)
	_check(not legacy_game.load_game() and not legacy_game.save_game() and FileAccess.get_file_as_string(legacy_game.save_path) == original, "out-of-order old progress is preserved rather than guessing tutorial completion")


func _resolution_rules() -> void:
	var game = _new("resolution-boundaries")
	_check(game.resolution_view("case01").is_empty() and game.resolution_view("not_a_case").is_empty(), "new or unknown case has no fabricated slip")
	_reject(game.record_resolution("case01", _slip(game, "case01")), "cannot stamp before actual disposition")
	_ok(game.take_case("case01"), "resolution fixture takes real first envelope")
	_ok(game.dispose("case01", "hold_for_verification", "", "External address remains uncertain."), "first legal unresolved physical disposition")
	_check(not game.state.tutorial_first_case_completed and game.save_game() and game.load_game(), "unstamped first disposition is a valid resumable state")
	_check(not game.case_state("case02").available, "restarting before stamp cannot release next mail")
	_ok(game.travel("community_center", 15), "try stamp away from physical postal counter")
	_reject(game.record_resolution("case01", _slip(game, "case01")), "remote stamp rejected")
	_ok(game.travel("post_office", 15), "return to physical postal counter")
	var result := _slip(game, "case01")
	for kind: String in ["extra_key", "hidden_answer", "missing_status", "long_field", "long_note", "not_stamped", "integer_stamp", "wrong_disposition", "invalid_type"]:
		var bad: Dictionary = result.duplicate(true)
		match kind:
			"extra_key": bad.case_id = "case01"
			"hidden_answer": bad.determination.correct_answer = "author-only"
			"missing_status": bad.determination.erase("status")
			"long_field": bad.determination.location = "a".repeat(81)
			"long_note": bad.note = "a".repeat(501)
			"not_stamped": bad.stamped = false
			"integer_stamp": bad.stamped = 1
			"wrong_disposition": bad.disposition = "deliver"
			"invalid_type": bad.determination.recipient = 17
		_reject(game.record_resolution("case01", bad), "unaccepted resolution payload " + kind)
		_check(game.resolution_view("case01").is_empty() and not game.state.tutorial_first_case_completed, "rejected slip cannot create progress " + kind)
	result.determination = {"recipient": "My unverified guess", "location": "Unknown address", "status": "Unresolved; retain for verification"}
	var before: Dictionary = game.state.duplicate(true)
	_ok(game.record_resolution("case01", result), "stamp actual route with explicitly provisional player judgment")
	_check(game.state.tutorial_first_case_completed and game.case_state("case02").available and game.case_state("case03").available, "first physical resolution stamp releases remaining introductory mail")
	_check(game.state.minute == before.minute and game.state.work_reliability == before.work_reliability and game.state.known_names == before.known_names, "stamp neither charges reading time nor awards hidden correctness or identity")
	var view: Dictionary = game.resolution_view("case01")
	_check(view.determination == result.determination and view.disposition == "hold_for_verification" and view.stamped and not view.legacy_resolution, "player judgment and actual disposition remain explicitly separate fields")
	var journal_count: int = game.state.journal.size()
	_ok(game.record_resolution("case01", result), "identical repeat callback is idempotent")
	_check(game.state.journal.size() == journal_count, "one physical stamp produces one record")
	result.determination.recipient = "Different later guess"
	_reject(game.record_resolution("case01", result), "already stamped record cannot be silently overwritten")
	view.determination.recipient = "external mutation"
	_check(game.resolution_view("case01").determination.recipient == "My unverified guess", "public view is detached from authoritative state")
	_ok(game.take_case("case02"), "after teaching actual next letter available")
	_ok(game.begin_operation("case02", "open"), "tool operation blocks paperwork")
	_reject(game.record_resolution("case01", _slip(game, "case01")), "active workbench cannot stamp concurrently")
	_ok(game.cancel_operation(game.case_state("case02").physical), "untouched tool cancellation keeps paperwork legal")
	_check(game.save_game() and game.save_game(), "valid stamped state makes recoverable backup")
	var valid: Dictionary = game.state.duplicate(true)
	for kind: String in ["wrong_route", "removed_stamp", "future_stamp", "remote_stamp", "hidden_truth", "unhandled", "deleted_first", "bad_legacy", "integer_stamp", "boolean_time"]:
		var bad: Dictionary = valid.duplicate(true)
		match kind:
			"wrong_route": bad.cases.case01.resolution.disposition = "deliver"
			"removed_stamp": bad.cases.case01.resolution.stamped = false
			"future_stamp": bad.cases.case01.resolution.recorded_minute = bad.minute + 1
			"remote_stamp": bad.cases.case01.resolution.recorded_location = "lookout"
			"hidden_truth": bad.cases.case01.resolution.determination.correct = true
			"unhandled": bad.cases.case02.resolution = bad.cases.case01.resolution.duplicate(true)
			"deleted_first": bad.cases.case01.resolution = {}
			"bad_legacy": bad.cases.case01.resolution.legacy_resolution = true
			"integer_stamp": bad.cases.case01.resolution.stamped = 1
			"boolean_time": bad.cases.case01.resolution.recorded_minute = true
		_write_envelope(game.save_path, bad)
		_check(game.load_game() and game.last_load_source == "backup" and game.state.tutorial_first_case_completed, "resolution business validation restores clean backup " + kind)
	var legacy: Dictionary = _legacy_resolution_snapshot(valid)
	_write_envelope(game.save_path, legacy)
	var bytes := FileAccess.get_file_as_string(game.save_path)
	_check(game.load_game() and game.case_state("case02").owner == "courier" and game.state.tutorial_first_case_completed, "previous v3 progress never loses already released or held mail")
	view = game.resolution_view("case01")
	_check(view.legacy_resolution and not view.stamped and view.recorded_minute == -1 and view.recorded_location == "" and view.determination == {"recipient": "", "location": "", "status": ""}, "migration marks explicit legacy resolution without fabricating old judgment, stamp or time")
	_check(FileAccess.get_file_as_string(game.save_path) == bytes and game.save_game(), "v3 loading preserves original bytes until explicit upgraded save")
	_check(game.state.checkpoint.snapshot.rules_version == Core.RULES_VERSION, "resolution migration also preserves valid nested pre-operation checkpoint")


func _legacy_tutorial_snapshot(current: Dictionary) -> Dictionary:
	var legacy: Dictionary = _legacy_amendment_snapshot(current)
	legacy.rules_version = Core.PRE_TUTORIAL_RULES
	legacy.erase("tutorial_first_case_completed")
	legacy.cases.case02.available = true
	legacy.cases.case03.available = true
	if not legacy.get("checkpoint", {}).is_empty(): legacy.checkpoint.snapshot = _legacy_tutorial_snapshot(legacy.checkpoint.snapshot)
	var pending: Dictionary = legacy.get("world_flags", {}).get("delegated_delivery", {})
	if not pending.is_empty(): pending.pre_handoff = _legacy_tutorial_snapshot(pending.pre_handoff)
	return legacy


func _legacy_amendment_snapshot(current: Dictionary) -> Dictionary:
	var legacy: Dictionary = _legacy_resolution_snapshot(current)
	legacy.rules_version = Core.PRE_AMENDMENT_RULES
	for id: String in Core.CASE_IDS:
		legacy.cases[id].erase("alterations")
		legacy.cases[id].physical.version = 2
		for key: String in Core.AMENDMENT_FIELDS + ["replacement_position", "attachment_position"]:
			legacy.cases[id].physical.erase(key)
	if not legacy.get("checkpoint", {}).is_empty(): legacy.checkpoint.snapshot = _legacy_amendment_snapshot(legacy.checkpoint.snapshot)
	var pending: Dictionary = legacy.get("world_flags", {}).get("delegated_delivery", {})
	if not pending.is_empty(): pending.pre_handoff = _legacy_amendment_snapshot(pending.pre_handoff)
	return legacy


func _legacy_resolution_snapshot(current: Dictionary) -> Dictionary:
	var legacy: Dictionary = current.duplicate(true)
	legacy.rules_version = Core.PRE_RESOLUTION_RULES
	for id: String in Core.CASE_IDS: legacy.cases[id].erase("resolution")
	if not legacy.get("checkpoint", {}).is_empty(): legacy.checkpoint.snapshot = _legacy_resolution_snapshot(legacy.checkpoint.snapshot)
	var pending: Dictionary = legacy.get("world_flags", {}).get("delegated_delivery", {})
	if not pending.is_empty(): pending.pre_handoff = _legacy_resolution_snapshot(pending.pre_handoff)
	return legacy


func _initial_and_time() -> void:
	var game = _new("initial")
	_check(game.state.minute == 540 and game.state.location == "post_office", "final calendar initial state")
	_check(game.case_data("case02").deadline == "17:30" and game.case_data("case03").deadline == null, "final deadline supersedes old case assignment")
	_check(game.case_data("case03").recipient_id == "june_arlen" and not game.catalog.people.has("nora_vale"), "June final identity, no old Nora migration")
	_check(game.dossier_view().known_people.is_empty() and game.known_person_label("helena_voss") == "尚未确认身份", "fresh dossier does not enumerate author-known names")
	_check(game.case_view("case04").is_empty() and game.case_view("case01").front.is_empty(), "unseen envelopes do not leak author data to UI view")
	for id: String in Core.CASE_IDS:
		var model = Paper.new()
		_ok(model.restore_state(game.case_state(id).physical), "fresh " + id + " enters physical model")
	_check(game.save_game(), "fresh complete physical states are saveable")
	_ok(game.take_case("case01"), "take actual first item")
	_ok(game.inspect_envelope("case01", "front"), "read addressed front")
	_ok(game.inspect_envelope("case01", "back"), "read reverse")
	_check(game.case_view("case01").front.recipient == "Elsie Moran" and not game.case_view("case01").has("sender_id") and game.case_view("case01").body.is_empty(), "UI sees inspected address but not rule answer or private body")
	_check(game.state.minute == 540 and game.body_text("case01").is_empty(), "inspection pauses clock and keeps body private")
	_ok(game.travel("residential", 15), "explicit previewed walk cost")
	_check(game.state.minute == 555, "travel charges once")
	_reject(game.travel("residential", 15), "same destination cannot charge")
	_reject(game.travel("community_center", 7), "unpreviewed arbitrary cost rejected")
	_reject(game.take_case("case02"), "cannot teleport desk mail into bag")
	_reject(game.observe("elsie_confirmation"), "cannot acquire NPC answer without on-site meeting")
	_ok(game.meet("elsie_moran"), "meet Elsie on site")
	_ok(game.observe("elsie_confirmation"), "voluntary fact after meeting")
	_check(game.state.minute == 555, "conversation observation does not drain clock")
	_check(game.dossier_view().observations[0].source == "elsie_moran" and game.dossier_view().observations[0].observed_minute == 555, "dossier preserves actual source, place and observed time")
	_ok(game.perform_time_event("long_help", "tea_for_elsie"), "long help event commits")
	_check(game.state.minute == 585, "long help costs exactly thirty")
	_reject(game.perform_time_event("long_help", "tea_for_elsie"), "repeat callback cannot charge twice")
	_ok(game.travel("community_center", 15), "visit equipment ledger")
	_reject(game.observe("telescope_returned"), "future return is not a present fact")
	_ok(game.observe("telescope_checkout"), "early checkout can be read")
	_check(not game.equipment_record().text.contains("returned 15:05"), "early public text excludes future return")
	game.state.minute = 890 # Explicit boundary fixture, not a player shortcut.
	_ok(game.perform_time_event("records_retrieval", "boundary_retrieval"), "event reaches 15:05")
	_check(game.state.minute == 905 and game.equipment_record().id == "telescope_returned", "15:05 event updates record exactly")
	_ok(game.observe("telescope_checkout"), "old record reference resolves current version")
	_check(game.has_evidence("telescope_returned"), "returned fact acquired only after event")
	_check(game.save_game(), "dated evidence round-trips valid state")


func _physical_and_privacy() -> void:
	var game = _new("physical")
	_ok(game.take_case("case01"), "take private ordinary letter")
	var model = _begin(game, "case01", "open")
	_ok(model.select_tool("opener"), "take opener")
	_check(model.tool_contact(model.seam_point(8)) == "visible_crease", "bad material contact damages without valid breach")
	model.cancel_operation()
	_ok(game.cancel_operation(model.export_state()), "cancel retains material snapshot")
	_check(game.case_state("case01").physical.privacy_violation and not game.case_state("case01").physical.opened, "unauthorized damaged paper is recorded before seal actually opens")
	_check(game.state.work_reliability == 0 and game.state.npc_trust.is_empty(), "unknown private act is separate from job score and NPC trust")
	_check(game.save_game(), "cancelled physical trace can be saved")
	var clone = _new("physical-reload")
	clone.save_path = game.save_path
	_check(clone.load_game() and clone.case_state("case01").physical.tamper_trace == 1.0, "cancel damage survives restart")
	model = _begin(clone, "case01", "open")
	_ok(model.select_tool("opener"), "resume opener")
	_ok(model.tool_contact(model.seam_point(0)), "valid breach commits")
	_reject(clone.finish_operation("case01", model.export_state()), "seam breach alone grants no complete reading")
	_check(not clone.save_game(), "no intermediate tool autosave")
	model.cancel_operation()
	_ok(clone.cancel_operation(model.export_state()), "partial seam safe exit")
	_check(clone.body_text("case01").is_empty(), "partial opening does not expose full body API")
	_open(clone, "case01")
	_check(clone.body_text("case01").contains("blue bowl") and clone.state.minute == 540, "actual extraction plus unfolds grants original body without time drain")
	_reject(clone.can_dispose("case01", "return_to_sender"), "return route cannot receive unsealed paper")
	_reseal(clone, "case01")
	_check(clone.case_state("case01").physical.opened and clone.case_state("case01").read_body, "resealing never erases opening or knowledge")
	_check(clone.save_game(), "full physical state and history save")
	_ok(clone.dispose("case01", "return_to_sender"), "real first disposition releases later mail")
	_stamp(clone, "case01")
	_ok(clone.take_case("case03"), "take damaged label after tutorial")
	_reject(clone.observe("label_reconstructed"), "unrepaired label cannot grant fact")
	_repair(clone)
	_ok(clone.observe("label_reconstructed"), "read actual repaired exterior")
	_check(clone.state.minute == 540 and clone.body_text("case03").is_empty() and clone.state.privacy.violations == ["case01"], "authorized exterior repair adds no clock or privacy cost")
	_check(clone.case_data("case03").envelope.recovered_fields.forwarding_valid_until == "2025-07-19", "physical source displays date rather than solved conclusion")
	_check(clone.case_view("case03").body.is_empty() and clone.case_view("case03").attachment.is_empty(), "repaired exterior view leaks neither Leonie nor private photo")
	var score: int = clone.state.work_reliability
	_ok(clone.adjust_trust("chenyuan", -2, "an unrelated rude answer"), "individual trust can change independently")
	_check(clone.state.work_reliability == score and clone.has_evidence("label_reconstructed"), "low trust does not rewrite job facts")
	# Body source remains reachable in every optional branch through the same physical API.
	for id: String in ["case02", "case03"]:
		if clone.case_state(id).owner != "courier": _ok(clone.take_case(id), "take " + id)
		_open(clone, id)
		_reseal(clone, id)
	_check(clone.state.failure.is_empty() and clone.state.privacy.violations.size() == 3, "third opening is allowed and does not itself trigger detection failure")


func _inspection_bridge() -> void:
	var game = _new("inspection-bridge")
	_finish_tutorial(game)
	_ok(game.take_case("case03"), "take inspection-only item")
	var model = Paper.new()
	_ok(model.restore_state(game.case_state("case03").physical), "initial no-tool inspection snapshot")
	_ok(model.set_inspection(1.2, Vector2.ZERO), "pose-only zoom before deliberate face inspection")
	_ok(game.accept_inspection("case03", model.export_state()), "pose-only snapshot does not invent inspected face")
	_ok(model.inspect_face("front"), "inspection front")
	_ok(model.inspect_face("back"), "inspection reverse")
	_ok(model.set_inspection(1.8, Vector2(70, -15)), "inspection zoom and pan")
	_drag(model, "envelope", Vector2(35, 25))
	_ok(game.accept_inspection("case03", model.export_state()), "commit real pose and faces without fake tool session")
	_check(game.state.minute == 540 and not game.case_state("case03").read_body and game.known_person_label("june_arlen") == "June Arlen", "inspection teaches addressed name, no body or time cost")
	_check(game.save_game(), "inspection-only state persists")
	var loaded = _new("inspection-resume"); loaded.save_path = game.save_path
	_check(loaded.load_game() and loaded.case_state("case03").physical == JSON.parse_string(JSON.stringify(game.case_state("case03").physical)), "inspection full snapshot survives restart")
	var malicious = Paper.new()
	malicious.restore_state(game.case_state("case03").physical)
	_ok(malicious.begin_operation("open"), "construct valid unauthorized open snapshot")
	_ok(malicious.select_tool("opener"), "fixture opener")
	_ok(malicious.tool_contact(malicious.seam_point(0)), "fixture actual breach")
	malicious.cancel_operation()
	_reject(game.accept_inspection("case03", malicious.export_state()), "even valid physical breach cannot enter through inspection permission")
	_check(not game.case_state("case03").physical.opened and game.state.privacy.violations.is_empty(), "rejected snapshot commits no material mutation")
	var altered: Dictionary = model.export_state()
	altered.paper_position[0] = float(altered.paper_position[0]) + 50.0
	_reject(game.accept_inspection("case03", altered), "dependent inner-page pose cannot be independently relocated")
	_ok(game.begin_operation("case03", "repair_exterior"), "legitimate tool mode starts")
	_reject(game.accept_inspection("case03", model.export_state()), "inspection cannot bypass active-operation boundary")
	_ok(game.cancel_operation(model.export_state()), "safe exit legitimate tool mode")


func _routing_and_deadline() -> void:
	var game = _new("routes")
	_ok(game.take_case("case01"), "first teaching letter only")
	_ok(game.travel("residential", 15), "first recipient location")
	_ok(game.meet("elsie_moran"), "Elsie encounter")
	_ok(game.observe("elsie_confirmation"), "current first address confirmed")
	_reject(game.dispose("case01", "deliver", "june_arlen"), "wrong handoff rejected but recoverable")
	_check(game.case_state("case01").owner == "courier" and game.state.failure.is_empty(), "one wrong delivery keeps custody and game running")
	_ok(game.dispose("case01", "deliver", "elsie_moran"), "correct delivery after wrong attempt")
	_check(game.case_state("case01").owner == "elsie_moran", "handoff records actual custody")
	_reject(game.take_case("case01"), "delivered object cannot be reclaimed")
	_ok(game.travel("post_office", 15), "return after first delivery to collect remaining mail")
	_stamp(game, "case01")
	for id: String in ["case02", "case03"]: _ok(game.take_case(id), "newly released bag " + id)
	_ok(game.travel("residential", 15), "return to investigate old June address")
	_ok(game.observe("current_3c_resident"), "old June address now belongs to someone else")
	_repair(game)
	_ok(game.observe("label_reconstructed"), "read repaired forwarding dates")
	_ok(game.travel("community_center", 15), "find approved cubby")
	_ok(game.observe("june_current_mailpoint"), "public current mail authority")
	_reject(game.dispose("case03", "forward", "north_pier_hostel"), "expired forwarding destination rejected")
	_ok(game.dispose("case03", "forward", "community_center_cubby"), "approved current local forwarding")
	_check(not game.case_state("case03").read_body and game.state.privacy.violations.is_empty(), "case03 resolves completely without reading private letter")
	_ok(game.travel("lookout", 15), "Mira route")
	game.state.minute = 1049; game._refresh_time_events()
	_ok(game.dispose("case02", "deliver", "mira_vale"), "17:29 actual handoff accepted")
	_check(not game.case_state("case02").late, "before boundary is not late")
	var late = _new("late")
	_finish_tutorial(late)
	_ok(late.take_case("case02"), "take priority for late route")
	_ok(late.travel("lookout", 30), "late-route location")
	late.state.minute = 1050; late._refresh_time_events()
	_reject(late.dispose("case02", "deliver", "mira_vale"), "17:30 person has departed")
	_check(late.case_state("case02").owner == "courier" and late.case_state("case02").disposition.is_empty(), "late attempt cannot teleport mail back to desk")
	_check(late.state.work_reliability == 1 and late.state.failure.is_empty(), "honest lateness does not erase earlier legitimate tutorial credit")
	_reject(late.dispose("case02", "unresolved_with_note", "", "Mira left"), "registration still requires physical return to post office")
	_ok(late.travel("post_office", 15), "return with undelivered mail")
	_ok(late.dispose("case02", "unresolved_with_note", "", "Arrived after Mira left at 17:30."), "lawful late reason filed")
	_check(late.case_state("case02").owner == "desk_b" and late.case_state("case02").late, "late state and custody retained")
	var relay = _new("relay")
	_finish_tutorial(relay)
	_ok(relay.take_case("case02"), "take relay case")
	_ok(relay.observe("trusted_handoff_rule"), "read rule")
	_ok(relay.travel("bus_stop", 15), "meet possible relay")
	_reject(relay.agree_handoff(600, true, true), "presence alone is not agreement")
	_ok(relay.meet("chenyuan"), "talk to Chenyuan")
	_reject(relay.agree_handoff(600, false, true), "route must be confirmed")
	_ok(relay.agree_handoff(600, true, true), "explicit legal relay agreement")
	_ok(relay.dispose("case02", "delegate", "chenyuan"), "physical handover to agreed carrier")
	_check(relay.case_state("case02").owner == "chenyuan", "delegation does not invent immediate future delivery")
	_ok(relay.perform_time_event("long_help", "relay_wait_activity"), "other work until 09:45")
	_check(relay.case_state("case02").owner == "chenyuan", "before agreed arrival carrier still owns mail")
	_ok(relay.travel("post_office", 15), "reach agreed 10:00 event")
	_check(relay.case_state("case02").owner == "mira_vale" and relay.state.world_flags.delegated_delivery.arrived, "actual clock crossing resolves registered relay")
	_check(not relay.state.world_flags.case02_personal_foreshadow, "delegation loses on-site response without blocking later cases")
	_check(relay.save_game(), "delivered relay custody validates")


func _prepare_archive(game) -> void:
	if not game.state.tutorial_first_case_completed:
		if game.case_state("case01").disposition.is_empty(): _finish_tutorial(game)
		else:
			if game.state.location != "post_office": _ok(game.travel("post_office", 15), "return first completed case to stamp counter")
			_stamp(game, "case01")
	_ok(game.travel("community_center", 15), "find June publicly")
	_ok(game.observe("june_current_mailpoint"), "June authorized present-day contact")
	_ok(game.travel("post_office", 15), "return for archive sorting")
	_ok(game.discover_archive_box(), "physical archive box introduced")
	_ok(game.take_case("case04"), "take old June mail")
	_ok(game.inspect_envelope("case04", "front"), "June is named externally")


func _detected_tampering() -> void:
	var game = _new("detected")
	_prepare_archive(game)
	_check(game.known_person_label("mira_vale") == "尚未确认身份", "old external envelope names June but does not reveal private sender")
	var model = _begin(game, "case04", "open")
	_ok(model.select_tool("opener"), "aged envelope opener")
	for i: int in range(2): _check(model.tool_contact(model.seam_point(8)) == "visible_crease", "permanent paper crease " + str(i))
	model.cancel_operation()
	_ok(game.cancel_operation(model.export_state()), "aged damaged operation safe exit")
	_open(game, "case04")
	_check(game.known_person_label("mira_vale") == "Mira Vale" and game.body_text("case04").ends_with("Mira"), "actual full private reading reveals sender from original signature")
	_check(game.state.work_reliability == 1 and game.state.privacy.discovered.is_empty(), "private knowledge does not alter legitimate tutorial credit before detection")
	_reseal(game, "case04")
	_ok(game.travel("community_center", 15), "visit June for actual receipt")
	_ok(game.dispose("case04", "deliver", "june_arlen"), "opened restored letter can still be physically delivered")
	_check(game.state.privacy.discovered == ["case04"] and game.state.npc_trust.get("june_arlen") == -1, "careful recipient detects sufficiently visible surviving trace")
	_check(game.state.work_reliability == 0 and game.state.failure.is_empty(), "tutorial credit, delivery credit and trace concern remain separate; no instant moral gameover")
	_check(game.save_game(), "detected trace and recipient custody survive validation")


func _archive_and_endings() -> void:
	var index := 0
	for fourth: String in ["deliver", "archive_review", "hold_for_verification"]:
		for fifth: String in ["file_officially", "keep_at_desk", "supervisor_next_shift"]:
			var game = _new("ending-%d" % index); index += 1
			for id: String in ["case01", "case02", "case03"]:
				_ok(game.take_case(id), "initial owned for honest hold")
				_ok(game.dispose(id, "hold_for_verification", "", "Need a second source next shift."), "legal unresolved branch")
				_stamp(game, id)
			_prepare_archive(game)
			_reject(game.take_case("case05"), "fifth cannot be enumerated from bag before actual discovery")
			_reject(game.dispose("case04", "return_to_sender", "mira_vale"), "archive review never means return to assumed Mira sender")
			if fourth == "deliver": _ok(game.travel("community_center", 15), "June handoff destination")
			_ok(game.dispose("case04", fourth, "june_arlen" if fourth == "deliver" else "", "The recovered hold requires review."), "fourth ethical disposition " + fourth)
			if game.state.location != "post_office": _ok(game.travel("post_office", 15), "back to ledger after old mail left custody")
			_reject(game.observe("ledger_hv_repeat"), "handled count alone cannot unlock fifth")
			_ok(game.observe("case04_manual_hold"), "ledger can recover mark after delivery without reclaiming physical mail")
			_ok(game.observe("ledger_hv_repeat"), "actually notice repeated HV in records")
			_ok(game.take_case("case05"), "take existing staff envelope from ledger sleeve")
			_ok(game.observe("ledger_hv_repeat"), "reread ledger while holding fifth")
			_check(game.case_state("case05").owner == "courier", "repeat observation cannot teleport held envelope")
			_ok(game.inspect_envelope("case05", "front"), "staff sender visible without opening")
			if index == 1:
				_open(game, "case05")
				_check(game.body_text("case05").contains("Desk B") and not game.case_state("case05").physical.privacy_violation, "internal staff reading is legally distinct")
				_reseal(game, "case05")
			for clue: String in ["helena_rota", "procedure_codes", "ledger_returns"]: _ok(game.observe(clue), "archive factual source " + clue)
			_ok(game.record_archive_draft({"hv_person": "mira_vale", "desk": "desk_b", "formal_code": false}, ["helena_rota", "procedure_codes"]), "wrong factual draft is accepted provisionally")
			_check(not game.state.archive_draft.confirmed, "no instant answer validation")
			if index != 1: _ok(game.record_archive_draft({"hv_person": "helena_voss", "desk": "desk_b", "formal_code": false}, [] if index == 9 else ["helena_rota", "procedure_codes", "ledger_returns"]), "revisable factual draft with explicit chosen sources")
			_check(game.dossier_view().confirmed.is_empty(), "provisional draft is visually distinct from confirmed facts")
			_ok(game.dispose("case05", fifth), "fifth lawful decision " + fifth)
			var owner: String = game.case_state("case05").owner
			_ok(game.observe("ledger_hv_repeat"), "reread ledger after fifth decision")
			_check(game.case_state("case05").owner == owner, "repeat discovery preserves official custody")
			_reject(game.end_shift(), "all actual dispositions still require their postal slips")
			_stamp_all(game)
			if index == 1:
				_ok(game.travel("bus_stop", 15), "all-complete shift can still be physically away from office")
				var away: Dictionary = game.state.duplicate(true)
				_check(game.end_shift().contains("邮局") and game.state == away, "complete slips cannot remotely close shift or mutate ending")
				_ok(game.travel("post_office", 15), "return to genuine handover desk")
			_ok(game.end_shift(), "all lawful dispositions support complete ending")
			_check(game.state.ending.archive_context == ("not_fully_reconstructed" if index in [1, 9] else "recorded"), "factual outcome requires linked sources and remains separate from lawful ethical option")
			_check(game.state.privacy.violations.is_empty() and game.state.work_reliability == 5, "all nine ethical combinations carry no hidden moral score")
			var loaded = _new("ending-load-%d" % index); loaded.save_path = game.save_path
			_check(loaded.load_game() and loaded.state.ending == game.state.ending, "Continue resumes actual ending")
			_reject(loaded.travel("bus_stop", 15), "completed shift cannot mutate into new day")
			_reject(loaded.record_resolution("case01", _slip(loaded, "case01")), "ended shift cannot add another stamp callback")
			if index == 1:
				_write_envelope(loaded.save_path, _legacy_resolution_snapshot(loaded.state))
				_check(loaded.load_game() and not loaded.state.ending.is_empty() and loaded.resolution_view("case05").legacy_resolution, "completed old v3 shift migrates without reopening or inventing stamps")


func _save_recovery() -> void:
	var game = _new("save")
	_check(game.save_game(), "first save published")
	var first: String = FileAccess.get_file_as_string(game.save_path)
	_ok(game.travel("residential", 15), "progress before second save")
	_check(game.save_game(), "second save rotates validated backup")
	_check(FileAccess.get_file_as_string(game.save_path + ".bak") == first, "backup is previous complete envelope")
	_write(game.save_path, "{broken")
	_write(game.save_path + ".tmp", "half-written interrupted payload")
	_check(game.load_game() and game.last_load_source == "backup" and game.state.minute == 540, "corrupt primary ignores temp and recovers valid backup")
	_check(game.save_game(), "recovered state can publish safely")
	_check(FileAccess.get_file_as_string(game.save_path + ".bak") == first, "corrupt primary does not replace valid recovery copy")
	var good: Dictionary = game.state.duplicate(true)
	var bad: Dictionary = good.duplicate(true)
	bad.cases.case01.owner = "mira_vale"
	_write_envelope(game.save_path, bad)
	_check(game.load_game() and game.last_load_source == "backup", "valid checksum cannot legitimize inconsistent custody")
	bad = good.duplicate(true); bad.cases.case03.physical.fold_progress = [1.0, 1.0]
	_write_envelope(game.save_path, bad)
	_check(game.load_game() and game.last_load_source == "backup", "every physical stage validated, not only summary flags")
	bad = good.duplicate(true); bad.checkpoint = {"snapshot": {"checkpoint": {}}}
	_write_envelope(game.save_path, bad)
	_check(game.load_game() and game.last_load_source == "backup", "nested or malformed recovery point rejected")
	var future := JSON.parse_string(first) as Dictionary; future.version = Core.SAVE_VERSION + 1
	var future_text := JSON.stringify(future)
	_write(game.save_path, future_text)
	_check(not game.load_game() and not game.has_save(), "future format does not silently downgrade to old backup")
	_check(not game.save_game() and FileAccess.get_file_as_string(game.save_path) == future_text, "future primary preserved byte-for-byte against autosave")
	_write(game.save_path, first); _write(game.save_path + ".bak", future_text)
	_check(not game.save_game() and FileAccess.get_file_as_string(game.save_path + ".bak") == future_text, "unknown future backup also preserved")
	_write(game.save_path, JSON.stringify({"minute": 700, "letters": {"case03": {"recipient": "nora_vale"}}}))
	var old: String = FileAccess.get_file_as_string(game.save_path)
	_check(not game.load_game() and not game.save_game() and FileAccess.get_file_as_string(game.save_path) == old, "legacy state cannot be silently migrated or overwritten")


func _failure_recovery() -> void:
	var game = _new("failure")
	_ok(game.take_case("case01"), "first owned loss fixture")
	_ok(game.report_loss("case01", false), "first distinct serious loss")
	_stamp(game, "case01")
	for id: String in ["case02", "case03"]: _ok(game.take_case(id), "owned subsequent loss fixture " + id)
	_check(game.state.failure.is_empty(), "single serious incident is not automatic ending")
	_reject(game.report_loss("case01", false), "same missing item cannot be counted twice")
	_ok(game.travel("bus_stop", 15), "earlier day travel preserved")
	_ok(game.report_loss("case02", false), "second distinct serious loss")
	var before: Dictionary = game.state.duplicate(true)
	_ok(game.report_loss("case03", false), "third serious event reaches implementation threshold")
	_check(game.can_resume_failure() and not game.state.failure.is_empty(), "repeated severe negligence creates recoverable professional stop")
	_reject(game.travel("post_office", 15), "failure gates travel")
	_reject(game.observe("shuttle_timetable"), "failure gates inspecting new facts")
	_reject(game.adjust_trust("chenyuan", 1, "after stop"), "failure gates social mutation")
	_check(not game.state.checkpoint.snapshot.has("checkpoint"), "recovery points never recursively embed older checkpoints")
	var loaded = _new("failure-load"); loaded.save_path = game.save_path
	_check(loaded.load_game() and loaded.can_resume_failure(), "bad ending and recovery survive restart")
	_ok(loaded.resume_checkpoint(), "restore before latest serious operation")
	_check(loaded.state.minute == before.minute and loaded.state.location == before.location and loaded.state.work_reliability == before.work_reliability, "recovery retains earlier day exactly")
	_check(loaded.case_state("case01").owner == "lost" and loaded.case_state("case02").owner == "lost" and loaded.case_state("case03").owner == "courier", "only current failed incident is undone")
	_check(loaded.state.failure.is_empty() and loaded.state.severe_incidents.size() == 2, "resume clears failed current incident without erasing history")
	_ok(loaded.travel("post_office", 15), "resumed normal route")
	_ok(loaded.dispose("case03", "hold_for_verification", "", "Preserve the damaged label for second review."), "honest different choice prevents repeated failure")
	_check(loaded.state.failure.is_empty(), "lawful hold does not create moral failure")


func _opening_budget() -> void:
	var game = _new("opening-budget")
	_ok(game.take_case("case01"), "budget original letter")
	var model = _begin(game, "case01", "open")
	_ok(model.select_tool("opener"), "selection alone")
	model.cancel_operation()
	_ok(game.cancel_operation(model.export_state()), "cancel untouched tool")
	_check(game.remaining_openings() == 3, "selection and untouched cancellation spend no openings")
	for count: int in range(1, 4):
		_open(game, "case01")
		_check(game.state.opening_history.size() == count and game.case_state("case01").physical.opened_count == count, "same envelope reopens spend one each " + str(count))
		_reseal(game, "case01")
		_check(game.remaining_openings() == 3 - count, "resealing never refunds the budget " + str(count))
	_check(game.state.failure.is_empty() and game.state.privacy.discovered.is_empty(), "three careful openings alone are not three discoveries")
	_reject(game.begin_operation("case01", "open"), "fourth reopening blocked")
	_ok(game.dispose("case01", "return_to_sender"), "tutorial finishes with real sealed return before next mail appears")
	_stamp(game, "case01")
	_ok(game.take_case("case02"), "remaining unopened letter still available")
	_reject(game.can_open("case02"), "fourth opening on another envelope blocked")
	_ok(game.inspect_envelope("case02", "front"), "external observation remains legal at cap")
	_ok(game.travel("lookout", 30), "travel remains possible at cap")
	_ok(game.dispose("case02", "deliver", "mira_vale"), "unopened legal delivery remains possible at cap")
	_check(game.save_game(), "reopening history persists")
	var clone = _new("opening-budget-loaded"); clone.save_path = game.save_path
	_check(clone.load_game() and clone.remaining_openings() == 0, "save reload preserves exact budget")
	_reject(clone.begin_operation("case01", "open"), "reload cannot bypass fourth opening guard")


func _internal_opening_budget() -> void:
	var game = _new("internal-opening-budget")
	for id: String in ["case01", "case02"]:
		_ok(game.take_case(id), "internal budget prior private item " + id)
		_open(game, id); _reseal(game, id)
		_ok(game.dispose(id, "hold_for_verification", "", "Further exterior verification next shift."), "preserve undelivered private item")
		_stamp(game, id)
	_ok(game.take_case("case03"), "third case unopened")
	_ok(game.dispose("case03", "hold_for_verification", "", "Repair is deferred to the next shift."), "unopened hold at approaching cap")
	_prepare_archive(game)
	_ok(game.observe("case04_manual_hold"), "actual old disposition record")
	_ok(game.dispose("case04", "archive_review", "", "Review the handwritten hold record."), "fourth legal record without opening")
	_ok(game.observe("ledger_hv_repeat"), "actually find staff sleeve")
	_ok(game.take_case("case05"), "take internal staff envelope")
	_open(game, "case05")
	_check(game.remaining_openings() == 0 and not game.case_state("case05").physical.privacy_violation, "third internal envelope consumes budget but remains lawful")
	_reseal(game, "case05")
	_check(game.state.privacy.violations.size() == 2, "staff seal creates no additional privacy violation")
	_ok(game.dispose("case05", "file_officially"), "internal staff filing at budget cap")
	_stamp_all(game)
	_ok(game.end_shift(), "all five cases can finish legally at opening cap")


func _damage_open_and_reseal(game, id: String, amend_before_reseal: bool = false) -> void:
	var model = _begin(game, id, "open")
	_ok(model.select_tool("opener"), "visible damage opener " + id)
	for i: int in range(4): _check(model.tool_contact(model.seam_point(8)) == "visible_crease", "permanent high trace " + str(i))
	model.cancel_operation()
	_ok(game.cancel_operation(model.export_state()), "keep damage without counting unopened seal")
	_open(game, id)
	if amend_before_reseal: _erase(game, id)
	_reject(game.can_dispose(id, "delegate", "chenyuan") if id == "case02" else game.can_dispose(id, "return_to_sender"), "opened envelope cannot be sent without real repacking")
	_reseal(game, id)


func _first_two_detected(game, amend_third: bool = false) -> void:
	_ok(game.take_case("case01"), "first detected case taken")
	_damage_open_and_reseal(game, "case01")
	_ok(game.travel("residential", 15), "first recipient on site")
	_ok(game.meet("elsie_moran"), "meet Elsie")
	_ok(game.observe("elsie_confirmation"), "verify Elsie address")
	_ok(game.dispose("case01", "deliver", "elsie_moran"), "first discovered private delivery")
	_check(game.state.privacy.discovered.size() == 1 and game.state.failure.is_empty(), "first discovery damages standing without stopping day")
	var score: int = game.state.work_reliability
	_reject(game.dispose("case01", "deliver", "elsie_moran"), "same delivered object cannot repeat discovery")
	_ok(game.meet("elsie_moran"), "revisit recipient")
	_check(game.state.privacy.discovered.size() == 1 and game.state.work_reliability == score, "revisit does not repeat penalty")
	_prepare_archive(game)
	_damage_open_and_reseal(game, "case04")
	_ok(game.travel("community_center", 15), "second recipient on site")
	_ok(game.dispose("case04", "deliver", "june_arlen"), "second discovered private delivery")
	_check(game.state.privacy.discovered.size() == 2 and game.state.failure.is_empty(), "second discovery still allows recovery by lawful decisions")
	_ok(game.travel("post_office", 15), "prepare last private letter")
	_ok(game.take_case("case03"), "record other damaged item honestly")
	_ok(game.dispose("case03", "hold_for_verification", "", "Keep the damaged exterior for next-shift verification."), "lawful work can improve standing before third detection")
	_ok(game.observe("case04_manual_hold"), "old disposition remains available after delivery")
	_ok(game.observe("ledger_hv_repeat"), "real repeated ledger mark")
	_ok(game.take_case("case05"), "staff envelope after actual ledger observation")
	_ok(game.dispose("case05", "file_officially"), "legitimate unread filing also improves standing")
	_check(game.state.work_reliability == 0, "third detection fixture has recovered above lowest tier through lawful work")
	_ok(game.take_case("case02"), "third detected letter taken")
	_damage_open_and_reseal(game, "case02", amend_third)


func _three_detections(delegated: bool, amended: bool = false) -> void:
	var game = _new(("detected-three-relay" if delegated else "detected-three-direct") + ("-amended" if amended else ""))
	_first_two_detected(game, amended)
	var before: Dictionary
	if delegated:
		_ok(game.observe("trusted_handoff_rule"), "read relay rule")
		_ok(game.travel("bus_stop", 15), "reach carrier")
		_ok(game.meet("chenyuan"), "meet carrier")
		_ok(game.agree_handoff(int(game.state.minute) + 30, true, true), "agree actual arrival")
		before = game.state.duplicate(true)
		_ok(game.dispose("case02", "delegate", "chenyuan"), "handoff itself is not recipient detection")
		_check(game.state.privacy.discovered.size() == 2 and game.state.failure.is_empty(), "carrier has no invented recipient reaction")
		_ok(game.travel("post_office", 15), "time before receipt")
		_check(game.state.privacy.discovered.size() == 2 and game.state.failure.is_empty(), "receipt remains pending before arrival")
		_check(game.save_game(), "pending handoff and its actual pre-handoff recovery point save")
		var pending_clone = _new("relay-in-flight-load"); pending_clone.save_path = game.save_path
		_check(pending_clone.load_game(), "in-flight handoff survives restart")
		var bad_pending: Dictionary = game.state.duplicate(true)
		bad_pending.world_flags.delegated_delivery.pre_handoff.cases.case02.physical.tamper_trace = 0.25
		_write_envelope(game.save_path, bad_pending)
		_check(pending_clone.load_game() and pending_clone.last_load_source == "backup", "pre-handoff snapshot cannot fabricate a cleaner letter")
		# Backup is before the last 15-minute leg; reestablish that exact progress legally.
		if pending_clone.state.location == "bus_stop": _ok(pending_clone.travel("post_office", 15), "resume legal first relay leg after backup recovery")
		game = pending_clone
		_ok(game.wait_for_handoff(), "explicit receipt wait triggers third recipient discovery")
	else:
		_ok(game.travel("lookout", 30), "third direct recipient reached")
		before = game.state.duplicate(true)
		_ok(game.dispose("case02", "deliver", "mira_vale"), "third discovered actual delivery")
	_check(game.state.failure.get("kind") == "repeated_detected_tampering" and game.state.failure.get("threshold") == 3, "third discovery triggers explicit user-rule failure")
	_check(game.state.privacy.discovered.size() == 3 and game.state.work_reliability <= Core.LOWEST_REPUTATION and game.reliability_label() == "Probation Concern", "third discovery forces lowest reputation tier")
	_check(game.state.npc_trust.get("mira_vale") == -1 and game.remaining_openings() == 0, "recipient trust and opening budget remain independently recorded")
	_check(game.can_resume_failure(), "detection failure has a usable checkpoint")
	_reject(game.travel("post_office", 15), "detection failure blocks travel")
	_reject(game.end_shift(), "third detected last delivery cannot escape into normal ending")
	_reject(game.dispose("case02", "deliver", "mira_vale"), "failure cannot repeat same delivery penalty")
	_reject(game.record_resolution("case02", _slip(game, "case02")), "failure cannot escape through a resolution stamp")
	_check(game.state.privacy.discovered.size() == 3, "same delivery cannot add fourth discovered entry")
	var clone = _new("detected-three-loaded"); clone.save_path = game.save_path
	_check(clone.load_game() and clone.state.failure.get("kind") == "repeated_detected_tampering", "failure is already persisted before explicit subsequent save")
	_check(clone.save_game(), "failed state can rotate valid backup")
	var stripped_failure: Dictionary = clone.state.duplicate(true)
	stripped_failure.failure = {}
	_write_envelope(clone.save_path, stripped_failure)
	_check(clone.load_game() and clone.last_load_source == "backup", "third discovered incident cannot silently clear its failure flag")
	_write(clone.save_path, "{corrupt failed primary")
	_check(clone.load_game() and clone.last_load_source == "backup" and clone.can_resume_failure(), "corrupt failure primary restores failed-state backup and checkpoint")
	_ok(clone.resume_checkpoint(), "resume before actual third handoff")
	before.checkpoint = {}; before.failure = {}; before.active_operation = {}
	_check(JSON.parse_string(JSON.stringify(clone.state)) == JSON.parse_string(JSON.stringify(before)), "resume restores exact pre-handoff day, knowledge, budget and custody")
	_check(clone.case_state("case02").owner == "courier" and clone.case_state("case02").disposition.is_empty() and clone.state.privacy.discovered.size() == 2, "recovered third item is actionable, not stuck in carrier custody")
	_check(clone.remaining_openings() == 0 and clone.case_state("case02").physical.resealed, "delivery recovery does not refund earlier opening or erase its trace")
	if amended:
		_check(clone.case_state("case02").alterations.confirmed.option_id == "case02_erase_request" and clone.case_state("case02").alterations.receipt.is_empty(), "failed handoff recovery retains actual edited copy but withdraws unobserved future receipt")
		_check(clone.body_text("case02") != clone.source_body_text("case02"), "failure recovery cannot magically return original authored contents")
	_ok(clone.travel("post_office", 15), "return with recovered letter")
	_ok(clone.dispose("case02", "hold_for_verification", "", "Existing damage needs supervisor verification before delivery."), "different lawful disposition avoids repeating failed delivery")
	_check(clone.state.failure.is_empty() and clone.state.privacy.discovered.size() == 2, "honest hold is not a recipient discovery")
	_stamp_all(clone)
	_ok(clone.end_shift(), "recovered honest alternate route still reaches a complete shift")


func _pending_handoff_end_shift() -> void:
	var game = _new("pending-receipt-end")
	for id: String in ["case01", "case03"]:
		_ok(game.take_case(id), "take pending finish case")
		_ok(game.dispose(id, "hold_for_verification", "", "Unverified external address, retain safely."), "record pending finish case")
		_stamp(game, id)
	_prepare_archive(game)
	_ok(game.observe("case04_manual_hold"), "read disposition before archive handoff")
	_ok(game.dispose("case04", "archive_review", "", "Ask archive staff to review the hold."), "record old case")
	_ok(game.observe("ledger_hv_repeat"), "read repeat in ledger")
	_ok(game.take_case("case05"), "take staff envelope unread")
	_ok(game.dispose("case05", "file_officially"), "file staff envelope unread")
	_ok(game.take_case("case02"), "take last unresolved letter")
	_ok(game.observe("trusted_handoff_rule"), "read actual relay rule")
	_ok(game.travel("bus_stop", 15), "reach agreed carrier")
	_ok(game.meet("chenyuan"), "meet agreed carrier")
	_reject(game.agree_handoff(int(game.state.minute), true, true), "cannot invent instantaneous future handoff")
	_ok(game.agree_handoff(int(game.state.minute) + 30, true, true), "last route arrival agreed")
	_ok(game.dispose("case02", "delegate", "chenyuan"), "last letter entrusted")
	_reject(game.wait_for_handoff(), "cannot wait through post-office register at another location")
	_ok(game.travel("post_office", 15), "return before receipt")
	_stamp_all(game)
	var minute: int = game.state.minute
	_check(game.end_shift().contains("回执") and game.state.ending.is_empty(), "all five recorded cannot bypass still-pending recipient event")
	_check(game.state.minute == minute, "blocked end shift never quietly advances reading time")
	_ok(game.wait_for_handoff(), "explicitly wait remaining fifteen minutes")
	_check(game.state.minute == minute + 15 and game.case_state("case02").owner == "mira_vale", "receipt wait advances exactly to actual delivery")
	_reject(game.wait_for_handoff(), "same receipt cannot be waited twice")
	_check(game.state.minute == minute + 15, "duplicate wait charges no extra time")
	_stamp_all(game)
	_ok(game.end_shift(), "confirmed receipt permits final end shift")


func _opening_integrity() -> void:
	var game = _new("opening-immediate")
	_ok(game.take_case("case01"), "spend first two openings on another seal")
	for cycle: int in range(2):
		_open(game, "case01"); _reseal(game, "case01")
	_ok(game.dispose("case01", "hold_for_verification", "", "Retain first letter for a second opinion before delivery."), "record first item before third opening on another mail")
	_stamp(game, "case01")
	_ok(game.take_case("case02"), "immediate counter item")
	var model = _begin(game, "case02", "open")
	_ok(model.select_tool("opener"), "immediate counter opener")
	_ok(model.tool_contact(model.seam_point(0)), "actual first breach before body extraction")
	_ok(game.accept_opening_breach("case02", model.export_state()), "adapter submits breach immediately")
	_check(game.remaining_openings() == 0 and game.body_text("case02").is_empty(), "third breach spends last opening without granting body")
	_ok(game.accept_opening_breach("case02", model.export_state()), "duplicate same breach callback is idempotent")
	_check(game.state.opening_history.size() == 3, "same callback cannot double charge")
	model.cancel_operation()
	_ok(game.cancel_operation(model.export_state()), "partial breached seal checkpoint")
	_check(game.save_game(), "partial real breach saves")
	var clone = _new("opening-immediate-loaded"); clone.save_path = game.save_path
	_check(clone.load_game() and clone.remaining_openings() == 0, "restart during incomplete third opening preserves cap")
	_ok(clone.can_open("case02"), "at cap the actually breached current seal may continue")
	_open(clone, "case02")
	_check(clone.remaining_openings() == 0, "continuing partial third seal does not count as fourth opening")
	_reseal(clone, "case02")
	_check(clone.save_game() and clone.save_game(), "valid sealed history and backup")
	var good: Dictionary = clone.state.duplicate(true)
	for mutation: String in ["serial", "ordinal", "missing_count", "old_flag", "duplicate_discovered", "unreceived_discovery", "bad_checkpoint_type"]:
		var bad: Dictionary = good.duplicate(true)
		match mutation:
			"serial": bad.opening_history[0].serial = 2
			"ordinal": bad.opening_history[0].ordinal = 2
			"missing_count": bad.cases.case02.physical.erase("opened_count")
			"old_flag": bad.cases.case02.physical.opened = false
			"duplicate_discovered": bad.privacy.discovered = ["case02", "case02"]
			"unreceived_discovery": bad.privacy.discovered = ["case02"]
			"bad_checkpoint_type": bad.checkpoint = {"snapshot": {"world_flags": []}}
		_write_envelope(clone.save_path, bad)
		_check(clone.load_game() and clone.last_load_source == "backup", "checksum cannot legitimize opening-history tamper: " + mutation)
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(clone.save_path + ".bak"))
	old.version = 1
	var old_text := JSON.stringify(old)
	_write(clone.save_path, old_text)
	_check(not clone.load_game() and not clone.save_game() and FileAccess.get_file_as_string(clone.save_path) == old_text, "old boolean-only save version is preserved, not guessed or overwritten")


func _amendment_game(label: String, id: String):
	var game = _new(label)
	_finish_tutorial(game)
	if id == "case04": _prepare_archive(game)
	else: _ok(game.take_case(id), "take editable object " + id)
	return game


func _erase(game, id: String, count: int = 8):
	var model = _begin(game, id, "amend")
	_ok(model.configure_amendments(game.amendment_options(id)), "configure finite observed amendment IDs")
	_ok(model.select_tool("eraser"), "pick physical eraser")
	var phrase: Rect2 = model.object_rect("phrase")
	for i: int in count:
		_ok(model.tool_contact(phrase.position + Vector2(phrase.size.x * (i + 0.5) / 8.0, phrase.size.y / 2.0)), "actual eraser segment " + str(i))
	return model


func _replace(game, id: String) -> void:
	var model = _begin(game, id, "amend")
	_ok(model.configure_amendments(game.amendment_options(id)), "configure replacement white list")
	_origin(model, "replacement", model.object_rect("phrase").position)


func _photo(game, included: bool) -> void:
	var model = _begin(game, "case03", "amend")
	_ok(model.configure_amendments(game.amendment_options("case03")), "configure actual original photo")
	_origin(model, "attachment", model.object_rect("attachment_slot").position if included else model.object_rect("attachment_tray").position + Vector2(8, 8))


func _amendment_permissions_and_text() -> void:
	var source_hash := FileAccess.get_sha256(Core.CATALOG_PATH)
	var game = _amendment_game("amend-text", "case02")
	_check(game.amendment_options("case02").is_empty(), "unopened mail exposes no editable source or spoiler preview")
	_reject(game.begin_operation("case02", "amend"), "sealed material cannot be amended")
	var opening = _begin(game, "case02", "open")
	_ok(opening.select_tool("opener"), "open before reading for actual visibility boundary")
	for i: int in 9: _ok(opening.tool_contact(opening.seam_point(i)), "actual seam for partly folded page")
	opening.return_tool(); _drag(opening, "paper", Vector2(220, 0))
	opening.cancel_operation()
	_ok(game.cancel_operation(opening.export_state()), "save extracted but still folded page")
	_check(game.amendment_options("case02").is_empty() and game.body_text("case02").is_empty(), "extraction does not disclose the sentence")
	_reject(game.begin_operation("case02", "amend"), "partly folded body has no amendment permission")
	_open(game, "case02")
	var options: Dictionary = game.amendment_options("case02")
	_check(options.slots.size() == 1 and options.slots[0].options.size() == 2, "only approved single sentence and two finite operations available")
	_check(not JSON.stringify(options).contains("consequence") and not JSON.stringify(options).contains("Mira把"), "safe configuration withholds future response")
	var original: String = game.body_text("case02")
	_check(original == game.source_body_text("case02"), "initial reader text matches immutable source")
	var partial = _erase(game, "case02", 3)
	partial.cancel_operation(); _ok(game.cancel_operation(partial.export_state()), "partial erasure safely exits with real mask")
	_check(game.case_state("case02").physical.erase_mask == 7 and game.case_state("case02").alterations.confirmed.is_empty(), "partial material is not a fabricated completed replacement")
	_check(game.body_text("case02") == original and game.case_state("case02").physical.tamper_trace == 0.5, "partial physical overlay preserves historical source record and irreversible trace")
	_check(game.save_game() and game.load_game() and game.case_state("case02").physical.erase_mask == 7, "partial erasure resumes after JSON round trip")
	_erase(game, "case02")
	var erased: Dictionary = game.case_state("case02")
	_check(erased.alterations.confirmed.option_id == "case02_erase_request" and erased.alterations.history.size() == 1, "actual full erasure commits finite blank option")
	_check(not game.body_text("case02").contains(options.slots[0].original) and game.source_body_text("case02") == original, "erasing changes current copy without rewriting authored source")
	_check(game.case_state("case02").physical.tamper_trace == 0.5, "revisiting erased segments cannot farm extra traces")
	var forged: Dictionary = erased.physical.duplicate(true)
	forged.replacement_id = "case04_replace_departure"; forged.replacement_placed = true
	forged.tamper_trace = 0.75
	_reject(game.accept_inspection("case02", forged), "ordinary inspection cannot insert replacement")
	_ok(game.begin_operation("case02", "amend"), "start authorized amend to check cross-case injection")
	_reject(game.finish_operation("case02", forged), "another letter option cannot be injected through valid physical shape")
	forged = erased.physical.duplicate(true); forged.erase_mask = 0; forged.edit_key = ""
	_reject(game.cancel_operation(forged), "cancel cannot recreate erased source")
	_ok(game.cancel_operation(erased.physical), "failed injection leaves original stored material intact")
	_replace(game, "case02")
	var expected: String = original.replace(options.slots[0].original, options.slots[0].options[1].text)
	_check(game.body_text("case02") == expected and game.source_body_text("case02") == original, "actual placed strip selects exact catalog replacement only")
	_check(game.case_state("case02").alterations.history.size() == 2 and game.remaining_openings() == 2, "amendment records separate steps without consuming new seal breach")
	_check(game.state.work_reliability == 1 and game.state.npc_trust.is_empty(), "meaning changes are not automatically moral-scored")
	_reject(game.dispose("case02", "deliver", "mira_vale"), "changed letter still cannot be delivered unsealed")
	_reseal(game, "case02")
	_check(game.amendment_options("case02").is_empty(), "resealed source is no longer actively editable")
	_ok(game.travel("lookout", 15), "take altered copy to actual recipient")
	_ok(game.dispose("case02", "deliver", "mira_vale"), "actual handoff retains amendment history")
	_check(game.recipient_feedback("case02").is_empty() and game.pending_recipient_readings("mira_vale").is_empty(), "handoff does not automatically stage reading or infer encounter")
	_reject(game.witness_recipient_reading("case02"), "cannot claim reading before on-site conversation")
	_ok(game.meet("mira_vale"), "onsite recipient encounter")
	_check(game.pending_recipient_readings("mira_vale") == ["case02"], "recipient API exposes only actual received unread response")
	_ok(game.witness_recipient_reading("case02"), "explicitly observe recipient reading changed version")
	_check(game.recipient_feedback("case02").contains("叫我留下") and not game.recipient_feedback("case02").contains("擦过"), "subtle undetected content receives story response without omniscient accusation")
	var reliability: int = game.state.work_reliability
	_ok(game.witness_recipient_reading("case02"), "reading the already witnessed response is idempotent")
	_check(game.state.work_reliability == reliability and game.pending_recipient_readings("mira_vale").is_empty(), "repeated reading adds no duplicate reaction or penalty")
	_reject(game.begin_operation("case02", "amend"), "recipient-owned object cannot be edited from retained record")
	_check(game.save_game() and game.load_game() and game.recipient_feedback("case02").contains("叫我留下"), "witnessed response persists with confirmed edited copy")
	_check(FileAccess.get_sha256(Core.CATALOG_PATH) == source_hash, "every authored original body remains byte-identical")
	var unsupported = _new("amend-unsupported"); _ok(unsupported.take_case("case01"), "take original tutorial envelope")
	_open(unsupported, "case01")
	_reject(unsupported.begin_operation("case01", "amend"), "no invented editing option on first letter")
	_check(unsupported.amendment_options("case01").is_empty(), "unsupported letter has no generic text editor")


func _amendment_attachment_and_receipts() -> void:
	for return_photo: bool in [false, true]:
		var game = _amendment_game("amend-photo-" + str(return_photo), "case03")
		_repair(game)
		_ok(game.observe("label_reconstructed"), "actually read repaired outer label")
		_check(game.amendment_options("case03").is_empty(), "authorized exterior repair grants no private attachment access")
		_open(game, "case03")
		_check(game.amendment_options("case03").slots.is_empty() and game.amendment_options("case03").attachment.id == "case03_lighthouse_photo", "third letter exposes only actual photo, never arbitrary text edit")
		_photo(game, false)
		_check(not game.case_state("case03").alterations.attachment_included and game.case_state("case03").physical.attachment_location == "desk", "removed photo remains a single separate physical object")
		if return_photo:
			_photo(game, true); _photo(game, false); _photo(game, true)
			_check(game.case_state("case03").alterations.history.size() == 4 and game.case_state("case03").physical.attachment_moved, "return restores inclusion but retains each actual handling event")
		_check(game.case_state("case03").physical.tamper_trace == 0.5 and game.remaining_openings() == 2, "repeated photo movement neither clears history nor repeatedly accumulates damage")
		_reseal(game, "case03")
		_ok(game.travel("residential", 15), "verify former photo letter address")
		_ok(game.observe("current_3c_resident"), "confirm expired addressee location")
		_ok(game.travel("community_center", 15), "current approved photo recipient contact")
		_ok(game.observe("june_current_mailpoint"), "record current cubby authority")
		_ok(game.dispose("case03", "forward", "community_center_cubby"), "forward actual resealed copy with current attachment state")
		_check(game.recipient_feedback("case03").is_empty(), "placing envelope in cubby does not emit remote conversation")
		_ok(game.meet("june_arlen"), "meet actual photo recipient")
		_check(game.pending_recipient_readings("mira_vale").is_empty(), "another person cannot see this pending reading")
		_ok(game.witness_recipient_reading("case03"), "observe June opening received copy onsite")
		var response: String = game.recipient_feedback("case03")
		_check(response.contains("真的留了") if return_photo else response.contains("里面却没有"), "received photo state selects grounded response")
		_check(not response.contains("你拿") and game.state.npc_trust.is_empty(), "missing photo is a visible discrepancy, not magical proof of theft")
		_check(game.save_game() and game.load_game() and game.case_state("case03").alterations.attachment_included == return_photo, "photo location and actual response survive restart")
	var fourth = _amendment_game("amend-fourth", "case04")
	_open(fourth, "case04"); _erase(fourth, "case04"); _replace(fourth, "case04")
	_check(fourth.body_text("case04").contains("If you leave tomorrow, wait.") and fourth.source_body_text("case04").contains("If you leave tomorrow, go."), "second finite slot preserves old historical source separately")
	_reseal(fourth, "case04")
	_ok(fourth.travel("community_center", 15), "fourth case actual contact")
	_ok(fourth.dispose("case04", "deliver", "june_arlen"), "June decides later when to read the old copy")
	_ok(fourth.meet("june_arlen"), "June on-site reading contact")
	_ok(fourth.witness_recipient_reading("case04"), "observe altered historical response")
	_check(fourth.recipient_feedback("case04").contains("她叫我等") and fourth.state.privacy.discovered.is_empty(), "changed meaning has story consequence without automatic blame")


func _amendment_delegation_and_storage() -> void:
	var game = _amendment_game("amend-relay", "case02")
	_open(game, "case02"); _erase(game, "case02"); _reseal(game, "case02")
	_ok(game.observe("trusted_handoff_rule"), "relay rules for changed mail")
	_ok(game.travel("bus_stop", 15), "relay carrier onsite")
	_ok(game.meet("chenyuan"), "confirm actual carrier")
	_ok(game.agree_handoff(600, true, true), "explicit arrival agreement for changed copy")
	_ok(game.dispose("case02", "delegate", "chenyuan"), "carrier accepts actual altered copy")
	_check(game.case_state("case02").alterations.receipt.is_empty(), "carrier handoff is not recipient reading")
	_check(game.save_game() and game.load_game(), "pending relay preserves edited physical snapshot and pre-handoff checkpoint")
	_ok(game.travel("post_office", 15), "return while carrier travels")
	_ok(game.wait_for_handoff(), "explicitly reach actual recipient arrival")
	_check(game.case_state("case02").alterations.receipt.status == "pending" and game.recipient_feedback("case02").is_empty(), "actual arrival queues but never remotely reveals narrative response")
	_reject(game.witness_recipient_reading("case02"), "post office cannot witness distant recipient")
	_check(game.pending_recipient_readings("mira_vale").is_empty(), "offsite neutral action is also hidden")
	_ok(game.travel("lookout", 15), "visit after relay receipt")
	_ok(game.meet("mira_vale"), "actual post-relay meeting")
	_ok(game.witness_recipient_reading("case02"), "later conversation observes actual received erased version")
	_check(game.recipient_feedback("case02").contains("约我上去") and game.save_game(), "relay retains erased request and grounded response")
	var detected = _amendment_game("amend-detected", "case02")
	_damage_open_and_reseal(detected, "case02")
	_open(detected, "case02"); _erase(detected, "case02"); _reseal(detected, "case02")
	_ok(detected.travel("lookout", 15), "bring visibly damaged altered mail onsite")
	_ok(detected.meet("mira_vale"), "present actual recipient")
	_ok(detected.dispose("case02", "deliver", "mira_vale"), "damaged sealed delivery triggers existing physical detection")
	_ok(detected.witness_recipient_reading("case02"), "observe visible trace question")
	_check(detected.recipient_feedback("case02").contains("擦过") and detected.state.privacy.discovered == ["case02"], "visible paper evidence replaces secret-content omniscience")
	var score: int = detected.state.work_reliability
	_ok(detected.witness_recipient_reading("case02"), "repeat visible response")
	_check(detected.state.work_reliability == score and detected.state.npc_trust.mira_vale == -1, "content callback never double-applies existing detection penalty")


func _amendment_save_integrity() -> void:
	var game = _amendment_game("amend-save", "case02")
	_open(game, "case02"); _erase(game, "case02"); _replace(game, "case02"); _reseal(game, "case02")
	_ok(game.travel("lookout", 15), "storage fixture actual delivery")
	_ok(game.meet("mira_vale"), "storage fixture recipient")
	_ok(game.dispose("case02", "deliver", "mira_vale"), "storage fixture handoff")
	_ok(game.witness_recipient_reading("case02"), "storage fixture witnessed read")
	_check(game.save_game() and game.save_game(), "create protected valid amendment backup")
	var valid: Dictionary = game.state.duplicate(true)
	for kind: String in ["source_hash", "option", "history", "history_rollback", "receipt_text", "remote_witness", "unearned_photo", "physical_key", "trace_deleted", "receipt_deleted"]:
		var bad: Dictionary = valid.duplicate(true)
		match kind:
			"source_hash": bad.cases.case02.alterations.original_body_sha256 = "forged-original"
			"option": bad.cases.case02.alterations.confirmed.option_id = "write-anything"
			"history": bad.cases.case02.alterations.history.clear()
			"history_rollback": bad.cases.case02.alterations.history[1].confirmed = {}
			"receipt_text": bad.cases.case02.alterations.receipt.feedback = "author-only secret"
			"remote_witness": bad.cases.case02.alterations.receipt.witnessed_location = "post_office"
			"unearned_photo": bad.cases.case01.alterations.attachment_included = true
			"physical_key": bad.cases.case02.physical.edit_key = "case04_departure"
			"trace_deleted": bad.cases.case02.physical.tamper_trace = 0.25
			"receipt_deleted": bad.cases.case02.alterations.receipt = {}
		_write_envelope(game.save_path, bad)
		_check(game.load_game() and game.last_load_source == "backup" and game.body_text("case02").contains("I am asking"), "checksum cannot legitimize amendment corruption " + kind)
	var previous = _amendment_game("amend-migrate", "case02")
	_open(previous, "case02"); _reseal(previous, "case02")
	var old: Dictionary = _legacy_amendment_snapshot(previous.state)
	_write_envelope(previous.save_path, old)
	var bytes := FileAccess.get_file_as_string(previous.save_path)
	_check(previous.load_game() and previous.remaining_openings() == 2 and previous.case_state("case02").physical.version == 3, "known v2 retains exact breach count while adding original baseline fields")
	_check(previous.case_state("case02").alterations.history.is_empty() and previous.body_text("case02") == previous.source_body_text("case02"), "migration never guesses an edit or witnessed response")
	_check(FileAccess.get_file_as_string(previous.save_path) == bytes and previous.save_game(), "load leaves old bytes intact until explicit valid upgraded save")
	_check(not previous.state.checkpoint.is_empty() and previous.state.checkpoint.snapshot.rules_version == Core.RULES_VERSION, "known nested recovery checkpoint upgrades consistently")


func _begin(game, id: String, mode: String):
	var model = Paper.new()
	_ok(model.restore_state(game.case_state(id).physical), "bridge stored physical snapshot " + id)
	_ok(game.begin_operation(id, mode), "core begins " + id + " " + mode)
	_ok(model.begin_operation(mode), "physical begins " + mode)
	model.operation_completed.connect(func(_mode: String, snapshot: Dictionary) -> void: _ok(game.finish_operation(id, snapshot), "real physical completion accepted " + id))
	return model


func _drag(model, object_id: String, delta: Vector2) -> void:
	var p: Vector2 = model.object_rect(object_id).get_center()
	_ok(model.begin_drag(object_id, p), "grab " + object_id)
	_ok(model.drag_to(p + delta), "drag " + object_id)
	_ok(model.release_drag(), "release " + object_id)


func _origin(model, object_id: String, destination: Vector2) -> void:
	_drag(model, object_id, destination - model.object_rect(object_id).position)


func _open(game, id: String) -> void:
	var model = _begin(game, id, "open")
	_ok(model.select_tool("opener"), "opener " + id)
	for i: int in range(int(model.export_state().seam_count), 9): _ok(model.tool_contact(model.seam_point(i)), "valid seam " + str(i))
	model.return_tool()
	_drag(model, "paper", Vector2(220, 0))
	_drag(model, "fold_0", Vector2(120, 0))
	_drag(model, "fold_1", Vector2(0, 120))


func _reseal(game, id: String) -> void:
	var model = _begin(game, id, "reseal")
	_drag(model, "fold_0", Vector2(120, 0))
	_drag(model, "fold_1", Vector2(0, 120))
	_origin(model, "paper", model.object_rect("envelope").position + Vector2(420, 65))
	_drag(model, "flap", Vector2(0, 90))
	_ok(model.select_tool("sealer"), "take final sealer")
	_ok(model.tool_contact(model.object_rect("flap").get_center()), "seal completed packed envelope")


func _repair(game) -> void:
	var model = _begin(game, "case03", "repair_exterior")
	if model.export_state().inspected_front and model.export_state().face == "front":
		_check(true, "repair keeps an already inspected front face")
	else: _ok(model.inspect_face("front"), "repair inspect front")
	_ok(model.inspect_face("back"), "repair inspect back")
	_drag(model, "envelope", Vector2(30, 0))
	_ok(model.select_tool("restorer"), "take exterior tool")
	_ok(model.tool_contact(model.object_rect("label").get_center()), "lift actual label")
	model.return_tool()
	var target: Vector2 = model.object_rect("envelope").position + Vector2(190, 130)
	_origin(model, "label", target)
	_ok(model.begin_drag("label", model.object_rect("label").get_center()), "grip exterior fragment")
	_ok(model.rotate_held(-1), "rotate exterior fragment")
	_ok(model.release_drag(), "release exterior fragment")
	_origin(model, "protector", target - Vector2(10, 10))
	_ok(model.select_tool("press"), "protected pressing tool")
	_ok(model.tool_contact(target + Vector2(20, 20)), "press protected aligned fragment")
	model.return_tool()
	_drag(model, "exterior_fold", Vector2(0, 70))
	_ok(model.inspect_face("front"), "deliberate final exterior reinspection")


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: failures.append("cannot write test fixture: " + path); return
	file.store_string(text); file.close()


func _write_envelope(path: String, payload: Dictionary) -> void:
	var text := JSON.stringify(payload)
	_write(path, JSON.stringify({"format": Core.FORMAT, "version": Core.SAVE_VERSION, "payload_json": text, "sha256": text.sha256_text()}))


func _ok(error: String, label: String) -> void:
	_check(error.is_empty(), label + (" — " + error if not error.is_empty() else ""))


func _reject(error: String, label: String) -> void:
	_check(not error.is_empty(), label)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
