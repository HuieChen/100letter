extends SceneTree
## Re-enter actual streets; reuse must not change rendered art or keep families forever.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const Cache=preload("res://scripts/rebuild/street_texture_cache.gd")
var out:=""
var checks:=0
var failures:Array[String]=[]
func _initialize():
 root.unfocusable=true;root.title="Street asset reuse QA";auto_accept_quit=false
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").replace("\\","/").trim_suffix("/")+"/"
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func make_road(family:String,view:SubViewport)->Control:
 var road=Road.new();road.size=Vector2(1600,900);road.scale=Vector2(.8,.8);road.minute=720
 road.postal=family=="postal";road.district=family if family in ["community","residential"] else "coastal"
 var start:=Time.get_ticks_usec();view.add_child(road)
 road.set_meta("ready_ms",float(Time.get_ticks_usec()-start)/1000.0)
 road.set_process(false);road.courier.set_process(false);road.courier.hide()
 road.set_weather_time(1.25);road.set_fountain_time(.34);road.set_time_of_day(720)
 road.world.position=Vector2(-7450 if family=="postal" else 0,0)
 return road
func capture(view:SubViewport)->Image:
 await process_frame;await RenderingServer.frame_post_draw
 return view.get_texture().get_image()
func run():
 if out.is_empty():quit(2);return
 DirAccess.make_dir_recursive_absolute(out)
 var view:=SubViewport.new();view.size=Vector2i(1280,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var observed:Dictionary={}
 var first_mask:WeakRef
 for family:String in ["community","residential","postal","coastal"]:
  var a=make_road(family,view);await capture(view)
  var cache_texture:Texture2D=a.atmosphere_material.get_shader_parameter("foliage_clearance")
  if family=="community":first_mask=weakref(cache_texture)
  var original:=Image.load_from_file("res://assets/authoring/street_motion_masks_20261103/%s_foliage_clearance.png"%family)
  check(cache_texture.get_image().get_data()==original.get_data(),family+" cached mask preserves original bytes")
  var samples:Array[Vector3]=[Vector3(720,1.25,.34),Vector3(1120,5.5,.68),Vector3(1200,2.0,0)]
  var expected:Array[Image]=[]
  for s:Vector3 in samples:
   a.set_time_of_day(s.x);a.set_weather_time(s.y);a.set_fountain_time(s.z);expected.append(await capture(view))
  view.remove_child(a)
  var b=make_road(family,view)
  for parameter:String in ["foliage_clearance","foregrass_alpha","foregrass_backmap"]:
   var left=a.atmosphere_material.get_shader_parameter(parameter);var right=b.atmosphere_material.get_shader_parameter(parameter)
   if left!=null:check(left==right,family+" repeat entry shares "+parameter)
  for parameter:String in ["clearance","star_clearance"]:
   check(a.cloud_material.get_shader_parameter(parameter)==b.cloud_material.get_shader_parameter(parameter),family+" repeat entry shares cloud "+parameter)
  for i:int in a.fountain_frames.size():
   check(a.fountain_frames[i]==b.fountain_frames[i],family+" repeat entry shares original fountain frame "+str(i))
  for i:int in samples.size():
   var s:Vector3=samples[i];b.set_time_of_day(s.x);b.set_weather_time(s.y);b.set_fountain_time(s.z)
   var actual:=await capture(view)
   check(actual.get_data()==expected[i].get_data(),family+" re-entry pixels unchanged at phase "+str(s.x))
   if i==0:actual.save_png(out+family+".png")
  check(Cache._families.size()<=2,"Only two street families retained after "+family)
  observed[family]={"cold_ms":a.get_meta("ready_ms"),"repeat_ms":b.get_meta("ready_ms")}
  view.remove_child(b);a.free();b.free();cache_texture=null;original=null;expected.clear()
  await process_frame
 check(first_mask!=null and first_mask.get_ref()==null,"Evicted family's masks release after its last road closes")
 view.queue_free();await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observed_entry_ms":observed,"method":"Actual Road repeated entry; source-mask byte identity, three framebuffer phases, shared immutable textures and two-family lifetime. Timings describe this QA process, not promised FPS."},"  "))
 print("STREET_ASSET_REUSE ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
