extends SceneTree
## Run with the matching official editor as an inspector of the actual PCK.
## Release templates disable external script/path overrides; test their boot separately.
## Does not write game state, invoke gameplay completion, or use workspace resources.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(FileAccess.file_exists("res://data/rebuild/final_cases.json"), "runtime catalog exists in package")
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/rebuild/final_cases.json"))
	_check(catalog is Dictionary and catalog.get("cases", []).size() == 5, "package contains all five authored cases")
	for path: String in ["res://data/rebuild/player_amendments.json", "res://data/rebuild/final_dialogues.json", "res://assets/fonts/OFL.txt", "res://assets/fonts/Caveat-OFL.txt", "res://assets/faefever_v2/characters/courier_walk_regions.json"]:
		_check(FileAccess.file_exists(path), "packaged runtime text/license: " + path)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/faefever_v2/manifest.json"))
	_check(manifest is Dictionary and not manifest.get("assets", {}).is_empty(), "package has adopted generated-art manifest")
	if manifest is Dictionary:
		for id: String in manifest.get("assets", {}):
			var entry: Dictionary = manifest.assets[id]
			var path: String = str(entry.get("path", ""))
			_check(path.begins_with("res://assets/faefever_v2/") and entry.get("ai_generated", false), id + " is registered new generated art")
			_check(ResourceLoader.exists(path) and load(path) is Texture2D, id + " actually decodes from packaged import resource")
	var required_roles: Array[String] = ["BG_workroom", "workroom", "mail_box_base", "mail_box_lid", "mail_box_latch", "envelope_front", "envelope_back", "letter_paper", "handbook_closed", "handbook_open", "resolution_slip", "postal_seal", "drawer_open", "drawer_front", "magnifier", "opener", "restorer", "press", "eraser", "sealer", "repair_label", "protector", "envelope_flap", "attachment_photo", "old_music_photo", "replacement_strip", "service_paper", "paper_corner", "wall_closeup", "wall_plate_old", "wall_plate_new", "door_closeup", "door_plate", "pen", "seal_mark", "satchel", "cover", "town_map", "BG_post_office", "BG_community_center", "BG_bus_stop", "BG_lookout", "BG_residential", "BG_chess_stall", "BG_tarot_shop", "CHAR_courier", "CHAR_mira", "CHAR_june", "CHAR_chenyuan", "CHAR_elsie", "CHAR_clerk"]
	var walk_geometry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/faefever_v2/characters/courier_walk_regions.json"))
	_check(walk_geometry is Dictionary and walk_geometry.get("frames",[]).size()==8,"package preserves eight walking frames and their feet metadata")
	if walk_geometry is Dictionary:
		for frame: Dictionary in walk_geometry.get("frames",[]):
			var key:=str(frame.get("key",""))
			_check(manifest.get("assets",{}).has(key),"walking region is registered: "+key)
			_check(frame.get("foot_anchor_px",[]).size()==2 and float(frame.get("reference_height_px",0))>0,"walking frame has valid foot anchor and common scale: "+key)
			required_roles.append(key)
	var material_provider: Variant = load("res://scripts/rebuild/physical_art.gd")
	_check(material_provider != null, "packaged material provider loads")
	if material_provider != null:
		var readiness: Dictionary = material_provider.readiness(required_roles)
		_check(readiness.ready, "all scene, character and physical material roles decode without development artwork fallback: " + JSON.stringify(readiness))
	for path: String in ["res://assets/fonts/SolmereSans.ttf", "res://assets/fonts/Caveat.ttf"]:
		_check(load(path) is Font, "packaged font decodes: " + path)
	for path: String in ["res://assets/display_user/street_scenery_USER_20261001_LOCKED.png", "res://assets/locked_user/street_scenery_USER_20261001_LOCKED.psd", "res://assets/characters/generated/courier_sheet.png", "res://assets/characters/generated/chenyuan.png", "res://data/game.json", "res://scenes/main.tscn", "res://scenes/reference_fidelity_prototype.tscn"]:
		_check(not FileAccess.file_exists(path) and not ResourceLoader.exists(path), "superseded source is absent from runtime: " + path)
	_check(load("res://scripts/rebuild/resolution_draft_store.gd") is Script,"unsealed draft persistence helper is packaged")
	var main: Variant = load("res://scenes/final_slice.tscn")
	_check(main is PackedScene, "release entry decodes as PackedScene")
	if main is PackedScene:
		var instance: Node = main.instantiate()
		root.add_child(instance)
		await process_frame; await process_frame
		_check(instance.get("view") == "title", "packaged host starts at actual title")
		_check(instance.find_child("TitleArtwork",true,false)==null and instance.find_child("TitleGround",true,false)!=null,"actual package uses the plain title instead of old illustration")
		var title:Label=instance.find_child("GameTitle",true,false) as Label
		_check(title!=null and title.text=="一百信","actual package displays the game name on its cover")
		for player: Node in instance.find_children("*", "AudioStreamPlayer", true, false):
			player.stop(); player.stream = null
		await create_timer(0.15).timeout
		instance.queue_free(); await process_frame; await process_frame
	var report := {"suite":"packaged_content", "checks":checks, "failures":failures,
		"engine":Engine.get_version_info(), "main_pack":ProjectSettings.globalize_path("res://"),
		"scope":"Actual PCK decoded by the matching Godot editor inspector and packaged entry initialized; separate release executable boot, complete native/human playthrough and listening are not implied."}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--package-report="):
			var file := FileAccess.open(argument.trim_prefix("--package-report="), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("PACKAGED CONTENT ", checks, " checks / ", failures.size(), " failures")
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
