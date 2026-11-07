extends SceneTree
## Actual shader at the normal 1280-window scale. Motion is measured from
## independently selected painted hem patches, with rigid landmark checks.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const ORIGIN=Vector2(330,250)
const SCALE=1.2
const HEMS=[Rect2(414,397,68,10),Rect2(503,440,70,13),Rect2(624,449,71,10)]
# The right trunk sample ends above the ochre grass tip at source y=492.
const FIXTURES=[Rect2(344,266,21,8),Rect2(700,291,20,5),Rect2(389,280,11,7),Rect2(639,301,17,8),Rect2(684,326,20,5),Rect2(737,475,15,15),Rect2(344,437,12,16)]
var out:="user://qa/postal-hanging-cloth/"
var checks:=0
var failures:Array[String]=[]
var records:Array=[]
func _initialize():
 root.unfocusable=true
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
 run.call_deferred()
func screen_box(box:Rect2)->Rect2i:
 return Rect2i(Vector2i((box.position-ORIGIN)*SCALE),Vector2i(box.size*SCALE))
func picture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func maximum(a:Image,b:Image,box:Rect2i)->float:
 var result:=0.0
 for y:int in range(box.position.y,box.end.y):
  for x:int in range(box.position.x,box.end.x):
   var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
   result=maxf(result,maxf(absf(d.r),maxf(absf(d.g),absf(d.b))))
 return result*255.0
func best_shift(a:Image,b:Image,box:Rect2i)->float:
 var best:=INF
 var shift:=0.0
 for step:int in range(-24,25):
  var dx:=float(step)*.25
  var error:=0.0
  for y:int in range(box.position.y,box.end.y):
   for x:int in range(box.position.x,box.end.x):
    var bx:=float(x)+dx
    var sample:=b.get_pixel(int(floor(bx)),y).lerp(b.get_pixel(int(floor(bx))+1,y),fposmod(bx,1.0))
    var d:=a.get_pixel(x,y)-sample
    error+=d.r*d.r+d.g*d.g+d.b*d.b
  if error<best:best=error;shift=dx
 return shift
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 RenderingServer.render_loop_enabled=false
 DirAccess.make_dir_recursive_absolute(out)
 var road=Road.new();road.size=Vector2(1600,900);road.postal=true;root.add_child(road);road.hide();road.set_process(false);road.courier.set_process(false)
 var view:=SubViewport.new();view.size=Vector2i(600,312);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var art:=TextureRect.new();art.texture=road.art.texture;art.material=road.atmosphere_material;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.position=-ORIGIN*SCALE;art.size=road.art.texture.get_size()*SCALE;view.add_child(art)
 for phase:int in range(4):
  road.set_time_of_day([540.0,720.0,1050.0,1200.0][phase]);art.texture=road.art.texture
  road.atmosphere_material.set_shader_parameter("motion_strength",0.0)
  var still:=await picture(view)
  still.save_png(out+"phase_%d_original.png"%phase)
  road.atmosphere_material.set_shader_parameter("motion_strength",1.0)
  var frames:Array[Image]=[]
  for t:float in [0.0,1.25,12.4,24.87]:
   road.set_weather_time(t)
   var frame:=await picture(view);frames.append(frame)
   frame.save_png(out+"phase_%d_t_%04d.png"%[phase,int(t*100)])
   for index:int in range(FIXTURES.size()):
    var delta:=maximum(frame,still,screen_box(FIXTURES[index]))
    check(delta<1.01,"phase %d t %.2f rigid rope/top/pole landmark %d delta %.2f"%[phase,t,index,delta])
  var shifts:Array=[]
  for index:int in range(HEMS.size()):
   var shift:=absf(best_shift(frames[0],frames[2],screen_box(HEMS[index])))
   shifts.append(shift)
   check(shift>=2.0 and shift<=4.0,"phase %d sheet %d normal-window hem travel %.2f px"%[phase,index,shift])
  records.append({"phase":phase,"hem_travel_screen_pixels":shifts})
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"scale":SCALE,"method":"Offscreen GPU render of actual street shader at normal 1280-window scale; original painted patches matched at quarter-pixel increments. Rigid source-art rope/top/pole landmarks compared against motion-disabled original."},"  "))
 print("POSTAL_HANGING_CLOTH ",checks," checks / ",failures.size()," failures")
 road.queue_free();view.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
