extends SceneTree
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const OUT="res://test-results/fountain-collar-20261103/"
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func shot(view:SubViewport)->Image:
 await process_frame;RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 OS.low_processor_usage_mode=false;RenderingServer.render_loop_enabled=false
 var view:=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var road=Road.new();road.district="community";road.size=Vector2(1600,900);view.add_child(road)
 road.set_process(false);road.courier.set_process(false);road.courier.hide();road.world.position=Vector2.ZERO;road.set_weather_time(0)
 var rows:Array=[]
 for period:Array in [["noon",720],["night",1200]]:
  road.set_time_of_day(period[1])
  for index in range(3):
   road.set_fountain_time(float(index)/3.0+.001)
   road.fountain.material.set_shader_parameter("spout_edge_cleanup",0.0)
   var before:=await shot(view)
   road.fountain.material.set_shader_parameter("spout_edge_cleanup",1.0)
   var after:=await shot(view)
   var source:Image=road.fountain_frames[index].get_image()
   var selected:=0;var changed:=0;var residual:=0
   var tint:Color=road.fountain.modulate
   # Only actual upper-spout white source pigment; cream sculpture is excluded.
   for sy in range(392,437):
    for sx in range(150,320):
     var c:=source.get_pixel(sx,sy)
     if c.a<.97 or c.r<.86 or c.g<.92 or c.b<.90:continue
     var xy:Vector2i=Vector2i(road.fountain.position+Vector2(float(sx)/486.0,float(sy)/620.0)*road.fountain.size)
     var a:=before.get_pixelv(xy);var b:=after.get_pixelv(xy)
     var ar:=a.r/tint.r;var ag:=a.g/tint.g
     if ar<.82 or ag-ar>.10:continue
     selected+=1
     if a.r-b.r>.025:changed+=1
     if b.r/tint.r>.82 and b.g/tint.g-b.r/tint.r<.10:residual+=1
   check(selected>50,"%s frame%d has measured original white collar"%[period[0],index])
   check(changed>=selected*.85,"%s frame%d recolors at least85 percent of white collar"%[period[0],index])
   check(residual<=selected*.15,"%s frame%d leaves no broad white collar"%[period[0],index])
   rows.append({"period":period[0],"frame":index,"selected_white_collar_pixels":selected,"recolored_pixels":changed,"residual_white_pixels":residual})
   var crop:=Rect2i(825,525,135,130)
   before.get_region(crop).save_png(OUT+"%s_%d_before.png"%[period[0],index])
   after.get_region(crop).save_png(OUT+"%s_%d_after.png"%[period[0],index])
 var out:=FileAccess.open(OUT+"receipt.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"method":"Actual noon/night current scene, all3 imported frames, same-frame old/new collar cleanup comparison. Select white collar directly from immutable source pixels, exclude warm statue pigment, measure rendered white-band reduction. Original frames and lower-stream interior detail retained."},"  "));out.close()
 print("FOUNTAIN_COLLAR_QUALITY ",checks," checks, ",failures.size()," failures")
 road.queue_free();view.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
