class_name AudioFeedback
extends Node
## Licensed recordings/foley live in assets/audio/foley. The older quiet musical
## motif is procedural; it is not described as a field recording.
signal cue_played(kind: String, sample: String)

const ROOT := "res://assets/audio/foley/"
const MUSIC_BUS := "SolmereMusic"
const SFX_BUS := "SolmereFoley"
const AMBIENT_BUS := "SolmereAmbience"
const POOLS := {
	"paper": ["paper_1.wav", "paper_2.wav", "paper_3.wav"],
	"flip": ["paper_unfold.wav", "paper_2.wav"],
	"map": ["paper_unfold.wav"],
	"snap": ["paper_slide.wav"],
	"repair": ["paper_slide.wav", "paper_3.wav"],
	"stamp": ["stamp_1.wav", "stamp_2.wav"],
	"deliver": ["paper_3.wav", "paper_1.wav"],
	"tool": ["tool_metal.wav", "paper_slide.wav"],
	"bell": ["bell.wav"],
	"door": ["door_open.wav"],
	"door_close": ["door_close.wav"],
	"tram": ["tram_pass.wav"],
	"birds": ["birds.wav"],
	"wood": ["wood_piece.wav"],
	"water": ["water_touch_1.wav", "water_touch_2.wav", "water_touch_3.wav"]
}
const BEDS := ["sea_bed.ogg", "town_bed.ogg", "wind_bed.ogg", "room_bed.ogg"]

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var muted: bool = false
var settings_path: String = "user://audio_settings.cfg"
var location_id: String = "post_office"
var indoors: bool = false
var minute: int = 540
var _quiet: bool = false
var _rng := RandomNumberGenerator.new()
var _beds: Dictionary = {}
var _bed_gains: Dictionary = {}
var _targets: Dictionary = {}
var _streams: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_played: Dictionary = {}
var _shots: Array[AudioStreamPlayer] = []
var _elapsed: float = 0.0
var _detail_after: float = 9.0
var _music_gain: float = 0.0
var _configured: bool = false
var _music_volume: float = 0.75
var _sfx_volume: float = 0.85
var _ambience_volume: float = 0.85
var menu_music:AudioStreamPlayer
var _settings_mode:=false
var _menu_gain:=0.0
var _shutdown_complete:=false
var _retiring_playbacks:Array[WeakRef]=[]


func _ready() -> void:
	load_settings()
	_rng.randomize()
	for bus: String in [MUSIC_BUS, SFX_BUS, AMBIENT_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	music = AudioStreamPlayer.new()
	music.bus = MUSIC_BUS
	add_child(music)
	if FileAccess.file_exists("res://assets/audio/user_guitar_loop.wav"):
		var motif: AudioStreamWAV = AudioStreamWAV.load_from_file("res://assets/audio/user_guitar_loop.wav")
		motif.loop_mode = AudioStreamWAV.LOOP_FORWARD
		motif.loop_end = int(motif.get_length() * motif.mix_rate)
		music.stream = motif
		music.volume_db = -80
		music.play()
	for file: String in BEDS:
		var bed := AudioStreamPlayer.new()
		bed.bus = AMBIENT_BUS
		add_child(bed)
		var stream: AudioStreamOggVorbis = _stream(file).duplicate() as AudioStreamOggVorbis
		if stream:
			stream.loop = true
			bed.stream = stream
			bed.volume_db = -80
			bed.play(_rng.randf_range(0.0, maxf(0.0, stream.get_length() - 1.0)))
		_beds[file] = bed
		_bed_gains[file] = 0.0
	ambience = _beds["sea_bed.ogg"]
	set_volumes(_music_volume, _sfx_volume, _ambience_volume)
	set_location(location_id, minute, indoors)
	menu_music=AudioStreamPlayer.new();menu_music.bus=MUSIC_BUS;add_child(menu_music)
	var menu_track:=load("res://assets/audio/settings_vaporware.ogg") as AudioStreamOggVorbis
	menu_track=menu_track.duplicate();menu_track.loop=true;menu_music.stream=menu_track;menu_music.volume_db=-80

func settings_music(enabled:bool)->void:
	if _shutdown_complete:return
	_settings_mode=false


func set_location(id: String, at_minute: int = 540, inside: bool = false) -> void:
	var changed: bool = not _configured or id != location_id or inside != indoors
	location_id = id
	minute = at_minute
	indoors = inside
	_configured = true
	var levels: Dictionary = {}
	if id == "title":
		levels = {"sea_bed.ogg": -15.0}
	elif inside:
		levels = {"room_bed.ogg": -20.0, "sea_bed.ogg": -40.0}
	else:
		match id:
			"post_office": levels = {"town_bed.ogg": -19.0, "wind_bed.ogg": -28.0, "sea_bed.ogg": -37.0}
			"community_center": levels = {"town_bed.ogg": -16.0, "wind_bed.ogg": -26.0}
			"bus_stop": levels = {"town_bed.ogg": -20.0, "sea_bed.ogg": -22.0, "wind_bed.ogg": -24.0}
			"lookout": levels = {"sea_bed.ogg": -12.0, "wind_bed.ogg": -20.0}
			"residential": levels = {"town_bed.ogg": -25.0, "wind_bed.ogg": -18.0}
			"chess_stall": levels = {"town_bed.ogg": -24.0, "wind_bed.ogg": -19.0}
			"tarot_shop": levels = {"wind_bed.ogg": -25.0, "sea_bed.ogg": -29.0, "town_bed.ogg": -30.0}
			_: levels = {"wind_bed.ogg": -29.0}
	for file: String in BEDS:
		var gain: float = db_to_linear(float(levels[file])) if levels.has(file) else 0.0
		if at_minute >= 1020 and file == "town_bed.ogg": gain *= 0.68
		_targets[file] = gain
	if changed:
		_detail_after = _rng.randf_range(8.0, 17.0)
		if id == "title": _detail_after = 1.5
		# A location transition must not leave the previous tram/bird one-shot
		# audible indoors or in an unrelated courtyard.
		for shot: AudioStreamPlayer in _shots:
			if is_instance_valid(shot) and shot.bus == AMBIENT_BUS:
				shot.stop()
				shot.queue_free()
		_clean_shots()


func set_volumes(music_level: float, effects_level: float, ambient_level: float = 0.85) -> void:
	_music_volume = _safe_volume(music_level, _music_volume)
	_sfx_volume = _safe_volume(effects_level, _sfx_volume)
	_ambience_volume = _safe_volume(ambient_level, _ambience_volume)
	for pair: Array in [[MUSIC_BUS, _music_volume], [SFX_BUS, _sfx_volume], [AMBIENT_BUS, _ambience_volume]]:
		var index: int = AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(pair[1]), 0.0001)))
			AudioServer.set_bus_mute(index, muted or float(pair[1]) <= 0.0)


func play(kind: String = "paper") -> void:
	if muted or _shutdown_complete: return
	var cooldown: float = 0.16 if kind == "step" else 0.11
	if kind in ["tool", "snap", "repair"]: cooldown = 0.22
	if kind in ["bell", "tram"]: cooldown = 2.0
	if _elapsed - float(_last_played.get(kind, -100.0)) < cooldown: return
	_last_played[kind] = _elapsed
	var variants: Array = []
	if kind == "step":
		var surface: String = "wood" if indoors else "concrete"
		if not indoors and location_id in ["residential", "chess_stall"]: surface = "grass"
		for index: int in range(1, 4): variants.append("step_%s_%d.wav" % [surface, index])
	else:
		variants = POOLS.get(kind, POOLS.paper)
	var index: int = _rng.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == int(_last_variant.get(kind, -1)):
		index = (index + 1) % variants.size()
	_last_variant[kind] = index
	var gain: float = -13.0
	if kind == "step": gain = -20.0
	elif kind == "bell": gain = -23.0
	elif kind in ["snap", "tool", "repair"]: gain = -18.0
	elif kind in ["stamp", "door", "door_close"]: gain = -14.0
	elif kind == "tram": gain = -25.0
	elif kind == "water":gain=-22.0
	_spawn(kind, str(variants[index]), gain, SFX_BUS, _rng.randf_range(0.97, 1.03))


func quiet_case(enabled: bool) -> void:
	_quiet = enabled


func toggle() -> void:
	set_muted(not muted)
	save_settings()


func set_muted(enabled: bool) -> void:
	muted = enabled
	set_volumes(_music_volume, _sfx_volume, _ambience_volume)


func get_volumes() -> Dictionary:
	return {"music": _music_volume, "effects": _sfx_volume, "ambience": _ambience_volume}


func load_settings() -> Error:
	var config := ConfigFile.new()
	var result: Error = config.load(settings_path)
	if result != OK: return result
	_music_volume = _safe_volume(config.get_value("audio", "music", 0.75), 0.75)
	_sfx_volume = _safe_volume(config.get_value("audio", "effects", 0.85), 0.85)
	_ambience_volume = _safe_volume(config.get_value("audio", "ambience", 0.85), 0.85)
	var saved_mute: Variant = config.get_value("audio", "muted", false)
	muted = saved_mute if saved_mute is bool else false
	set_volumes(_music_volume, _sfx_volume, _ambience_volume)
	return OK


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music", _music_volume)
	config.set_value("audio", "effects", _sfx_volume)
	config.set_value("audio", "ambience", _ambience_volume)
	config.set_value("audio", "muted", muted)
	return config.save(settings_path)


static func _safe_volume(value: Variant, fallback: float) -> float:
	if not value is float and not value is int: return fallback
	var number: float = float(value)
	return clampf(number, 0.0, 1.0) if is_finite(number) else fallback


func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		_streams[file] = load(ROOT + file) if ResourceLoader.exists(ROOT + file) else null
	return _streams[file] as AudioStream


func _spawn(kind: String, file: String, gain: float, bus: String, pitch: float = 1.0) -> void:
	if _shutdown_complete:return
	_clean_shots()
	if _shots.size() >= 10: return
	var resource: AudioStream = _stream(file)
	if resource == null: return
	var shot := AudioStreamPlayer.new()
	shot.stream = resource
	shot.bus = bus
	shot.volume_db = gain
	shot.pitch_scale = pitch
	add_child(shot)
	_shots.append(shot)
	shot.finished.connect(shot.queue_free)
	shot.play()
	cue_played.emit(kind, file)

func play_water_touch(point:Vector2,strength:float=1.0,body_contact:bool=false)->void:
	if muted or _sfx_volume<=0.0 or _shutdown_complete:return
	var value:=clampf(strength,0.1,1.0)
	# Distinct close touch / lighter surface contact; original CC0 PCM remains unchanged.
	var file:="water_touch_3.wav" if body_contact or value<0.45 else ("water_touch_2.wav" if int(point.x+point.y)%2==0 else "water_touch_1.wav")
	var bus:=SFX_BUS
	var side:=0 if point.x<550.0 else (2 if point.x>1050.0 else 1)
	var pan_bus:="SolmereWater"+str(side)
	if AudioServer.get_bus_index(pan_bus)==-1:
		AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,pan_bus);AudioServer.set_bus_send(index,SFX_BUS)
		var pan:=AudioEffectPanner.new();pan.pan=float(side-1)*0.3;AudioServer.add_bus_effect(index,pan)
	bus=pan_bus
	_spawn("water",file,-7.0+linear_to_db(lerpf(0.35,1.0,value)),bus,_rng.randf_range(0.96,1.04))


func _clean_shots() -> void:
	var alive: Array[AudioStreamPlayer] = []
	for shot: AudioStreamPlayer in _shots:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion(): alive.append(shot)
	_shots = alive


func _process(delta: float) -> void:
	if _shutdown_complete:return
	_elapsed += delta
	for file: String in _beds:
		var current: float = float(_bed_gains[file])
		var destination: float = float(_targets.get(file, 0.0))
		# Roughly two seconds of perceptual, click-free crossfade.
		current = lerpf(current, destination, 1.0 - exp(-delta * 1.6))
		_bed_gains[file] = current
		(_beds[file] as AudioStreamPlayer).volume_db = linear_to_db(maxf(current, 0.0001))
	var target_music: float = db_to_linear(-18.0 if _quiet else -12.0)
	if location_id == "title":target_music=0.0
	_music_gain = lerpf(_music_gain, target_music, 1.0 - exp(-delta * 1.3))
	if music: music.volume_db = linear_to_db(maxf(_music_gain, 0.0001))
	_menu_gain=lerpf(_menu_gain,db_to_linear(-15.0) if _settings_mode else 0.0,1.0-exp(-delta*3.0))
	if is_instance_valid(menu_music):
		menu_music.volume_db=linear_to_db(maxf(_menu_gain,0.0001))
		if not _settings_mode and _menu_gain<0.0002:menu_music.stop()
	_detail_after -= delta
	if _detail_after <= 0.0:
		_detail_after = _rng.randf_range(20.0, 42.0) * (1.4 if minute >= 1020 else 1.0)
		if muted or indoors: return
		if location_id == "bus_stop" and _rng.randf() < 0.55:
			_spawn("tram_ambient", "tram_pass.wav", -28.0, AMBIENT_BUS)
		elif location_id == "chess_stall" and _rng.randf() < 0.35:
			_spawn("chess_piece", "wood_piece.wav", -24.0, AMBIENT_BUS)
		else:
			_spawn("bird_ambient", "birds.wav", -25.0 if location_id == "lookout" else -21.0, AMBIENT_BUS, _rng.randf_range(0.94, 1.04))


func shutdown() -> void:
	# Call while the tree/audio mixer are alive, before the host's quit drain.
	# stop() retires native playback on a subsequent audio mix; _exit_tree alone
	# can be too late during an immediate engine shutdown. Only our players are
	# released here; shared buses, effects and volume/mute settings stay intact.
	if _shutdown_complete:return
	_shutdown_complete=true
	set_process(false)
	_settings_mode=false
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			# A weak fence observes only this player's native voice, not a shared
			# imported AudioStream or another owner's use of the same bus.
			if child.has_stream_playback():
				_retiring_playbacks.append(weakref(child.get_stream_playback()))
			child.stop()
			child.stream = null
	_shots.clear()
	_beds.clear()
	_streams.clear()
	_bed_gains.clear()
	_targets.clear()
	music=null
	menu_music=null
	ambience=null

func has_pending_playbacks() -> bool:
	# AudioServer owns stop/fade retirement after the player relinquishes its
	# voice. Poll between process frames; callers provide their own quit bound.
	# The weak observations never keep a stream/playback alive themselves.
	var pending:Array[WeakRef]=[]
	for reference:WeakRef in _retiring_playbacks:
		if reference.get_ref()!=null:pending.append(reference)
	_retiring_playbacks=pending
	return not _retiring_playbacks.is_empty()

func _exit_tree() -> void:
	shutdown()
