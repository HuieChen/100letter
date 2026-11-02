extends SceneTree
const Atmosphere=preload("res://scripts/rebuild/street_atmosphere.gd")
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const Sound=preload("res://scripts/ui/audio_feedback.gd")
var checks:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func picture(view:SubViewport)->Image:
 await process_frame;await RenderingServer.frame_post_draw
 return view.get_texture().get_image()
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://test-results/street-atmosphere-20261102")
 var wind_min:=1.0;var wind_max:=0.0;var gentle:=0
 for i in range(7200):
  var wind:=Atmosphere.wind_at(float(i)/60.0,2400)
  wind_min=minf(wind_min,wind);wind_max=maxf(wind_max,wind)
  if wind<.5:gentle+=1
 check(wind_min>=0 and wind_max<=1,"Wind remains bounded")
 check(gentle>7200*.7 and wind_max>.7,"Mostly gentle wind with occasional stronger gusts")
 for minute in [360.0,540.0,720.0,1050.0,1200.0,1440.0]:
  var pair:=Atmosphere.time_pair(minute)
  check(pair.z>=0 and pair.z<=1 and pair.x>=0 and pair.y<=3,"Valid time pair %s"%minute)
  var a:=Atmosphere.time_pair(minute-.001);var b:=Atmosphere.time_pair(minute+.001)
  var ca:Color=Atmosphere.LIGHTS[int(a.x)].lerp(Atmosphere.LIGHTS[int(a.y)],a.z)
  var cb:Color=Atmosphere.LIGHTS[int(b.x)].lerp(Atmosphere.LIGHTS[int(b.y)],b.z)
  check(absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)<.001,"No light jump at %s"%minute)
 # Sound envelope follows both the spatial and time phase used by the sea.
 for x:float in [0,1300,3450,7800]:
  for t:float in [0,3.7,18.2,44.0]:
   var displacement:=.65*sin(t*.81+x*.018)+.25*sin(t*1.17-x*.011)
   var envelope:=Atmosphere.swell_at(t,x)
   check(envelope>=0 and envelope<=1 and absf((envelope-.5)*1.8-displacement)<.00001,"Local sea sound matches rendered swell phase")
 var view:=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 for family:String in ["coastal","postal","community","residential"]:
  var road=Road.new();road.postal=family=="postal";road.district=family if family in ["community","residential"] else "coastal";road.size=Vector2(1600,900)
  view.add_child(road);road.set_process(false);road.courier.set_process(false);road.courier.hide()
  check(road.period_textures.size()==4,"All four source paintings loaded: "+family)
  for i in range(4):check(road.period_textures[i].get_width()>5000,"Full-resolution source: %s %d"%[family,i])
  road.set_time_of_day(720);road.world.position.x=-maxf(0.0,(Atmosphere.REGIONS[family].trees[0].x*1.5-200.0))
  road.atmosphere_material.set_shader_parameter("weather_time",0.0)
  var first:Image=await picture(view)
  road.atmosphere_material.set_shader_parameter("weather_time",9.0)
  var second:Image=await picture(view)
  var moving:=0;var floor_moving:=0
  for y in range(0,900,3):
   for x in range(0,1600,3):
    if first.get_pixel(x,y)!=second.get_pixel(x,y):
     moving+=1
     if y>800:floor_moving+=1
  check(moving>20,"Actual painted vegetation moves on GPU: "+family)
  check(floor_moving==0,"Ground remains stable: "+family)
  second.save_png("res://test-results/street-atmosphere-20261102/"+family+"_wind.png")
  # Verify every time variant and a continuous transition on the actual shader.
  for minute:float in [540,650,720,900,1050,1120,1200]:
   road.set_time_of_day(minute)
   var shot:Image=await picture(view)
   check(not shot.is_empty() and shot.get_pixel(1550,50).a>.99,"Opaque day/night render %s %s"%[family,minute])
  if family=="community":
   for at:float in [540,720,1050,1139]:
    road.set_time_of_day(at)
    check(is_zero_approx(float(road.atmosphere_material.get_shader_parameter("night_lights"))),"Stall lights remain off before night %s"%at)
   road.set_time_of_day(1170)
   check(is_equal_approx(float(road.atmosphere_material.get_shader_parameter("night_lights")),.5),"Stall lights fade on after night begins")
   road.set_time_of_day(1200)
   check(is_equal_approx(float(road.atmosphere_material.get_shader_parameter("night_lights")),1.0),"Stall lights fully on at night")
  # Independently chosen painted structures; they must not breathe with wind.
  var fixtures:Dictionary={
   "coastal":[Rect2i(400,100,480,410),Rect2i(2200,140,360,370),Rect2i(1600,350,90,160)],
   "postal":[Rect2i(2200,100,360,410),Rect2i(3730,150,380,360)],
   "community":[Rect2i(2000,100,520,410),Rect2i(2560,450,170,60),Rect2i(2880,350,90,160)],
   "residential":[Rect2i(2100,100,350,410),Rect2i(6390,320,440,190),Rect2i(6320,300,60,200)]}
  var full:=SubViewport.new();full.size=Vector2i(road.period_textures[1].get_width(),640);full.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(full)
  var painted:=TextureRect.new();painted.texture=road.period_textures[1];painted.material=road.atmosphere_material;full.add_child(painted)
  road.set_time_of_day(720);road.atmosphere_material.set_shader_parameter("weather_time",0.0)
  var still:Image=await picture(full)
  road.atmosphere_material.set_shader_parameter("weather_time",9.0)
  var windy:Image=await picture(full)
  for fixture:Rect2i in fixtures[family]:
   var moved:=0
   for y in range(fixture.position.y,fixture.end.y,2):
    for x in range(fixture.position.x,fixture.end.x,2):
     if still.get_pixel(x,y)!=windy.get_pixel(x,y):moved+=1
   check(moved==0,"Rigid building/sign remains exactly still: %s %s"%[family,fixture])
  # Every supplied endpoint remains the source painting (apart from the recorded roof repair).
  for endpoint:Array in [[540,0],[720,1],[1050,2],[1200,3]]:
   road.set_time_of_day(endpoint[0]);painted.texture=road.art.texture
   road.atmosphere_material.set_shader_parameter("motion_strength",0.0)
   var rendered:Image=await picture(full);var original:Image=road.period_textures[endpoint[1]].get_image()
   var max_error:=0.0
   for y in range(20,630,31):
    for x in range(20,full.size.x-20,47):
     if family=="community" and Rect2i(2138,305,25,25).has_point(Vector2i(x,y)):continue
     if family=="community" and endpoint[0]==1200 and Rect2i(6210,320,370,195).has_point(Vector2i(x,y)):continue
     var a:=rendered.get_pixel(x,y);var b:=original.get_pixel(x,y)
     max_error=maxf(max_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
   check(max_error<.012,"Original endpoint colors retained: %s %s"%[family,endpoint[0]])
   if family=="community" and endpoint[0]==1200:
    var roof_pixel:=rendered.get_pixel(2150,319)
    check(roof_pixel.b>roof_pixel.r,"Production night blend keeps foreground roof in front of warm window")
  road.atmosphere_material.set_shader_parameter("motion_strength",1.0)
  if family=="coastal":
   road.set_time_of_day(1500)
   road.transition_time_of_day(1500)
   check(is_equal_approx(road._clock_minute,1500) and road._light_tween==null,"Same-minute day-two save does not advance a day")
   road.transition_time_of_day(1515)
   road._light_tween.pause();road._light_tween.custom_step(.7)
   check(is_equal_approx(road._clock_minute,1507.5) and is_equal_approx(road.display_minute,67.5),"Day-two lighting advances only requested 15 minutes")
   var active_tween:Tween=road._light_tween
   road.transition_time_of_day(1515)
   check(road._light_tween==active_tween,"Repeated save does not restart active transition")
   road._light_tween.custom_step(.7)
   check(is_equal_approx(road._clock_minute,1515),"Day-two transition reaches cumulative target")
   road.set_time_of_day(1435);road.transition_time_of_day(1445)
   road._light_tween.pause();road._light_tween.custom_step(.7)
   check(is_equal_approx(road._clock_minute,1440) and is_equal_approx(road.display_minute,0),"Midnight crosses without sweeping a full day")
   road._light_tween.custom_step(.7)
   check(is_equal_approx(road.display_minute,5),"Midnight ends at correct next-day lighting")
  full.queue_free();road.queue_free();await process_frame
 view.queue_free();await process_frame
 var audio=Sound.new();audio.settings_path="user://qa/street-atmosphere/audio.cfg";root.add_child(audio);audio.set_process(false)
 check(is_instance_valid(audio.leaf_player),"Licensed leaf audio loads")
 audio.set_location("community_center",720,false);audio.set_weather(.15,.5,1)
 for i in range(120):audio._process(1.0/60)
 var gentle_db:float=audio.leaf_player.volume_db
 audio.set_weather(.9,.5,1)
 for i in range(120):audio._process(1.0/60)
 check(audio.leaf_player.volume_db>gentle_db+4,"Gust drives leaf audio up gently")
 check(audio.leaf_player.volume_db< -28,"Leaves stay below the music bed")
 audio.set_location("post_office",720,true)
 for i in range(180):audio._process(1.0/60)
 check(audio.leaf_player.volume_db< -65,"No outdoor leaf noise indoors")
 audio.set_muted(true)
 check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.AMBIENT_BUS)),"Settings mute affects new ambience")
 audio.shutdown();audio.queue_free();await process_frame;await process_frame
 print("STREET_ATMOSPHERE %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
