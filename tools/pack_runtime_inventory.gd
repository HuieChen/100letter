extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected inventory.json and output.pck arguments")
		quit(1)
		return
	var inventory = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not inventory is Dictionary or not inventory.get("entries") is Array:
		push_error("Invalid runtime inventory")
		quit(1)
		return
	var pack := PCKPacker.new()
	if pack.pck_start(args[1]) != OK:
		quit(1)
		return
	for entry: Dictionary in inventory.entries:
		if FileAccess.get_sha256(entry.source) != entry.sha256:
			push_error("Source mismatch: " + entry.path)
			quit(1)
			return
		if pack.add_file(entry.path, entry.source) != OK:
			push_error("Cannot pack: " + entry.path)
			quit(1)
			return
	if pack.flush() != OK or not ProjectSettings.load_resource_pack(args[1], true):
		quit(1)
		return
	for entry: Dictionary in inventory.entries:
		if FileAccess.get_sha256(entry.path) != entry.sha256:
			push_error("Packed content mismatch: " + entry.path)
			quit(1)
			return
	print("RUNTIME_PACK_VERIFIED ", inventory.total_entries, " entries")
	quit()
