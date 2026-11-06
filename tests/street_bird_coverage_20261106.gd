extends SceneTree
## Real Road composition at a normal 1280x720 display, including cloud overlay.
## Source-only bird shader coverage is supplemented by this production wiring
## regression. It is GPU/engine input evidence, not a human playthrough.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const Birds=preload("res://scripts/rebuild/street_bird_motion.gd")
const MINUTES=[540.0,720.0,1050.0,1200.0]
const TIMES=[0.0,.8,1.6,2.4,3.2,4.8,6.4,8.0,9.6,12.0]
const EXPECTED={"community":[9,9,9,9],"residential":[10,10,10,0],"postal":[8,8,8,8],"coastal":[6,6,6,3]}
var output:="res://test-results/street-birds-20261106/"
var checks:=0
var failures:Array[String]=[]
var results:Array=[]
func _initialize()->void:
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():output=args[0].trim_suffix("/")+"/"
 run.call_deferred()
func verify(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func picture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func channel_error(a:Color,b:Color)->float:
 return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func screen_box(b:Vector4,center:float)->Rect2i:
 return Rect2i(floori((b.x-center)*1.2+640.0)-2,floori(b.y*1.2)-2,ceili((b.z-b.x)*1.2)+4,ceili((b.w-b.y)*1.2)+4)
func run()->void:
 RenderingServer.render_loop_enabled=false
 OS.low_processor_usage_mode=false
 DirAccess.make_dir_recursive_absolute(output)
 for family:String in EXPECTED:
  var view:=SubViewport.new()
  view.size=Vector2i(1280,720)
  view.size_2d_override=Vector2i(1600,900)
  view.size_2d_override_stretch=true
  view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(view)
  var road=Road.new()
  road.size=Vector2(1600,900)
  road.district=family if family in ["community","residential"] else "coastal"
  road.postal=family=="postal"
  view.add_child(road)
  road.set_process(false)
  road.courier.set_process(false)
  road.courier.hide()
  for phase:int in range(4):
   road.set_time_of_day(MINUTES[phase])
   road.set_fountain_time(0.0)
   var items:=Birds.inventory(family,phase)
   verify(items.size()==EXPECTED[family][phase],"Observed source inventory %s phase %d"%[family,phase])
   # At these exact knots the original lookup uses B with blend==1, except
   # night's identical A/B pair. Assert real material wiring, not only data.
   verify(int(road.atmosphere_material.get_shader_parameter("bird_count_b"))==items.size(),"Road bird inventory %s phase %d"%[family,phase])
   verify(int(road.cloud_material.get_shader_parameter("bird_count_b"))==items.size(),"Cloud bird exclusion %s phase %d"%[family,phase])
   var groups:Array=[]
   for item:Dictionary in items:
    var x:float=item.anchor.x
    if groups.is_empty() or absf(x-float(groups[-1].center))>850.0:
     groups.append({"center":x,"items":[item]})
    else:groups[-1].items.append(item)
   if groups.is_empty():groups.append({"center":1040.0,"items":[]})
   for group_index:int in range(groups.size()):
    var group:Dictionary=groups[group_index]
    # Keep the complete last bird in the normal-width camera too.
    var center:float=(float(group.items[0].anchor.x)+float(group.items[-1].anchor.x))*.5 if not group.items.is_empty() else 1040.0
    road.world.position.x=800.0-center*1.5
    var first:Image
    var changes:Array[int]=[]
    var body_errors:Array[float]=[]
    for item:Dictionary in group.items:changes.append(0);body_errors.append(0.0)
    for t_index:int in range(TIMES.size()):
     road.set_weather_time(TIMES[t_index])
     var shot:Image=await picture(view)
     if first==null:first=shot
     for item_index:int in range(group.items.size()):
      var item:Dictionary=group.items[item_index]
      var box:=screen_box(item.box,center).intersection(Rect2i(0,0,1280,720))
      var changed:=0
      for y:int in range(box.position.y,box.end.y):
       for x:int in range(box.position.x,box.end.x):
        if channel_error(first.get_pixel(x,y),shot.get_pixel(x,y))>2.0/255.0:changed+=1
      changes[item_index]=maxi(changes[item_index],changed)
      var body:=Vector2i(roundi((float(item.anchor.x)-center)*1.2+640.0),roundi(float(item.anchor.y)*1.2))
      for dy:int in range(-1,2):
       body_errors[item_index]=maxf(body_errors[item_index],channel_error(first.get_pixelv(body+Vector2i(0,dy)),shot.get_pixelv(body+Vector2i(0,dy))))
     if group_index==0 and t_index in [0,3,6]:shot.save_png(output+"%s_phase%d_window_t%d.png"%[family,phase,t_index])
    for item_index:int in range(group.items.size()):
     var item:Dictionary=group.items[item_index]
     var label:="%s phase%d bird %.1f,%.1f"%[family,phase,item.anchor.x,item.anchor.y]
     verify(changes[item_index]>=12,"Visible original wings: "+label+" changed="+str(changes[item_index]))
     verify(body_errors[item_index]<=1.0/255.0,"Fixed painted wing attachment: "+label)
     results.append({"family":family,"phase":phase,"anchor":[item.anchor.x,item.anchor.y],"changed_pixels":changes[item_index],"body_max_error":body_errors[item_index]})
   print("BIRD_ROAD ",family," phase=",phase," observed=",items.size())
  view.queue_free()
  await process_frame
 var receipt={"checks":checks,"failures":failures,"birds":results,"viewport":[1280,720],"times":TIMES,"expected":EXPECTED,"scope":"Actual production Road and cloud composition, static daylight, real GPU; visual coverage is not subjective motion acceptance."}
 var file:=FileAccess.open(output+"receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "));file.close()
 print("BIRD_ROAD_COMPLETE ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
