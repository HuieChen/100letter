extends SceneTree
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const OUT="res://test-results/clouds-20261103/"
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func capture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 OS.low_processor_usage_mode=false;RenderingServer.render_loop_enabled=false
 var view:=SubViewport.new();view.size=Vector2i(9204,640);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var road=Road.new();road.district="community";road.size=Vector2(13806,960);road.scale=Vector2.ONE/1.5;view.add_child(road)
 road.set_process(false);road.courier.set_process(false);road.courier.hide();road.world.position=Vector2.ZERO
 road.set_time_of_day(720);road.set_fountain_time(0);road.atmosphere_material.set_shader_parameter("weather_time",0)
 var source:Image=road.period_textures[0].get_image()
 var first:Image
 var samples:Array=[]
 for seconds:float in [0.0,6.0,12.0,49.0,98.0,147.0,600.0]:
  road.cloud_material.set_shader_parameter("weather_time",seconds)
  var shot:=await capture(view)
  if first==null:first=shot
  var fixed_changed:=0;var clouds_changed:=0
  for y in range(70,530,2):
   for x in range(30,9180,2):
    var c:=source.get_pixel(x,y);var a:=first.get_pixel(x,y);var b:=shot.get_pixel(x,y)
    var delta:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
    # Independent original foreground pigments: warm buildings/statue/wood,
    # green foliage, and dark lamp poles, all must remain pixel-stationary.
    var foreground:bool=(c.r>c.b+.08 and c.r>c.g+.025) or (c.g>c.b+.055 and c.g>c.r+.03) or maxf(c.r,maxf(c.g,c.b))<.30
    if foreground and delta>.0041:fixed_changed+=1
    if y<350 and c.r>.32 and c.g>c.r+.035 and c.b>c.g+.025 and delta>.0041:clouds_changed+=1
  check(fixed_changed==0,"Cloud flow leaves original foreground fixed at %.1fs (%d changed)"%[seconds,fixed_changed])
  if seconds in [6.0,12.0,49.0,147.0,600.0]:check(clouds_changed>300,"Actual original cloud contours move at %.1fs (%d pixels)"%[seconds,clouds_changed])
  samples.append({"seconds":seconds,"fixed_changed":fixed_changed,"cloud_pixels_changed":clouds_changed})
  if seconds in [0.0,6.0,49.0]:
   shot.get_region(Rect2i(20,30,1650,500)).save_png(OUT+"fountain_cloud_%04d.png"%roundi(seconds*10))
   shot.get_region(Rect2i(4900,120,800,390)).save_png(OUT+"open_cloud_%04d.png"%roundi(seconds*10))
  if seconds==6.0:shot.save_png(OUT+"panorama.png")
 # A disabled layer reveals the exact original rendering; no replacement sky.
 road.cloud_material.set_shader_parameter("motion_strength",0)
 var off:=await capture(view)
 road.clouds.hide();var hidden:=await capture(view)
 check(off.get_data()==hidden.get_data(),"Disabling cloud motion leaves underlying art unchanged")
 var receipt={"checks":checks,"failures":failures,"samples":samples,"method":"Actual current community scene at source resolution; only cloud clock advances. Independent original foreground pigments remain stationary and original cloud pixels change, including positive/negative maximum travel. No source art rewritten."}
 var out:=FileAccess.open(OUT+"receipt.json",FileAccess.WRITE);out.store_string(JSON.stringify(receipt,"  "));out.close()
 print("STREET_CLOUDS ",checks," checks, ",failures.size()," failures")
 road.queue_free();view.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
