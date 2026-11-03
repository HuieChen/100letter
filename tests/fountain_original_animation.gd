extends SceneTree
## Render the actual road and imported overlay together. No substitute water effect.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const OUT="res://test-results/fountain-original-20261103/"
const TIMES=[0.0,0.34,0.68,1.0]
const FRAME_IDS=[0,1,2,0]
var checks:=0
var failures:Array[String]=[]
var results:Array[Dictionary]=[]

func _initialize()->void:run.call_deferred()

func verify(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures.append(label)
  push_error(label)

func difference(a:Image,b:Image,box:Rect2i)->Dictionary:
 var count:=0
 var maximum:=0.0
 for y in range(box.position.y,box.end.y):
  for x in range(box.position.x,box.end.x):
   var c:=a.get_pixel(x,y)
   var d:=b.get_pixel(x,y)
   var delta:=maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))
   maximum=maxf(maximum,delta)
   if delta>.0041:count+=1
 return {"changed_pixels":count,"maximum_channel_difference":maximum}

func snapshot(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()

func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 OS.low_processor_usage_mode=false
 RenderingServer.render_loop_enabled=false
 var view:=SubViewport.new()
 view.size=Vector2i(1600,900)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var road=Road.new()
 road.district="community"
 road.size=Vector2(1600,900)
 view.add_child(road)
 road.set_process(false)
 road.courier.set_process(false)
 road.courier.hide()
 road.world.position=Vector2.ZERO
 road.atmosphere_material.set_shader_parameter("weather_time",0.0)
 verify(is_instance_valid(road.fountain),"Community road contains the original fountain overlay")
 verify(road.fountain_frames.size()==3,"All three imported fountain frames are present")
 if not is_instance_valid(road.fountain) or road.fountain_frames.size()!=3:
  save_receipt()
  quit(1)
  return
 verify(road.fountain.position.is_equal_approx(Vector2(386.5,86.7)*1.5),"Overlay aligns to supplied community statue")
 verify(road.fountain.size.is_equal_approx(Vector2(335.46,427.96)*1.5),"Overlay keeps source aspect and fitted community scale")
 for index in range(3):
  var original:=Image.load_from_file("res://assets/authoring/fountain_20261030/frame_%d.png"%index)
  var loaded:Image=road.fountain_frames[index].get_image()
  verify(original.get_size()==Vector2i(486,620),"Original frame %d dimensions"%index)
  verify(original.get_data()==loaded.get_data(),"Frame %d texture pixels equal supplied asset bytes"%index)
 var water_box:=Rect2i(666,537,336,135)
 var statue_box:=Rect2i(580,130,502,400)
 var basin_box:=Rect2i(589,672,486,84)
 for period:Array in [["noon",720.0],["night",1200.0]]:
  var label:String=period[0]
  road.set_time_of_day(period[1])
  verify(road.fountain.modulate.is_equal_approx(road.courier.modulate),label+" original water uses the scene light tint")
  var first:Image
  for i in range(TIMES.size()):
   road.set_fountain_time(TIMES[i])
   verify(road.fountain.texture==road.fountain_frames[FRAME_IDS[i]],"%s t=%.2f selects original frame %d"%[label,TIMES[i],FRAME_IDS[i]])
   var shot:Image=await snapshot(view)
   if first==null:first=shot
   var water:=difference(first,shot,water_box)
   var statue:=difference(first,shot,statue_box)
   var basin:=difference(first,shot,basin_box)
   var row:={"period":label,"seconds":TIMES[i],"frame":FRAME_IDS[i],"water":water,"statue":statue,"basin":basin}
   results.append(row)
   if i in [1,2]:verify(water.changed_pixels>100,"%s frame %d original water visibly changes pixels"%[label,FRAME_IDS[i]])
   verify(statue.changed_pixels==0,"%s frame %d statue remains fixed"%[label,FRAME_IDS[i]])
   verify(basin.changed_pixels==0,"%s frame %d stone basin remains fixed"%[label,FRAME_IDS[i]])
   if i==3:verify(first.get_data()==shot.get_data(),label+" animation returns exactly to frame zero after one second")
   var suffix:="%s_%04d"%[label,roundi(TIMES[i]*100)]
   shot.save_png(OUT+suffix+".png")
   shot.get_region(Rect2i(555,105,570,680)).save_png(OUT+"fountain_"+suffix+".png")
 # An adjacent-minute sample catches a discrete overlay tint jump at the
 # sunset/night boundary while allowing the authored time blend to progress.
 road.set_time_of_day(1139.99)
 var before:Color=road.fountain.modulate
 road.set_time_of_day(1140.01)
 var after:Color=road.fountain.modulate
 var tint_delta:=maxf(absf(before.r-after.r),maxf(absf(before.g-after.g),absf(before.b-after.b)))
 verify(tint_delta<.002,"Original fountain tint is continuous across sunset/night")
 results.append({"tint_boundary_delta":tint_delta})
 save_receipt()
 print("FOUNTAIN_ORIGINAL_ANIMATION ",checks," checks, ",failures.size()," failures")
 road.queue_free()
 view.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)

func save_receipt()->void:
 var receipt:={"checks":checks,"failures":failures,"samples":results,"method":"Actual community road and imported water overlay rendered together on GPU at 1600x900; fixed camera/weather; source asset byte equality, original frame order/cadence, rendered water changes, rigid statue/basin, exact loop and scene tint. Automated evidence is not user aesthetic acceptance."}
 var output:=FileAccess.open(OUT+"receipt.json",FileAccess.WRITE)
 output.store_string(JSON.stringify(receipt,"  "))
 output.close()
