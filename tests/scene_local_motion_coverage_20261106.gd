extends SceneTree
## Offscreen GPU checks for the actual authored cover and two-room atlas.
## Uses no save data, OS input, or hidden gameplay paths.
const Motion=preload("res://scripts/rebuild/scene_local_motion.gd")
const COVER="res://assets/display_user/dear_somewhere_cover_USER_20261024.png"
const ROOM="res://assets/authoring/post_office_20261019/room_pair.jpg"
const SAMPLES=[0.0,1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5,21.0,22.5]
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/local_motion_coverage/"
var records:Array[Dictionary]=[]
func _initialize()->void:
 root.unfocusable=true
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
 run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frame(view:SubViewport)->Image:
 await process_frame
 await RenderingServer.frame_post_draw
 return view.get_texture().get_image()
func pixel_rect(source:Rect2,origin:float,dimensions:Vector2)->Rect2i:
 var scale:=Vector2(1280,720)/dimensions
 var start:=(source.position-Vector2(origin,0))*scale
 var end:=(source.end-Vector2(origin,0))*scale
 var a:=Vector2i(ceilf(start.x)+1,ceilf(start.y)+1)
 var b:=Vector2i(floorf(end.x)-1,floorf(end.y)-1)
 return Rect2i(a,b-a)
func changed_pixels(a:Image,b:Image,region:Rect2i)->int:
 var count:=0
 for y:int in range(region.position.y,region.end.y):
  for x:int in range(region.position.x,region.end.x):
   var delta:=a.get_pixel(x,y)-b.get_pixel(x,y)
   if maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b)))>2.0/255.0:count+=1
 return count
func run()->void:
 DirAccess.make_dir_recursive_absolute(out)
 var view:=SubViewport.new();view.size=Vector2i(1280,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 for kind:String in ["cover","counter","workroom"]:
  var is_cover:=kind=="cover"
  # Match the production resource loader: exported rooms are imported textures,
  # not raw JPEG files. Keep this fixture valid in an asset-free PCK host.
  var tex:Texture2D=load(COVER if is_cover else ROOM)
  check(tex!=null,kind+" original texture resource is available")
  if tex==null:continue
  var source:=tex.get_image()
  var art:=TextureRect.new();art.size=Vector2(1280,720);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_SCALE;art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  var origin:=1926.0 if kind=="workroom" else 0.0
  var dimensions:=Vector2(source.get_size()) if is_cover else Vector2(1914,1080)
  if is_cover:art.texture=tex
  else:
   var atlas:=AtlasTexture.new();atlas.atlas=tex;atlas.region=Rect2(origin,0,1914,1080);atlas.filter_clip=true;art.texture=atlas
  view.add_child(art)
  var original:=await frame(view)
  if is_cover:
   # The newly supplied 2026-11-07 cover stays intact; the old illustration's
   # pixel-space boat masks must not be applied to its different composition.
   check(source.get_size()==Vector2i(7262,4085),"cover retains supplied full resolution")
   await create_timer(.1).timeout
   var unchanged:=await frame(view)
   check(original.get_data()==unchanged.get_data(),"new cover remains unwarped")
   unchanged.save_png(out+"cover_original.png")
   records.append({"scene":kind,"motion":"disabled for replacement illustration"})
   art.queue_free();await process_frame
   continue
  var driver=Motion.attach_room(art)
  driver.set_process(false);driver.material.set_shader_parameter("motion_strength",0.0)
  var still:=await frame(view)
  check(original.get_data()==still.get_data(),kind+" zero motion is byte-exact source rendering")
  driver.material.set_shader_parameter("motion_strength",1.0)
  var guards:Dictionary={}
  var targets:Dictionary={}
  if kind=="counter":
   guards={"door_and_parcel":Rect2(0,0,400,1080),"spine_phone_table":Rect2(610,650,1304,430),"lower_paper_stack_and_red_cover":Rect2(430,930,470,150)}
   targets={"free_book_corner":Rect2(440,740,165,185)}
  else:
   guards={"window_and_chair":Rect2(2000,90,1320,600),"wooden_rack":Rect2(3492,0,348,1080),"large_pin":Rect2(3426,195,38,49),"small_pin":Rect2(3439,422,10,10),"desk_and_typewriter":Rect2(2400,700,1439,380)}
   targets={"hanging_note":Rect2(3350,250,140,139),"small_note":Rect2(3419,394,63,61)}
  var maxima:Dictionary={}
  for name:String in targets:maxima[name]=0
  var first:Image
  for t:float in SAMPLES:
   driver.set_motion_time(t)
   var image:=await frame(view)
   if first==null:first=image
   for name:String in guards:
    var region:=pixel_rect(guards[name],origin,dimensions)
    check(image.get_region(region).get_data()==still.get_region(region).get_data(),kind+" "+name+" fixed at "+str(t))
   for name:String in targets:
    maxima[name]=maxi(maxima[name],changed_pixels(first,image,pixel_rect(targets[name],origin,dimensions)))
   if t in [0.0,1.5,3.0,4.5,6.0,9.0,12.0,15.0,18.0]:image.save_png(out+kind+"_"+str(t).replace(".","_")+".png")
  for name:String in targets:
   check(int(maxima[name])>=12,kind+" "+name+" moves at the real 1280 window scale")
  records.append({"scene":kind,"max_changed_pixels_gt2":maxima,"samples":SAMPLES,"fixed_regions":guards.keys()})
  art.queue_free();await process_frame
 # Match the room component: both crossfade images are created in the same
 # frame and only their AtlasTexture changes when navigating between rooms.
 var room_source:Texture2D=load(ROOM)
 var left:=AtlasTexture.new();left.atlas=room_source;left.region=Rect2(0,0,1914,1080)
 var right:=AtlasTexture.new();right.atlas=room_source;right.region=Rect2(1926,0,1914,1080)
 var previous:=TextureRect.new();previous.texture=left;view.add_child(previous)
 var current:=TextureRect.new();current.texture=left;view.add_child(current)
 var previous_driver=Motion.attach_room(previous)
 var current_driver=Motion.attach_room(current)
 await create_timer(.12).timeout
 check(is_equal_approx(previous_driver.motion_time,current_driver.motion_time),"room crossfade drivers share a continuous clock")
 var before_swap:float=current_driver.motion_time
 previous.texture=current.texture;current.texture=right
 await create_timer(.12).timeout
 check(current_driver.motion_time>before_swap,"changing the room atlas does not reset paper pose time")
 check(is_equal_approx(previous_driver.motion_time,current_driver.motion_time),"old and new room remain phase aligned through crossfade")
 view.queue_free();await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"Actual GPU production Texture2D and AtlasTexture resource loading, zero-motion byte equality, fixed fixture pixels and 22.5-second motion coverage at 1280x720. This is not human gameplay acceptance.","records":records,"texture_paths":[COVER,ROOM]},"  "))
 print("LOCAL_MOTION_COVERAGE ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
