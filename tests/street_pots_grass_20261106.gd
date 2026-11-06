extends SceneTree
const Road=preload("res://scripts/rebuild/coastal_road.gd")
## Independently measured original tips and clear pot surfaces, not shader masks.
const TIPS=[Rect2i(5888,490,16,16),Rect2i(5910,478,12,17),Rect2i(5925,480,14,15),Rect2i(5933,492,14,13),Rect2i(5951,479,12,16)]
const FIXED=[Rect2i(5875,469,35,4),Rect2i(5880,482,9,5),Rect2i(5930,460,25,8),Rect2i(5940,470,16,6),Rect2i(5950,505,16,7),Rect2i(5888,517,78,4)]
var out:="user://qa/pots-grass/"
var checks:=0
var failures:Array[String]=[]
var records:Array=[]
func _initialize():
 root.unfocusable=true
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
 run.call_deferred()
func picture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func changed(a:Image,b:Image,box:Rect2i)->int:
 var count:=0
 for y:int in range(box.position.y,box.end.y):
  for x:int in range(box.position.x,box.end.x):
   var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
   if maxf(absf(d.r),maxf(absf(d.g),absf(d.b)))>2.0/255.0:count+=1
 return count
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 RenderingServer.render_loop_enabled=false
 DirAccess.make_dir_recursive_absolute(out)
 var road=Road.new();road.district="community";road.size=Vector2(1600,900);root.add_child(road);road.hide();road.set_process(false);road.courier.set_process(false)
 var view:=SubViewport.new();view.size=road.art.texture.get_size();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var art:=TextureRect.new();art.texture=road.art.texture;art.material=road.atmosphere_material;art.size=view.size;view.add_child(art)
 for phase:int in range(4):
  road.set_time_of_day([540.0,720.0,1050.0,1200.0][phase]);art.texture=road.art.texture
  road.atmosphere_material.set_shader_parameter("motion_strength",0.0)
  var original:=await picture(view)
  road.atmosphere_material.set_shader_parameter("motion_strength",1.0)
  var maxima:=[0,0,0,0,0]
  var first:Image
  for seconds:float in [0.0,3.34,9.68,20.0,56.0]:
   road.set_weather_time(seconds)
   var frame:=await picture(view)
   if first==null:first=frame
   for i:int in range(TIPS.size()):maxima[i]=maxi(maxima[i],changed(first,frame,TIPS[i]))
   for i:int in range(FIXED.size()):check(changed(original,frame,FIXED[i])==0,"phase %d time %s fixed pot/rock/root %d"%[phase,seconds,i])
   frame.get_region(Rect2i(5865,450,120,75)).save_png(out+"phase%d_t%d.png"%[phase,int(seconds*100)])
  for i:int in range(TIPS.size()):check(maxima[i]>=3,"phase %d original blade %d visibly moves (%d pixels)"%[phase,i,maxima[i]])
  records.append({"phase":phase,"max_changed_tip_pixels":maxima})
 road.queue_free();view.queue_free();await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"method":"Actual PCK full source-size GPU rendering across four phases and five wind samples; original observed tip boxes plus separate rigid pot/rock/root surfaces."},"  "))
 print("POTS_GRASS ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
