extends SceneTree
## Independent pixel comparison: cloud overlay must reproduce original moving
## wings, never sample distant scenery. Includes late wind-clock extrema.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const BOXES=[Rect2i(976,149,79,25),Rect2i(1039,162,46,22),Rect2i(1016,202,81,27)]
var out:="user://qa/bird-cloud-sampling/"
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
func maximum(a:Image,b:Image,box:Rect2i)->float:
 var result:=0.0
 for y:int in range(box.position.y,box.end.y):
  for x:int in range(box.position.x,box.end.x):
   var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
   result=maxf(result,maxf(absf(d.r),maxf(absf(d.g),absf(d.b))))
 return result*255.0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 RenderingServer.render_loop_enabled=false
 DirAccess.make_dir_recursive_absolute(out)
 for family:String in ["residential","postal"]:
  var road=Road.new();road.size=Vector2(1600,900);road.district=family if family=="residential" else "coastal";road.postal=family=="postal";root.add_child(road);road.hide();road.set_process(false);road.courier.set_process(false)
  var view:=SubViewport.new();view.size=road.art.texture.get_size();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
  var art:=TextureRect.new();art.texture=road.art.texture;art.material=road.atmosphere_material;art.size=view.size;view.add_child(art)
  var cloud:=TextureRect.new();cloud.texture=road.clouds.texture;cloud.material=road.cloud_material;cloud.size=view.size;view.add_child(cloud)
  for weather:float in [60.0,120.0,180.0,891.69,998.31]:
   road.set_weather_time(weather)
   for phase:int in range(4):
    road.set_time_of_day([540.0,720.0,1050.0,1200.0][phase]);art.texture=road.art.texture;cloud.texture=road.clouds.texture
    var name:="%s_%d_%d"%[family,int(weather*100),phase]
    cloud.show();var visible:=await picture(view)
    cloud.hide();var bare:=await picture(view)
    var deltas:Array=[]
    if not(family=="residential" and phase==3):
     for box:Rect2i in BOXES:
      var delta:=maximum(visible,bare,box);deltas.append(delta)
      check(delta<=2.01,name+" original moving wing matches under cloud overlay, delta="+str(delta))
    var margin:=maximum(visible,bare,Rect2i(950,145,24,40))
    check(margin<16.01,name+" empty sky margin contains no displaced wing/scenery fragment, delta="+str(margin))
    var crop:=Rect2i(940,130,180,115)
    visible.get_region(crop).save_png(out+name+"_cloud.png")
    bare.get_region(crop).save_png(out+name+"_bare.png")
    records.append({"case":name,"wing_deltas_255":deltas,"margin_delta_255":margin})
  road.queue_free();view.queue_free();await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"method":"Offscreen GPU comparison of actual PCK cloud overlay and underlying original moving wings; independent measured source rectangles; normal and late wind-clock extrema."},"  "))
 print("BIRD_CLOUD_SAMPLING ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
