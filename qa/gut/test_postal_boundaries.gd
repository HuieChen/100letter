extends "res://addons/gut/test.gd"
## Real production state, isolated saves. These are model tests, not OS input QA.
const Core = preload("res://scripts/rebuild/final_case_state.gd")
const Physical = preload("res://scripts/rebuild/mail_physics_state.gd")
var core: Node

func before_each() -> void:
	core = Core.new()
	core.save_path = "user://qa/gut/" + str(Time.get_ticks_usec()) + ".json"
	add_child_autofree(core)

func test_unopened_letter_and_unmet_people_remain_private() -> void:
	assert_eq(core.case_view("case01").body, "")
	assert_eq(core.case_view("case01").front, {})
	assert_eq(core.dossier_view().known_people, {})
	assert_eq(core.case_view("case04"), {})
	assert_eq(core.take_case("case01"), "")
	assert_eq(core.inspect_envelope("case01", "front"), "")
	assert_false(core.case_view("case01").front.is_empty())
	assert_eq(core.case_view("case01").body, "")
	assert_false(core.case_state("case01").read_body)

func test_invalid_commands_cannot_change_custody_time_or_progress() -> void:
	var before: Dictionary = core.state.duplicate(true)
	watch_signals(core)
	for i: int in range(40):
		var unknown := "not-a-real-object-" + str(i)
		assert_ne(core.take_case(unknown), "")
		assert_ne(core.inspect_envelope("case01", "front"), "")
		assert_ne(core.travel(unknown, 15), "")
		assert_ne(core.travel("residential", 0), "")
		assert_ne(core.observe(unknown), "")
		assert_ne(core.meet(unknown), "")
		assert_ne(core.begin_operation("case01", "open"), "")
		assert_eq(core.state, before, "Rejected commands leave the same physical world")
	assert_signal_not_emitted(core, "changed")

func test_unknown_envelope_face_is_atomic(face = use_parameters(["", "inside", "FRONT", "null", "front/back"])) -> void:
	assert_eq(core.take_case("case01"), "")
	var before: Dictionary = core.state.duplicate(true)
	assert_ne(core.inspect_envelope("case01", face), "")
	assert_eq(core.state, before)

func test_repeated_pickup_never_duplicates_an_envelope() -> void:
	for i: int in range(100):
		assert_eq(core.take_case("case01"), "")
		assert_eq(core.case_state("case01").owner, "courier")
	assert_eq(core.state.cases.size(), 5)
	assert_true(core.state.opening_history.is_empty())
	assert_false(core.case_state("case01").read_body)

func test_ui_copies_cannot_rewrite_original_letter_or_dossier() -> void:
	assert_eq(core.take_case("case01"), "")
	assert_eq(core.inspect_envelope("case01", "front"), "")
	var before: Dictionary = core.state.duplicate(true)
	var exposed: Dictionary = core.case_view("case01")
	exposed.front.address = "Injected address"
	var dossier: Dictionary = core.dossier_view()
	dossier.known_people.clear()
	var item: Dictionary = core.case_state("case01")
	item.owner = "lost"
	assert_eq(core.state, before)
	assert_ne(core.case_view("case01").front.address, "Injected address")

func test_corrupt_save_recovers_last_verified_physical_object() -> void:
	assert_eq(core.take_case("case01"), "")
	assert_eq(core.inspect_envelope("case01", "front"), "")
	assert_true(core.save_game())
	assert_eq(core.inspect_envelope("case01", "back"), "")
	assert_true(core.save_game())
	var broken := FileAccess.open(core.save_path, FileAccess.WRITE)
	broken.store_string("interrupted-write")
	broken.close()
	var restored := Core.new()
	restored.save_path = core.save_path
	add_child_autofree(restored)
	assert_true(restored.load_game())
	assert_eq(restored.last_load_source, "backup")
	assert_eq(restored.case_state("case01").owner, "courier")
	assert_true(restored.case_state("case01").physical.inspected_front)
	assert_false(restored.case_state("case01").physical.inspected_back)
	assert_false(restored.case_state("case01").read_body)

func test_safe_tool_cancel_releases_world_without_losing_letter() -> void:
	assert_eq(core.take_case("case01"), "")
	assert_eq(core.dispose("case01", "hold_for_verification", "", "Address needs verified evidence."), "")
	assert_eq(core.record_resolution("case01", {
		"determination": {"recipient": "Unverified", "location": "Unverified address", "status": "Held for verification"},
		"disposition": "hold_for_verification", "note": "Preserve the object for further verification.", "stamped": true
	}), "")
	assert_eq(core.take_case("case03"), "")
	assert_eq(core.begin_operation("case03", "repair_exterior"), "")
	assert_ne(core.travel("residential", 15), "")
	assert_false(core.save_game(), "No partial tool save is silently committed")
	var paper := Physical.new()
	assert_eq(paper.restore_state(core.case_state("case03").physical), "")
	assert_eq(core.cancel_operation(paper.export_state()), "")
	assert_true(core.state.active_operation.is_empty())
	assert_eq(core.case_state("case03").owner, "courier")
	assert_false(core.case_state("case03").read_body)
	assert_true(core.save_game())
	assert_eq(core.travel("residential", 15), "")

func test_remote_dialogue_cannot_inject_a_clue() -> void:
	var before: Dictionary = core.state.duplicate(true)
	assert_eq(core.dialogue_topics("elsie_moran"), [])
	assert_ne(core.speak("elsie_moran", "elsie_address").error, "")
	assert_eq(core.state, before)
