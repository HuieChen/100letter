extends RefCounted
## Versioned JSON storage. Keep the last valid snapshot if a write is interrupted.

const VERSION = 1
const FORMAT = "solmere-post-save"

static func read_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return {}
	var payload = json.data
	if not payload is Dictionary or payload.get("format", "") != FORMAT:
		return {}
	if int(payload.get("version", -1)) != VERSION:
		return {}
	var data = payload.get("state", {})
	if not data is Dictionary or not valid_state(data):
		return {}
	return data

static func valid_state(data: Dictionary) -> bool:
	for key in ["minute", "location", "current_case", "letters", "clues", "visited", "met_npcs", "asked", "journal", "ending", "archive_matched", "reputation", "repair_materials"]:
		if not data.has(key):
			return false
	if not data.letters is Dictionary or not data.ending is String:
		return false
	if not data.location is String or not data.current_case is String:
		return false
	if not data.current_case in ["case01", "case02", "case03", "case04", "case05"]:
		return false
	if not (data.minute is int or data.minute is float) or data.minute < 0:
		return false
	for key in ["reputation", "repair_materials"]:
		if not (data[key] is int or data[key] is float) or data[key] < 0:
			return false
	if not data.archive_matched is bool:
		return false
	for key in ["clues", "visited", "met_npcs", "asked", "journal"]:
		if not data[key] is Array:
			return false
	for key in ["clues", "visited", "met_npcs", "asked"]:
		for value in data[key]:
			if not value is String:
				return false
	for entry in data.journal:
		if not entry is Dictionary or not entry.get("time") is String or not entry.get("text") is String:
			return false
	for id in ["case01", "case02", "case03", "case04", "case05"]:
		if not data.letters.get(id) is Dictionary:
			return false
		for key in ["status", "opened", "restored", "tamper", "repair_solved", "tool", "removed_attachment", "choice", "recipient", "sender", "late", "attempts", "factual_correct", "restore_quality"]:
			if not data.letters[id].has(key):
				return false
		var letter: Dictionary = data.letters[id]
		for key in ["status", "tool", "choice", "recipient", "sender"]:
			if not letter[key] is String:
				return false
		for key in ["opened", "restored", "repair_solved", "removed_attachment", "late", "factual_correct"]:
			if not letter[key] is bool:
				return false
		for key in ["tamper", "attempts", "restore_quality"]:
			if not (letter[key] is int or letter[key] is float):
				return false
	return true

static func write_state(path: String, data: Dictionary) -> bool:
	if not valid_state(data):
		return false
	var absolute = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary = absolute + ".tmp"
	var backup = absolute + ".bak"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"format": FORMAT, "version": VERSION, "state": data}, "\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK or read_state(temporary).is_empty():
		return false
	if FileAccess.file_exists(absolute):
		# Never replace the recovery snapshot with a corrupt primary save.
		if not read_state(absolute).is_empty():
			if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
				return false
			if DirAccess.rename_absolute(absolute, backup) != OK:
				return false
		elif DirAccess.remove_absolute(absolute) != OK:
			return false
	if DirAccess.rename_absolute(temporary, absolute) == OK:
		return true
	# The previous valid snapshot remains recoverable even if final rename fails.
	return false
