class_name MailPhysicsState
extends RefCounted
## Pure object model for final-v1 mail. No UI, save I/O, clock or social scores.
## Coordinates/tolerances are local engineering defaults, not reference measurements.
signal changed(snapshot: Dictionary)
signal operation_completed(mode: String, snapshot: Dictionary)

const VERSION := 3
const CASE_IDS := ["case01", "case02", "case03", "case04", "case05"]
const MODES := ["", "repair_exterior", "open", "reseal", "amend"]
const TABLE := Rect2(0, 0, 1180, 630)
const MAT := Rect2(70, 80, 680, 480)
const ENVELOPE_SIZE := Vector2(420, 240)
const LABEL_SIZE := Vector2(92, 48)
const ALIGN_TOLERANCE := 16.0
const SEAM_TOLERANCE := 15.0
const EXTRACT_DISTANCE := 220.0
const FOLD_DISTANCE := 120.0
const SEAM_COUNT := 9
# Leave room for the complete fold gestures, not only their starting handles.
const OPENING_MAX_ORIGIN := Vector2(220, 260)
const PAGE_MAX_ORIGIN := Vector2(860, 325)

var _s: Dictionary = {}
var _tool: String = ""
var _drag: String = ""
var _grab := Vector2.ZERO
var _start_pointer := Vector2.ZERO
var _start_progress := 0.0
var _moved := false
var _amendments: Dictionary = {}
var _drag_origin := Vector2.ZERO


func setup(case_id: String) -> String:
	if case_id not in CASE_IDS:
		return "unknown_case"
	_s = _initial(case_id)
	_amendments = {}
	_clear_input()
	return ""


func export_state() -> Dictionary:
	if not _s.is_empty(): _s.folded = _all_folds(0.0)
	return _s.duplicate(true)


func restore_state(value: Dictionary) -> String:
	var normalized := value.duplicate(true)
	if int(normalized.get("version",0)) == 2:
		# v2 never exposed alteration or attachment actions, so these defaults are
		# known. Unlike the old opened boolean, no historical count is guessed.
		normalized.version=VERSION
		var defaults := _initial(str(normalized.get("case_id","")))
		for key: String in ["edit_key","erase_mask","replacement_id","replacement_position","replacement_placed","attachment_location","attachment_position","attachment_moved"]:
			if normalized.has(key):return "legacy_snapshot_contains_unknown_amendments"
			normalized[key]=defaults[key]
	var error := _validate(normalized)
	if not error.is_empty():
		return error
	_s = normalized
	_amendments = {}
	_clear_input()
	changed.emit(export_state())
	return ""


func configure_amendments(options: Dictionary) -> String:
	if _s.is_empty():return "not_configured"
	var rules: Dictionary={"edit_key":"","replacement_ids":[]}
	var slots: Array=options.get("slots",[])
	if slots.size()>1:return "only_one_editable_sentence"
	if not slots.is_empty():
		if not slots[0] is Dictionary or str(slots[0].get("id","")).is_empty():return "invalid_amendment_options"
		rules.edit_key=str(slots[0].id)
		for option: Dictionary in slots[0].get("options",[]):
			if option.get("operation","")=="replace":
				if str(option.get("id","")).is_empty():return "invalid_amendment_options"
				rules.replacement_ids.append(str(option.id))
	if rules.replacement_ids.size()>1:return "only_one_replacement_strip"
	_amendments=rules
	return ""


func begin_operation(mode: String) -> String:
	if _s.is_empty(): return "not_configured"
	if mode not in MODES or mode.is_empty(): return "unknown_mode"
	if not str(_s.operation_mode).is_empty() and _s.operation_mode != mode:
		return "operation_in_progress"
	if mode == "repair_exterior":
		if _s.case_id != "case03": return "no_authorized_exterior_repair"
		if _s.exterior_repaired: return "already_repaired"
		if _s.seal_condition not in ["intact", "resealed"]: return "close_private_contents_first"
	elif mode == "open":
		if not _opening_room(_point(_s.envelope_position)): return "move_to_opening_area"
		if _s.paper_location == "partly_inserted": return "resume_reseal_first"
		if _s.paper_location == "desk" and _all_folds(1.0) and _s.open_cycle_completed: return "already_unfolded"
		if _s.seal_condition == "closed_unsealed": return "finish_or_resume_reseal"
		if _s.seal_condition == "resealed":
			_s.seam_count = 0
			_s.extraction_progress = 0.0
			_s.open_cycle_completed = false
	elif mode == "reseal":
		if _s.seal_condition == "intact": return "nothing_to_reseal"
		if _s.seal_condition == "loosened": return "seam_not_open"
		if _s.seal_condition == "resealed": return "already_resealed"
	elif mode == "amend":
		if not _fully_unfolded():return "unfold_body_before_amending"
		if _s.case_id not in ["case02","case03","case04"]:return "no_amendment_surface"
		if _s.erase_mask==0 and not _s.replacement_placed:
			_s.replacement_position=_array((_point(_s.paper_position)+Vector2(-155,198)).clamp(TABLE.position,TABLE.end-Vector2(196,78)))
	_s.operation_mode = mode
	_clear_input()
	_notify()
	return ""


func cancel_operation() -> void:
	if _s.is_empty(): return
	_clear_input()
	_s.operation_mode = ""
	_notify()


func input_is_captured() -> bool:
	return not _drag.is_empty() or not _tool.is_empty()


func inspect_face(face: String) -> String:
	if _s.is_empty(): return "not_configured"
	if face not in ["front", "back"]: return "unknown_face"
	if not _drag.is_empty(): return "release_object_first"
	if _s.face == face and _s["inspected_" + face]: return "already_facing"
	_s.face = face
	_s["inspected_" + face] = true
	if _s.operation_mode == "repair_exterior" and _s.exterior_fold_aligned:
		_s.exterior_repaired = true
		_s.repair_quality = clampf(1.0 - float(_s.permanent_damage) * 0.05, 0.0, 1.0)
		_finish("repair_exterior")
	else:
		_notify()
	return ""


func set_inspection(zoom: float, pan: Vector2) -> String:
	if _s.is_empty(): return "not_configured"
	if not is_finite(zoom) or not pan.is_finite(): return "non_finite_input"
	_s.zoom = clampf(zoom, 1.0, 3.0)
	_s.pan = _array(pan.clamp(Vector2(-500, -300), Vector2(500, 300)))
	_notify()
	return ""


func select_tool(tool: String) -> String:
	if _s.is_empty(): return "not_configured"
	if not _drag.is_empty(): return "release_object_first"
	var allowed: Array = []
	match _s.operation_mode:
		"repair_exterior": allowed = ["restorer", "press"]
		"open": allowed = ["opener"]
		"reseal": allowed = ["sealer"]
		"amend":
			if not str(_amendments.get("edit_key","")).is_empty() and not _s.replacement_placed:allowed=["eraser"]
	if tool not in allowed: return "tool_not_available"
	_tool = tool
	return ""


func return_tool() -> void:
	_tool = ""


func object_rect(object_id: String) -> Rect2:
	if _s.is_empty(): return Rect2()
	var envelope := _point(_s.envelope_position)
	match object_id:
		"envelope": return Rect2(envelope, ENVELOPE_SIZE)
		"label": return Rect2(_point(_s.label_position), LABEL_SIZE)
		"protector": return Rect2(_point(_s.protector_position), Vector2(180, 120))
		"exterior_fold": return Rect2(envelope + Vector2(75, 215), Vector2(200, 25))
		"paper":
			if _s.paper_location in ["inside", "partly_extracted"]:
				return Rect2(_mouth() + Vector2(float(_s.extraction_progress) * EXTRACT_DISTANCE, 0), Vector2(28, 60))
			return Rect2(_point(_s.paper_position), Vector2(220, 210))
		"fold_0": return Rect2(_point(_s.paper_position) + Vector2(180, 10), Vector2(35, 80))
		"fold_1": return Rect2(_point(_s.paper_position) + Vector2(35, 165), Vector2(120, 35))
		"flap": return Rect2(envelope + Vector2(375, 60), Vector2(45, 90))
		"phrase":return Rect2(_point(_s.paper_position)+Vector2(12,65),Vector2(196,78))
		"replacement":return Rect2(_point(_s.replacement_position),Vector2(196,78))
		"attachment":
			return Rect2(_point(_s.attachment_position) if _s.attachment_location=="desk" or _drag=="attachment" else _attachment_slot(),Vector2(112,78))
		"attachment_slot":return Rect2(_attachment_slot(),Vector2(112,78))
		"attachment_tray":return Rect2((_point(_s.paper_position)+Vector2(230,110)).clamp(TABLE.position,TABLE.end-Vector2(170,105)),Vector2(170,105))
	return Rect2()


func begin_drag(object_id: String, pointer: Vector2) -> String:
	if _s.is_empty(): return "not_configured"
	if not pointer.is_finite(): return "non_finite_input"
	if not _drag.is_empty() or not _tool.is_empty(): return "hand_busy"
	if not object_rect(object_id).has_point(pointer): return "missed_object"
	var mode: String = _s.operation_mode
	match object_id:
		"envelope":
			if _s.paper_location != "inside" or _s.seal_condition not in ["intact", "resealed"]:
				return "loose_contents_on_table"
		"label":
			if mode != "repair_exterior" or not _s.label_lifted or _s.label_pressed or _s.face != "back":
				return "label_not_movable"
		"protector":
			if mode != "repair_exterior" or not _s.label_aligned or _s.label_pressed:
				return "align_label_first"
		"exterior_fold":
			if mode != "repair_exterior" or not _s.label_pressed: return "press_label_first"
		"paper":
			if mode == "open":
				if _s.seal_condition != "open": return "open_seam_first"
			elif mode == "reseal":
				if not _all_folds(0.0): return "refold_before_insertion"
				if _s.paper_location == "inside": return "paper_already_inside"
			elif mode=="amend":
				if not _fully_unfolded():return "unfold_body_before_amending"
			else: return "paper_operation_required"
		"replacement":
			if mode!="amend" or not _fully_unfolded():return "amendment_operation_required"
			if _s.erase_mask!=255 or _s.replacement_placed:return "erase_selected_sentence_first"
			if (_amendments.get("replacement_ids",[]) as Array).is_empty():return "no_replacement_option"
		"attachment":
			if mode!="amend" or not _fully_unfolded():return "amendment_operation_required"
			if _s.attachment_location=="none":return "no_attachment"
		"fold_0", "fold_1":
			if mode not in ["open", "reseal"] or _s.paper_location != "desk": return "extract_paper_first"
		"flap":
			if mode != "reseal" or _s.paper_location != "inside" or not _all_folds(0.0):
				return "insert_folded_paper_first"
		_: return "unknown_object"
	var original_rect:=object_rect(object_id)
	_drag = object_id
	_grab = pointer - original_rect.position
	_start_pointer = pointer
	_drag_origin=original_rect.position
	if object_id=="attachment":_s.attachment_position=_array(_drag_origin)
	_moved = false
	match object_id:
		"paper": _start_progress = float(_s.extraction_progress)
		"exterior_fold": _start_progress = float(_s.exterior_fold_progress)
		"flap": _start_progress = float(_s.flap_progress)
		"fold_0", "fold_1": _start_progress = float(_s.fold_progress[int(object_id.right(1))])
	return ""


func drag_to(pointer: Vector2) -> String:
	if _drag.is_empty(): return "no_grab"
	if not pointer.is_finite(): return "non_finite_input"
	var delta := pointer - _start_pointer
	_moved = _moved or delta.length() > 2.0
	var position := pointer - _grab
	match _drag:
		"envelope":
			position = position.clamp(TABLE.position, TABLE.end - ENVELOPE_SIZE)
			if _s.operation_mode == "open":
				position = position.clamp(TABLE.position, OPENING_MAX_ORIGIN)
			var offset := position - _point(_s.envelope_position)
			_s.envelope_position = _array(position)
			if not _s.label_lifted or _s.label_pressed: _s.label_position = _array(_point(_s.label_position) + offset)
			_s.paper_position = _array(_mouth())
			_s.exterior_on_mat = false
		"label":
			_s.label_position = _array(position.clamp(TABLE.position, TABLE.end - LABEL_SIZE))
			_s.label_aligned = false
			_s.protector_placed = false
		"protector":
			_s.protector_position = _array(position.clamp(TABLE.position, TABLE.end - Vector2(180, 120)))
			_s.protector_placed = false
		"exterior_fold":
			_s.exterior_fold_progress = clampf(_start_progress + delta.y / 70.0, 0.0, 1.0)
		"paper": _drag_paper(position, delta)
		"fold_0", "fold_1":
			var index := int(_drag.right(1))
			var movement: float = delta.x if index == 0 else delta.y
			var direction := 1.0 if _s.operation_mode == "open" else -1.0
			_s.fold_progress[index] = clampf(_start_progress + movement * direction / FOLD_DISTANCE, 0.0, 1.0)
			if _s.operation_mode == "open" and float(_s.fold_progress[index]) > 0.25:
				_s.body_exposed = true
		"flap": _s.flap_progress = clampf(_start_progress + delta.y / 90.0, 0.0, 1.0)
		"replacement":_s.replacement_position=_array(position.clamp(TABLE.position,TABLE.end-Vector2(196,78)))
		"attachment":_s.attachment_position=_array(position.clamp(TABLE.position,TABLE.end-Vector2(112,78)))
	_notify()
	return ""


func rotate_held(quarter_turns: int) -> String:
	if _drag != "label": return "hold_label_first"
	_s.label_turn = posmod(int(_s.label_turn) + quarter_turns, 4)
	_s.label_aligned = false
	_s.protector_placed = false
	_notify()
	return ""


func release_drag() -> String:
	if _drag.is_empty(): return "no_grab"
	var released := _drag
	_drag = ""
	match released:
		"envelope":
			_s.exterior_on_mat = _s.operation_mode == "repair_exterior" and _moved and MAT.encloses(object_rect("envelope"))
		"label":
			if int(_s.label_turn) == 0 and _point(_s.label_position).distance_to(_label_target()) <= ALIGN_TOLERANCE:
				_s.label_position = _array(_label_target())
				_s.label_aligned = true
		"protector":
			_s.protector_placed = object_rect("protector").encloses(Rect2(_label_target(), LABEL_SIZE))
		"exterior_fold":
			_s.exterior_fold_aligned = float(_s.exterior_fold_progress) >= 1.0
		"paper":
			if _s.operation_mode == "reseal" and float(_s.insertion_progress) >= 1.0:
				_s.paper_location = "inside"
				_s.paper_position = _array(_mouth())
				_s.inserted = true
		"fold_0", "fold_1":
			if _s.operation_mode == "open" and _all_folds(1.0) and not _s.open_cycle_completed:
				_s.body_unfolded = true
				_s.unfolded = true
				_s.open_cycle_completed = true
				_finish("open")
		"flap":
			if float(_s.flap_progress) >= 1.0:
				_s.flap_closed = true
				_s.seal_condition = "closed_unsealed"
		"replacement":
			if _point(_s.replacement_position).distance_to(object_rect("phrase").position)<=ALIGN_TOLERANCE:
				_s.replacement_position=_array(object_rect("phrase").position)
				_s.replacement_id=str(_amendments.replacement_ids[0])
				_s.replacement_placed=true
				_s.tamper_trace+=0.25
				_finish("amend")
		"attachment":
			var position:=_point(_s.attachment_position)
			var target:=""
			if position.distance_to(_attachment_slot())<=ALIGN_TOLERANCE:target="with_letter"
			elif object_rect("attachment_tray").encloses(Rect2(position,Vector2(112,78))):target="desk"
			if target.is_empty():
				_s.attachment_position=_array(_drag_origin)
			elif target!=_s.attachment_location:
				_s.attachment_location=target
				if target=="desk" and not _s.attachment_moved:
					_s.attachment_moved=true
					_s.tamper_trace+=0.25
				_finish("amend")
	_notify()
	return ""


func tool_contact(pointer: Vector2) -> String:
	if _s.is_empty(): return "not_configured"
	if not pointer.is_finite(): return "non_finite_input"
	if _tool.is_empty(): return "no_tool"
	if _s.operation_mode == "repair_exterior":
		if not _s.exterior_on_mat or not _s.inspected_front or not _s.inspected_back or _s.face != "back":
			return "inspect_both_sides_on_mat_first"
		if _tool == "restorer":
			if not object_rect("label").has_point(pointer): return "no_material_contact"
			if _s.label_pressed: return "label_already_pressed"
			_s.label_lifted = true
		elif _tool == "press":
			if not _s.label_aligned or not _s.protector_placed: return "align_and_protect_first"
			if not Rect2(_label_target(), LABEL_SIZE).has_point(pointer): return "no_material_contact"
			_s.label_pressed = true
	elif _s.operation_mode == "open":
		if _tool != "opener": return "wrong_tool"
		if not _opening_room(_point(_s.envelope_position)): return "move_to_opening_area"
		if int(_s.seam_count) >= SEAM_COUNT: return "seam_already_open"
		var expected := seam_point(int(_s.seam_count))
		if pointer.distance_to(expected) > SEAM_TOLERANCE:
			# Continuous pointer samples along the already worked corridor are neutral.
			# A jump to an unworked distant endpoint still cannot skip ordered contact.
			if int(_s.seam_count) > 0:
				var nearest := Geometry2D.get_closest_point_to_segment(pointer, seam_point(0), expected)
				if pointer.distance_to(nearest) <= SEAM_TOLERANCE: return ""
			if object_rect("envelope").has_point(pointer):
				_s.tampering_started = true
				_s.privacy_violation = _s.case_id != "case05"
				_s.permanent_damage += 1.0
				_s.tamper_trace += 1.0
				_s.irreversible_damage = true
				_notify()
				return "visible_crease"
			return "no_material_contact"
		# A resealed envelope starts a fresh material cycle. The first effective
		# seam contact counts, even if the player never extracts its contents.
		# Inspection, tool selection and off-seam creases never increment this.
		if int(_s.seam_count) == 0:
			_s.opened_count += 1
			_s.tamper_trace += 0.25
		if not _s.opened:
			_s.opened = true
			_s.opened_history = true
			_s.privacy_violation = _s.case_id != "case05"
		_s.tampering_started = true
		_s.resealed = false
		_s.restored = false
		_s.flap_closed = false
		_s.flap_progress = 0.0
		_s.seam_count += 1
		_s.seal_condition = "open" if int(_s.seam_count) == SEAM_COUNT else "loosened"
	elif _s.operation_mode == "reseal":
		if _tool != "sealer": return "wrong_tool"
		if not _s.flap_closed or _s.paper_location != "inside" or not _all_folds(0.0):
			return "close_flap_after_insertion"
		if not object_rect("flap").has_point(pointer): return "no_material_contact"
		_s.seal_condition = "resealed"
		_s.resealed = true
		_s.restored = true
		# Contents may never have left the envelope. Closing them does not invent reading.
		_s.inserted = true
		_s.insertion_progress = 1.0
		_finish("reseal")
	elif _s.operation_mode=="amend":
		if _tool!="eraser" or not _fully_unfolded():return "unfold_body_before_amending"
		if _s.replacement_placed:return "replacement_already_placed"
		var phrase:=object_rect("phrase")
		if not phrase.has_point(pointer):return "no_material_contact"
		if str(_amendments.get("edit_key","")).is_empty():return "no_editable_sentence"
		var segment:=clampi(int((pointer.x-phrase.position.x)/(phrase.size.x/8.0)),0,7)
		var previous:int=_s.erase_mask
		_s.erase_mask=int(_s.erase_mask)|(1<<segment)
		if previous!=_s.erase_mask:
			if previous==0:_s.tamper_trace+=0.25
			_s.edit_key=str(_amendments.edit_key)
			if _s.erase_mask==255:_finish("amend")
	else:
		return "no_operation"
	_notify()
	return ""


func seam_point(index: int) -> Vector2:
	if _s.is_empty(): return Vector2.ZERO
	return _point(_s.envelope_position) + Vector2(45 + clampi(index, 0, SEAM_COUNT - 1) * 40, 25)


func visible_label_field_ids() -> Array[String]:
	if _s.is_empty() or not _s.exterior_repaired or _s.face != "back": return []
	# UI resolves literal object text from case03.envelope.recovered_fields.
	# The model exposes availability, never the conclusion about the dates.
	return ["original_address", "forwarding_recipient", "forwarding_destination", "forwarding_valid_from", "forwarding_valid_until"]


func body_is_currently_visible() -> bool:
	return not _s.is_empty() and _s.paper_location == "desk" and (float(_s.fold_progress[0]) > 0.25 or float(_s.fold_progress[1]) > 0.25)


func _drag_paper(position: Vector2, delta: Vector2) -> void:
	if _s.operation_mode == "open" and _s.paper_location in ["inside", "partly_extracted"]:
		_s.extraction_progress = clampf(_start_progress + delta.x / EXTRACT_DISTANCE, 0.0, 1.0)
		_s.paper_position = _array(_mouth() + Vector2(float(_s.extraction_progress) * EXTRACT_DISTANCE, 0))
		_s.paper_location = "inside" if is_zero_approx(float(_s.extraction_progress)) else ("desk" if float(_s.extraction_progress) >= 1.0 else "partly_extracted")
		if float(_s.extraction_progress) > 0.0:
			_s.inserted = false
			_s.insertion_progress = 0.0
		else:
			_s.inserted = true
			_s.insertion_progress = 1.0
		if float(_s.extraction_progress) >= 1.0: _s.extracted = true
	elif _s.operation_mode == "reseal" and not _s.extracted and _s.paper_location in ["partly_extracted", "partly_inserted"]:
		# Before full extraction, the still-inserted page remains constrained by the mouth.
		# Reject off-axis attempts instead of teleporting it to a free-standing desk pose.
		var mouth := _mouth()
		if absf(position.y - mouth.y) > 22.0: return
		_s.extraction_progress = clampf((position.x - mouth.x) / EXTRACT_DISTANCE, 0.0, 1.0)
		_s.insertion_progress = 1.0 - float(_s.extraction_progress)
		_s.paper_position = _array(mouth + Vector2(float(_s.extraction_progress) * EXTRACT_DISTANCE, 0))
		_s.paper_location = "desk" if float(_s.extraction_progress) >= 1.0 else "partly_inserted"
		if float(_s.extraction_progress) >= 1.0: _s.extracted = true
	else:
		var old_position:=_point(_s.paper_position)
		_s.paper_position = _array(position.clamp(TABLE.position, PAGE_MAX_ORIGIN))
		if _s.replacement_placed:_s.replacement_position=_array(_point(_s.replacement_position)+_point(_s.paper_position)-old_position)
		if _s.operation_mode == "reseal":
			var mouth := _mouth()
			var ready: bool = absf(position.y - mouth.y) <= 22.0 and position.x >= mouth.x - 8.0
			_s.insertion_progress = clampf(1.0 - (position.x - mouth.x) / EXTRACT_DISTANCE, 0.0, 1.0) if ready else 0.0
			_s.paper_location = "partly_inserted" if float(_s.insertion_progress) > 0.0 else "desk"


func _label_target() -> Vector2:
	return _point(_s.envelope_position) + Vector2(190, 130)


func _mouth() -> Vector2:
	return _point(_s.envelope_position) + Vector2(420, 65)


func _all_folds(value: float) -> bool:
	return is_equal_approx(float(_s.fold_progress[0]), value) and is_equal_approx(float(_s.fold_progress[1]), value)


func _finish(mode: String) -> void:
	_s.operation_mode = ""
	_s.completion_serial += 1
	_clear_input()
	operation_completed.emit(mode, export_state())


func _notify() -> void:
	changed.emit(export_state())


func _clear_input() -> void:
	_tool = ""
	_drag = ""
	_moved = false
	_grab = Vector2.ZERO
	_start_pointer = Vector2.ZERO
	_start_progress = 0.0


static func _array(point: Vector2) -> Array:
	return [point.x, point.y]


static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _initial(case_id: String) -> Dictionary:
	return {
		"version": VERSION, "case_id": case_id, "operation_mode": "", "completion_serial": 0,
		"inspected_front": false, "inspected_back": false, "face": "front", "zoom": 1.0, "pan": [0.0, 0.0],
		"opened": false, "opened_history": false, "opened_count": 0, "body_unfolded": false, "unfolded": false, "body_exposed": false, "open_cycle_completed": false,
		"extracted": false, "inserted": false, "folded": true, "exterior_repaired": false, "resealed": false, "restored": false,
		"tamper_trace": 0.0, "permanent_damage": 0.0, "repair_quality": 0.0, "irreversible_damage": false,
		"damage_failure": false, "privacy_violation": false, "tampering_started": false, "seal_condition": "intact", "seam_count": 0,
		"envelope_position": [140.0, 160.0], "label_position": [360.0, 315.0], "label_turn": 1,
		"exterior_on_mat": false, "label_lifted": false, "label_aligned": false, "label_pressed": false,
		"protector_position": [940.0, 440.0], "protector_placed": false,
		"exterior_fold_progress": 0.0, "exterior_fold_aligned": false,
		"paper_location": "inside", "paper_position": [560.0, 225.0], "extraction_progress": 0.0,
		"fold_progress": [0.0, 0.0], "insertion_progress": 0.0, "flap_progress": 0.0, "flap_closed": false,
		"edit_key":"", "erase_mask":0, "replacement_id":"", "replacement_position":[900.0,85.0], "replacement_placed":false,
		"attachment_location":"with_letter" if case_id=="case03" else "none", "attachment_position":[935.0,420.0], "attachment_moved":false
	}


static func _validate(value: Dictionary) -> String:
	if value.get("case_id", "") not in CASE_IDS or value.get("version", 0) != VERSION: return "unsupported_snapshot"
	var template := _initial(str(value.case_id))
	if value.size() != template.size(): return "snapshot_fields_mismatch"
	for key: String in template:
		if not value.has(key): return "snapshot_fields_mismatch"
		var expected: Variant = template[key]
		var actual: Variant = value[key]
		if expected is bool:
			if not actual is bool: return "invalid_boolean"
		elif expected is String:
			if not actual is String: return "invalid_string"
		elif expected is Array:
			if not actual is Array or actual.size() != 2: return "invalid_pair"
			for item: Variant in actual:
				if not _finite_number(item): return "invalid_pair"
		else:
			if not _finite_number(actual): return "invalid_number"
	for key: String in ["version", "completion_serial", "seam_count", "label_turn", "opened_count", "erase_mask"]:
		if float(value[key]) != floorf(float(value[key])) or float(value[key]) < 0: return "invalid_integer"
	if value.operation_mode not in MODES or value.face not in ["front", "back"]: return "invalid_mode"
	if value.seal_condition not in ["intact", "loosened", "open", "closed_unsealed", "resealed"]: return "invalid_seal"
	if value.paper_location not in ["inside", "partly_extracted", "desk", "partly_inserted"]: return "invalid_paper_location"
	if float(value.zoom) < 1.0 or float(value.zoom) > 3.0: return "invalid_zoom"
	var pan := _point(value.pan)
	if absf(pan.x) > 500.0 or absf(pan.y) > 300.0: return "invalid_pan"
	if int(value.seam_count) > SEAM_COUNT or int(value.label_turn) > 3: return "invalid_geometry"
	for key: String in ["exterior_fold_progress", "extraction_progress", "insertion_progress", "flap_progress", "repair_quality"]:
		if float(value[key]) < 0.0 or float(value[key]) > 1.0: return "invalid_progress"
	for part: Variant in value.fold_progress:
		if float(part) < 0.0 or float(part) > 1.0: return "invalid_fold"
	if float(value.tamper_trace) < float(value.permanent_damage) or float(value.permanent_damage) < 0: return "invalid_trace"
	if value.irreversible_damage != (float(value.permanent_damage) > 0.0): return "invalid_damage_summary"
	if value.irreversible_damage and not value.tampering_started: return "missing_damage_history"
	if value.damage_failure: return "unsupported_failure_state"
	if value.case_id == "case05" and value.privacy_violation: return "invalid_staff_violation"
	if value.opened != value.opened_history or (value.privacy_violation and not value.tampering_started): return "invalid_history"
	if value.opened != (int(value.opened_count) > 0): return "invalid_opening_count"
	if float(value.tamper_trace) + 0.00001 < float(value.permanent_damage) + float(value.opened_count) * 0.25: return "missing_breach_trace"
	if value.opened and not value.tampering_started: return "missing_handling_history"
	if value.tampering_started and value.case_id != "case05" and not value.privacy_violation: return "missing_private_history"
	if value.body_unfolded != value.unfolded or (value.body_unfolded and not value.body_exposed): return "invalid_body_history"
	if value.open_cycle_completed and not value.body_unfolded: return "unearned_open_completion"
	var folded: bool = is_zero_approx(float(value.fold_progress[0])) and is_zero_approx(float(value.fold_progress[1]))
	if value.folded != folded: return "invalid_fold_summary"
	if value.paper_location == "inside" and not folded: return "unfolded_inside_envelope"
	if value.paper_location != "inside" and (not value.opened or int(value.seam_count) != SEAM_COUNT or value.seal_condition != "open"):
		return "paper_outside_closed_envelope"
	if value.paper_location == "desk" and (not value.extracted or float(value.extraction_progress) < 1.0): return "unearned_extraction"
	if value.paper_location == "partly_extracted" and float(value.extraction_progress) >= 1.0: return "invalid_partial_extraction"
	if value.paper_location == "partly_inserted" and not folded: return "unfolded_insertion"
	if value.paper_location == "partly_inserted" and float(value.insertion_progress) <= 0.0: return "invalid_partial_insertion"
	if value.inserted and (value.paper_location != "inside" or not is_equal_approx(float(value.insertion_progress), 1.0)):
		return "invalid_insertion_summary"
	if (value.extracted or value.body_exposed) and not value.opened: return "unearned_body_state"
	if value.body_exposed and not value.extracted: return "unextracted_body_state"
	if value.exterior_repaired and (value.case_id != "case03" or not value.label_pressed or not value.exterior_fold_aligned): return "invalid_repair"
	if value.label_pressed and (value.case_id != "case03" or not value.label_lifted or not value.label_aligned or not value.protector_placed): return "invalid_label_press"
	if value.exterior_fold_aligned and (not value.label_pressed or float(value.exterior_fold_progress) < 1.0): return "invalid_exterior_fold"
	if value.label_aligned and (not value.label_lifted or int(value.label_turn) != 0): return "invalid_label_alignment"
	if value.resealed != value.restored: return "invalid_reseal_summary"
	if value.resealed and (value.seal_condition != "resealed" or value.paper_location != "inside" or not value.flap_closed): return "invalid_reseal"
	if value.seal_condition == "resealed" and not value.resealed: return "missing_reseal_summary"
	if value.seal_condition in ["open", "closed_unsealed"] and int(value.seam_count) != SEAM_COUNT: return "incomplete_open_seam"
	if value.seal_condition == "loosened" and (int(value.seam_count) < 1 or int(value.seam_count) >= SEAM_COUNT): return "invalid_partial_seam"
	if not value.opened and int(value.seam_count) != 0: return "unearned_seam_state"
	if value.seal_condition == "intact" and (value.opened or value.extracted or value.body_exposed): return "intact_with_open_history"
	if value.operation_mode == "repair_exterior" and value.case_id != "case03": return "invalid_repair_authorization"
	if (value.operation_mode == "open" or value.seal_condition in ["loosened", "open", "closed_unsealed"]) and not _opening_room(_point(value.envelope_position)):
		return "inaccessible_opening_area"
	if not TABLE.encloses(Rect2(_point(value.envelope_position), ENVELOPE_SIZE)): return "envelope_outside_workspace"
	if not TABLE.encloses(Rect2(_point(value.label_position), LABEL_SIZE)): return "label_outside_workspace"
	if not TABLE.encloses(Rect2(_point(value.protector_position), Vector2(180, 120))): return "protector_outside_workspace"
	var paper := _point(value.paper_position)
	if value.paper_location != "inside" and (paper.x < 0.0 or paper.y < 0.0 or paper.x > PAGE_MAX_ORIGIN.x or paper.y > PAGE_MAX_ORIGIN.y):
		return "paper_gestures_outside_workspace"
	if not TABLE.grow(1).has_point(paper): return "paper_outside_workspace"
	if int(value.erase_mask)>255:return "invalid_erasure_mask"
	if (int(value.erase_mask)>0)!=not str(value.edit_key).is_empty():return "missing_edit_identity"
	if int(value.erase_mask)>0 and (not value.body_unfolded or value.case_id not in ["case02","case04"]):return "unearned_erasure"
	if value.replacement_placed!=(not str(value.replacement_id).is_empty()):return "invalid_replacement_identity"
	if value.replacement_placed and value.erase_mask!=255:return "replacement_before_erasure"
	if value.attachment_location not in (["with_letter","desk"] if value.case_id=="case03" else ["none"]):return "invalid_attachment"
	if (value.attachment_moved or value.attachment_location=="desk") and (value.case_id!="case03" or not value.body_unfolded):return "unearned_attachment_access"
	if value.attachment_location=="desk" and not value.attachment_moved:return "missing_attachment_history"
	if not TABLE.encloses(Rect2(_point(value.replacement_position),Vector2(196,78))):return "replacement_outside_workspace"
	if not TABLE.encloses(Rect2(_point(value.attachment_position),Vector2(112,78))):return "attachment_outside_workspace"
	return ""


func _fully_unfolded() -> bool:
	return _s.paper_location=="desk" and _all_folds(1.0) and _s.body_unfolded


func _attachment_slot() -> Vector2:
	return _point(_s.paper_position)+Vector2(37,73)


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _opening_room(position: Vector2) -> bool:
	return position.x >= 0.0 and position.y >= 0.0 and position.x <= OPENING_MAX_ORIGIN.x and position.y <= OPENING_MAX_ORIGIN.y
