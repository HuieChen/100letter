class_name FinalCaseState
extends Node
## Independent final-production state. No old GameSession, save or UI dependency.
signal changed
signal save_failed(message: String)

const CATALOG_PATH := "res://data/rebuild/final_cases.json"
const FORMAT := "solmere-final-production-state"
const SAVE_VERSION := 2
const PRE_TUTORIAL_RULES := "user-2026-10-01-openings-and-detection-v1"
const PRE_AMENDMENT_RULES := "user-2026-10-01-tutorial-and-openings-v2"
const PRE_RESOLUTION_RULES := "user-2026-10-01-tutorial-openings-amendments-v3"
const RULES_VERSION := "user-2026-10-01-postal-resolution-v4"
const AMENDMENTS_PATH := "res://data/rebuild/player_amendments.json"
const DIALOGUES_PATH := "res://data/rebuild/final_dialogues.json"
const AMENDMENT_FIELDS := ["edit_key", "erase_mask", "replacement_id", "replacement_placed", "attachment_location", "attachment_moved"]
const MAX_OPENINGS := 3
const DETECTION_FAILURE_THRESHOLD := 3
const LOWEST_REPUTATION := -3
const CATALOG_VERSION := "final-production-v1"
const PhysicalModel = preload("res://scripts/rebuild/mail_physics_state.gd")
const CASE_IDS := ["case01", "case02", "case03", "case04", "case05"]

var catalog: Dictionary = {}
var amendment_catalog: Dictionary = {}
var dialogue_catalog: Dictionary = {}
var state: Dictionary = {}
var save_path := "user://final_v2/progress.json"
var last_save_error := ""
var last_load_source := ""


func _ready() -> void:
	_load_catalog()
	if state.is_empty(): new_game()


func _load_catalog() -> void:
	if not catalog.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary and parsed.get("catalog_version") == CATALOG_VERSION:
		catalog = parsed
	if FileAccess.file_exists(AMENDMENTS_PATH):
		var additions: Variant = _parse_json(FileAccess.get_file_as_string(AMENDMENTS_PATH))
		if additions is Dictionary and additions.get("version") == 1 and additions.get("cases") is Dictionary and additions.get("consequences") is Dictionary:
			amendment_catalog = additions
	if FileAccess.file_exists(DIALOGUES_PATH):
		var dialogue_data: Variant = _parse_json(FileAccess.get_file_as_string(DIALOGUES_PATH))
		if dialogue_data is Dictionary and dialogue_data.get("version") == 1 and dialogue_data.get("people") is Dictionary:
			dialogue_catalog = dialogue_data


func new_game() -> void:
	_load_catalog()
	state = {"catalog_version": CATALOG_VERSION, "rules_version": RULES_VERSION,
		"tutorial_first_case_completed": false, "opening_history": [], "minute": int(catalog.calendar.start_minute),
		"location": "post_office", "cases": {}, "evidence": {}, "encounters": {},
		"known_names": [], "work_reliability": 0, "npc_trust": {},
		"privacy": {"violations": [], "discovered": []}, "time_events": [],
		"world_flags": {}, "journal": [], "archive_draft": {}, "severe_incidents": [],
		"active_operation": {}, "checkpoint": {}, "failure": {}, "ending": {}}
	for id: String in CASE_IDS:
		var model := PhysicalModel.new()
		model.setup(id)
		var physical: Dictionary = model.export_state()
		state.cases[id] = {"available": id == "case01",
			"owner": "desk_b" if id in ["case01", "case02", "case03"] else "archive_box",
			"physical": physical, "disposition": "", "note": "", "target": "", "late": false,
			"attempts": 0, "read_body": false, "feedback": "", "credited": false,
			"alterations": _initial_alterations(id), "resolution": {}}
	_refresh_time_events()
	changed.emit()


func case_data(id: String) -> Dictionary:
	# Authoring/rules access only. UI must use case_view/body_text/dossier_view.
	for item: Dictionary in catalog.get("cases", []):
		if item.id == id: return item.duplicate(true)
	return {}


func case_view(id: String) -> Dictionary:
	if not state.cases.has(id) or not state.cases[id].available: return {}
	var item: Dictionary = state.cases[id]
	var data := case_data(id)
	var view := {"id": id, "front": {}, "back": {}, "body": body_text(id), "attachment": ""}
	if item.physical.inspected_front:
		for key: String in ["recipient", "address", "return", "sender", "date", "service_mark", "counter_note", "status"]:
			if data.envelope.has(key): view.front[key] = data.envelope[key]
	if item.physical.inspected_back:
		for key: String in ["back", "archive_mark"]:
			if data.envelope.has(key): view.back[key] = data.envelope[key]
		if item.physical.exterior_repaired and data.envelope.has("recovered_fields"):
			view.back.recovered_fields = data.envelope.recovered_fields.duplicate(true)
	if item.read_body: view.attachment = data.get("attachment", "")
	if item.read_body:
		view.alterations = item.alterations.duplicate(true)
		if view.alterations.receipt.get("status") != "witnessed": view.alterations.receipt = {}
		view.attachment_included = item.alterations.attachment_included
	return view


func known_person_label(id: String) -> String:
	return str(catalog.people.get(id, "尚未确认身份")) if id in state.known_names else "尚未确认身份"


func dossier_view() -> Dictionary:
	var view := {"known_people": {}, "observations": [], "draft": state.archive_draft.duplicate(true), "confirmed": {}}
	for id: String in state.known_names: view.known_people[id] = catalog.people[id]
	for id: String in state.evidence:
		var fact: Dictionary = state.evidence[id].duplicate(true)
		fact.id = id
		fact.text = clue_data(id).text
		view.observations.append(fact)
	if state.ending.get("archive_context") == "recorded": view.confirmed = state.archive_draft.claims.duplicate(true)
	return view


func case_state(id: String) -> Dictionary:
	return state.cases.get(id, {}).duplicate(true)


func clue_data(id: String) -> Dictionary:
	for item: Dictionary in catalog.get("clues", []):
		if item.id == id: return item.duplicate(true)
	return {}


func _blocked() -> String:
	if not state.failure.is_empty(): return "请先从失败前的检查点恢复。"
	if not state.ending.is_empty(): return "本班次已经结束。"
	return ""


func take_case(id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.cases.has(id) or not state.cases[id].available: return "这件邮件尚未在工作中出现。"
	if not state.active_operation.is_empty(): return "先放下正在操作的物件。"
	var item: Dictionary = state.cases[id]
	if not str(item.disposition).is_empty(): return "这件邮件已有处置记录。"
	if item.owner not in ["desk_b", "archive_box", "ledger_sleeve", "courier"]: return "邮件不在你手中。"
	if item.owner != "courier" and state.location != "post_office": return "邮件仍保存在邮局，需到现场取件。"
	item.owner = "courier"
	changed.emit()
	return ""


func inspect_envelope(id: String, side: String) -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	if side not in ["front", "back"]: return "未知信封面。"
	state.cases[id].physical["inspected_" + side] = true
	if side == "front":
		var data := case_data(id)
		_learn_name(str(data.recipient_id))
		if not str(data.envelope.get("return", "")).is_empty(): _learn_name(str(data.sender_id))
		if id == "case05": _learn_name("helena_voss")
	changed.emit()
	return ""


func accept_inspection(id: String, snapshot: Dictionary) -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "已有物件操作，请通过完成或安全退出提交。"
	error = _validate_physical(id, snapshot)
	if not error.is_empty(): return error
	if not str(snapshot.operation_mode).is_empty(): return "纯观察不能携带活动工具模式。"
	# Replay only legitimate inspection operations from the trusted stored object.
	# Full-model comparison also protects dependent pose fields and all materials.
	var model := PhysicalModel.new()
	model.restore_state(state.cases[id].physical)
	for face: String in ["front", "back"]:
		if snapshot["inspected_" + face]: model.inspect_face(face)
	if snapshot["inspected_" + str(snapshot.face)]: model.inspect_face(str(snapshot.face))
	model.set_inspection(float(snapshot.zoom), Vector2(float(snapshot.pan[0]), float(snapshot.pan[1])))
	var position := Vector2(float(snapshot.envelope_position[0]), float(snapshot.envelope_position[1]))
	var current: Rect2 = model.object_rect("envelope")
	# Even a subpixel move from an older save must replay. Approximate equality
	# could skip that legitimate translation, then reject its dependent poses.
	if current.position != position or model.export_state().exterior_on_mat != snapshot.exterior_on_mat:
		if not model.begin_drag("envelope", current.get_center()).is_empty(): return "当前实物不能作为完整信封移动。"
		model.drag_to(current.get_center() + position - current.position)
		model.release_drag()
	var expected: Variant = _parse_json(JSON.stringify(model.export_state()))
	if expected != _parse_json(JSON.stringify(snapshot)): return "观察只能更改正反面、视野和完整信封位置，不能改变材料或阅读状态。"
	_accept_physical(id, snapshot)
	if snapshot.inspected_front: inspect_envelope(id, "front")
	changed.emit()
	return ""


func _learn_name(id: String) -> void:
	if catalog.people.has(id) and id not in state.known_names: state.known_names.append(id)


func _owned_error(id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.cases.has(id) or not state.cases[id].available: return "邮件尚未出现。"
	if state.cases[id].owner != "courier" or not str(state.cases[id].disposition).is_empty(): return "邮件已离开你的保管范围。"
	return ""


func observe(clue_id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	var data := clue_data(clue_id)
	if data.is_empty(): return "未知资料。"
	if not state.active_operation.is_empty(): return "先放下正在使用的工具。"
	if data.location != "" and data.location != state.location: return "需要到资料所在地点查看。"
	if data.knowledge_owner in catalog.people and (not state.encounters.has(data.knowledge_owner) or not npc_present(data.knowledge_owner, str(state.location))): return "这条信息需要在场向知情者询问。"
	if int(state.minute) < int(data.validity_time.available_after_minute): return "这条记录描述的事件尚未发生。"
	if clue_id == "label_reconstructed" and not state.cases.case03.physical.exterior_repaired: return "外部标签尚未修复到可读状态。"
	if clue_id == "case04_archive_mark" and (not state.cases.case04.available or not state.cases.case04.physical.inspected_back): return "需要实际查看旧件背面的标记。"
	if clue_id == "case04_manual_hold" and not state.cases.case04.available: return "尚未找到这件旧档案件。"
	if clue_id == "ledger_hv_repeat":
		if str(state.cases.case04.disposition).is_empty() or not (has_evidence("case04_archive_mark") or has_evidence("case04_manual_hold")):
			return "先处理旧件，并保留实际见过的 HV 标记记录。"
	if clue_id in ["helena_rota", "procedure_codes", "ledger_returns"] and not state.cases.case04.available:
		return "旧档案尚未进入这次工作。"
	if clue_id == "telescope_checkout" and int(state.minute) >= int(catalog.calendar.equipment_return_minute):
		return observe("telescope_returned")
	if not state.evidence.has(clue_id):
		state.evidence[clue_id] = {"source": data.source, "observed_minute": state.minute,
			"location": state.location, "public_or_private": data.public_or_private}
	for person: String in data.get("reveals_names", []): _learn_name(person)
	if clue_id == "ledger_hv_repeat" and not state.cases.case05.available:
		state.world_flags.repeated_hv_noticed = true
		state.cases.case05.available = true
		state.cases.case05.owner = "ledger_sleeve"
		_note("在已处理旧件的记录旁发现重复 HV；账本夹袋中的职员封现在可取。")
	changed.emit()
	return ""


func has_evidence(id: String) -> bool:
	return state.evidence.has(id)


func discover_archive_box() -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.tutorial_first_case_completed: return "先处理第一封邮件，再回邮局盖好处理单，才整理后续邮件。"
	if state.location != "post_office": return "档案清理箱在邮局。"
	if not has_evidence("june_current_mailpoint"): return "先通过现行资料找到 June 的合法收信点。"
	if not state.cases.case04.available:
		state.cases.case04.available = true
		state.world_flags.archive_box_introduced = true
		_note("整理 UNRESOLVED — DESK B 箱，发现寄给 June 的六年前旧件。")
	changed.emit()
	return ""


func meet(npc_id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not npc_present(npc_id, str(state.location)): return "对方不在此处。"
	if not state.encounters.has(npc_id): state.encounters[npc_id] = {"minute": state.minute, "location": state.location}
	_learn_name(npc_id)
	changed.emit()
	return ""


func npc_present(id: String, location: String) -> bool:
	match id:
		"mira_vale": return location == "lookout" and not bool(state.world_flags.get("mira_departed", false))
		"june_arlen": return location in ["community_center", "lookout"]
		"elsie_moran": return location == "residential"
		"chenyuan": return location in ["bus_stop", "chess_stall"]
		"community_clerk": return location == "community_center"
	return false


func dialogue_greeting(npc_id: String) -> String:
	if not _dialogue_access(npc_id).is_empty(): return ""
	return str(dialogue_catalog.get("people", {}).get(npc_id, {}).get("greeting", "你好。"))


func dialogue_topics(npc_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _dialogue_access(npc_id).is_empty(): return result
	for topic: Dictionary in dialogue_catalog.get("people", {}).get(npc_id, {}).get("topics", []):
		if _dialogue_topic_available(topic, npc_id):
			# Merely displaying a question must not reveal a reply or add evidence.
			result.append({"id": str(topic.id), "label": str(topic.label), "question": str(topic.question)})
	return result


func speak(npc_id: String, topic_id: String) -> Dictionary:
	var error := _dialogue_access(npc_id)
	if not error.is_empty(): return {"error": error, "answer": "", "evidence": []}
	for topic: Dictionary in dialogue_catalog.get("people", {}).get(npc_id, {}).get("topics", []):
		if topic.id != topic_id: continue
		if not _dialogue_topic_available(topic, npc_id): return {"error": "当前尚无这段提问所依据的实际资料。", "answer": "", "evidence": []}
		var learned: Array[String] = []
		for clue_id: String in topic.get("evidence", []):
			var clue := clue_data(clue_id)
			if clue.get("knowledge_owner") != npc_id: return {"error": "这段答话不能替代另一份实物资料。", "answer": "", "evidence": []}
			var failure := observe(clue_id)
			if not failure.is_empty(): return {"error": failure, "answer": "", "evidence": []}
			learned.append(clue_id)
		return {"error": "", "answer": str(topic.answer), "evidence": learned}
	return {"error": "没有这项现场话题。", "answer": "", "evidence": []}


func _dialogue_access(npc_id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先安全收好正在使用的物件。"
	if not state.encounters.has(npc_id) or not npc_present(npc_id, str(state.location)): return "需要先在现场和对方打招呼。"
	return ""


func _dialogue_topic_available(topic: Dictionary, npc_id: String) -> bool:
	if topic.has("locations") and state.location not in topic.locations: return false
	if topic.has("case_available") and not state.cases.get(topic.case_available, {}).get("available", false): return false
	if topic.has("case_front") and not state.cases.get(topic.case_front, {}).get("physical", {}).get("inspected_front", false): return false
	if topic.has("any_front") and not topic.any_front.any(func(id: String) -> bool: return state.cases.get(id, {}).get("physical", {}).get("inspected_front", false)): return false
	for clue_id: String in topic.get("requires", []):
		if not has_evidence(clue_id): return false
	if topic.has("any_evidence") and not topic.any_evidence.any(func(id: String) -> bool: return has_evidence(id)): return false
	if topic.has("received_case"):
		var item: Dictionary = state.cases.get(topic.received_case, {})
		if item.get("owner") != npc_id or item.get("disposition") not in ["deliver", "delegate"]: return false
	return true


func travel(destination: String, previewed_minutes: int) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先结束或安全退出物件操作。"
	if destination not in catalog.locations: return "未知地点。"
	if float(previewed_minutes) not in catalog.policy.travel_costs: return "路线必须明确为 15 或 30 分钟。"
	if destination == state.location: return "已经在这里。"
	state.location = destination
	state.minute = int(state.minute) + previewed_minutes
	_refresh_time_events()
	changed.emit()
	if not state.failure.is_empty(): save_game()
	return ""


func perform_time_event(kind: String, unique_id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "物件操作尚未安全退出。"
	var costs := {"long_help": 30, "kitchen_help": 30, "records_retrieval": 15}
	if not costs.has(kind) or unique_id.strip_edges().is_empty(): return "未知事件或缺少稳定事件编号。"
	if unique_id in state.time_events: return "这件帮助或检索已经完成，不能重复扣时。"
	state.time_events.append(unique_id)
	state.minute = int(state.minute) + int(costs[kind])
	_refresh_time_events()
	changed.emit()
	if not state.failure.is_empty(): save_game()
	return ""


func _refresh_time_events() -> void:
	state.world_flags.equipment_returned = int(state.minute) >= int(catalog.calendar.equipment_return_minute)
	state.world_flags.mira_departed = int(state.minute) >= int(catalog.calendar.mira_departure_minute)
	var pending: Dictionary = state.world_flags.get("delegated_delivery", {})
	if not pending.is_empty() and not pending.get("arrived", false) and int(state.minute) >= int(pending.arrival_minute):
		pending.arrived = true
		state.cases.case02.owner = "mira_vale"
		_check_detection("case02")
		_note("登记接力的到达时刻已过，尘缘的交付回执现已归入记录。")
		if not state.failure.is_empty():
			state.checkpoint = {"label": "恢复交给尘缘前的检查点；其后至回执到达的行动一并撤回",
				"snapshot": pending.pre_handoff.duplicate(true)}


func equipment_record() -> Dictionary:
	return clue_data("telescope_returned" if state.world_flags.equipment_returned else "telescope_checkout")


func remaining_openings() -> int:
	return maxi(0, MAX_OPENINGS - state.opening_history.size())


func can_open(id: String) -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	var physical: Dictionary = state.cases[id].physical
	# An already broken current seal may still be extracted/read/repacked at the cap.
	var continuing: bool = physical.opened and not physical.resealed and physical.seal_condition in ["loosened", "open", "closed_unsealed"]
	if not continuing and remaining_openings() == 0: return "本班次已开封三次。其余邮件请通过外部资料与合法处置完成。"
	return ""


func accept_opening_breach(id: String, snapshot: Dictionary) -> String:
	if state.active_operation.get("case_id") != id or state.active_operation.get("mode") != "open": return "没有对应的开封操作。"
	var error := _validate_physical(id, snapshot)
	if not error.is_empty(): return error
	if int(snapshot.opened_count) == int(state.cases[id].physical.opened_count): return ""
	_accept_physical(id, snapshot)
	changed.emit()
	return ""


func begin_operation(id: String, mode: String) -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "已有一项物件操作。"
	if mode not in ["repair_exterior", "open", "reseal", "amend"]: return "未知操作。"
	if mode == "amend":
		error = _amendment_access(id)
		if not error.is_empty(): return error
	if mode == "open":
		error = can_open(id)
		if not error.is_empty(): return error
	if mode == "repair_exterior" and id != "case03": return "此件不是获准的外部损坏修复。"
	if mode == "reseal" and not state.cases[id].physical.opened: return "尚未打开，无需封回。"
	var model := PhysicalModel.new()
	if not model.restore_state(state.cases[id].physical).is_empty() or not model.begin_operation(mode).is_empty(): return "当前实物阶段不能直接进入此项操作。"
	_set_checkpoint("恢复本次物件操作前的状态")
	state.active_operation = {"case_id": id, "mode": mode}
	changed.emit()
	return ""


func finish_operation(id: String, snapshot: Dictionary) -> String:
	if state.active_operation.get("case_id") != id: return "没有对应的活动操作。"
	var mode := str(state.active_operation.mode)
	var error := _validate_physical(id, snapshot)
	if not error.is_empty(): return error
	if mode == "repair_exterior" and not snapshot.exterior_repaired: return "标签外修尚未完成。"
	if mode == "open" and not (snapshot.extracted and snapshot.body_exposed and snapshot.body_unfolded): return "内页尚未实际抽出并展开。"
	if mode == "reseal" and not snapshot.resealed: return "内页尚未折回、装回并封合。"
	if mode == "amend" and _derived_changes(id, snapshot) == _derived_changes(id, state.cases[id].physical): return "尚未完成指定句子的擦除、替换或附件放置。"
	_accept_physical(id, snapshot)
	state.active_operation = {}
	changed.emit()
	return ""


func cancel_operation(snapshot: Dictionary) -> String:
	if state.active_operation.is_empty(): return "没有活动操作。"
	var id := str(state.active_operation.case_id)
	var error := _validate_physical(id, snapshot)
	if not error.is_empty(): return error
	# Safe cancellation keeps already committed material changes and knowledge.
	_accept_physical(id, snapshot)
	state.active_operation = {}
	changed.emit()
	return ""


func _validate_physical(id: String, snapshot: Dictionary) -> String:
	var model := PhysicalModel.new()
	if snapshot.get("version") != PhysicalModel.VERSION: return "请先加载当前版本的实物快照。"
	if not model.restore_state(snapshot).is_empty(): return "实物阶段快照不合法。"
	if snapshot.case_id != id: return "物件快照归属不符。"
	if str(snapshot.operation_mode) not in ["", str(state.active_operation.get("mode", ""))]: return "实物工具模式与当前核心操作不符。"
	var old: Dictionary = state.cases[id].physical
	for key: String in AMENDMENT_FIELDS:
		if old.get(key) != snapshot.get(key) and state.active_operation.get("mode") != "amend": return "正文与附件变化只能来自指定的实物修改操作。"
	if not _valid_amendment_material(id, snapshot): return "实物修改不是本信允许的关键句或附件。"
	if state.active_operation.get("mode") == "amend":
		if not _amendment_access(id, true).is_empty(): return "当前不具备修改内页的权限或物态。"
		if snapshot.paper_location != "desk" or float(snapshot.fold_progress[0]) < 1.0 or float(snapshot.fold_progress[1]) < 1.0: return "修改操作中内页必须保持实际完整展开。"
		if (int(snapshot.erase_mask) | int(old.erase_mask)) != int(snapshot.erase_mask): return "擦除痕迹不能通过取消或换工具倒退。"
		if not str(old.edit_key).is_empty() and snapshot.edit_key != old.edit_key: return "不能更换已经擦过的关键句。"
		if old.replacement_placed and (not snapshot.replacement_placed or snapshot.replacement_id != old.replacement_id): return "已粘贴的替换条不能恢复为原稿。"
		if old.attachment_moved and not snapshot.attachment_moved: return "附件取出历史不能倒退。"
		var mutable := AMENDMENT_FIELDS + ["replacement_position", "attachment_position", "operation_mode", "completion_serial", "tamper_trace", "paper_position", "envelope_position", "face", "zoom", "pan", "inspected_front", "inspected_back", "exterior_on_mat"]
		for key: String in old:
			if key not in mutable and snapshot[key] != old[key]: return "修改内页不能改变其他材料、封合或阅读状态。"
		var added_trace := 0.0
		if int(old.erase_mask) == 0 and int(snapshot.erase_mask) != 0: added_trace += 0.25
		if not old.replacement_placed and snapshot.replacement_placed: added_trace += 0.25
		if not old.attachment_moved and snapshot.attachment_moved: added_trace += 0.25
		if not is_equal_approx(float(snapshot.tamper_trace), float(old.tamper_trace) + added_trace): return "修改痕迹与实际擦除、粘贴或取出历史不符。"
	var opening_delta := int(snapshot.opened_count) - int(old.opened_count)
	if opening_delta < 0 or opening_delta > 1: return "开封历史次数不能倒退或跳过实际破口。"
	if opening_delta == 1:
		if state.active_operation.get("mode") != "open" or state.active_operation.get("case_id") != id: return "新增破口必须来自当前开封操作。"
		if remaining_openings() == 0: return "本班次已达到三次实际开封上限。"
	for key: String in ["opened", "body_unfolded", "body_exposed", "extracted", "privacy_violation", "irreversible_damage", "tampering_started", "exterior_repaired", "inspected_front", "inspected_back"]:
		if old.get(key, false) and not snapshot[key]: return "不能抹除已发生的物态或知情历史。"
	if float(snapshot.tamper_trace) < float(old.tamper_trace): return "不能通过退出抹去历史拆痕。"
	if state.active_operation.get("mode") == "repair_exterior":
		for key: String in ["opened", "body_exposed", "extracted", "body_unfolded"]:
			if snapshot[key] and not old.get(key, false): return "外部修复不授权打开或阅读私人内页。"
	return ""


func _accept_physical(id: String, snapshot: Dictionary) -> void:
	var previous_count := int(state.cases[id].physical.opened_count)
	if int(snapshot.opened_count) > previous_count:
		state.opening_history.append({"serial": state.opening_history.size() + 1,
			"case_id": id, "ordinal": int(snapshot.opened_count), "minute": state.minute})
	state.cases[id].physical = snapshot.duplicate(true)
	state.cases[id].physical.operation_mode = ""
	_sync_alterations(id)
	if snapshot.privacy_violation and id not in state.privacy.violations:
		state.privacy.violations.append(id)
		_note("私人件已发生未经授权的纸面干预：" + id)
	if snapshot.body_exposed and snapshot.body_unfolded and snapshot.extracted:
		state.cases[id].read_body = true
		_learn_name(str(case_data(id).sender_id))
		if id == "case04": _learn_name("mira_vale")
		if id == "case05": _learn_name("helena_voss")


func body_text(id: String) -> String:
	if not state.cases.has(id) or not state.cases[id].read_body: return ""
	var text := str(case_data(id).body)
	var change: Dictionary = state.cases[id].alterations.confirmed
	if not change.is_empty():
		var slot := _amendment_slot(id, str(change.edit_key))
		var option := _amendment_option(id, str(change.edit_key), str(change.option_id))
		if not slot.is_empty() and not option.is_empty(): text = text.replace(str(slot.original), str(option.text))
	return text


func source_body_text(id: String) -> String:
	return str(case_data(id).body) if state.cases.has(id) and state.cases[id].read_body else ""


func amendment_options(id: String) -> Dictionary:
	if not _amendment_access(id, true).is_empty(): return {}
	var result := {"slots": [], "attachment": {}}
	var spec: Dictionary = amendment_catalog.get("cases", {}).get(id, {})
	for slot: Dictionary in spec.get("slots", []):
		var visible := {"id": slot.id, "original": slot.original, "options": []}
		for option: Dictionary in slot.get("options", []):
			visible.options.append({"id": option.id, "label": option.label, "operation": option.operation, "text": option.text, "meaning_preview": option.get("meaning_preview", "")})
		result.slots.append(visible)
	var attachment: Dictionary = spec.get("attachment", {})
	if not attachment.is_empty(): result.attachment = {"id": attachment.id, "label": attachment.label}
	return result


func _amendment_access(id: String, allow_active: bool = false) -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	if not state.active_operation.is_empty() and not (allow_active and state.active_operation.get("case_id") == id and state.active_operation.get("mode") == "amend"): return "先收好其他正在使用的工具。"
	var item: Dictionary = state.cases[id]
	var physical: Dictionary = item.physical
	if not item.read_body or not physical.opened or physical.resealed or physical.paper_location != "desk" or float(physical.fold_progress[0]) < 1.0 or float(physical.fold_progress[1]) < 1.0:
		return "先实际拆开、取出并完整展开仍由你保管的内页。"
	var spec: Dictionary = amendment_catalog.get("cases", {}).get(id, {})
	if spec.is_empty() or (spec.get("slots", []).is_empty() and spec.get("attachment", {}).is_empty()): return "这封信没有获准实现的关键句或可取放附件。"
	return ""


func _amendment_slot(id: String, key: String) -> Dictionary:
	var source := str(case_data(id).get("body", ""))
	for slot: Dictionary in amendment_catalog.get("cases", {}).get(id, {}).get("slots", []):
		if slot.get("id") == key and slot.get("original") is String and not str(slot.original).is_empty() and source.count(str(slot.original)) == 1: return slot
	return {}


func _amendment_option(id: String, key: String, option_id: String) -> Dictionary:
	var slot := _amendment_slot(id, key)
	for option: Dictionary in slot.get("options", []):
		if option.get("id") != option_id or option.get("operation") not in ["erase", "replace"] or not option.get("text") is String: continue
		if (option.operation == "erase") != str(option.text).is_empty(): continue
		if not amendment_catalog.get("consequences", {}).has(option.get("consequence_id")): continue
		return option
	return {}


func _derived_changes(id: String, physical: Dictionary) -> Dictionary:
	var confirmed := {}
	var key := str(physical.get("edit_key", ""))
	if int(physical.get("erase_mask", 0)) == 255:
		if physical.get("replacement_placed", false): confirmed = {"edit_key": key, "option_id": str(physical.get("replacement_id", ""))}
		else:
			for option: Dictionary in _amendment_slot(id, key).get("options", []):
				if option.get("operation") == "erase": confirmed = {"edit_key": key, "option_id": str(option.id)}; break
	return {"confirmed": confirmed, "attachment_included": physical.get("attachment_location", "none") == "with_letter"}


func _initial_alterations(id: String) -> Dictionary:
	return {"original_body_sha256": str(case_data(id).body).sha256_text(), "confirmed": {},
		"attachment_included": not str(case_data(id).get("attachment", "")).is_empty(), "history": [], "receipt": {}}


func _sync_alterations(id: String) -> void:
	var item: Dictionary = state.cases[id]
	var next := _derived_changes(id, item.physical)
	var changes: Dictionary = item.alterations
	if changes.confirmed == next.confirmed and changes.attachment_included == next.attachment_included: return
	changes.confirmed = next.confirmed.duplicate(true)
	changes.attachment_included = next.attachment_included
	changes.history.append({"serial": changes.history.size() + 1, "minute": state.minute,
		"confirmed": next.confirmed.duplicate(true), "attachment_included": next.attachment_included})


func _valid_amendment_material(id: String, physical: Dictionary) -> bool:
	var key := str(physical.get("edit_key", ""))
	var mask := int(physical.get("erase_mask", 0))
	var replacement := str(physical.get("replacement_id", ""))
	if not key.is_empty() and _amendment_slot(id, key).is_empty(): return false
	if mask != 0 and key.is_empty(): return false
	if not replacement.is_empty():
		var option := _amendment_option(id, key, replacement)
		if option.is_empty() or option.operation != "replace": return false
	var has_attachment := not str(case_data(id).get("attachment", "")).is_empty()
	var location := str(physical.get("attachment_location", "none"))
	if has_attachment:
		if location not in ["with_letter", "desk"]: return false
	else:
		if location != "none": return false
	var minimum_trace := float(physical.permanent_damage) + float(physical.opened_count) * 0.25
	if mask > 0: minimum_trace += 0.25
	if physical.replacement_placed: minimum_trace += 0.25
	if physical.attachment_moved: minimum_trace += 0.25
	if float(physical.tamper_trace) + 0.00001 < minimum_trace: return false
	return true


func _consequence_ids(id: String, changes: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if not changes.confirmed.is_empty():
		var option := _amendment_option(id, str(changes.confirmed.edit_key), str(changes.confirmed.option_id))
		if not option.is_empty(): ids.append(str(option.consequence_id))
	var attachment: Dictionary = amendment_catalog.get("cases", {}).get(id, {}).get("attachment", {})
	if not attachment.is_empty():
		var key := "returned_consequence_id" if changes.attachment_included else "removed_consequence_id"
		if amendment_catalog.get("consequences", {}).has(attachment.get(key)): ids.append(str(attachment[key]))
	return ids


func _record_alteration_receipt(id: String) -> void:
	var changes: Dictionary = state.cases[id].alterations
	if not changes.receipt.is_empty(): return
	var effects := _consequence_ids(id, changes)
	if effects.is_empty(): return
	changes.receipt = {"status": "pending", "recipient_id": str(case_data(id).recipient_id),
		"consequence_ids": effects, "received_minute": state.minute, "feedback": ""}


func witness_recipient_reading(id: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先收好正在操作的物件。"
	if not state.cases.has(id): return "没有对应的邮件。"
	var receipt: Dictionary = state.cases[id].alterations.receipt
	if receipt.is_empty(): return "还没有这封邮件的实际收件记录。"
	var recipient := str(receipt.recipient_id)
	if not state.encounters.has(recipient) or not npc_present(recipient, str(state.location)): return "需要在场与实际收件人交谈，才能看到阅读后的回应。"
	if receipt.status == "witnessed": return ""
	receipt.status = "witnessed"
	receipt.witnessed_minute = state.minute
	receipt.witnessed_location = state.location
	receipt.feedback = _reading_feedback(id, receipt.consequence_ids, id in state.privacy.discovered)
	_note("在场看到了收件人对实际收到版本的回应：" + id)
	changed.emit()
	save_game()
	return ""


func recipient_feedback(id: String) -> String:
	if not state.cases.has(id): return ""
	var receipt: Dictionary = state.cases[id].alterations.receipt
	return str(receipt.get("feedback", "")) if receipt.get("status") == "witnessed" else ""


func pending_recipient_readings(person_id: String) -> Array[String]:
	var result: Array[String] = []
	if not _blocked().is_empty() or not state.active_operation.is_empty(): return result
	if not state.encounters.has(person_id) or not npc_present(person_id, str(state.location)): return result
	for id: String in CASE_IDS:
		var receipt: Dictionary = state.cases[id].alterations.receipt
		if receipt.get("status") == "pending" and receipt.get("recipient_id") == person_id: result.append(id)
	return result


func _reading_feedback(_id: String, ids: Array, detected: bool) -> String:
	if detected: return str(amendment_catalog.get("detection", {}).get("generic_feedback", "对方发现了可见的纸面处理痕迹。"))
	var parts: Array[String] = []
	for consequence_id: String in ids:
		var definition: Dictionary = amendment_catalog.get("consequences", {}).get(consequence_id, {})
		if not str(definition.get("feedback", "")).is_empty(): parts.append(str(definition.feedback))
	return "\n".join(parts)


func _valid_confirmed_change(id: String, change: Variant) -> bool:
	if not change is Dictionary: return false
	if change.is_empty(): return true
	return change.size() == 2 and change.get("edit_key") is String and change.get("option_id") is String and not _amendment_option(id, change.edit_key, change.option_id).is_empty()


func _valid_alterations(id: String, item: Dictionary, value: Dictionary) -> bool:
	var changes: Variant = item.get("alterations")
	if not changes is Dictionary or changes.size() != 5: return false
	if changes.get("original_body_sha256") != str(case_data(id).body).sha256_text(): return false
	if not _valid_confirmed_change(id, changes.get("confirmed")) or not changes.get("attachment_included") is bool: return false
	if not changes.get("history") is Array or not changes.get("receipt") is Dictionary: return false
	if not _valid_amendment_material(id, item.physical): return false
	var current := _derived_changes(id, item.physical)
	if changes.confirmed != current.confirmed or changes.attachment_included != current.attachment_included: return false
	var previous := _initial_alterations(id)
	var prior_minute := 0
	var photo_was_removed := false
	for index: int in changes.history.size():
		var event: Variant = changes.history[index]
		if not event is Dictionary or event.size() != 4 or not _integer(event.get("serial")) or int(event.serial) != index + 1: return false
		if not _integer(event.get("minute")) or int(event.minute) < prior_minute or int(event.minute) > int(value.minute): return false
		if not _valid_confirmed_change(id, event.get("confirmed")) or not event.get("attachment_included") is bool: return false
		if str(case_data(id).get("attachment", "")).is_empty() and event.attachment_included: return false
		if not str(case_data(id).get("attachment", "")).is_empty() and not event.attachment_included: photo_was_removed = true
		if event.confirmed == previous.confirmed and event.attachment_included == previous.attachment_included: return false
		if event.confirmed != previous.confirmed:
			if event.confirmed.is_empty(): return false
			var option := _amendment_option(id, event.confirmed.edit_key, event.confirmed.option_id)
			if previous.confirmed.is_empty():
				# Full erase is a completed physical action before a replacement can fit.
				if option.operation != "erase": return false
			else:
				var former := _amendment_option(id, previous.confirmed.edit_key, previous.confirmed.option_id)
				if former.operation != "erase" or option.operation != "replace" or previous.confirmed.edit_key != event.confirmed.edit_key: return false
		prior_minute = int(event.minute)
		previous = event
	if previous.confirmed != changes.confirmed or previous.attachment_included != changes.attachment_included: return false
	if bool(item.physical.attachment_moved) != photo_was_removed: return false
	if not changes.history.is_empty() and not item.read_body: return false
	var receipt: Dictionary = changes.receipt
	if receipt.is_empty():
		var actually_received: bool = item.disposition in ["deliver", "forward"] or (item.disposition == "delegate" and item.owner == case_data(id).recipient_id)
		return changes.history.is_empty() or not actually_received # Old v2 had no alterations or reading record.
	if item.disposition not in ["deliver", "forward", "delegate"]: return false
	if item.disposition == "delegate" and item.owner != case_data(id).recipient_id: return false
	if receipt.get("status") not in ["pending", "witnessed"] or receipt.get("recipient_id") != case_data(id).recipient_id: return false
	if not receipt.get("consequence_ids") is Array or receipt.consequence_ids.is_empty() or receipt.consequence_ids != _consequence_ids(id, changes): return false
	if not _integer(receipt.get("received_minute")) or int(receipt.received_minute) < prior_minute or int(receipt.received_minute) > int(value.minute): return false
	if receipt.status == "pending": return receipt.size() == 5 and receipt.get("feedback") == ""
	if receipt.size() != 7 or not _integer(receipt.get("witnessed_minute")) or int(receipt.witnessed_minute) < int(receipt.received_minute) or int(receipt.witnessed_minute) > int(value.minute): return false
	if not value.encounters.has(receipt.recipient_id): return false
	if receipt.recipient_id == "mira_vale":
		if receipt.get("witnessed_location") != "lookout" or int(receipt.witnessed_minute) >= int(catalog.calendar.mira_departure_minute): return false
	elif receipt.recipient_id == "june_arlen":
		if receipt.get("witnessed_location") not in ["community_center", "lookout"]: return false
	else: return false
	return receipt.get("feedback") == _reading_feedback(id, receipt.consequence_ids, id in value.privacy.discovered)


func agree_handoff(arrival_minute: int, route_confirmed: bool, no_signature_required: bool) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not has_evidence("trusted_handoff_rule") or not state.encounters.has("chenyuan") or not npc_present("chenyuan", str(state.location)):
		return "需当面与尘缘确认，并查明本服务允许登记接力。"
	if not route_confirmed or not no_signature_required: return "顺路及无需签收的条件尚未成立。"
	if arrival_minute <= int(state.minute) or arrival_minute >= int(catalog.calendar.mira_departure_minute): return "约定到达必须晚于现在，并赶在 Mira 离场前。"
	state.world_flags.handoff = {"carrier": "chenyuan", "arrival_minute": arrival_minute, "agreed": true}
	changed.emit()
	return ""


func can_dispose(id: String, action: String, target: String = "", note: String = "") -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先结束或安全退出物件操作。"
	var data := case_data(id)
	if action not in data.legal_dispositions: return "本案没有这项专业处置。"
	if action in ["hold_for_verification", "unresolved_with_note", "archive_review"] and note.strip_edges().is_empty(): return "请记录具体未决原因或复核依据。"
	if action in ["return_to_sender", "hold_for_verification", "unresolved_with_note", "archive_review", "file_officially", "keep_at_desk", "supervisor_next_shift"] and state.location != "post_office": return "此项登记与存放在邮局办理。"
	if action in ["deliver", "forward", "repair_and_reenter", "delegate"]:
		if target.strip_edges().is_empty(): return "尚未选择实际交接对象或批准收信点。"
		if state.cases[id].physical.opened and not state.cases[id].physical.resealed: return "先把打开的邮件装回并封合。"
	if action == "return_to_sender" and state.cases[id].physical.opened and not state.cases[id].physical.resealed: return "退回邮路前仍需装回并封合。"
	if id == "case01" and action == "deliver":
		if state.location != "residential": return "需要到住宅现场。"
		if not has_evidence("elsie_confirmation") and not (has_evidence("street_renaming") and has_evidence("moran_entry")): return "尚未核实旧街名与 Elsie 的现址。"
	if id == "case02":
		if action == "deliver" and state.location != "lookout": return "需要到观景台实际寻找 Mira。"
		if action == "delegate":
			var agreement: Dictionary = state.world_flags.get("handoff", {})
			if not agreement.get("agreed", false) or not npc_present("chenyuan", str(state.location)) or target != "chenyuan": return "尚未在场达成合规的委托约定。"
			if int(agreement.arrival_minute) <= int(state.minute) or int(agreement.arrival_minute) >= int(catalog.calendar.mira_departure_minute): return "原到达约定已失效，请重新确认。"
	if id == "case03" and action in ["forward", "repair_and_reenter"]:
		if not state.cases[id].physical.exterior_repaired or not has_evidence("label_reconstructed"): return "尚未完成并查看外部标签重建。"
		if not has_evidence("june_current_mailpoint"): return "尚未核实 June 当前批准的收信点。"
		if not has_evidence("current_3c_resident") and not has_evidence("chenyuan_june_history"): return "还需确认旧地址已经不再是 June 的收信处。"
		if state.location != "community_center" and not (action == "repair_and_reenter" and state.location == "post_office"): return "在社区收信格或邮局当地转递流程办理。"
	if id == "case04" and action == "deliver" and state.location not in ["community_center", "lookout"]: return "需要到 June 的合法收信点或当面交付。"
	return ""


func dispose(id: String, action: String, target: String = "", note: String = "") -> String:
	var error := can_dispose(id, action, target, note)
	if not error.is_empty(): return error
	var item: Dictionary = state.cases[id]
	if action in ["deliver", "forward", "repair_and_reenter"]:
		var expected := "community_center_cubby" if id == "case03" else str(case_data(id).recipient_id)
		if target != expected:
			item.attempts = int(item.attempts) + 1
			state.work_reliability = int(state.work_reliability) - 1
			_note("交接对象／去向不符，邮件仍在邮袋，可更正。")
			changed.emit()
			return "这次交接未成立；请重新核对，邮件仍由你保管。"
	if id == "case02" and action == "deliver" and state.world_flags.mira_departed:
		item.late = true
		item.feedback = "Mira 已在 17:30 离场。邮件仍在邮袋，请回邮局记录正当未送说明。"
		changed.emit()
		return item.feedback
	_set_checkpoint("恢复本次处置前的状态")
	item.disposition = action
	item.target = target
	item.note = note.strip_edges()
	match action:
		"deliver", "forward": item.owner = target
		"delegate":
			item.owner = "chenyuan"
			state.world_flags.case02_personal_foreshadow = false
			state.world_flags.delegated_delivery = {"arrival_minute": state.world_flags.handoff.arrival_minute, "arrived": false,
				"pre_handoff": state.checkpoint.snapshot.duplicate(true)}
		"return_to_sender": item.owner = "return_mailstream"
		"repair_and_reenter": item.owner = "local_mailstream"
		"archive_review", "file_officially": item.owner = "official_archive"
		"supervisor_next_shift": item.owner = "supervisor_inbox"
		_: item.owner = "desk_b"
	if id == "case02" and action == "deliver": state.world_flags.case02_personal_foreshadow = true
	if not item.credited:
		state.work_reliability = int(state.work_reliability) + 1
		item.credited = true
	if action in ["deliver", "forward"]: _check_detection(id)
	item.feedback = "已按记录处理；未决原因和保管位置一并保留。" if action in ["hold_for_verification", "unresolved_with_note", "archive_review"] else "物件去向已记录。"
	if item.late: item.feedback = "Mira 已离场，邮件未送达；已留下正当未送说明。"
	if id == "case04": item.feedback = "旧件去向已登记。对关系的影响不会由这条工作回执评判。"
	_note(id + " → " + action)
	changed.emit()
	save_game()
	return ""


func _check_detection(id: String) -> void:
	var item: Dictionary = state.cases[id]
	_record_alteration_receipt(id)
	if not item.physical.privacy_violation or id in state.privacy.discovered: return
	var threshold: float = float(catalog.policy.careful_trace_threshold if case_data(id).recipient_attention == "careful" else catalog.policy.casual_trace_threshold)
	if float(item.physical.tamper_trace) >= threshold:
		state.privacy.discovered.append(id)
		state.work_reliability = int(state.work_reliability) - 2
		var person := str(case_data(id).recipient_id)
		state.npc_trust[person] = int(state.npc_trust.get(person, 0)) - 1
		_note("收件时拆痕被察觉；职业记录与该人物信任分别更新。")
		if state.privacy.discovered.size() >= DETECTION_FAILURE_THRESHOLD:
			state.work_reliability = mini(int(state.work_reliability), LOWEST_REPUTATION)
			state.failure = {"kind": "repeated_detected_tampering", "case_id": id,
				"count": state.privacy.discovered.size(), "threshold": DETECTION_FAILURE_THRESHOLD,
				"message": "三次交付被收件人发现拆痕，本班次声望已降至最低，工作中止。可恢复到本次交付前，重新处理仍有拆痕的邮件。"}


func _complete_first_case_if_recorded() -> void:
	if str(state.cases.case01.disposition).is_empty() or state.cases.case01.resolution.is_empty(): return
	state.tutorial_first_case_completed = true
	for id: String in ["case02", "case03"]: state.cases[id].available = true


func record_resolution(id: String, result: Dictionary) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先收好正在操作的物件，再填写处理单。"
	if state.location != "post_office": return "处理单须回邮局柜台盖章登记。"
	if not state.cases.has(id) or not state.cases[id].available: return "这件邮件尚未出现。"
	var item: Dictionary = state.cases[id]
	if str(item.disposition).is_empty(): return "先为实物完成交付或合法处置，再登记处理单。"
	if not _valid_resolution_input(result) or result.disposition != item.disposition: return "处理单栏位不完整，或所写去向与已经执行的处置不一致。"
	var normalized: Dictionary = result.duplicate(true)
	for key: String in ["recipient", "location", "status"]: normalized.determination[key] = str(normalized.determination[key]).strip_edges()
	normalized.note = str(normalized.note).strip_edges()
	if not item.resolution.is_empty():
		var existing: Dictionary = item.resolution.duplicate(true)
		for key: String in ["legacy_resolution", "recorded_minute", "recorded_location"]: existing.erase(key)
		return "" if existing == normalized else "此件处理单已经登记，不能通过重复盖章覆盖原记录。"
	normalized.legacy_resolution = false
	normalized.recorded_minute = state.minute
	normalized.recorded_location = state.location
	item.resolution = normalized
	_complete_first_case_if_recorded()
	_note(id + " 的判断与实际处置已分别登记并盖章；判断保留为玩家记录。")
	changed.emit()
	save_game()
	return ""


func resolution_view(id: String) -> Dictionary:
	if not state.cases.has(id) or not state.cases[id].available: return {}
	return state.cases[id].resolution.duplicate(true)


func _valid_resolution_input(result: Dictionary) -> bool:
	if result.size() != 4 or not result.get("stamped") is bool or not result.stamped: return false
	if not result.get("determination") is Dictionary or result.determination.size() != 3: return false
	for key: String in ["recipient", "location", "status"]:
		if not result.determination.get(key) is String: return false
		var text: String = result.determination[key]
		if text.strip_edges().is_empty() or text.length() > 80: return false
		for index: int in text.length():
			if text.unicode_at(index) == 0: return false
	if not result.get("disposition") is String or result.disposition.length() > 80 or not result.get("note") is String or result.note.length() > 500: return false
	for index: int in result.note.length():
		if result.note.unicode_at(index) == 0: return false
	return true


func _valid_resolution(item: Dictionary, value: Dictionary) -> bool:
	var record: Variant = item.get("resolution")
	if not record is Dictionary: return false
	if record.is_empty(): return true
	if record.size() != 7 or not record.get("legacy_resolution") is bool or str(item.disposition).is_empty(): return false
	if not record.get("stamped") is bool: return false
	if not record.get("disposition") is String or not record.get("determination") is Dictionary or not record.get("note") is String: return false
	if not _integer(record.get("recorded_minute")) or not record.get("recorded_location") is String: return false
	if record.get("disposition") != item.disposition: return false
	if record.legacy_resolution:
		return record.get("stamped") == false and record.get("determination") == {"recipient": "", "location": "", "status": ""} and record.get("note") == "" and record.get("recorded_minute") == -1 and record.get("recorded_location") == ""
	if not _integer(record.get("recorded_minute")) or int(record.recorded_minute) < 0 or int(record.recorded_minute) > int(value.minute) or record.get("recorded_location") != "post_office": return false
	var input: Dictionary = record.duplicate(true)
	for key: String in ["legacy_resolution", "recorded_minute", "recorded_location"]: input.erase(key)
	return _valid_resolution_input(input)


func adjust_trust(npc_id: String, amount: int, reason: String) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not catalog.people.has(npc_id) or reason.strip_edges().is_empty(): return "缺少人物或具体交往原因。"
	state.npc_trust[npc_id] = int(state.npc_trust.get(npc_id, 0)) + amount
	changed.emit()
	return ""


func record_archive_draft(claims: Dictionary, sources: Array) -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if claims.keys().any(func(key: Variant) -> bool: return key not in ["hv_person", "desk", "formal_code"]): return "未知的档案事实栏位。"
	if (claims.has("hv_person") and not claims.hv_person is String) or (claims.has("desk") and not claims.desk is String) or (claims.has("formal_code") and not claims.formal_code is bool): return "草稿栏位格式不符。"
	for id: String in sources:
		if not has_evidence(id): return "草稿引用了尚未实际查看的资料。"
	state.archive_draft = {"claims": claims.duplicate(true), "sources": sources.duplicate(), "confirmed": false}
	changed.emit()
	return ""


func report_loss(id: String, recorded: bool, note: String = "") -> String:
	var error := _owned_error(id)
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先安全退出物件操作。"
	if recorded and note.strip_edges().is_empty(): return "记录丢件必须说明经过。"
	_set_checkpoint("恢复本次严重失职之前，保留此前班次状态")
	state.cases[id].owner = "lost"
	state.cases[id].disposition = "unresolved_with_note" if recorded else "unrecorded_loss"
	state.cases[id].note = note.strip_edges()
	state.work_reliability = int(state.work_reliability) - (1 if recorded else 2)
	if not recorded:
		state.severe_incidents.append({"case_id": id, "kind": "unrecorded_loss", "minute": state.minute})
		if state.severe_incidents.size() >= int(catalog.policy.failure_after_severe_breaches):
			state.failure = {"kind": "repeated_serious_negligence", "case_id": id,
				"message": "连续严重失职使本班次中止。可回到本次事件前继续，此前记录仍保留。"}
	changed.emit()
	save_game()
	return ""


func can_resume_failure() -> bool:
	return not state.failure.is_empty() and state.checkpoint.get("snapshot") is Dictionary


func resume_checkpoint() -> String:
	if not can_resume_failure(): return "没有可恢复的失败检查点。"
	var restored: Dictionary = state.checkpoint.snapshot.duplicate(true)
	restored.failure = {}
	restored.checkpoint = {}
	restored.active_operation = {}
	if not _valid_state(restored): return "恢复点格式无效。"
	state = restored
	changed.emit()
	save_game()
	return ""


func _set_checkpoint(label: String) -> void:
	var snapshot: Dictionary = state.duplicate(true)
	snapshot.erase("checkpoint")
	snapshot.erase("failure")
	snapshot.erase("active_operation")
	state.checkpoint = {"label": label, "snapshot": snapshot}


func wait_for_handoff() -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if not state.active_operation.is_empty(): return "先收好正在操作的物件。"
	if state.location != "post_office": return "在邮局登记簿处明确等候受托交付回执。"
	var pending: Dictionary = state.world_flags.get("delegated_delivery", {})
	if pending.is_empty() or pending.arrived: return "没有尚待到达的受托交付回执。"
	var minutes := int(pending.arrival_minute) - int(state.minute)
	if minutes <= 0: return "回执时刻需要核对。"
	state.minute = int(pending.arrival_minute)
	_note("明确等候受托交付回执 %d 分钟。" % minutes)
	_refresh_time_events()
	changed.emit()
	save_game()
	return ""


func end_shift() -> String:
	var error := _blocked()
	if not error.is_empty(): return error
	if state.location != "post_office": return "请回邮局核对实物保管与处理单，再完成交班。"
	if not state.active_operation.is_empty(): return "先收好正在操作的物件。"
	var pending: Dictionary = state.world_flags.get("delegated_delivery", {})
	if not pending.is_empty() and not pending.arrived: return "受托交付回执尚未到达，请先明确等候回执再交班。"
	for id: String in CASE_IDS:
		if str(state.cases[id].disposition).is_empty(): return "尚有邮件没有处置或未决说明：" + id
		if state.cases[id].resolution.is_empty(): return "尚有邮件的处理单未盖章登记：" + id
	state.ending = {"dispositions": {}, "status": reliability_label(), "hook": "Desk B 仍有其他未决条目。"}
	for id: String in CASE_IDS: state.ending.dispositions[id] = state.cases[id].disposition
	# Factual reading is separate from the three equally legal note dispositions.
	var claims: Dictionary = state.archive_draft.get("claims", {})
	var sources: Array = state.archive_draft.get("sources", [])
	var supported := ["helena_rota", "procedure_codes", "ledger_returns"].all(func(id: String) -> bool: return id in sources and has_evidence(id))
	state.ending.archive_context = "recorded" if supported and has_evidence("ledger_hv_repeat") and claims.get("hv_person") == "helena_voss" and claims.get("desk") == "desk_b" and claims.get("formal_code") == false else "not_fully_reconstructed"
	changed.emit()
	save_game()
	return ""


func reliability_label() -> String:
	var value := int(state.work_reliability)
	if value >= 4: return "Trusted"
	if value >= 0: return "Good Standing"
	if value >= -2: return "Under Review"
	return "Probation Concern"


func time_text() -> String:
	var minute := int(state.minute)
	var result := "%02d:%02d" % [(minute / 60) % 24, minute % 60]
	return result if minute < 1440 else result + " (+%d day)" % (minute / 1440)


func _note(text: String) -> void:
	state.journal.append({"minute": state.minute, "text": text})


func save_game() -> bool:
	last_save_error = ""
	if not state.active_operation.is_empty(): return _save_error("不在工具操作中途自动保存；先明确结束或安全退出。")
	if not _valid_state(state): return _save_error("状态格式不合法。")
	var path := ProjectSettings.globalize_path(save_path)
	if _save_status(path) == "unsupported" or _save_status(path + ".bak") == "unsupported":
		return _save_error("目标文件使用不同或较新的存档格式，已保留原字节；请另选独立存档槽。")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return _save_error("无法创建独立存档目录。")
	var temporary := path + ".tmp"
	var backup := path + ".bak"
	var payload := JSON.stringify(state)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _save_error("无法写入临时存档。")
	file.store_string(JSON.stringify({"format": FORMAT, "version": SAVE_VERSION, "payload_json": payload, "sha256": payload.sha256_text()}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_save(temporary).is_empty(): return _save_error("临时存档校验失败。")
	if FileAccess.file_exists(path):
		if not _read_save(path).is_empty():
			if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK: return _save_error("无法轮换恢复副本。")
			if DirAccess.rename_absolute(path, backup) != OK: return _save_error("无法保留上一份有效存档。")
		elif DirAccess.remove_absolute(path) != OK: return _save_error("无法替换损坏的主存档。")
	if DirAccess.rename_absolute(temporary, path) != OK: return _save_error("存档发布失败；上一份有效副本仍可恢复。")
	return true


func _save_error(message: String) -> bool:
	last_save_error = message
	save_failed.emit(message)
	return false


func has_save() -> bool:
	if _save_status(save_path) == "unsupported": return false
	return not _read_save(save_path).is_empty() or not _read_save(save_path + ".bak").is_empty()


func load_game() -> bool:
	_load_catalog()
	if _save_status(save_path) == "unsupported":
		last_load_source = ""
		last_save_error = "此槽为不同或较新的格式，未降级读取或改写。"
		return false
	var loaded := _read_save(save_path)
	last_load_source = "primary"
	if loaded.is_empty():
		loaded = _read_save(save_path + ".bak")
		last_load_source = "backup"
	if loaded.is_empty():
		last_load_source = ""
		return false
	state = loaded
	_refresh_time_events()
	changed.emit()
	return true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var outer: Variant = _parse_json(FileAccess.get_file_as_string(path))
	if not outer is Dictionary or outer.get("format") != FORMAT or outer.get("version") != SAVE_VERSION: return {}
	if not outer.get("payload_json") is String or not outer.get("sha256") is String: return {}
	if str(outer.payload_json).sha256_text() != outer.sha256: return {}
	var parsed: Variant = _parse_json(outer.payload_json)
	if parsed is Dictionary and parsed.get("rules_version") == PRE_TUTORIAL_RULES:
		parsed = _upgrade_tutorial_snapshot(parsed)
	if parsed is Dictionary and parsed.get("rules_version") == PRE_AMENDMENT_RULES:
		parsed = _upgrade_amendment_snapshot(parsed)
	if parsed is Dictionary and parsed.get("rules_version") == PRE_RESOLUTION_RULES:
		parsed = _upgrade_resolution_snapshot(parsed)
	return parsed if parsed is Dictionary and _valid_state(parsed) else {}


func _save_status(path: String) -> String:
	if not FileAccess.file_exists(path): return "missing"
	var outer: Variant = _parse_json(FileAccess.get_file_as_string(path))
	if not outer is Dictionary: return "corrupt"
	if outer.get("format") != FORMAT or outer.get("version") != SAVE_VERSION: return "unsupported"
	if outer.get("payload_json") is String:
		var payload: Variant = _parse_json(outer.payload_json)
		if payload is Dictionary and payload.get("catalog_version") != CATALOG_VERSION: return "unsupported"
		if payload is Dictionary:
			if payload.get("rules_version") not in [RULES_VERSION, PRE_TUTORIAL_RULES, PRE_AMENDMENT_RULES, PRE_RESOLUTION_RULES]: return "unsupported"
			if payload.get("rules_version") == PRE_TUTORIAL_RULES and _upgrade_tutorial_snapshot(payload).is_empty(): return "unsupported"
			if payload.get("rules_version") == PRE_AMENDMENT_RULES and _upgrade_amendment_snapshot(payload).is_empty(): return "unsupported"
			if payload.get("rules_version") == PRE_RESOLUTION_RULES and _upgrade_resolution_snapshot(payload).is_empty(): return "unsupported"
	return "valid" if not _read_save(path).is_empty() else "corrupt"


func _upgrade_tutorial_snapshot(previous: Dictionary, depth: int = 0) -> Dictionary:
	# Same-day v2 compatibility uses actual dispositions, never guessed completion.
	if depth > 3 or previous.get("rules_version") != PRE_TUTORIAL_RULES or not previous.get("cases") is Dictionary: return {}
	var cases: Dictionary = previous.cases
	if not cases.get("case01") is Dictionary: return {}
	var completed: bool = not str(cases.case01.get("disposition", "")).is_empty()
	if not completed:
		for id: String in ["case02", "case03"]:
			if not cases.get(id) is Dictionary or cases[id].get("owner") != "desk_b" or cases[id].get("disposition") != "": return {}
			var fresh := PhysicalModel.new()
			fresh.setup(id)
			var historical := PhysicalModel.new()
			if not cases[id].get("physical") is Dictionary or not historical.restore_state(cases[id].physical).is_empty(): return {}
			if _parse_json(JSON.stringify(historical.export_state())) != _parse_json(JSON.stringify(fresh.export_state())): return {}
		for id: String in ["case04", "case05"]:
			if not cases.get(id) is Dictionary or cases[id].get("available") != false: return {}
	var upgraded: Dictionary = previous.duplicate(true)
	upgraded.rules_version = PRE_AMENDMENT_RULES
	upgraded.tutorial_first_case_completed = completed
	for id: String in ["case02", "case03"]: upgraded.cases[id].available = completed
	var checkpoint: Variant = upgraded.get("checkpoint", {})
	if checkpoint is Dictionary and not checkpoint.is_empty():
		if not checkpoint.get("snapshot") is Dictionary: return {}
		checkpoint.snapshot = _upgrade_tutorial_snapshot(checkpoint.snapshot, depth + 1)
		if checkpoint.snapshot.is_empty(): return {}
	var world: Variant = upgraded.get("world_flags", {})
	if not world is Dictionary: return {}
	var pending: Variant = world.get("delegated_delivery", {})
	if pending is Dictionary and not pending.is_empty():
		if not pending.get("pre_handoff") is Dictionary: return {}
		pending.pre_handoff = _upgrade_tutorial_snapshot(pending.pre_handoff, depth + 1)
		if pending.pre_handoff.is_empty(): return {}
	return upgraded


func _upgrade_amendment_snapshot(previous: Dictionary, depth: int = 0) -> Dictionary:
	# Physical v2 had no editing actions. Its original contents are a known baseline;
	# exact breach counts are retained. This is not a guessed legacy v1 migration.
	if depth > 3 or previous.get("rules_version") != PRE_AMENDMENT_RULES or not previous.get("cases") is Dictionary: return {}
	var upgraded: Dictionary = previous.duplicate(true)
	upgraded.rules_version = PRE_RESOLUTION_RULES
	for id: String in CASE_IDS:
		var item: Variant = upgraded.cases.get(id)
		if not item is Dictionary or not item.get("physical") is Dictionary or item.has("alterations"): return {}
		if item.physical.get("version") != 2: return {}
		var model := PhysicalModel.new()
		if not model.restore_state(item.physical).is_empty(): return {}
		item.physical = model.export_state()
		item.alterations = _initial_alterations(id)
	var checkpoint: Variant = upgraded.get("checkpoint", {})
	if checkpoint is Dictionary and not checkpoint.is_empty():
		if not checkpoint.get("snapshot") is Dictionary: return {}
		checkpoint.snapshot = _upgrade_amendment_snapshot(checkpoint.snapshot, depth + 1)
		if checkpoint.snapshot.is_empty(): return {}
	var world: Variant = upgraded.get("world_flags", {})
	if not world is Dictionary: return {}
	var pending: Variant = world.get("delegated_delivery", {})
	if pending is Dictionary and not pending.is_empty():
		if not pending.get("pre_handoff") is Dictionary: return {}
		pending.pre_handoff = _upgrade_amendment_snapshot(pending.pre_handoff, depth + 1)
		if pending.pre_handoff.is_empty(): return {}
	return upgraded


func _upgrade_resolution_snapshot(previous: Dictionary, depth: int = 0) -> Dictionary:
	if depth > 3 or previous.get("rules_version") != PRE_RESOLUTION_RULES or not previous.get("cases") is Dictionary: return {}
	var upgraded: Dictionary = previous.duplicate(true)
	upgraded.rules_version = RULES_VERSION
	for id: String in CASE_IDS:
		var item: Variant = upgraded.cases.get(id)
		if not item is Dictionary or item.has("resolution"): return {}
		item.resolution = {}
		if not str(item.get("disposition", "")).is_empty():
			# Retain proven old progress without inventing a past stamp, guess or place.
			item.resolution = {"determination": {"recipient": "", "location": "", "status": ""},
				"disposition": item.disposition, "note": "", "stamped": false, "legacy_resolution": true,
				"recorded_minute": -1, "recorded_location": ""}
	var checkpoint: Variant = upgraded.get("checkpoint", {})
	if checkpoint is Dictionary and not checkpoint.is_empty():
		if not checkpoint.get("snapshot") is Dictionary: return {}
		checkpoint.snapshot = _upgrade_resolution_snapshot(checkpoint.snapshot, depth + 1)
		if checkpoint.snapshot.is_empty(): return {}
	var world: Variant = upgraded.get("world_flags", {})
	if not world is Dictionary: return {}
	var pending: Variant = world.get("delegated_delivery", {})
	if pending is Dictionary and not pending.is_empty():
		if not pending.get("pre_handoff") is Dictionary: return {}
		pending.pre_handoff = _upgrade_resolution_snapshot(pending.pre_handoff, depth + 1)
		if pending.pre_handoff.is_empty(): return {}
	return upgraded


static func _parse_json(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


static func _number(value: Variant) -> bool:
	return value is int or value is float


func _valid_state(value: Dictionary, allow_checkpoint: bool = true) -> bool:
	if value.get("catalog_version") != CATALOG_VERSION: return false
	if value.get("rules_version") != RULES_VERSION: return false
	if not value.get("tutorial_first_case_completed") is bool: return false
	if not _integer(value.get("minute")) or float(value.minute) < 0: return false
	if value.get("location") not in catalog.locations or not _integer(value.get("work_reliability")): return false
	for key: String in ["cases", "evidence", "encounters", "npc_trust", "privacy", "world_flags", "archive_draft", "active_operation", "checkpoint", "failure", "ending"]:
		if not value.get(key) is Dictionary: return false
	for key: String in ["known_names", "time_events", "journal", "severe_incidents", "opening_history"]:
		if not value.get(key) is Array: return false
	if not value.active_operation.is_empty(): return false
	if not value.privacy.get("violations") is Array or not value.privacy.get("discovered") is Array: return false
	if _unique_count(value.privacy.violations) != value.privacy.violations.size() or _unique_count(value.privacy.discovered) != value.privacy.discovered.size(): return false
	var opening_counts := {}
	if value.opening_history.size() > MAX_OPENINGS: return false
	for index: int in value.opening_history.size():
		var entry: Variant = value.opening_history[index]
		if not entry is Dictionary or entry.get("case_id") not in CASE_IDS: return false
		if not _integer(entry.get("serial")) or int(entry.serial) != index + 1: return false
		if not _integer(entry.get("ordinal")) or int(entry.ordinal) != int(opening_counts.get(entry.case_id, 0)) + 1: return false
		if not _integer(entry.get("minute")) or int(entry.minute) < 0 or int(entry.minute) > int(value.minute): return false
		if index > 0 and int(entry.minute) < int(value.opening_history[index - 1].minute): return false
		opening_counts[entry.case_id] = int(entry.ordinal)
	for id: Variant in value.privacy.violations:
		if id not in CASE_IDS or id == "case05": return false
	for id: Variant in value.privacy.discovered:
		if id not in value.privacy.violations: return false
	for person: Variant in value.known_names:
		if person not in catalog.people: return false
	for person: Variant in value.npc_trust:
		if person not in catalog.people or not _integer(value.npc_trust[person]): return false
	for id: Variant in value.evidence:
		if not id is String or not value.evidence[id] is Dictionary: return false
		var data := clue_data(id)
		var evidence: Dictionary = value.evidence[id]
		if data.is_empty() or evidence.get("source") != data.source: return false
		if not _integer(evidence.get("observed_minute")) or int(evidence.observed_minute) > int(value.minute) or int(evidence.observed_minute) < int(data.validity_time.available_after_minute): return false
		if evidence.get("location") not in catalog.locations or (data.location != "" and evidence.location != data.location) or evidence.get("public_or_private") != data.public_or_private: return false
	if value.cases.size() != CASE_IDS.size(): return false
	for id: String in CASE_IDS:
		var item: Variant = value.cases.get(id)
		if not item is Dictionary: return false
		for key: String in ["owner", "disposition", "note", "target", "feedback"]:
			if not item.get(key) is String: return false
		for key: String in ["available", "late", "read_body", "credited"]:
			if not item.get(key) is bool: return false
		if not _integer(item.get("attempts")) or int(item.attempts) < 0 or not item.get("physical") is Dictionary: return false
		var model := PhysicalModel.new()
		if item.physical.get("version") != PhysicalModel.VERSION: return false
		if item.physical.get("case_id") != id or not model.restore_state(item.physical).is_empty(): return false
		if int(item.physical.opened_count) != int(opening_counts.get(id, 0)): return false
		if not str(item.physical.operation_mode).is_empty(): return false
		if item.read_body != bool(item.physical.body_exposed and item.physical.extracted and item.physical.body_unfolded): return false
		if bool(item.physical.privacy_violation) != (id in value.privacy.violations): return false
		if not _valid_custody(id, item, value): return false
		if not _valid_alterations(id, item, value): return false
		if not _valid_resolution(item, value): return false
	if value.tutorial_first_case_completed != (not value.cases.case01.resolution.is_empty()): return false
	if not value.cases.case01.available: return false
	for id: String in ["case02", "case03"]:
		if value.cases[id].available != value.tutorial_first_case_completed: return false
	if value.cases.case04.available and not value.tutorial_first_case_completed: return false
	for id: String in value.privacy.discovered:
		var received: Dictionary = value.cases[id]
		if received.disposition not in ["deliver", "forward", "delegate"]: return false
		if received.disposition == "delegate" and received.owner != case_data(id).recipient_id: return false
		var threshold: float = float(catalog.policy.careful_trace_threshold if case_data(id).recipient_attention == "careful" else catalog.policy.casual_trace_threshold)
		if float(received.physical.tamper_trace) < threshold: return false
	if value.privacy.discovered.size() >= DETECTION_FAILURE_THRESHOLD and value.failure.get("kind") != "repeated_detected_tampering": return false
	if value.cases.case05.available and (not value.evidence.has("ledger_hv_repeat") or str(value.cases.case04.disposition).is_empty()): return false
	var pending: Variant = value.world_flags.get("delegated_delivery", {})
	if not pending is Dictionary: return false
	if not pending.is_empty():
		if not _integer(pending.get("arrival_minute")) or not pending.get("arrived") is bool or int(pending.arrival_minute) >= int(catalog.calendar.mira_departure_minute): return false
		if value.cases.case02.disposition != "delegate": return false
		if value.cases.case02.owner != ("mira_vale" if pending.arrived else "chenyuan"): return false
		if bool(pending.arrived) != (int(value.minute) >= int(pending.arrival_minute)): return false
		var before: Variant = pending.get("pre_handoff")
		if not _valid_checkpoint_snapshot(before): return false
		if before.world_flags.has("delegated_delivery") or before.cases.case02.owner != "courier" or not str(before.cases.case02.disposition).is_empty(): return false
		if int(before.minute) > int(pending.arrival_minute) or int(before.minute) > int(value.minute): return false
		if before.cases.case02.physical != value.cases.case02.physical: return false
		for key: String in ["original_body_sha256", "confirmed", "attachment_included", "history"]:
			if before.cases.case02.alterations[key] != value.cases.case02.alterations[key]: return false
		if before.opening_history.size() > value.opening_history.size(): return false
		for index: int in before.opening_history.size():
			if before.opening_history[index] != value.opening_history[index]: return false
	if not value.failure.is_empty():
		if value.checkpoint.is_empty() or value.failure.get("case_id") not in CASE_IDS: return false
		match value.failure.get("kind"):
			"repeated_serious_negligence":
				if value.severe_incidents.size() < int(catalog.policy.failure_after_severe_breaches): return false
			"repeated_detected_tampering":
				if value.privacy.discovered.size() < DETECTION_FAILURE_THRESHOLD or int(value.work_reliability) > LOWEST_REPUTATION: return false
				if value.failure.get("count") != value.privacy.discovered.size() or value.failure.get("threshold") != DETECTION_FAILURE_THRESHOLD: return false
				if value.failure.case_id != value.privacy.discovered.back(): return false
			_: return false
	if not value.ending.is_empty():
		for id: String in CASE_IDS:
			if str(value.cases[id].disposition).is_empty() or value.cases[id].resolution.is_empty(): return false
	if not value.checkpoint.is_empty():
		if not allow_checkpoint: return false
		var snapshot: Variant = value.checkpoint.get("snapshot")
		if not _valid_checkpoint_snapshot(snapshot): return false
	return true


func _valid_checkpoint_snapshot(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.has("checkpoint") or snapshot.has("failure") or snapshot.has("active_operation"): return false
	if not snapshot.get("world_flags") is Dictionary: return false
	# An in-flight handoff may contain its actual pre-handoff state, never another handoff.
	var pending: Variant = snapshot.get("world_flags", {}).get("delegated_delivery", {})
	if not pending is Dictionary: return false
	if not pending.is_empty():
		var before: Variant = pending.get("pre_handoff")
		if not before is Dictionary or not before.get("world_flags") is Dictionary or before.world_flags.has("delegated_delivery"): return false
	var restored: Dictionary = snapshot.duplicate(true)
	restored.checkpoint = {}; restored.failure = {}; restored.active_operation = {}
	return _valid_state(restored, false)


static func _unique_count(values: Array) -> int:
	var found := {}
	for item: Variant in values:
		if not item is String: return -1
		found[item] = true
	return found.size()


static func _integer(value: Variant) -> bool:
	return _number(value) and is_finite(float(value)) and floor(float(value)) == float(value)


func _valid_custody(id: String, item: Dictionary, value: Dictionary) -> bool:
	var action := str(item.disposition)
	if not item.available:
		if id in ["case02", "case03"]:
			var fresh := PhysicalModel.new()
			fresh.setup(id)
			return not value.tutorial_first_case_completed and item.owner == "desk_b" and action.is_empty() and _parse_json(JSON.stringify(item.physical)) == _parse_json(JSON.stringify(fresh.export_state()))
		return id in ["case04", "case05"] and item.owner == "archive_box" and action.is_empty()
	if action.is_empty():
		return item.owner in (["courier", "desk_b"] if id in ["case01", "case02", "case03"] else ["courier", "archive_box", "ledger_sleeve"])
	if item.owner == "lost": return action in ["unrecorded_loss", "unresolved_with_note"]
	if action not in case_data(id).legal_dispositions: return false
	if action in ["deliver", "forward", "repair_and_reenter", "delegate"] and item.physical.opened and not item.physical.resealed: return false
	match action:
		"deliver": return item.owner == case_data(id).recipient_id and item.target == item.owner
		"forward": return item.owner == "community_center_cubby" and item.target == item.owner
		"delegate": return item.owner in ["chenyuan", "mira_vale"] and value.world_flags.has("delegated_delivery")
		"return_to_sender": return item.owner == "return_mailstream"
		"repair_and_reenter": return item.owner == "local_mailstream" and item.target == "community_center_cubby"
		"archive_review", "file_officially": return item.owner == "official_archive"
		"supervisor_next_shift": return item.owner == "supervisor_inbox"
		_: return item.owner == "desk_b"
