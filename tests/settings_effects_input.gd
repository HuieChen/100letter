extends "res://tests/core_review_input.gd"
## Endpoint checks after real settings clicks/drags. No slider assignment,
## preference mutation, mocked AudioServer or direct signal emission.
const EFFECTS_OUT := "res://test-results/fullflow-20261018/settings/"
var measured: Dictionary = {}

func _run() -> void:
	root.unfocusable = true
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1600,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var slot := "user://qa/settings-effects/" + run_id + "/preferences.json"
	host = Host.new()
	host.allow_display_changes = false # Native display has its own genuine-window suite.
	host.preferences_path = slot
	root.add_child(host)
	host.core.save_path = "user://qa/settings-effects/" + run_id + "/story.json"
	root.position = Vector2i(-12000,-12000)
	await _named("OpenSettings")
	_check(host.sound.menu_music.playing, "settings starts the actual music stream")
	await _slider_to("master", 0.0)
	_check(AudioServer.is_bus_mute(0), "master zero really mutes Master")
	await _slider_to("master", 0.71)
	_check(not AudioServer.is_bus_mute(0), "raising master really unmutes output")
	_check(_bus_level("Master", host.preferences.values.master), "master output gain matches drag")
	await _slider_to("music", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SolmereMusic")), "music zero really mutes its mixer bus")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SolmereFoley")), "muting music leaves effects available")
	await _slider_to("music", 0.31)
	_check(_bus_level("SolmereMusic", host.preferences.values.music), "music drag changes actual mixer gain")
	_check(host.sound.menu_music.bus == "SolmereMusic" and host.sound.music.bus == "SolmereMusic", "menu and in-world music both use controlled bus")
	await _slider_to("sfx", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SolmereFoley")), "SFX zero really mutes Foley")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SolmereAmbience")), "SFX zero also mutes environmental sound")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SolmereMusic")), "muting SFX leaves music available")
	await _slider_to("sfx", 0.62)
	_check(_bus_level("SolmereFoley", host.preferences.values.sfx) and _bus_level("SolmereAmbience", host.preferences.values.sfx), "SFX drag changes Foley and ambience gains")
	await _slider_to("sensitivity", 1.0)
	await _select("language", 1)
	_check(host.find_child("NewShift",true,false).text == "New shift", "language changes actual title interface")
	await _select("text_speed", 0)
	await _named("CloseSettings")
	await _named("NewShift")
	await _wait(func():return _node("FinishBriefing")!=null, "normal game creates supervisor dialogue")
	var dialogue: Control = host.modal
	await create_timer(0.22).timeout
	var slow_chars: int = dialogue._spoken.visible_characters
	_check(slow_chars > 0 and slow_chars < dialogue._spoken.get_total_character_count(), "slow setting really reveals a partial line")
	measured.slow = {"rate":dialogue._text_rate,"visible_characters":slow_chars,"total":dialogue._spoken.get_total_character_count()}
	await _named("FinishBriefing") # Natural first press completes the current line.
	_check(is_instance_valid(host.modal) and dialogue._spoken.visible_characters == -1, "advance during typing reveals all text without skipping the dialogue")
	await _named("FinishBriefing")
	await _key(KEY_ESCAPE)
	await _text("Settings")
	await _select("text_speed", 2)
	await _named("CloseSettings")
	await _text("Save and title")
	await _named("NewShift")
	await _text("Start new shift")
	await _wait(func():return _node("FinishBriefing")!=null, "new normal briefing after changed speed")
	dialogue = host.modal
	await create_timer(0.22).timeout
	var fast_chars: int = dialogue._spoken.visible_characters
	_check(fast_chars > slow_chars * 2 and fast_chars < dialogue._spoken.get_total_character_count(), "fast setting reveals substantially more actual characters over the same interval")
	measured.fast = {"rate":dialogue._text_rate,"visible_characters":fast_chars,"total":dialogue._spoken.get_total_character_count()}
	var saved: Dictionary = host.preferences.values.duplicate(true)
	host.queue_free()
	await process_frame
	await process_frame
	host = Host.new()
	host.allow_display_changes = false
	host.preferences_path = slot
	root.add_child(host)
	_check(host.preferences.loaded and host.preferences.values == saved, "fresh host restores all selected settings")
	_check(_bus_level("Master",saved.master) and _bus_level("SolmereMusic",saved.music) and _bus_level("SolmereFoley",saved.sfx), "fresh host reapplies saved gains to actual AudioServer buses")
	_check(_node("NewShift").text == "New shift", "fresh title restores selected interface language")
	await _named("OpenSettings")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(EFFECTS_OUT)
	var capture := EFFECTS_OUT + "restored_en_1920.png"
	_check(root.get_texture().get_image().save_png(capture) == OK, "actual restored settings frame saved")
	await _named("CloseSettings")
	host.queue_free()
	await process_frame
	var file := FileAccess.open(EFFECTS_OUT + "results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite":"settings_effects_input","checks":checks,"failures":failures,"measured_dialogue":measured,"saved_values":saved,"screenshots":[capture],"scope":"Actual routed setting clicks/drags, AudioServer gains/mutes, timed real dialogue, fresh-host restoration. Complemented by real paper zoom/pan and native-window geometry suites. No listening or human acceptance claim."},"\t"))
	file.close()
	print("SETTINGS EFFECTS: %d checks, %d failures" % [checks,failures.size()])
	for failure: String in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _slider_to(key: String, fraction: float) -> void:
	var slider: Slider = host.modal.controls[key]
	var rect := slider.get_global_rect()
	var left := rect.position + Vector2(12,rect.size.y*0.5)
	var right := rect.position + Vector2(rect.size.x-12,rect.size.y*0.5)
	await _drag(slider.get_global_rect().get_center(),left.lerp(right,fraction))
	_check(is_equal_approx(slider.value,host.preferences.values[key]), "actual drag reaches preference: " + key)
	_check(slider.value == slider.min_value if fraction == 0.0 else slider.value > slider.min_value, "actual slider moved: " + key)

func _select(key: String, index: int) -> void:
	await _named("Setting_" + key)
	await _named("Option_" + key + "_" + str(index))
	await process_frame
	await process_frame

func _bus_level(bus: String, expected: float) -> bool:
	var index := AudioServer.get_bus_index(bus)
	return index >= 0 and not AudioServer.is_bus_mute(index) and absf(db_to_linear(AudioServer.get_bus_volume_db(index))-expected) < 0.002
