extends SceneTree
## Actual road wiring, including Host's postal=true/district=coastal route.
## Compare the water repair with the unmodified panorama at fixed rigid landmarks.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const BASE=Rect2(386.5,86.7,335.46,427.96)
const SCALE=1.2
const PHASES=[540.0,720.0,1050.0,1125.0,1200.0]
const TIMES=[0.0,0.34,0.68,1.0]
const FRAME_IDS=[0,1,2,0]
# Independently selected original stone: upper statue, full central pillar down
# through the old crop boundary, and the basin below the stream landing points.
const RIGID=[Rect2(390,95,325,250),Rect2(533,392,42,91),Rect2(390,455,325,45)]
const WATER=Rect2(484,376,132,72)
var out:="user://qa/fountain-composite/"
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
func _initialize():
 root.unfocusable=true
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
 run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func picture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func difference(a:Image,b:Image,box:Rect2i)->Dictionary:
 var count:=0
 var maximum:=0.0
 for y:int in range(box.position.y,box.end.y):
  for x:int in range(box.position.x,box.end.x):
   var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
   var delta:=maxf(absf(d.r),maxf(absf(d.g),absf(d.b)))*255.0
   maximum=maxf(maximum,delta)
   if delta>1.01:count+=1
 return {"changed_pixels":count,"maximum_channel_delta":maximum}
func screen_box(box:Rect2,rect:Rect2,origin:float)->Rect2i:
 var ratio:=rect.size/BASE.size
 var source_position:=rect.position+(box.position-BASE.position)*ratio
 return Rect2i(Vector2i((source_position-Vector2(origin,0))*SCALE),Vector2i(box.size*ratio*SCALE))
func run():
 RenderingServer.render_loop_enabled=false
 OS.low_processor_usage_mode=false
 DirAccess.make_dir_recursive_absolute(out)
 var view:=SubViewport.new()
 view.size=Vector2i(1280,720)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 for family:String in ["community","residential","coastal","postal"]:
  var road=Road.new()
  road.district=family if family in ["community","residential"] else "coastal"
  road.postal=family=="postal"
  road.size=Vector2(1600,900)
  road.scale=Vector2(.8,.8)
  view.add_child(road)
  road.process_mode=Node.PROCESS_MODE_DISABLED
  road.courier.hide()
  var rect:=BASE
  if family=="coastal":rect=Rect2(4104,93,337,430)
  elif family=="postal":rect=Rect2(5390,91,337,430)
  var origin:=rect.position.x-290.0
  road.world.position=Vector2(-origin*1.5,0)
  road.set_weather_time(0.0)
  verify(is_instance_valid(road.fountain),family+" original water node exists")
  verify(is_instance_valid(road.fountain_background),family+" clears painted water behind animation")
  if not is_instance_valid(road.fountain) or not is_instance_valid(road.fountain_background):
   road.queue_free();await process_frame
   continue
  verify(road.fountain_frames.size()==3,family+" has all 3 supplied frames")
  for i in range(3):
   var supplied:=Image.load_from_file("res://assets/authoring/fountain_20261030/frame_%d.png"%i)
   verify(road.fountain_frames[i].get_image().get_data()==supplied.get_data(),family+" frame %d original pixels unchanged"%i)
  var water_box:=screen_box(WATER,rect,origin)
  for minute:float in PHASES:
   road.set_time_of_day(minute)
   var first:Image
   for index:int in range(TIMES.size()):
    road.set_fountain_time(TIMES[index])
    verify(road.fountain.texture==road.fountain_frames[FRAME_IDS[index]],"%s %.0f original frame order %d"%[family,minute,index])
    road.fountain_background.hide()
    var original:=await picture(view)
    road.fountain_background.show()
    var repaired:=await picture(view)
    var cleared:=difference(original,repaired,water_box)
    verify(cleared.changed_pixels>50,"%s %.0f frame %d removes static ghost water"%[family,minute,index])
    var rigid_results:Array=[]
    for k in range(RIGID.size()):
     var fixed:=difference(original,repaired,screen_box(RIGID[k],rect,origin))
     rigid_results.append(fixed)
     verify(fixed.changed_pixels==0,"%s %.0f frame %d rigid stone %d unchanged"%[family,minute,index,k])
    if first==null:first=repaired
    var motion:=difference(first,repaired,water_box)
    if index in [1,2]:verify(motion.changed_pixels>100,"%s %.0f frame %d water visibly animates"%[family,minute,index])
    if index==3:verify(first.get_data()==repaired.get_data(),"%s %.0f exact one-second loop"%[family,minute])
    rows.append({"family":family,"minute":minute,"frame":FRAME_IDS[index],"water_repair":cleared,"rigid":rigid_results,"motion":motion})
    if family=="postal" and index<3:
     repaired.save_png(out+"postal_%04d_frame_%d.png"%[int(minute),index])
   # Phase blend must tint both the original animation and its background repair.
   verify(road.fountain.modulate.is_equal_approx(road.courier.modulate),"%s %.0f original water follows scene tint"%[family,minute])
  road.queue_free()
  await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"method":"Actual road GPU at 1280x720, 4 families x 4 periods plus sunset/night blend x 3 supplied frames and exact loop. Repairs compared with original panorama for independently chosen statue, center column through crop seam, and basin landmarks. No OS input or aesthetic-acceptance claim."},"  "))
 print("FOUNTAIN_COMPOSITE_20261108 ",checks," checks / ",failures.size()," failures")
 view.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
