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
func _ready()->void:
	var birds:Array=preload("res://scripts/rebuild/street_bird_motion.gd").inventory(road.family,0)
	for i in range(0,birds.size(),3):
		var anchor:Vector4=birds[i].anchor
		_add("birds",Vector2(anchor.x,anchor.y)*1.5,"birds.wav",false,-21.0,1800.0,float(i)*.8+1.0)
	var trees:Array=preload("res://scripts/rebuild/street_atmosphere.gd").REGIONS.get(road.family,{}).get("trees",[])
	for i in range(0,trees.size(),3):
		var crown:Vector4=trees[i]
		_add("leaves",Vector2((crown.x+crown.z)*.75,(crown.y+crown.w)*.75),"leaves_soft_cc0.ogg",true,-25.0,1000.0,0)
	_add("sea",Vector2(road.world.size.x*.63,480),"gentle_ocean_cc0.mp3",true,-21.0,3800.0,0)
func _add(id:String,at:Vector2,file:String,loop:bool,db:float,radius:float,delay:float)->void:
	var stream:AudioStream
	if file.ends_with(".wav"):stream=AudioStreamWAV.load_from_file(ROOT+file)
	elif file.ends_with(".mp3"):stream=AudioStreamMP3.load_from_file(ROOT+file)
	else:stream=AudioStreamOggVorbis.load_from_file(ROOT+file)
	if stream==null:return
	if loop:stream.set("loop",true)
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
		var offset:Vector2=source.at-ear
		var attenuation:=1.0/(1.0+pow(offset.length()/float(source.radius),2.5))
		var alignment:=maxf(0.0,direction.dot(offset.normalized()))
		var pickup:=lerpf(.07,1.0,pow(alignment,3)) if focused else .27
		var desired:float=db_to_linear(float(source.base))*attenuation*pickup*_gain
		if source.id=="birds" and (road.display_minute>=1140 or road.display_minute<360):desired=0.0
		source.gain=lerpf(float(source.gain),desired,1.0-exp(-delta*7.0))
		var player:AudioStreamPlayer=source.player
		player.volume_db=linear_to_db(maxf(.00001,float(source.gain)))
		source.pan.pan=clampf(offset.x/1100.0,-.78,.78)
		source.filter.cutoff_hz=lerpf(1800.0,12000.0,alignment) if focused else 10000.0
		if not source.loop and not player.playing and _clock>=source.next:
			player.play();source.next=_clock+stream_length(player)+8.0+float(sources.find(source)%3)*2.3
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
