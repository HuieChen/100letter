extends SceneTree
## Run with the matching official editor as an inspector of the actual PCK.
## Release templates disable external script/path overrides; test their boot separately.
## Does not write game state, invoke gameplay completion, or use workspace resources.
var failures: Array[String] = []
var checks := 0
const BOUND_SHADERS := ["settings_water","lemon_companion_water","pdf_tape_matte","pdf_color_matte"]
var expected_shader_sha256:Dictionary={}
var observed_shader_sha256:Dictionary={}
var packaged_no_focus:=false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_require_shader_hashes()
	packaged_no_focus=bool(ProjectSettings.get_setting("display/window/size/no_focus",false))
	_check(not packaged_no_focus,"actual player package does not contain the QA no-focus startup override")
	for path:String in ["res://assets/fonts/DynaPuff-OFL.txt","res://assets/fonts/ZCOOLKuaiLe-OFL.txt","res://assets/fonts/LilitaOne-OFL.txt","res://assets/fonts/NotoSansSC-OFL.txt","res://assets/fonts/settings-font-provenance.json","res://assets/audio/foley/WATER_CC0.txt","res://assets/audio/foley/water-provenance.json","res://assets/audio/SETTINGS_MUSIC_CC0.txt","res://assets/audio/settings-music-provenance.json","res://third_party/webgl-water/LICENSE-MIT.txt"]:
		_check(FileAccess.file_exists(path),"settings license/provenance exists in actual package "+path)
	for name:String in ["DynaPuff","ZCOOLKuaiLe","LilitaOne"]:
		var font:Font=load("res://assets/fonts/"+name+".ttf")
		_check(font!=null,"actual settings font decodes "+name)
		var chars:String="SettingsLanguageDisplayModeResolutionMasterVolumeMusicSFXMouseSensitivityTextSpeed" if name!="ZCOOLKuaiLe" else "设置语言显示模式分辨率总音乐效量鼠标灵敏度文字速度中文界面窗口全屏无边框慢快即时"
		for c:String in chars:_check(font.has_char(c.unicode_at(0)),"actual font glyph "+c)
	_verify_packaged_shader("settings_water","water shader exists in actual package")
	_check(load("res://scripts/ui/water_field.gd") is Script,"continuous surface-wave port exists in actual package")
	_check(load("res://scripts/ui/lemon_white_matte.gdshader") is Shader,"lemon-specific fringe recovery survives actual packaging")
	_verify_packaged_shader("lemon_companion_water","original fruit shadows and arcs follow the packaged native fruit compositor")
	_verify_packaged_shader("pdf_tape_matte","source-specific tape edge recovery survives actual packaging")
	_verify_packaged_shader("pdf_color_matte","original blue paper edge coverage survives actual packaging")
	var soundtrack:=load("res://assets/audio/settings_vaporware.ogg") as AudioStreamOggVorbis
	_check(soundtrack!=null and soundtrack.get_length()>160,"Settings soundtrack is decoded from actual PCK")
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
			var video_role:bool=id=="CHAR_courier" or id=="CHAR_courier_walk" or (id.begins_with("CHAR_courier_walk_") and int(id.trim_prefix("CHAR_courier_walk_")) in range(6))
			var authorized_video:bool=video_role and entry.get("source_kind","")=="user_video_extraction" and entry.get("source_video_sha256","")==manifest.get("user_animation_override",{}).get("source_video_sha256","missing")
			var authorized_pdf:bool=id in manifest.get("settings_ui_override",{}).get("scope",[]) and entry.get("source_kind","")=="user_pdf_embedded_image_exact_bytes" and entry.get("source_pdf_sha256","")=="ff54771c8c7d98ee2d9cfeeac496eb203a324ebc96a3b9a5dcba9853f19c191f"
			_check(path.begins_with("res://assets/faefever_v2/") and (entry.get("ai_generated", false) or authorized_video or authorized_pdf), id + " has reviewed generated or explicitly supplied source provenance")
			_check(ResourceLoader.exists(path) and load(path) is Texture2D, id + " actually decodes from packaged import resource")
	var required_roles: Array[String] = ["BG_workroom", "workroom", "mail_box_base", "mail_box_lid", "mail_box_latch", "envelope_front", "envelope_back", "letter_paper", "handbook_closed", "handbook_open", "resolution_slip", "postal_seal", "drawer_open", "drawer_front", "magnifier", "opener", "restorer", "press", "eraser", "sealer", "repair_label", "protector", "envelope_flap", "attachment_photo", "old_music_photo", "replacement_strip", "service_paper", "paper_corner", "wall_closeup", "wall_plate_old", "wall_plate_new", "door_closeup", "door_plate", "pen", "seal_mark", "satchel", "cover", "town_map", "BG_post_office", "BG_community_center", "BG_bus_stop", "BG_lookout", "BG_residential", "BG_chess_stall", "BG_tarot_shop", "CHAR_courier", "CHAR_mira", "CHAR_june", "CHAR_chenyuan", "CHAR_elsie", "CHAR_clerk"]
	var walk_geometry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/faefever_v2/characters/courier_walk_regions.json"))
	_check(walk_geometry is Dictionary and walk_geometry.get("frames",[]).size()==6 and walk_geometry.get("source_kind","")=="user_video_extraction","package preserves the six authored video walking frames and source provenance")
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
	for helper:String in ["mail_imprint","physical_envelope"]:
		_check(load("res://scripts/rebuild/"+helper+".gd") is Script,"physical envelope helper decodes from the actual package: "+helper)
	_check(manifest.get("style_lock","")=="SOLMERE_SOFT_PASTEL_20261004","actual package selects the latest globally requested visual style")
	var main: Variant = load("res://scenes/final_slice.tscn")
	_check(main is PackedScene, "release entry decodes as PackedScene")
	if main is PackedScene:
		var instance: Node = main.instantiate()
		root.add_child(instance)
		await process_frame; await process_frame
		_check(instance.get("view") == "title", "packaged host starts at actual title")
		_check(instance.find_child("TitleArtwork",true,false)==null and instance.find_child("TitleGround",true,false)!=null,"actual package uses the plain title instead of old illustration")
		var title:Label=instance.find_child("GameTitle",true,false) as Label
		_check(title!=null and title.text=="Dear Somewhere","actual package displays the game name on its cover")
		_check(ProjectSettings.get_setting("application/config/name")=="Dear Somewhere","actual packaged project has the correct game name")
		_check(OS.get_user_data_dir().replace("\\","/").ends_with("Godot/app_userdata/一百信 · Solmere Post"),"Windows packaged rename preserves the original user data directory")
		instance.set("allow_display_changes",false);instance.call("_settings_page")
		await process_frame;await process_frame
		var settings:Control=instance.get("modal")
		_check(settings!=null and settings.get("surface")!=null,"actual packaged Settings mounts its physical water world")
		if settings!=null and settings.get("surface")!=null:
			var surface:Node2D=settings.get("surface")
			var bodies:Array=surface.get("bodies")
			_check(surface.call("press_lemon",1,bodies[1].position),"packaged native fruit pressure begins")
			for frame:int in 12:await physics_frame;await process_frame
			var held_state:Dictionary=surface.call("snapshot")
			_check(held_state.active_presses==1 and held_state.bodies[1].press.depth>3.0,"actual packaged pressure remains held with small submergence")
			_check(surface.call("release_lemon",1),"packaged native pressure releases")
			_check(surface.call("snapshot").active_presses==0,"packaged pressure leaves no stuck capture")
			settings.call("request_close");await process_frame
			_check(instance.get("modal")==null,"packaged Settings arrow-close path removes the physical world")
		for player: Node in instance.find_children("*", "AudioStreamPlayer", true, false):
			player.stop(); player.stream = null
		await create_timer(0.15).timeout
		instance.queue_free(); await process_frame; await process_frame
	var report := {"suite":"packaged_content", "checks":checks, "failures":failures,
		"engine":Engine.get_version_info(), "main_pack":ProjectSettings.globalize_path("res://"),
		"packaged_no_focus":packaged_no_focus,"expected_shader_sha256":expected_shader_sha256,"observed_shader_sha256":observed_shader_sha256,
		"scope":"Actual PCK decoded by the matching Godot editor inspector and packaged entry initialized; separate release executable boot, complete native/human playthrough and listening are not implied."}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--package-report="):
			var file := FileAccess.open(argument.trim_prefix("--package-report="), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("PACKAGED CONTENT ", checks, " checks / ", failures.size(), " failures")
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _require_shader_hashes()->void:
	var hexadecimal:=RegEx.new();hexadecimal.compile("^[0-9a-f]{64}$")
	for argument:String in OS.get_cmdline_user_args():
		for name:String in BOUND_SHADERS:
			var prefix:="--shader-sha-"+name+"="
			if argument.begins_with(prefix):
				if expected_shader_sha256.has(name):_check(false,"duplicate expected shader hash argument: "+name)
				expected_shader_sha256[name]=argument.trim_prefix(prefix).to_lower()
	for name:String in BOUND_SHADERS:
		var value:String=expected_shader_sha256.get(name,"")
		_check(hexadecimal.search(value)!=null,"required current-source SHA256 argument supplied: "+name)

func _verify_packaged_shader(name:String,label:String)->void:
	var shader:Shader=load("res://scripts/ui/"+name+".gdshader") as Shader
	_check(shader!=null,label)
	var actual:=""
	if shader!=null:
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
		digest.update(shader.code.replace("\r\n","\n").to_utf8_buffer())
		actual=digest.finish().hex_encode()
	observed_shader_sha256[name]=actual
	_check(not actual.is_empty() and actual==str(expected_shader_sha256.get(name,"")),"actual PCK Shader.code matches LF-normalized tested source: "+name)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
