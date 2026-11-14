extends Node
## World-space sound sources. Same voices are heard, aimed at and recorded.
const ROOT:="res://assets/audio/foley/"
var road:Control
var sources:Array[Dictionary]=[]
var focused:=false
var aim:=Vector2.ZERO
var _clock:=0.0
var _gain:=0.0
var _owned_buses:Array[String]=[]
var _rng:=RandomNumberGenerator.new()
func _ready()->void:
	_rng.randomize()
	var birds:Array=preload("res://scripts/rebuild/street_bird_motion.gd").inventory(road.family,0)
	for i in range(0,birds.size(),3):
		var anchor:Vector4=birds[i].anchor
		_add("birds",Vector2(anchor.x,anchor.y)*1.5,"birds.wav",false,-21.0,1800.0,float(i)*.8+1.0)
	var trees:Array=preload("res://scripts/rebuild/street_atmosphere.gd").REGIONS.get(road.family,{}).get("trees",[])
	for i in range(0,trees.size(),3):
		var crown:Vector4=trees[i]
		_add("leaves",Vector2((crown.x+crown.z)*.75,(crown.y+crown.w)*.75),"leaves_soft_cc0.ogg",true,-25.0,1000.0,0)
	var sea_db:float={"coastal":-19.0,"postal":-30.0,"community":-36.0,"residential":-25.0}.get(road.family,-26.0)
	_add("sea",Vector2(road.world.size.x*.63,480),"gentle_ocean_cc0.mp3",true,sea_db,3800.0,0)
	if is_instance_valid(road.fountain):
		_add("fountain",road.fountain.position+road.fountain.size*Vector2(.5,.82),"fountain_flow_cc0.mp3",true,-20.0,650.0,0)
	match road.family:
		"postal":
			_add("chess",Vector2(550,520)*1.5,"wood_piece.wav",false,-24.0,550.0,3.0)
			_add("book_pages",Vector2(3860,510)*1.5,"paper_unfold.wav",false,-27.0,420.0,5.0)
		"community":
			_add("market",Vector2(6400,520)*1.5,"town_bed.ogg",true,-22.0,1000.0,0)
			_add("grocery_bell",Vector2(4350,500)*1.5,"bell.wav",false,-29.0,520.0,9.0)
			_add("food_truck",Vector2(12100,700),"tool_metal.wav",false,-27.0,600.0,6.0)
		"residential":
			_add("lookout_wind",Vector2(4470,400)*1.5,"wind_bed.ogg",true,-21.0,1500.0,0)
			_add("tram",Vector2(6500,520)*1.5,"tram_pass.wav",false,-24.0,1350.0,8.0)
		"coastal":
			_add("shore_wind",Vector2(road.world.size.x*.75,540),"wind_bed.ogg",true,-28.0,2400.0,0)
func _add(id:String,at:Vector2,file:String,loop:bool,db:float,radius:float,delay:float)->void:
	var stream:AudioStream
	if file.ends_with(".wav"):stream=AudioStreamWAV.load_from_file(ROOT+file)
	elif file.ends_with(".mp3"):stream=AudioStreamMP3.load_from_file(ROOT+file)
	else:stream=AudioStreamOggVorbis.load_from_file(ROOT+file)
	if stream==null:return
	if loop:
		if stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate)
		else:stream.set("loop",true)
	var bus:="DearField_%s_%s"%[get_instance_id(),sources.size()]
	AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus);AudioServer.set_bus_send(index,"SolmereAmbience")
	var pan:=AudioEffectPanner.new();AudioServer.add_bus_effect(index,pan)
	var filter:=AudioEffectLowPassFilter.new();filter.cutoff_hz=12000;filter.resonance=.5;AudioServer.add_bus_effect(index,filter)
	_owned_buses.append(bus)
	var player:=AudioStreamPlayer.new();player.bus=bus;player.stream=stream;player.volume_db=-80;add_child(player)
	sources.append({"id":id,"at":at,"player":player,"pan":pan,"filter":filter,"base":db,"radius":radius,"loop":loop,"next":delay,"gain":0.0})
	if loop:player.play(fmod(float(sources.size())*.73,maxf(.1,stream.get_length())))
func set_focus(value:bool,target:Vector2=Vector2.ZERO)->void:
	focused=value;aim=target
func _process(delta:float)->void:
	if not is_instance_valid(road.courier):return
	_clock+=delta;_gain=move_toward(_gain,1.0,delta*1.5)
	var ear:Vector2=road.courier.foot-Vector2(0,210)
	var direction:Vector2=(aim-ear).normalized()
	for source:Dictionary in sources:
		var position:Vector2=source.at
		if source.id=="tram" and source.player.playing:
			position.x+=lerpf(-950.0,950.0,clampf(source.player.get_playback_position()/maxf(.1,stream_length(source.player)),0.0,1.0))
		var offset:Vector2=position-ear
		var attenuation:=1.0/(1.0+pow(offset.length()/float(source.radius),2.5))
		var alignment:=maxf(0.0,direction.dot(offset.normalized()))
		var pickup:=lerpf(.20,1.0,pow(alignment,2)) if focused else .40
		var desired:float=db_to_linear(float(source.base))*attenuation*pickup*_gain
		if source.id in ["birds","market","grocery_bell","food_truck","chess"] and (road.display_minute>=1140 or road.display_minute<360):desired=0.0
		if source.id in ["leaves","lookout_wind","shore_wind"]:
			desired*=lerpf(.45,1.15,preload("res://scripts/rebuild/street_atmosphere.gd").wind_at(road.weather_time,source.at.x/1.5))
		source.gain=lerpf(float(source.gain),desired,1.0-exp(-delta*7.0))
		var player:AudioStreamPlayer=source.player
		player.volume_db=linear_to_db(maxf(.00001,float(source.gain)))
		source.pan.pan=clampf(offset.x/1100.0,-.78,.78)
		source.filter.cutoff_hz=lerpf(1800.0,12000.0,alignment) if focused else 10000.0
		if not source.loop and not player.playing and _clock>=source.next:
			if attenuation>.06 and desired>0.00001:
				player.pitch_scale=_rng.randf_range(.96,1.04) if source.id in ["birds","chess","book_pages","food_truck"] else 1.0
				player.play()
			var gap:=_rng.randf_range(10.0,22.0) if source.id=="birds" else _rng.randf_range(16.0,34.0)
			if source.id=="tram":gap=_rng.randf_range(30.0,48.0)
			source.next=_clock+stream_length(player)+gap
func stream_length(player:AudioStreamPlayer)->float:return player.stream.get_length() if player.stream else 0.0
func strongest()->Dictionary:
	var best:Dictionary={};var gain:float=0
	for source:Dictionary in sources:
		if source.player.playing and float(source.gain)>gain:gain=source.gain;best=source
	return best
func shutdown()->void:
	set_process(false)
	for source:Dictionary in sources:
		var player:AudioStreamPlayer=source.player
		if is_instance_valid(player):player.stop();player.stream=null
	for bus:String in _owned_buses:
		var index:=AudioServer.get_bus_index(bus)
		if index>=0:AudioServer.remove_bus(index)
	_owned_buses.clear()
func _exit_tree()->void:shutdown()
