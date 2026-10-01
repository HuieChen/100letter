extends Node
class_name GameSession
## The only authority for time, evidence, custody, choices, and persistence.
## UI controllers report completed interactions; reading never advances time.

signal changed

const SaveStore = preload("res://scripts/core/SaveData.gd")
const CASE_IDS = ["case01", "case02", "case03", "case04", "case05"]
const INDEPENDENT_EVIDENCE = ["old_nameplate", "event_archive", "old_photo", "handwriting_sample"]
const HANDLED_STATUSES = ["delivered", "delegated", "delayed", "held", "returned", "filed", "kept", "destroyed"]

var catalog: Dictionary = {}
var state: Dictionary = {}
var save_path = "user://solmere_save.json"
var last_save_ok = true
var recovered_backup = false

func _init() -> void:
	var file = FileAccess.open("res://data/game.json", FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			catalog = parsed
		file.close()
	_reset_state()

func _reset_state() -> void:
	state = {
		"version": 1, "minute": 540, "location": "post_office", "current_case": "case01",
		"clues": [], "visited": ["post_office"], "met_npcs": [], "asked": [], "letters": {},
		"journal": [], "ending": "", "archive_matched": false, "reputation": 70, "repair_materials": 3,
		"courier_met_at_bus": false, "checkpoint": {}, "failure": {}
	}
	for id in CASE_IDS:
		state.letters[id] = {
			"status": "unhandled", "opened": false, "restored": false, "tamper": 0,
			"repair_solved": false, "tool": "", "removed_attachment": false, "choice": "",
			"recipient": "", "sender": "", "late": false, "attempts": 0,
			"factual_correct": false, "restore_quality": 0.0, "feedback": "", "evening_feedback": "",
			"repair_material_allocated": false, "opening_tamper": 0, "deduction_claims": {},
			"identity_correct": false, "evidence_correct": false, "decision_minute": -1, "handoff_note": ""
		}

func new_game() -> void:
	_reset_state()
	recovered_backup = false
	_note("09:00 到岗。桌上有五封异常件。先看信封，再决定要去哪里。")
	_commit()

func save_game() -> bool:
	last_save_ok = SaveStore.write_state(save_path, state)
	return last_save_ok

func has_save() -> bool:
	return not SaveStore.read_state(save_path).is_empty() or not SaveStore.read_state(save_path + ".bak").is_empty()

func load_game() -> bool:
	var loaded = SaveStore.read_state(save_path)
	recovered_backup = false
	if loaded.is_empty():
		loaded = SaveStore.read_state(save_path + ".bak")
		recovered_backup = not loaded.is_empty()
	if loaded.is_empty():
		return false
	if location_data(str(loaded.location)).is_empty():
		return false
	if not loaded.has("checkpoint"):
		loaded.checkpoint = {}
	if not loaded.has("failure"):
		loaded.failure = {}
	state = loaded
	changed.emit()
	return true

func letter_data(id: String) -> Dictionary:
	return _find(catalog.get("letters", []), id)

func letter(id: String) -> Dictionary:
	return letter_data(id)

func location_data(id: String) -> Dictionary:
	return _find(catalog.get("locations", []), id)

func npc_data(id: String) -> Dictionary:
	return _find(catalog.get("npcs", []), id)

func case_state(id: String) -> Dictionary:
	return state.letters.get(id, {})

func select_case(id: String) -> void:
	if id in CASE_IDS and state.ending.is_empty() and not has_failure():
		state.current_case = id
		_commit()

func is_handled(id: String) -> bool:
	return case_state(id).get("status", "") in HANDLED_STATUSES

func first_four_handled() -> bool:
	for id in ["case01", "case02", "case03", "case04"]:
		if not is_handled(id):
			return false
	return true

func status_text(id: String) -> String:
	if id == "case04" and is_handled(id) and state.ending.is_empty():
		return "已登记处理"
	var labels = {"unhandled": "待调查", "investigating": "调查中", "delivered": "已投递", "delegated": "已托付尘缘", "delayed": "延至下一班", "held": "暂扣保管", "returned": "已退回", "filed": "已归档", "kept": "私人保留", "destroyed": "已销毁"}
	return labels.get(case_state(id).get("status", ""), "待调查")

func add_clue(id: String) -> void:
	if state.ending.is_empty() and not has_failure() and _add_clue(id):
		_commit()

func _add_clue(id: String) -> bool:
	if id.is_empty() or id in state.clues or not catalog.get("clues", {}).has(id):
		return false
	state.clues.append(id)
	var clue: Dictionary = catalog.clues[id]
	_note("记录线索：" + str(clue.get("title", id)))
	return true

func inspect_hotspot(location_id: String, hotspot_id: String) -> String:
	if has_failure():
		return _failure_message()
	if not state.ending.is_empty():
		return "今天的工作已经结束。"
	if state.location != location_id:
		return "先到这个地点，才能仔细看。"
	var hotspot = _find(location_data(location_id).get("hotspots", []), hotspot_id)
	if hotspot.is_empty():
		return "这里没有可查看的记录。"
	if not _has_all(hotspot.get("requires", [])):
		return "还缺少关联记录；先检查手上的信件。"
	for clue in hotspot.get("clues", []):
		_add_clue(str(clue))
	_commit()
	return str(hotspot.get("text", "已记录观察。"))

func travel_cost(id: String) -> int:
	if id == state.location:
		return 0
	var destination = location_data(id)
	if destination.is_empty():
		return 0
	# Every journey has a cost, including the return to the post office.
	if id == "post_office":
		return maxi(20, int(location_data(state.location).get("travel", 30)))
	return maxi(20, int(destination.get("travel", 30)))

func travel_options(id: String) -> Array:
	var destination = location_data(id)
	if destination.is_empty():
		return []
	var now: int = int(state.minute)
	var walk_minutes: int = travel_cost(id)
	var blocked: String = ""
	if has_failure():
		blocked = _failure_message()
	elif not state.ending.is_empty():
		blocked = "今天的工作已经结束。"
	elif id == state.location:
		blocked = "你已经在这里。"
	var options: Array = [{
		"mode": "walk", "label": "步行", "minutes": walk_minutes,
		"wait_minutes": 0, "ride_minutes": 0, "depart_minute": now,
		"arrive_minute": now + walk_minutes, "available": blocked.is_empty(), "reason": blocked
	}]
	var service: Dictionary = catalog.get("travel_service", {})
	if str(state.location) != str(service.get("from", "")) or id != str(service.get("to", "")):
		return options
	var next_departure: int = -1
	var last_departure: int = -1
	for scheduled in service.get("departures", []):
		var departure: int = int(scheduled)
		last_departure = maxi(last_departure, departure)
		if departure >= now and (next_departure < 0 or departure < next_departure):
			next_departure = departure
	var ride: int = maxi(1, int(service.get("ride_minutes", 15)))
	var wait_minutes: int = next_departure - now if next_departure >= 0 else 0
	var reason: String = blocked
	if reason.is_empty() and next_departure < 0:
		var last_time: String = "%02d:%02d" % [last_departure / 60, last_departure % 60] if last_departure >= 0 else ""
		reason = "今日末班%s已过，可以步行继续。" % last_time
	options.append({
		"mode": "bus", "label": str(service.get("label", "17 路公交")),
		"minutes": wait_minutes + ride if next_departure >= 0 else 0,
		"wait_minutes": wait_minutes, "ride_minutes": ride,
		"depart_minute": next_departure,
		"arrive_minute": next_departure + ride if next_departure >= 0 else -1,
		"available": reason.is_empty(), "reason": reason
	})
	return options

func travel(id: String, mode: String = "walk") -> String:
	if has_failure():
		return _failure_message()
	if not state.ending.is_empty():
		return "今天的工作已经结束。"
	var destination = location_data(id)
	if destination.is_empty():
		return "地图上没有这个地点。"
	if id == state.location:
		return "你已经在这里。"
	var route: Dictionary = {}
	for option in travel_options(id):
		if option.mode == mode:
			route = option
			break
	if route.is_empty():
		return "这段路没有所选交通方式，请重新查看路线。"
	if not route.available:
		return str(route.reason)
	var cost: int = int(route.minutes)
	state.minute += cost
	state.location = id
	if not id in state.visited:
		state.visited.append(id)
	var message = "步行抵达%s · 路上用了 %d 分钟。" % [destination.get("name", id), cost]
	if mode == "bus":
		message = "搭乘%s抵达%s · 等车 %d 分钟，乘车 %d 分钟。" % [route.label, destination.get("name", id), route.wait_minutes, route.ride_minutes]
	if state.minute >= 1080 and not is_handled("case02"):
		message += " 日落的约定已经过去；仍可继续调查和处理信件。"
	_note(message)
	_commit()
	return message

func available_questions(npc_id: String) -> Array:
	var result: Array = []
	for question in npc_data(npc_id).get("dialogues", []):
		if question.get("location", "") != state.location:
			continue
		if _has_all(question.get("requires", [])):
			result.append(question)
	return result

func ask(npc_id: String, question_id: String) -> String:
	if has_failure():
		return _failure_message()
	if not state.ending.is_empty():
		return "今天的工作已经结束。"
	var npc = npc_data(npc_id)
	var question = _find(npc.get("dialogues", []), question_id)
	if question.is_empty() or question.get("location", "") != state.location:
		return "现在不在对方身边。"
	if not _has_all(question.get("requires", [])):
		return "先找到能让这句话说清楚的证据。"
	if not npc_id in state.met_npcs:
		state.met_npcs.append(npc_id)
	if npc_id == "chenyuan" and state.location == "bus_stop":
		state.courier_met_at_bus = true
	var key = npc_id + ":" + question_id
	if not key in state.asked:
		state.asked.append(key)
		_note(str(npc.get("name", npc_id)) + "：" + str(question.get("answer", "")))
	for clue in question.get("clues", []):
		_add_clue(str(clue))
	_commit()
	return str(question.get("answer", ""))

func solve_fragments(id: String) -> String:
	if has_failure():
		return _failure_message()
	if id != "case03" or is_handled(id) or not state.ending.is_empty():
		return "这封信不需要再拼合地址。"
	if case_state(id).repair_solved:
		return "旧标签已经拼合。"
	case_state(id).repair_solved = true
	case_state(id).status = "investigating"
	state.minute += 15
	_add_clue("repair_address")
	_note("六片标签对上了：Rose Court 302。这是旧地址，还要确认现在的住户。")
	_commit()
	return "Rose Court 302。标签上的地址终于连起来了。"

func can_open(id: String) -> String:
	if has_failure():
		return _failure_message()
	if not state.ending.is_empty():
		return "今天的工作已经结束。"
	if not bool(letter_data(id).get("can_open", false)):
		return "这封信的封口完整，岗位规则不允许拆开。"
	if is_handled(id):
		return "这封信已经离开待处理托盘，今天不能追回。"
	if case_state(id).get("opened", false):
		return "内页已经取出。"
	if id == "case03" and not case_state(id).repair_solved:
		return "先把六片旧标签拼合，保全信封上的信息。"
	if id == "case05" and not first_four_handled():
		return "先为前四封信登记去向，再拆开写给下一位工作人员的信。"
	return ""

func complete_open(id: String, tool: String, mistakes: int) -> String:
	var error = can_open(id)
	if not error.is_empty():
		return error
	if not tool in ["safe", "quick"]:
		return "请选一件工作台上的虚构拆封工具。"
	if mistakes >= 8:
		var checkpoint: Dictionary = state.get("checkpoint", {})
		if checkpoint.get("case_id", "") != id or checkpoint.get("mode", "") != "open":
			_capture_checkpoint(id, "open")
		var damaged = case_state(id)
		damaged.tamper = 100
		damaged.tool = tool
		damaged.status = "damaged"
		state.minute += 25 if tool == "safe" else 10
		state.failure = {
			"kind": "damaged_letter", "id": id,
			"message": "多次偏离后，信纸已无法完整交接。今天的这次操作需要停下；可以回到拆封前，保留此前的调查和决定，重新处理这一封。",
			"checkpoint_label": str(state.checkpoint.get("label", "拆封前"))
		}
		_note("操作中止：《%s》的纸张严重受损。" % letter_data(id).get("title", id))
		_commit()
		return _failure_message()
	var entry = case_state(id)
	entry.opened = true
	entry.restored = false
	entry.status = "investigating"
	entry.tool = tool
	entry.tamper = mini(100, (8 if tool == "safe" else 25) + maxi(0, mistakes) * (3 if tool == "safe" else 9))
	entry.opening_tamper = entry.tamper
	state.minute += 25 if tool == "safe" else 10
	if id == "case03":
		_add_clue("case03_body")
	elif id == "case04":
		_add_clue("old_photo")
	elif id == "case05":
		_add_clue("old_mail_log")
	_note("取出了《%s》的内页。" % letter_data(id).get("title", id))
	_commit()
	return "内页已经取出，请手动展开阅读。"

func complete_restore(id: String, quality: float) -> String:
	if has_failure():
		return _failure_message()
	var entry = case_state(id)
	if entry.is_empty() or not entry.get("opened", false):
		return "这封信尚未拆开。"
	if is_handled(id) or not state.ending.is_empty():
		return "这封信已经登记处理，不能改动。"
	if entry.restored:
		return "封口已复位。"
	var material_allocated: bool = entry.get("repair_material_allocated", false)
	if state.repair_materials <= 0 and not material_allocated:
		return "修复材料已经用完；先将这封信延迟或保管。"
	var amount = clampf(quality, 0.0, 1.0)
	entry.restored = true
	entry.restore_quality = amount
	entry.tamper = clampi(int(entry.get("opening_tamper", entry.tamper)) - int(round(amount * 18)) + int(round((1.0 - amount) * 12)), 0, 100)
	if not material_allocated:
		state.repair_materials -= 1
		entry.repair_material_allocated = true
	state.minute += 15
	_note("《%s》的折痕和封口已经复位。" % letter_data(id).get("title", id))
	_commit()
	return "封边已经压平。" if amount >= 0.85 else "封口已经合上，一角还留有修复带的痕迹。"

func evidence_count(id: String) -> int:
	var total = 0
	var evidence = INDEPENDENT_EVIDENCE if id == "case04" else letter_data(id).get("clue_ids", [])
	for clue in evidence:
		if clue in state.clues:
			total += 1
	return total

func can_choose(id: String, action: String, recipient: String = "", sender: String = "", preparing: bool = false) -> String:
	if has_failure():
		return _failure_message()
	if not state.ending.is_empty():
		return "今天的工作已经结束。"
	if not id in CASE_IDS or letter_data(id).is_empty():
		return "没有这封信。"
	if is_handled(id):
		return "这封信已经登记处理，今天不能追回。"
	var allowed = _actions(letter_data(id).get("choices", []))
	if not action in allowed:
		return "这封信不允许这种处理方式。"
	if action in ["open", "restore"]:
		return "请在工作台实际操作工具，完成拆封或修复。"
	if id == "case03" and action == "deliver":
		if not case_state(id).repair_solved:
			return "先拼合六片标签，读出残缺地址。"
		if case_state(id).opened and not case_state(id).restored:
			return "内页已经展开，请先对齐折痕并封回信封。"
	if id == "case02" and action == "delegate":
		if state.location != "bus_stop" or not state.get("courier_met_at_bus", false):
			return "先在公交站找到尘缘，和对方谈过之后才能当面托付。"
		if not "delegate_terms" in state.clues:
			return "先询问尘缘能否代送，听清对方的答复和交接约定，再把急件交出去。"
	if id == "case04":
		if evidence_count(id) < 3:
			return "至少需要三条独立的旧记录，再登记你对寄件人和收件人的判断。"
		if not _deduction_structure_error(case_state(id).get("deduction_claims", {})).is_empty():
			return "先在推理垫上，把三份独立物证分别放到地址、日期和寄件依据的位置。"
		if recipient.is_empty() or sender.is_empty():
			return "请先分别登记收件人与寄件人的判断。"
		if action == "remove_attachment" and not case_state(id).opened:
			return "还没有取出照片，不能决定将它留下。"
		if not preparing and action in ["deliver", "return_to_sender", "remove_attachment"] and case_state(id).opened and not case_state(id).restored:
			return "信已经拆开，请先修复封口再交出。"
		if action in ["deliver", "remove_attachment"]:
			if state.location != "lookout" or not "june_arlen" in location_data(state.location).get("npc_ids", []):
				return "请把信带到观景台，和收件人当面办理交接。"
		if action == "return_to_sender":
			if not state.location in ["community_center", "lookout"] or not "mira_vale" in location_data(state.location).get("npc_ids", []):
				return "寄件人今天不在这里；请到观景台当面办理退回。"
	if id == "case05":
		if not first_four_handled():
			return "前四封信还没有全部登记去向。"
		if not case_state(id).opened:
			return "先取出写给你的信和旧清单。"
		if not state.archive_matched:
			return "先将今日旧信的编号与清单中的一条记录对应。"
	return ""

func choose(id: String, action: String, recipient: String = "", sender: String = "") -> String:
	var error = can_choose(id, action, recipient, sender)
	if not error.is_empty():
		return error
	var entry = case_state(id)
	var data = letter_data(id)
	if action == "deliver" and id in ["case01", "case02", "case03"]:
		if not _ordinary_delivery_correct(id, recipient):
			entry.attempts += 1
			entry.status = "investigating"
			state.reputation = maxi(0, int(state.reputation) - 3)
			var message = "信被退回手中，尚未结案。"
			if id == "case01":
				message += " 对方认不出旧市政厅这个地址；去看看社区中心的旧牌子。"
			elif id == "case02":
				message += " Mira 今天下午不在这里。公交站或许有她的行程。"
			else:
				message += " 旧门牌不能确认今天的去向；问问社区登记处，或看看公交站的志愿排班。"
			entry.feedback = message
			_note(message)
			_commit()
			return message
	entry.choice = action
	entry.decision_minute = int(state.minute)
	entry.recipient = recipient
	entry.sender = sender
	if id == "case04":
		entry.identity_correct = recipient == data.get("recipient", "") and sender == data.get("sender", "")
		entry.evidence_correct = _deduction_facts_match(entry.get("deduction_claims", {}))
		entry.factual_correct = entry.identity_correct and entry.evidence_correct
	else:
		entry.factual_correct = true
	var statuses = {"deliver": "delivered", "delegate": "delegated", "delay": "delayed", "hold": "held", "return": "returned", "return_to_sender": "returned", "remove_attachment": "delivered", "file": "filed", "keep": "kept", "destroy": "destroyed"}
	entry.status = statuses.get(action, "held")
	entry.removed_attachment = action == "remove_attachment"
	if id == "case02":
		entry.late = state.minute + (25 if action == "delegate" else 0) >= 1080 or action == "delay"
		if action == "deliver" and not entry.late:
			_add_clue("early_bench")
		if action in ["deliver", "delegate"]:
			state.reputation = clampi(int(state.reputation) + (-3 if entry.late else 3), 0, 100)
		elif action == "delay":
			state.reputation = maxi(0, int(state.reputation) - 3)
	elif id != "case04" and action == "deliver":
		state.reputation = mini(100, int(state.reputation) + 3)
	if id in ["case03", "case04"] and action in ["deliver", "return_to_sender", "remove_attachment"] and entry.tamper > 35:
		# Professional consequences concern visible condition, never moral alignment.
		state.reputation = maxi(0, int(state.reputation) - 2)
	# Evaluate deadline/condition at actual handoff first. Routine batch pauses
	# advance the working day only after a successful registered decision.
	if id != "case05":
		entry.handoff_note = _apply_shift_milestone()
	var message = "已登记：%s · %s。" % [data.get("title", id), status_text(id)]
	if id == "case04":
		message += " 你的判断已写入交接栏。傍晚再看看这封信抵达以后。"
	elif id == "case02" and action == "delegate":
		message += " 尘缘把信放进随身袋。今天不能追回，也不会替你查看观景台。"
	elif id in ["case01", "case03"]:
		message += " " + str(data.get("outcome", {}).get(action, ""))
	if not str(entry.get("handoff_note", "")).is_empty():
		message += "\n\n" + str(entry.handoff_note)
	entry.feedback = message
	_note(message)
	_commit()
	return message

func _apply_shift_milestone() -> String:
	var handled = 0
	for id in ["case01", "case02", "case03", "case04"]:
		if is_handled(id):
			handled += 1
	var minimum = {2: 780, 3: 930, 4: 1050}.get(handled, 0)
	if int(state.minute) >= minimum:
		return ""
	state.minute = minimum
	return "本轮处理记录归档，换上下一轮邮袋。继续工作时已是 %s。" % time_text()

func match_archive(serial: String) -> bool:
	if has_failure() or not state.ending.is_empty() or not case_state("case05").opened or not first_four_handled():
		return false
	if serial != str(catalog.get("archive_target", "")):
		return false
	state.archive_matched = true
	_add_clue("case04_number_match")
	_note("今日的陈年信与旧清单吻合。那封信并非遗失，而是曾被登记暂扣。")
	_commit()
	return true

func end_day() -> String:
	if has_failure():
		return _failure_message()
	if not state.ending.is_empty():
		return state.ending
	if not first_four_handled() or not is_handled("case05"):
		return "还没有完成交接。普通件可以登记延迟，旧信也可以先保管；写给你的信尚待处理。"
	state.minute = maxi(1080, int(state.minute))
	var sections: Array[String] = ["傍晚 · Solmere", ""]
	for id in CASE_IDS:
		var data = letter_data(id)
		var entry = case_state(id)
		var action = str(entry.choice)
		var outcome: Dictionary = data.get("outcome", {})
		var text = str(outcome.get(action, "已登记处理。"))
		if id == "case02" and entry.late:
			text = str(outcome.get(action + "_late", "Mira 已经离开观景台。信仍会交到她手上，只是今天的约定没有赶上。"))
		if id == "case04" and not entry.factual_correct:
			entry.status = "held"
			if entry.get("identity_correct", false):
				text = "交接复核发现证据对应有误：旧门牌支持收件地址，活动档案或旧照片核对日期，而署名活动卡才能支持寄件笔迹。你登记的人名吻合，证据栏却还需要更正。信封留在保管柜；这次复核没有替任何人判断应不应该读信。"
			else:
				text = "交接核对发现寄收关系有误：旧门牌、活动记录与笔迹共同指向 Mira → June。信封留在异常件保管柜，明日可以更正。今天，两人没有收到你的转交。"
		entry.evening_feedback = text
		sections.append("《%s》\n%s" % [data.get("title", id), text])
	sections.append("职业状态：" + reputation_label())
	sections.append(str(catalog.get("ending_text", "有些信迟到了。\n有些信，从来没有被允许抵达。")))
	state.ending = "\n\n".join(sections)
	_note("下班交接完成。")
	_commit()
	return state.ending

func has_failure() -> bool:
	return not state.get("failure", {}).is_empty()

func _failure_message() -> String:
	return str(state.get("failure", {}).get("message", "请先从操作前的检查点继续。"))

func begin_physical(id: String, mode: String) -> String:
	if has_failure():
		return _failure_message()
	if not id in CASE_IDS or is_handled(id) or not state.ending.is_empty():
		return "这封信当前不在可操作的托盘中。"
	if mode == "open":
		var error = can_open(id)
		if not error.is_empty():
			return error
	elif mode == "restore":
		if not case_state(id).opened or case_state(id).restored:
			return "当前没有需要封回的内页。"
	elif not mode in ["fragments", "archive", "attachment"]:
		return "没有这种信件操作。"
	_capture_checkpoint(id, mode)
	_commit()
	return ""

func _capture_checkpoint(id: String, mode: String) -> void:
	# Remove the preceding checkpoint BEFORE deep-copying the rest of state.
	# Each checkpoint contains exactly one flat snapshot, never an older chain.
	var snapshot: Dictionary = state.duplicate(false)
	snapshot["checkpoint"] = {}
	snapshot["failure"] = {}
	snapshot = snapshot.duplicate(true)
	var operation = {"open": "拆封", "restore": "修复", "fragments": "拼合", "archive": "比对", "attachment": "整理附件"}.get(mode, "操作")
	state.checkpoint = {"case_id": id, "mode": mode, "label": "%s · %s前" % [letter_data(id).get("title", id), operation], "snapshot": snapshot}

func can_resume_failure() -> bool:
	if not has_failure():
		return false
	var snapshot = state.get("checkpoint", {}).get("snapshot", {})
	return snapshot is Dictionary and SaveStore.valid_state(snapshot) and snapshot.get("checkpoint", {}).is_empty() and snapshot.get("failure", {}).is_empty()

func resume_checkpoint() -> bool:
	if not can_resume_failure():
		return false
	state = state.checkpoint.snapshot.duplicate(true)
	state.checkpoint = {}
	state.failure = {}
	_commit()
	return true

func begin_attachment_arrangement(id: String = "case04") -> String:
	if has_failure():
		return _failure_message()
	if id != "case04" or is_handled(id) or not case_state(id).get("opened", false) or not state.ending.is_empty():
		return "先取出这封旧信的内页，才能整理附件。"
	var entry = case_state(id)
	if entry.restored:
		# Already allocated material stays with this envelope. Rearranging or
		# cancelling cannot burn the finite stock or create a restoration deadlock.
		entry.repair_material_allocated = true
	entry.restored = false
	_commit()
	return ""

func record_deduction(claims: Dictionary) -> String:
	if has_failure():
		return _failure_message()
	if is_handled("case04") or not state.ending.is_empty():
		return "这封旧信已经登记处理，当前记录不能再改写。"
	var error = _deduction_structure_error(claims)
	if not error.is_empty():
		return error
	case_state("case04").deduction_claims = claims.duplicate(true)
	case_state("case04").status = "investigating"
	_note("旧信的地址、日期与寄件依据已排列为暂定判断；尚待交接复核。")
	_commit()
	return ""

func _deduction_structure_error(claims: Dictionary) -> String:
	if claims.size() != 3:
		return "地址、日期与寄件依据各需要一份记录。"
	var used: Array = []
	for role in ["address", "date", "sender"]:
		var clue = claims.get(role, "")
		if not clue is String or not clue in INDEPENDENT_EVIDENCE or not clue in state.clues:
			return "请使用已经亲自取得的独立原始物证填满三栏。"
		if clue in used:
			return "同一份物证不能同时占据两栏，请换一份独立记录。"
		used.append(clue)
	return ""

func _deduction_facts_match(claims: Dictionary) -> bool:
	return claims.get("address", "") == "old_nameplate" and claims.get("date", "") in ["event_archive", "old_photo"] and claims.get("sender", "") == "handwriting_sample"

func time_text() -> String:
	var minute = int(state.get("minute", 540))
	return "%02d:%02d" % [minute / 60, minute % 60]

func reputation_label() -> String:
	var value = int(state.get("reputation", 70))
	if value >= 85:
		return "受到信任"
	if value >= 70:
		return "专业"
	if value >= 50:
		return "评价一般"
	if value >= 30:
		return "被质疑"
	return "审查中"

func _ordinary_delivery_correct(id: String, recipient: String) -> bool:
	var data = letter_data(id)
	var target = str(data.get("recipient", ""))
	var place = str(data.get("location", ""))
	var candidate = recipient if not recipient.is_empty() else str(state.location)
	if state.location != place or not candidate in [target, place]:
		return false
	if id == "case03":
		return "case03_body" in state.clues or ("resident_moved" in state.clues and ("lookout_schedule" in state.clues or "nora_registry" in state.clues))
	return true

func _find(entries, id: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and entry.get("id", "") == id:
			return entry
	return {}

func _actions(entries: Array) -> Array:
	var actions: Array = []
	for entry in entries:
		actions.append(entry.get("id", entry.get("action", "")) if entry is Dictionary else entry)
	return actions

func _has_all(clues: Array) -> bool:
	for clue in clues:
		if not clue in state.clues:
			return false
	return true

func _note(text: String) -> void:
	state.journal.append({"time": time_text(), "text": text})

func _commit() -> void:
	save_game()
	changed.emit()
