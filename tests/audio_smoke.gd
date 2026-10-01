extends SceneTree
const Sound = preload("res://scripts/ui/audio_feedback.gd")
var checks: int = 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var audio: AudioFeedback

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	audio = Sound.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	audio.settings_path = "user://qa/audio_smoke_%d.cfg" % Time.get_ticks_usec()
	root.add_child(audio)
	audio.set_process(false)
	audio.cue_played.connect(func(kind: String, file: String) -> void: events.append({"kind":kind,"file":file}))
	for filename: String in Sound.BEDS:
		var stream: AudioStream = audio._stream(filename)
		check(stream != null and stream.get_length() > 25.0, "recorded ambience decodes: " + filename)
	check(audio._beds.size() == 4, "four independently mixed beds have their own players")
	var signatures: Array[String] = []
	for id: String in ["post_office", "community_center", "bus_stop", "lookout", "residential", "chess_stall", "tarot_shop"]:
		audio.set_location(id,600,false)
		var signature: String = JSON.stringify(audio._targets)
		check(not signature in signatures, "location has a distinct sound mix: " + id)
		signatures.append(signature)
	audio.set_location("lookout",600,false)
	var before: float = audio._bed_gains["sea_bed.ogg"]
	audio._process(.1)
	check(audio._bed_gains["sea_bed.ogg"] > before and audio._bed_gains["sea_bed.ogg"] < audio._targets["sea_bed.ogg"], "coast bed fades in instead of jumping to full level")
	audio.set_location("post_office",600,true)
	check(audio._targets["room_bed.ogg"] > 0.0 and audio._targets["town_bed.ogg"] == 0.0, "indoor context routes a filtered room bed")
	check(audio._targets["sea_bed.ogg"] < db_to_linear(-35.0), "outdoor sea is muffled through the indoor boundary")
	audio.play("paper")
	audio.play("paper")
	check(events.size() == 1, "same-frame duplicate paper cues are cooled down")
	var initial_paper: String = events[-1].file
	audio._process(.3)
	audio.play("paper")
	check(events[-1].file != initial_paper, "paper action avoids immediately repeating a sample")
	audio._process(.3)
	audio.play("step")
	check("wood" in str(events[-1].file), "interior foot contact uses a wooden surface")
	audio.set_location("residential",600,false)
	audio._process(.3)
	audio.play("step")
	check("grass" in str(events[-1].file), "courtyard contact uses the softer surface pool")
	audio.set_location("bus_stop",600,false)
	audio._process(.3)
	audio.play("step")
	check("concrete" in str(events[-1].file), "street contact uses stone/concrete foley")
	var master_before: bool = AudioServer.is_bus_mute(0)
	audio.toggle()
	var count: int = events.size()
	audio._process(.3)
	audio.play("door")
	check(events.size() == count, "mute suppresses new action cues")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)), "mute applies to the game's effects bus")
	check(AudioServer.is_bus_mute(0) == master_before, "game mute does not overwrite the master bus setting")
	audio.toggle()
	audio.set_volumes(0.0,.6,.4)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.MUSIC_BUS)), "music can be silenced independently")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)), "effects remain enabled when music volume is zero")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Sound.AMBIENT_BUS)) - linear_to_db(.4)) < .01, "environment has its own volume control")
	audio.quiet_case(true)
	check(audio._quiet, "intimate letter scenes request the lower music target")
	for kind: String in Sound.POOLS:
		for file: String in Sound.POOLS[kind]:
			check(audio._stream(file) != null and audio._stream(file).get_length() > 0, "action sample decodes: " + file)
	audio._spawn("test_ambient", "tram_pass.wav", -30, Sound.AMBIENT_BUS)
	audio.set_location("community_center",600,true)
	var stale: bool = false
	for shot: AudioStreamPlayer in audio._shots:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion() and shot.bus == Sound.AMBIENT_BUS: stale = true
	check(not stale, "a tram passage cannot follow the player into another room")
	audio.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("AUDIO SMOKE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
