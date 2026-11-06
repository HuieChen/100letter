extends SceneTree
## Actual host/arrival/road wiring at ordinary player resolution. This does not
## replace per-object edge tests or human judgement of the captured clips.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const ROUTES={"post_office":"post_office","chess_stall":"chess_stall","bookstore":"post_office","tarot_shop":"tarot_shop","record_store":"tarot_shop","statue":"tarot_shop","community_center":"community_center","residential":"residential","grocery":"community_center","market":"community_center","food_truck":"community_center","lookout":"lookout","bus_stop":"bus_stop"}
const PERIODS=[540.0,720.0,1050.0,1200.0]
const TIMES=[0.0,1.7,3.2,5.5,8.8,12.4]
var out:="user://qa/motion-open-locations/"
var checks:=0
var failures:Array[String]=[]
var records:Array=[]
var view:SubViewport
var game:Control
func _initialize():
 var isolated:=false
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--final-save=user://qa/"):isolated=true
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
 if not isolated:push_error("Pass an isolated --final-save=user://qa/... path");quit(1);return
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func freeze(node:Node):
 node.set_process(false);node.set_physics_process(false)
 for child:Node in node.get_children():freeze(child)
func picture()->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func delta_count(a:Image,b:Image,box:Rect2i)->int:
 var changed:=0
 for y in range(box.position.y,box.end.y,2):
  for x in range(box.position.x,box.end.x,2):
   var v:=a.get_pixel(x,y)-b.get_pixel(x,y)
   if maxf(absf(v.r),maxf(absf(v.g),absf(v.b)))>2.0/255.0:changed+=1
 return changed
func run():
 root.unfocusable=true;OS.low_processor_usage_mode=false
 RenderingServer.render_loop_enabled=false
 DirAccess.make_dir_recursive_absolute(out)
 view=SubViewport.new();view.size=Vector2i(1280,720)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 game=Host.new();game.allow_display_changes=false;game.size=Vector2(1600,900);game.scale=Vector2(.8,.8);view.add_child(game)
 game.core.new_game()
 for destination:String in ROUTES:
  game.core.state.location=ROUTES[destination];game.core.state.minute=720
  game._world(destination)
  await process_frame
  freeze(game.stage)
  var road:Control=game._street_road
  check(road!=null and road.atmosphere_material!=null,destination+" has live motion material")
  check(road.cloud_material!=null,destination+" has independent cloud layer")
  for phase:int in range(4):
   road.set_time_of_day(PERIODS[phase])
   # Capture the authored scene with a fixed actor/clock/camera. Only motion
   # clocks advance, so blink/HUD changes cannot masquerade as environment.
   road.set_weather_time(TIMES[0]);road.set_fountain_time(TIMES[0])
   var before:Image=await picture()
   var peak:=0
   var ground_peak:=0
   var after:Image=before
   var peak_t:=0.0
   for time:float in TIMES.slice(1):
    road.set_weather_time(time);road.set_fountain_time(time)
    var frame:Image=await picture()
    var count:=delta_count(before,frame,Rect2i(0,0,1280,625))
    if count>peak:peak=count;after=frame;peak_t=time
    ground_peak=maxi(ground_peak,delta_count(before,frame,Rect2i(0,650,1280,35)))
   check(peak>24,destination+" phase "+str(phase)+" has visible-area environment activity")
   check(ground_peak==0,destination+" phase "+str(phase)+" fixed path stays still")
   check(is_equal_approx(float(road.atmosphere_material.get_shader_parameter("weather_time")),TIMES[-1]),destination+" material receives weather clock")
   if road.family=="residential" and phase==3:
    check(int(road.atmosphere_material.get_shader_parameter("bird_count_b"))==0,"Residential night does not invent absent birds")
   var label:=destination+"_"+str(phase)
   before.save_png(out+label+"_before.png");after.save_png(out+label+"_after.png")
   records.append({"destination":destination,"family":road.family,"phase":phase,"camera_x":road.world.position.x,"sampled_changed_pixels_peak":peak,"peak_time":peak_t,"ground_changed":ground_peak,"render_size":[1280,720]})
  print("MOTION_LOCATION ",destination," complete")
 game.sound.shutdown();game.queue_free();await process_frame;view.queue_free();await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"method":"GPU real Host arrivals, 13 open destinations x four source phases x six weather times, fixed actor and camera, 1280x720. Activity is a coverage floor, not artistic acceptance."},"  "))
 print("MOTION_OPEN_LOCATIONS ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
