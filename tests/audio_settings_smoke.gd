extends SceneTree
const Sound = preload("res://scripts/ui/audio_feedback.gd")
const Main = preload("res://scripts/main.gd")
var checks: int = 0
var failures: Array[String] = []
var settings_file: String

func _initialize() -> void:
	_run.call_deferred()

func _new_audio(path: String) -> AudioFeedback:
	var player := Sound.new()
	player.settings_path = path
	root.add_child(player)
	player.set_process(false)
	return player

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	settings_file = "user://qa/audio_preferences_%d.cfg" % Time.get_ticks_usec()
	var sentinel_path: String = settings_file + ".game-progress.json"
	var sentinel := FileAccess.open(sentinel_path,FileAccess.WRITE)
	sentinel.store_string('{"progress":"do not overwrite"}')
	sentinel.close()
	var audio := _new_audio(settings_file)
	check(audio.get_volumes() == {"music":.75,"effects":.85,"ambience":.85},"missing preference file keeps the initial listening levels")
	check(not audio.muted,"missing preference file does not accidentally mute sound")
	audio.set_volumes(.21,.48,.73)
	check(audio.save_settings() == OK,"three independent volume gains save successfully")
	var gains: Dictionary = audio.get_volumes()
	audio.set_muted(true)
	check(audio.get_volumes() == gains,"master mute retains all user gains")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.MUSIC_BUS)) and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)) and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.AMBIENT_BUS)),"master mute silences all three game buses")
	audio.set_volumes(.34,.52,.85)
	check(audio.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)),"adjusting a slider while muted does not unmute audio")
	audio.save_settings()
	audio.queue_free()
	await process_frame
	audio = _new_audio(settings_file)
	check(audio.muted,"a new AudioFeedback instance restores saved master mute on startup")
	check(audio.get_volumes() == {"music":.34,"effects":.52,"ambience":.85},"restart restores the exact independently adjusted gains")
	audio.set_muted(false)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)),"unmute restores sound without moving the effects slider")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sound.SFX_BUS)) - linear_to_db(.52)) < .001,"unmute applies the retained effects gain")
	audio.set_volumes(0,.52,.85)
	audio.save_settings()
	audio.queue_free()
	await process_frame
	audio = _new_audio(settings_file)
	check(not audio.muted and audio.get_volumes().music == 0,"zero music volume is preserved separately from master mute")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.MUSIC_BUS)) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)),"restart keeps zero music silent while leaving effects audible")
	var malformed := ConfigFile.new()
	malformed.set_value("audio","music",4.2)
	malformed.set_value("audio","effects",-3)
	malformed.set_value("audio","ambience","invalid")
	malformed.set_value("audio","muted","true")
	malformed.save(settings_file)
	audio.load_settings()
	check(audio.get_volumes() == {"music":1.0,"effects":0.0,"ambience":.85},"loaded out-of-range gains clamp and invalid types use safe defaults")
	check(not audio.muted,"a nonboolean stored mute value cannot silently enable mute")
	audio.set_volumes(NAN,INF,.42)
	check(audio.get_volumes() == {"music":1.0,"effects":0.0,"ambience":.42},"nonfinite gain requests never reach an audio bus")
	check(FileAccess.get_file_as_string(sentinel_path) == '{"progress":"do not overwrite"}',"preference writes leave the separate progress fixture byte-for-byte unchanged")
	audio.queue_free()
	await process_frame
	var main: Control = Main.new()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.sound.settings_path = settings_file
	main.sound.set_muted(false)
	main.sound.set_volumes(.75,.85,.85)
	var state_before: String = JSON.stringify(main.game.state)
	main._audio_settings()
	var music_slider: HSlider = main.overlay.find_child("MusicVolume",true,false)
	var effects_slider: HSlider = main.overlay.find_child("EffectsVolume",true,false)
	var ambience_slider: HSlider = main.overlay.find_child("AmbienceVolume",true,false)
	var mute: CheckButton = main.overlay.find_child("MasterMute",true,false)
	check(music_slider != null and effects_slider != null and ambience_slider != null and mute != null,"settings screen exposes three keyboard-accessible sliders and master mute")
	music_slider.value = 37
	effects_slider.value = 61
	ambience_slider.value = 28
	check(main.sound.get_volumes() == {"music":.37,"effects":.61,"ambience":.28},"each real slider signal changes only its own audio channel")
	mute.button_pressed = true
	var saved := ConfigFile.new()
	saved.load(settings_file)
	check(saved.get_value("audio","muted") == true and saved.get_value("audio","music") == .37 and saved.get_value("audio","effects") == .61 and saved.get_value("audio","ambience") == .28,"UI interactions persist current gains and mute to the independent settings file")
	check(JSON.stringify(main.game.state) == state_before,"changing audio settings does not modify game progress")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/audio_settings.png")
	main.queue_free()
	await process_frame
	await create_timer(.2).timeout
	print("AUDIO SETTINGS SMOKE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
