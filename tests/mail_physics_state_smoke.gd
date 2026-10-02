extends SceneTree
## Tests the independent object model, not the main UI, OS input, or reference feel.
const Model = preload("res://scripts/rebuild/mail_physics_state.gd")
const CONTRACT := "res://tests/fixtures/final_mail_interaction_contract.json"
var checks: int = 0
var failures: Array[String] = []
var completed: Array[Dictionary] = []
var covered := ["INS01", "INS02", "REP01", "REP02", "REP03", "REP04", "REP05", "OPEN01", "OPEN02", "OPEN03", "OPEN04", "OPEN05", "OPEN06", "OPEN07", "OPEN08", "RESEAL01", "RESEAL02", "RESEAL03", "RESEAL04", "SAVE01", "SAVE03", "SAVE05", "RULE07", "RULE08"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_contract_ids()
	_inspection()
	_repair_case03()
	_private_open_and_reseal()
	_staff_and_authorization()
	_edge_workspace()
	_unreleased_last_fold()
	_continuous_seam_motion()
	_unread_partial_return()
	_unextracted_close()
	_opening_count_cycles()
	_limited_amendments()
	_snapshot_guards()
	var report := {
		"suite": "mail_physics_state", "checks": checks, "failures": failures,
		"runtime": Engine.get_version_info(), "started_or_finished_utc": Time.get_datetime_string_from_system(true),
		"scope": "Public model operation API and JSON checkpoint tests. No Main/UI, native input, audio, reference-fidelity or human-player validation.",
		"contract_ids_with_model_assertions": covered,
		"contract_status_note": "Only model-level subsets are tested; fixture scenarios stay NOT_EXECUTED until a real-input adapter exists.",
		"source_sha256": FileAccess.get_sha256("res://scripts/rebuild/mail_physics_state.gd"),
		"test_sha256": FileAccess.get_sha256("res://tests/mail_physics_state_smoke.gd"),
		"contract_sha256": FileAccess.get_sha256(CONTRACT)
	}
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var output := FileAccess.open("res://test-results/mail_physics_state_results.json", FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	else:
		failures.append("could not write isolated test report")
	print("MAIL PHYSICS MODEL: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _new(case_id: String):
	var model = Model.new()
	_ok(model.setup(case_id), "configure " + case_id)
	model.operation_completed.connect(func(mode: String, state: Dictionary) -> void: completed.append({"mode": mode, "state": state}))
	return model


func _roundtrip(model, label: String):
	var snapshot: Dictionary = model.export_state()
	var decoded: Variant = JSON.parse_string(JSON.stringify(snapshot))
	var restored = Model.new()
	_ok(restored.restore_state(decoded), label + " JSON restores")
	_check(restored.export_state() == decoded, label + " preserves all stable state")
	_check(not restored.input_is_captured(), label + " clears transient input")
	restored.operation_completed.connect(func(mode: String, state: Dictionary) -> void: completed.append({"mode": mode, "state": state}))
	return restored


func _drag_delta(model, object_id: String, delta: Vector2) -> void:
	var start: Vector2 = model.object_rect(object_id).get_center()
	_ok(model.begin_drag(object_id, start), "grab " + object_id)
	_ok(model.drag_to(start + delta), "move " + object_id)
	_ok(model.release_drag(), "release " + object_id)


func _drag_origin(model, object_id: String, destination: Vector2) -> void:
	var box: Rect2 = model.object_rect(object_id)
	_drag_delta(model, object_id, destination - box.position)


func _inspection() -> void:
	var model = _new("case04")
	var before: Dictionary = model.export_state()
	var box: Rect2 = model.object_rect("envelope")
	var grab := box.position + Vector2(25, 170)
	_ok(model.begin_drag("envelope", grab), "off-centre paper grab")
	_ok(model.drag_to(grab + Vector2(71, 32)), "paper follows pointer")
	_check(model.object_rect("envelope").position == box.position + Vector2(71, 32), "grab offset does not jump to centre")
	_ok(model.release_drag(), "drop envelope")
	_ok(model.inspect_face("back"), "flip to back")
	_ok(model.set_inspection(2.0, Vector2(90, -20)), "zoom and pan")
	var state: Dictionary = model.export_state()
	_check(state.inspected_back and state.face == "back", "external inspection recorded")
	_check(not state.opened and not state.body_exposed and not model.body_is_currently_visible(), "flip/zoom never expose private body")
	_check(state.tamper_trace == before.tamper_trace, "inspection does not alter material trace")
	_check(not state.has("clock") and not state.has("npc_trust") and not state.has("disposition"), "object model owns no clock/social/disposition state")
	state.opened = true
	_check(not model.export_state().opened, "export is a defensive deep snapshot")
	_check(not model.begin_drag("paper", model.object_rect("paper").get_center()).is_empty(), "intact envelope has no usable inner page grab")
	_check(not model.select_tool("destroy").is_empty(), "no permanent alteration/destruction tool")


func _repair_case03() -> void:
	completed.clear()
	var model = _new("case03")
	_check(model.object_rect("envelope").encloses(model.object_rect("label")), "damaged exterior label begins on the envelope being repaired")
	_ok(model.begin_operation("repair_exterior"), "authorized repair starts")
	_ok(model.inspect_face("front"), "inspect front")
	_ok(model.inspect_face("back"), "inspect back")
	_ok(model.select_tool("restorer"), "take restoration tool")
	_check(not model.tool_contact(model.object_rect("label").get_center()).is_empty(), "cannot lift before placing on mat")
	model.return_tool()
	_drag_delta(model, "envelope", Vector2(30, 0))
	_ok(model.select_tool("restorer"), "take restoration tool on mat")
	_ok(model.tool_contact(model.object_rect("label").get_center()), "touch actual damaged exterior label")
	model.return_tool()
	var target: Vector2 = model.object_rect("envelope").position + Vector2(190, 130)
	_drag_origin(model, "label", target)
	_check(not model.export_state().label_aligned, "correct position with wrong rotation remains unaligned")
	var label_center: Vector2 = model.object_rect("label").get_center()
	_ok(model.begin_drag("label", label_center), "pick fragment to rotate")
	_ok(model.rotate_held(-1), "rotate fragment")
	_ok(model.release_drag(), "drop aligned fragment")
	_check(model.export_state().label_aligned and not model.export_state().exterior_repaired, "mild snap is not repair completion")
	model = _roundtrip(model, "aligned but unpressed label")
	_ok(model.select_tool("press"), "take press")
	_check(not model.tool_contact(target + Vector2(20, 20)).is_empty(), "protective sheet is required before pressing")
	model.return_tool()
	_drag_origin(model, "protector", target - Vector2(10, 10))
	_ok(model.select_tool("press"), "take press after protection")
	_ok(model.tool_contact(target + Vector2(20, 20)), "press the actual protected label")
	model.return_tool()
	model = _roundtrip(model, "pressed exterior label")
	_drag_delta(model, "exterior_fold", Vector2(0, 70))
	_check(completed.is_empty(), "alignment still requires deliberate reinspection")
	_ok(model.inspect_face("front"), "reinspect repaired mail")
	var state: Dictionary = model.export_state()
	_check(state.exterior_repaired and state.repair_quality > 0.0, "authorized repair completion")
	_check(not state.opened and not state.body_exposed and not state.privacy_violation, "Case03 exterior work grants no private-body permission")
	_check(state.seal_condition == "intact", "Case03 original seal remains closed")
	_check(completed.size() == 1 and completed[0].mode == "repair_exterior", "repair emits one boundary event")
	_ok(model.inspect_face("back"), "read recovered fields on object reverse")
	_check(model.visible_label_field_ids() == ["original_address", "forwarding_recipient", "forwarding_destination", "forwarding_valid_from", "forwarding_valid_until"], "repaired object exposes source field IDs, including both dates, without a matching verdict")
	_check(not model.begin_operation("repair_exterior").is_empty() and completed.size() == 1, "repeat attempt cannot emit a second repair reward")


func _private_open_and_reseal() -> void:
	completed.clear()
	var model = _new("case04")
	_ok(model.begin_operation("open"), "private opening mode")
	_ok(model.select_tool("opener"), "take abstract opener")
	_check(not model.export_state().opened and not model.export_state().privacy_violation, "tool selection does not cross material boundary")
	_check(model.tool_contact(Vector2(-10, -10)) == "no_material_contact", "outside-material contact is neutral")
	_check(model.export_state().tamper_trace == 0, "outside-material contact leaves no trace")
	_check(model.tool_contact(model.seam_point(8)) == "visible_crease", "jump to seam endpoint cannot complete ordered work")
	_check(model.export_state().seam_count == 0 and model.export_state().irreversible_damage, "wrong material contact records visible damage without advancing seal")
	_check(model.export_state().privacy_violation and model.export_state().tampering_started and not model.export_state().opened, "damaging private paper is recorded separately from actual seal breach")
	_check(not model.export_state().damage_failure, "single damage does not create final failure")
	model.cancel_operation()
	model = _roundtrip(model, "damaged but not yet breached private paper")
	_ok(model.begin_operation("open"), "resume after damaged-paper cancellation")
	_ok(model.select_tool("opener"), "pick opener after interrupted damage")
	_ok(model.tool_contact(model.seam_point(0)), "first valid seam contact")
	var partial: Dictionary = model.export_state()
	_check(partial.opened and partial.privacy_violation and partial.seal_condition == "loosened", "first actual private breach, not final read, records history")
	model.cancel_operation()
	_check(model.export_state().tamper_trace == partial.tamper_trace and model.export_state().seam_count == 1, "cancel does not erase partial work or damage")
	model = _roundtrip(model, "cancelled partial private seam")
	_ok(model.begin_operation("open"), "resume private opening")
	_ok(model.select_tool("opener"), "resume tool explicitly")
	for index: int in range(1, 9): _ok(model.tool_contact(model.seam_point(index)), "seam segment %d" % index)
	model.return_tool()
	_check(model.export_state().seal_condition == "open" and not model.export_state().extracted, "open seam does not extract paper")
	_check(not model.body_is_currently_visible() and completed.is_empty(), "no completion/body on seam finish")
	var grip: Vector2 = model.object_rect("paper").get_center()
	_ok(model.begin_drag("paper", grip), "grab visible paper edge")
	_ok(model.drag_to(grip + Vector2(99, 0)), "partially extract paper")
	model.cancel_operation()
	_check(is_equal_approx(float(model.export_state().extraction_progress), 0.45), "partial extraction survives cancellation")
	model = _roundtrip(model, "partial extraction")
	_ok(model.begin_operation("open"), "resume extraction")
	_drag_delta(model, "paper", Vector2(121, 0))
	_check(model.export_state().extracted and not model.body_is_currently_visible(), "extracted folded paper still conceals body")
	_drag_delta(model, "fold_0", Vector2(120, 0))
	_check(model.export_state().body_exposed and not model.export_state().body_unfolded, "partial unfold has exposure but no full completion")
	model = _roundtrip(model, "one unfolded panel")
	_drag_delta(model, "fold_1", Vector2(0, 120))
	_check(completed.size() == 1 and completed[0].mode == "open", "actual extraction and both panels emit opening completion once")
	_check(model.body_is_currently_visible() and model.export_state().unfolded, "fully open page is currently readable")
	_check(not model.begin_operation("open").is_empty(), "re-entering fully unfolded state does not duplicate completion")
	_ok(model.begin_operation("reseal"), "begin physical repacking")
	_check(model.begin_drag("paper", model.object_rect("paper").get_center()) == "refold_before_insertion", "unfolded page cannot teleport inside")
	_ok(model.select_tool("sealer"), "take sealer early")
	_check(not model.tool_contact(model.object_rect("flap").get_center()).is_empty(), "tool cannot skip refold/insert/flap")
	model.return_tool()
	_drag_delta(model, "fold_0", Vector2(120, 0))
	_drag_delta(model, "fold_1", Vector2(0, 60))
	model.cancel_operation()
	model = _roundtrip(model, "half refolded page")
	_ok(model.begin_operation("reseal"), "resume refolding")
	_check(model.begin_drag("paper", model.object_rect("paper").get_center()) == "refold_before_insertion", "half fold still cannot be inserted")
	_drag_delta(model, "fold_1", Vector2(0, 60))
	_check(model.export_state().folded and not model.body_is_currently_visible(), "folded object hides content but preserves read history")
	var mouth: Vector2 = model.object_rect("envelope").position + Vector2(420, 65)
	_drag_origin(model, "paper", mouth + Vector2(100, 0))
	_check(model.export_state().paper_location == "partly_inserted", "partial insertion is a distinct resumable state")
	model = _roundtrip(model, "partial insertion")
	_drag_origin(model, "paper", mouth)
	_check(model.export_state().inserted and model.export_state().paper_location == "inside", "actual drag release inserts folded contents")
	_drag_delta(model, "flap", Vector2(0, 45))
	model = _roundtrip(model, "half closed flap")
	_drag_delta(model, "flap", Vector2(0, 45))
	_check(model.export_state().seal_condition == "closed_unsealed" and not model.export_state().resealed, "closing flap does not reseal")
	_ok(model.select_tool("sealer"), "take sealer after closing")
	_ok(model.tool_contact(model.object_rect("flap").get_center()), "physical final sealing contact")
	var sealed: Dictionary = model.export_state()
	_check(sealed.resealed and sealed.restored and sealed.folded and sealed.inserted and sealed.flap_closed, "complete stable reseal summary for core")
	_check(sealed.opened and sealed.body_exposed and sealed.body_unfolded and sealed.privacy_violation, "reseal cannot erase private knowledge/history")
	_check(sealed.tamper_trace == partial.tamper_trace and sealed.irreversible_damage, "reseal preserves permanent damage floor")
	_check(completed.size() == 2 and completed[1].mode == "reseal", "single final reseal boundary event")
	model = _roundtrip(model, "resealed mail")
	_ok(model.begin_operation("open"), "sealed mail can be deliberately reopened")
	model = _roundtrip(model, "selected reopen before contact")
	_ok(model.select_tool("opener"), "reopen tool")
	_ok(model.tool_contact(model.seam_point(0)), "first reopened seam segment")
	_check(not model.export_state().resealed and model.export_state().body_exposed, "new opening changes current seal but keeps historic exposure")


func _staff_and_authorization() -> void:
	var ordinary = _new("case04")
	_check(ordinary.begin_operation("repair_exterior") == "no_authorized_exterior_repair", "intact private Case04 cannot impersonate authorized repair")
	var staff = _new("case05")
	_ok(staff.begin_operation("open"), "staff note can be opened")
	_ok(staff.select_tool("opener"), "staff opener")
	for index: int in range(9): _ok(staff.tool_contact(staff.seam_point(index)), "staff seam %d" % index)
	_check(staff.export_state().opened and not staff.export_state().privacy_violation, "Case05 staff addressee is not a private-customer violation")
	_check(not staff.export_state().body_exposed, "staff authorization still does not skip extraction")


func _snapshot_guards() -> void:
	var model = _new("case04")
	var baseline: Dictionary = model.export_state()
	var bad: Dictionary = baseline.duplicate(true)
	bad.version = 99
	_check(not model.restore_state(bad).is_empty() and model.export_state() == baseline, "unknown version rejected without changing live state")
	bad = baseline.duplicate(true)
	bad.tamper_trace = NAN
	_check(not model.restore_state(bad).is_empty(), "NaN trace rejected")
	bad = baseline.duplicate(true)
	bad.opened = "true"
	_check(not model.restore_state(bad).is_empty(), "truthy string is not accepted as boolean")
	bad = baseline.duplicate(true)
	bad.fold_progress = [1.0, 1.0]
	bad.folded = false
	_check(not model.restore_state(bad).is_empty(), "unfolded paper inside sealed envelope rejected")
	bad = baseline.duplicate(true)
	bad.body_exposed = true
	_check(not model.restore_state(bad).is_empty(), "save cannot grant unearned body exposure")
	bad = baseline.duplicate(true)
	bad.extra_complete_flag = true
	_check(not model.restore_state(bad).is_empty(), "unknown schema keys rejected rather than assumed complete")
	bad = baseline.duplicate(true)
	bad.seal_condition = "open"
	_check(not model.restore_state(bad).is_empty(), "open seal without seam progression rejected")
	_check(model.export_state() == baseline, "all malformed loads leave prior live snapshot intact")
	bad = baseline.duplicate(true)
	bad.label_pressed = true
	_check(not model.restore_state(bad).is_empty(), "pressed label without alignment/protection cannot be loaded")
	bad = baseline.duplicate(true)
	bad.paper_location = "desk"
	_check(not model.restore_state(bad).is_empty(), "loading a desk location cannot teleport closed contents out")
	bad = baseline.duplicate(true)
	bad.irreversible_damage = true
	_check(not model.restore_state(bad).is_empty(), "damage summary must match actual permanent material damage")
	bad = baseline.duplicate(true)
	bad.inserted = true
	_check(not model.restore_state(bad).is_empty(), "loading inserted flag cannot manufacture completed insertion")
	bad = baseline.duplicate(true)
	bad.open_cycle_completed = true
	_check(not model.restore_state(bad).is_empty(), "completed cycle requires real prior full unfolding")
	for field: String in ["envelope_position", "label_position", "protector_position", "paper_position", "pan"]:
		bad = baseline.duplicate(true)
		bad[field] = [1600.0, 900.0]
		_check(not model.restore_state(bad).is_empty() and model.export_state() == baseline, "out-of-workspace " + field + " cannot replace usable live state")


func _edge_workspace() -> void:
	var model = _new("case04")
	_drag_origin(model, "envelope", Vector2(760, 390))
	_check(model.begin_operation("open") == "move_to_opening_area", "edge inspection position requests reachable work area before breach")
	_check(not model.export_state().opened, "work-area guard changes no material")
	_drag_origin(model, "envelope", Vector2(220, 260))
	_ok(model.begin_operation("open"), "maximum safe opening position accepted")
	_ok(model.select_tool("opener"), "edge-case opener")
	for index: int in range(9): _ok(model.tool_contact(model.seam_point(index)), "edge-case seam %d" % index)
	model.return_tool()
	_check(Model.TABLE.encloses(model.object_rect("paper")), "edge extraction grip remains inside workspace")
	_drag_delta(model, "paper", Vector2(220, 0))
	_check(Model.TABLE.encloses(model.object_rect("paper")), "entire extracted page remains inside workspace")
	_check(Model.TABLE.encloses(model.object_rect("fold_0")) and Model.TABLE.encloses(model.object_rect("fold_1")), "both required fold controls remain reachable")
	_check(Model.TABLE.has_point(model.object_rect("fold_0").get_center() + Vector2(120, 0)), "complete first-fold pointer stroke remains inside work area")
	_check(Model.TABLE.has_point(model.object_rect("fold_1").get_center() + Vector2(0, 120)), "complete second-fold pointer stroke remains inside work area")
	_drag_origin(model, "paper", Vector2(1050, 500))
	_check(Model.TABLE.has_point(model.object_rect("fold_0").get_center() + Vector2(120, 0)) and Model.TABLE.has_point(model.object_rect("fold_1").get_center() + Vector2(0, 120)), "repositioning loose page also preserves complete gesture reachability")
	_drag_delta(model, "fold_0", Vector2(120, 0))
	_drag_delta(model, "fold_1", Vector2(0, 120))
	_check(model.export_state().body_unfolded, "maximum edge still permits complete unfold")
	var bad: Dictionary = model.export_state()
	bad.paper_position = [1000.0, 400.0]
	_check(model.restore_state(bad) == "paper_gestures_outside_workspace", "save with visible but unusable complete fold gesture is rejected")
	bad = model.export_state()
	bad.envelope_position = [760.0, 390.0]
	_check(model.restore_state(bad) == "inaccessible_opening_area", "old off-table open state rejected without overwriting valid live state")


func _unreleased_last_fold() -> void:
	completed.clear()
	var model = _new("case04")
	_open_to_folded_page(model)
	for cycle: int in range(2):
		_drag_delta(model, "fold_0", Vector2(120, 0))
		var grip: Vector2 = model.object_rect("fold_1").get_center()
		_ok(model.begin_drag("fold_1", grip), "last fold capture, cycle %d" % cycle)
		_ok(model.drag_to(grip + Vector2(0, 120)), "last fold reaches position before release")
		var count_before := completed.size()
		model.cancel_operation()
		_check(completed.size() == count_before, "cancel at final pose never commits completion")
		_check(not model.export_state().open_cycle_completed, "unreleased pose is separate from committed open cycle")
		model = _roundtrip(model, "last fold at endpoint but not released")
		_ok(model.begin_operation("open"), "resume last uncommitted fold, cycle %d" % cycle)
		_ok(model.begin_drag("fold_1", model.object_rect("fold_1").get_center()), "reacquire final fold at preserved pose")
		_ok(model.release_drag(), "explicit release commits preserved final pose")
		_check(completed.size() == count_before + 1 and completed.back().mode == "open", "resumed final release emits exactly once")
		_check(model.export_state().body_unfolded and model.export_state().open_cycle_completed, "historical read and current cycle now committed")
		if cycle == 0:
			_reseal_page(model)
			_open_to_folded_page(model)
			_check(model.export_state().body_unfolded and not model.export_state().open_cycle_completed, "reopening keeps historical reading but begins a new physical cycle")


func _open_to_folded_page(model) -> void:
	_ok(model.begin_operation("open"), "start a real opening cycle")
	_ok(model.select_tool("opener"), "pick up opener for cycle")
	for index: int in range(9): _ok(model.tool_contact(model.seam_point(index)), "cycle seam contact %d" % index)
	model.return_tool()
	_drag_delta(model, "paper", Vector2(220, 0))
	_check(not model.export_state().inserted, "extracted contents are no longer marked inserted")


func _reseal_page(model) -> void:
	_ok(model.begin_operation("reseal"), "start real reseal cycle")
	_drag_delta(model, "fold_0", Vector2(120, 0))
	_drag_delta(model, "fold_1", Vector2(0, 120))
	_drag_origin(model, "paper", model.object_rect("envelope").position + Vector2(420, 65))
	_drag_delta(model, "flap", Vector2(0, 90))
	_ok(model.select_tool("sealer"), "pick up final sealer")
	_ok(model.tool_contact(model.object_rect("flap").get_center()), "complete final physical seal")


func _continuous_seam_motion() -> void:
	var model = _new("case04")
	_ok(model.begin_operation("open"), "continuous stroke begins")
	_ok(model.select_tool("opener"), "continuous stroke tool")
	var origin: Vector2 = model.seam_point(0)
	for offset: int in range(0, 321, 5):
		if model.export_state().seam_count >= 9: break
		_ok(model.tool_contact(origin + Vector2(offset, 0)), "five-pixel continuous stroke sample %d" % offset)
	_check(model.export_state().seam_count == 9, "continuous ordered motion reaches open seam")
	_check(model.export_state().permanent_damage == 0.0 and is_equal_approx(float(model.export_state().tamper_trace), 0.25), "sampling density does not damage paper while pointer stays on worked seam")
	_check(not model.export_state().body_exposed, "smooth tool motion still does not expose inner contents")


func _unread_partial_return() -> void:
	completed.clear()
	var model = _new("case04")
	_ok(model.begin_operation("open"), "opening before unread return")
	_ok(model.select_tool("opener"), "pick tool before unread return")
	for index: int in range(9): _ok(model.tool_contact(model.seam_point(index)), "unread return seam %d" % index)
	model.return_tool()
	_drag_delta(model, "paper", Vector2(99, 0))
	model.cancel_operation()
	_ok(model.begin_operation("reseal"), "may choose to put a half-extracted unread page back")
	var pose_before: Vector2 = model.object_rect("paper").position
	_drag_delta(model, "paper", Vector2(0, 80))
	_check(model.object_rect("paper").position == pose_before and not model.export_state().extracted, "off-axis motion cannot free a page still caught in the mouth")
	model = _roundtrip(model, "off-axis partial return")
	_drag_delta(model, "paper", Vector2(-39, 0))
	_check(model.export_state().paper_location == "partly_inserted", "unread page is partly returned")
	model.cancel_operation()
	model = _roundtrip(model, "half return without body exposure")
	_ok(model.begin_operation("reseal"), "continue unread partial return")
	_drag_origin(model, "paper", model.object_rect("envelope").position + Vector2(420, 65))
	_drag_delta(model, "flap", Vector2(0, 90))
	_ok(model.select_tool("sealer"), "unread final sealing tool")
	_ok(model.tool_contact(model.object_rect("flap").get_center()), "unread final material seal")
	var state: Dictionary = model.export_state()
	_check(state.resealed and state.inserted and not state.extracted, "actual return can finish without ever extracting the whole page")
	_check(state.privacy_violation and not state.body_exposed and not state.body_unfolded, "material privacy breach is retained without inventing read knowledge")
	_check(completed.size() == 1 and completed[0].mode == "reseal", "unread reseal emits no opening/read completion")
	model = _roundtrip(model, "resealed unread private envelope")


func _unextracted_close() -> void:
	var model = _new("case04")
	_ok(model.begin_operation("open"), "open seam before changing mind")
	_ok(model.select_tool("opener"), "unextracted opening tool")
	for index: int in range(9): _ok(model.tool_contact(model.seam_point(index)), "unextracted seam %d" % index)
	model.return_tool()
	model.cancel_operation()
	_ok(model.begin_operation("reseal"), "may close a breached envelope without taking its contents out")
	_drag_delta(model, "flap", Vector2(0, 90))
	_ok(model.select_tool("sealer"), "seal original contents in place")
	_ok(model.tool_contact(model.object_rect("flap").get_center()), "unextracted final seal")
	_check(model.export_state().inserted and model.export_state().resealed and not model.export_state().extracted, "core receives accurate contents-inside summary without fabricated extraction")
	model = _roundtrip(model, "unextracted envelope resealed")
	_ok(model.begin_operation("open"), "reopen unread envelope")
	_ok(model.select_tool("opener"), "second unextracted opening tool")
	for index: int in range(9): _ok(model.tool_contact(model.seam_point(index)), "second unextracted seam %d" % index)
	model.return_tool()
	_drag_delta(model, "paper", Vector2.ZERO)
	_check(model.export_state().paper_location == "inside" and not model.export_state().body_exposed, "zero movement does not create a partial or exposed page")
	model = _roundtrip(model, "zero-motion paper grab after reopen")


func _opening_count_cycles() -> void:
	var model = _new("case04")
	_ok(model.begin_operation("open"), "counted cycle preparation")
	_ok(model.select_tool("opener"), "tool choice does not breach")
	_check(model.export_state().opened_count==0,"selecting opener consumes no opening")
	model.cancel_operation()
	_check(model.export_state().opened_count==0,"cancelling before contact consumes no opening")
	_ok(model.begin_operation("open"), "prepare after untouched cancellation")
	_ok(model.select_tool("opener"), "select before off-seam crease")
	_check(model.tool_contact(model.object_rect("envelope").get_center())=="visible_crease","off-seam damaging contact has its own feedback")
	_check(model.export_state().tampering_started and model.export_state().opened_count==0,"off-seam damage preserves privacy history but does not fake seal breach")
	for cycle: int in range(1,4):
		if cycle>1:
			_ok(model.begin_operation("open"),"begin another deliberately resealed cycle")
			_ok(model.select_tool("opener"),"select opener for repeated actual cycle")
		_ok(model.tool_contact(model.seam_point(0)),"first effective contact in cycle "+str(cycle))
		_check(model.export_state().opened_count==cycle,"same-envelope effective breach increments exactly once in cycle "+str(cycle))
		model.cancel_operation()
		model=_roundtrip(model,"breached cycle "+str(cycle)+" cancellation")
		_ok(model.begin_operation("open"),"resume partial breached cycle")
		_ok(model.select_tool("opener"),"resume tool after restored partial seam")
		_ok(model.tool_contact(model.seam_point(0)),"already-worked seam contact is neutral")
		_check(model.export_state().opened_count==cycle,"resuming already-breached seam does not charge again")
		for index: int in range(1,9):_ok(model.tool_contact(model.seam_point(index)),"finish counted seam segment")
		model.return_tool();model.cancel_operation()
		_ok(model.begin_operation("reseal"),"return breached but unread contents")
		_drag_delta(model,"flap",Vector2(0,90))
		_ok(model.select_tool("sealer"),"physically seal counted cycle")
		_ok(model.tool_contact(model.object_rect("flap").get_center()),"complete counted final seal")
		_check(model.export_state().opened_count==cycle and not model.export_state().body_exposed,"reseal retains count without inventing a read")
		model=_roundtrip(model,"counted reseal "+str(cycle))
	_check(is_equal_approx(float(model.export_state().tamper_trace),1.75),"each repeated breach retains its own material trace")
	var legacy: Dictionary=model.export_state()
	legacy.version=1;legacy.erase("opened_count")
	_check(not model.restore_state(legacy).is_empty(),"v1 cannot silently invent unknown historical reopening count")
	var invalid: Dictionary=model.export_state();invalid.opened_count=0
	_check(not model.restore_state(invalid).is_empty(),"opened history cannot be loaded with zero breaches")
	invalid=model.export_state();invalid.opened_count=1.5
	_check(not model.restore_state(invalid).is_empty(),"fractional opening count is rejected")
	invalid=model.export_state();invalid.opened_count=-1
	_check(not model.restore_state(invalid).is_empty(),"negative opening count is rejected")
	var staff = _new("case05")
	_ok(staff.begin_operation("open"),"legal staff opening begins")
	_ok(staff.select_tool("opener"),"legal staff tool")
	_ok(staff.tool_contact(staff.seam_point(0)),"staff effective breach")
	_check(staff.export_state().opened_count==1 and not staff.export_state().privacy_violation,"legal internal envelope still uses one physical opening")


func _validate_contract_ids() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	_check(fixture is Dictionary, "source design contract parses")
	if not fixture is Dictionary: return
	var ids: Array = []
	for scenario: Dictionary in fixture.scenarios: ids.append(scenario.id)
	for id: String in covered: _check(id in ids, "model coverage refers to actual contract ID " + id)

func _limited_amendments() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rebuild/player_amendments.json"))
	var model = _new("case02")
	_ok(model.configure_amendments(catalog.cases.case02),"bind one allowed sentence without importing source body")
	_check(not model.begin_operation("amend").is_empty(),"sealed body cannot be amended")
	_open_to_folded_page(model)
	_check(not model.begin_operation("amend").is_empty(),"extracted but folded body cannot be amended")
	_drag_delta(model,"fold_0",Vector2(120,0));_drag_delta(model,"fold_1",Vector2(0,120))
	var opening_count: int=model.export_state().opened_count
	_ok(model.begin_operation("amend"),"amend truly unfolded selected sentence")
	_check(not model.begin_drag("replacement",model.object_rect("replacement").get_center()).is_empty(),"replacement strip cannot skip erasing")
	_ok(model.select_tool("eraser"),"select actual eraser")
	var phrase: Rect2=model.object_rect("phrase")
	_check(model.tool_contact(phrase.position-Vector2(5,5))=="no_material_contact","eraser outside selected phrase has no authority")
	_ok(model.tool_contact(phrase.position+Vector2(8,12)),"rub first original phrase segment")
	var once: int=model.export_state().erase_mask
	_ok(model.tool_contact(phrase.position+Vector2(8,12)),"stationary eraser contact")
	_check(model.export_state().erase_mask==once and once!=255,"holding still cannot automatically erase the whole sentence")
	model.cancel_operation();model=_roundtrip(model,"partially erased original sentence")
	_ok(model.configure_amendments(catalog.cases.case02),"rebind safe permitted IDs after load")
	_ok(model.begin_operation("amend"),"resume unfinished erasure")
	_ok(model.select_tool("eraser"),"resume eraser")
	for index: int in range(1,8):_ok(model.tool_contact(phrase.position+Vector2((float(index)+0.5)*phrase.size.x/8,12)),"rub another actual phrase segment")
	_check(model.export_state().erase_mask==255 and model.export_state().replacement_id.is_empty(),"full physical erasure is a distinct confirmed blank state")
	_ok(model.begin_operation("amend"),"choose subsequent physical replacement")
	var source: Vector2=model.object_rect("replacement").position
	_drag_origin(model,"replacement",source+Vector2(30,-20))
	_check(not model.export_state().replacement_placed,"dropping replacement away from the selected sentence does not apply it")
	_drag_origin(model,"replacement",phrase.position)
	_check(model.export_state().replacement_placed and model.export_state().replacement_id=="case02_replace_request","only real aligned drop applies the allowed replacement ID")
	_check(model.export_state().opened_count==opening_count,"erasure and replacement consume no additional openings")
	_check(not model.export_state().has("original") and not model.export_state().has("body"),"object snapshot cannot overwrite the immutable source letter")
	model=_roundtrip(model,"physical replacement applied")
	_reseal_page(model)
	_check(model.export_state().replacement_placed and model.export_state().erase_mask==255,"refolding and sealing retain the edited material state")
	var photo = _new("case03")
	_open_to_folded_page(photo);_drag_delta(photo,"fold_0",Vector2(120,0));_drag_delta(photo,"fold_1",Vector2(0,120))
	_ok(photo.configure_amendments(catalog.cases.case03),"bind original attachment only")
	_ok(photo.begin_operation("amend"),"physically handle revealed original photograph")
	_check(not photo.select_tool("eraser").is_empty(),"attachment-only case has no arbitrary editable sentence")
	var slot: Vector2=photo.object_rect("attachment_slot").position
	_drag_origin(photo,"attachment",slot+Vector2(-28,0))
	_check(photo.export_state().attachment_location=="with_letter" and not photo.export_state().attachment_moved,"wrong photo drop keeps the original attached without a fabricated remove")
	var tray: Vector2=photo.object_rect("attachment_tray").position+Vector2(8,8)
	_drag_origin(photo,"attachment",tray)
	_check(photo.export_state().attachment_location=="desk" and photo.export_state().attachment_moved,"actual photo drop in table tray records independent custody")
	var trace: float=photo.export_state().tamper_trace
	photo.cancel_operation();photo=_roundtrip(photo,"photo outside letter on its own desk position")
	_ok(photo.begin_operation("amend"),"return same original photo")
	_drag_origin(photo,"attachment",slot)
	_check(photo.export_state().attachment_location=="with_letter" and photo.export_state().attachment_moved,"photo returns without erasing handling history")
	_check(photo.export_state().tamper_trace==trace and photo.export_state().opened_count==1,"photo return neither clears trace nor adds an opening")
	var legacy: Dictionary=photo.export_state()
	legacy.version=2
	for key: String in ["edit_key","erase_mask","replacement_id","replacement_position","replacement_placed","attachment_location","attachment_position","attachment_moved"]:legacy.erase(key)
	var restored = Model.new()
	_ok(restored.restore_state(legacy),"v2 physical snapshot upgrades only known empty amendment defaults")
	_check(restored.export_state().version==3 and restored.export_state().opened_count==1 and restored.export_state().attachment_location=="with_letter","known legacy photo baseline preserved without resetting actual opening count")
	legacy.erase_mask=1
	_check(not restored.restore_state(legacy).is_empty(),"legacy v2 cannot smuggle amendment fields into a known-empty migration")


func _ok(error: String, label: String) -> void:
	_check(error.is_empty(), label + (" (" + error + ")" if not error.is_empty() else ""))


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)
