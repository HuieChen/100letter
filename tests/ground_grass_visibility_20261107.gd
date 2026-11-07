extends SceneTree
## Fixed source-observed objects at the actual 1280x720 Road scale.
## No production masks/regions are read to choose blade targets.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const GROUPS=[
 {"id":"residential_fountain","optional":true,"family":"residential","start":0.0,"targets":[["fountain_left",Rect2i(435,485,16,16)],["fountain_right",Rect2i(660,481,19,21)]],"guards":[Rect2i(500,480,80,4),Rect2i(425,517,50,4),Rect2i(647,517,57,4)]},
 {"id":"community_fountain","family":"community","start":0.0,"targets":[["fountain_left",Rect2i(435,485,16,16)],["fountain_right",Rect2i(660,481,19,21)],["small_1015",Rect2i(1006,479,21,23)]],"guards":[Rect2i(425,517,50,4),Rect2i(990,517,47,4)]},
 {"id":"community_open","family":"community","start":4500.0,"targets":[["single_4805",Rect2i(4795,463,26,32)],["open_4980",Rect2i(4960,443,29,38)],["three_blades_5180",Rect2i(5160,475,23,23)],["small_5340",Rect2i(5332,491,27,13)]],"guards":[Rect2i(4785,517,50,4),Rect2i(5155,517,53,4)]},
 {"id":"community_pots","family":"community","start":5500.0,"targets":[["small_5790",Rect2i(5782,481,30,22)],["pot_blade_5910",Rect2i(5910,478,12,17)],["pot_blade_5925",Rect2i(5925,480,14,15)],["pot_blade_5951",Rect2i(5951,479,12,16)]],"guards":[Rect2i(5875,469,35,4),Rect2i(5930,460,25,8),Rect2i(5888,517,78,4)]},
 {"id":"residential_chair","family":"residential","start":1300.0,"targets":[["chair_blades",Rect2i(1734,458,43,36)]],"guards":[Rect2i(1720,517,70,4)]},
 {"id":"residential_open","family":"residential","start":5100.0,"targets":[["bent_blades",Rect2i(5338,472,50,29)],["lamp_blades",Rect2i(5667,483,23,17)],["tree_before_bus",Rect2i(5997,474,46,26)]],"guards":[Rect2i(5691,476,5,15),Rect2i(5330,517,60,4)]},
 {"id":"coastal_lamp","family":"coastal","start":500.0,"targets":[["first_lamp",Rect2i(999,468,86,31)]],"guards":[Rect2i(1090,462,6,38),Rect2i(990,517,105,4)]},
 {"id":"coastal_open","family":"coastal","start":4400.0,"targets":[["late_lamp",Rect2i(4680,487,25,16)],["mailbox",Rect2i(4746,498,23,9)],["clump_left",Rect2i(4966,487,28,17)],["clump_right",Rect2i(5033,489,36,14)],["high_blades",Rect2i(5366,486,17,18)]],"guards":[Rect2i(4728,475,5,25),Rect2i(5004,470,13,13),Rect2i(4960,517,110,4)]},
 {"id":"postal_left_pots","family":"postal","start":0.0,"targets":[["left_pots_blades",Rect2i(413,478,45,28)],["tiny_pot_blade",Rect2i(470,503,12,9)],["pot_pair",Rect2i(630,500,18,12)]],"guards":[Rect2i(460,504,8,3),Rect2i(530,495,40,4),Rect2i(410,520,250,4)]},
 {"id":"postal_open","family":"postal","start":1400.0,"targets":[["upright_blades",Rect2i(1818,468,48,33)],["bent_blade",Rect2i(1862,450,31,45)]],"guards":[Rect2i(1810,520,100,4)]},
 {"id":"postal_lamp","family":"postal","start":2600.0,"targets":[["fence_right_blades",Rect2i(2875,498,42,14)],["left_lamp_blades",Rect2i(2960,488,30,17)],["right_lamp_blades",Rect2i(3030,486,25,17)],["tall_blade",Rect2i(3048,472,22,28)]],"guards":[Rect2i(2976,433,4,57),Rect2i(3010,520,75,4)]}
]
var out:="user://qa/ground-grass-visibility/"
var records:Array=[]
var capture_minute:=720.0
var only_groups:PackedStringArray=[]
func _initialize():
 root.unfocusable=true
 root.title="Ground grass visibility QA %d"%OS.get_process_id()
 auto_accept_quit=false
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").replace("\\","/").trim_suffix("/")+"/"
  if arg.begins_with("--qa-only="):only_groups=arg.trim_prefix("--qa-only=").split(",")
  if arg.begins_with("--qa-minute="):capture_minute=float(arg.trim_prefix("--qa-minute="))
 run.call_deferred()
func picture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func screen_rect(source:Rect2i,start:float,grow_by:int=0)->Rect2i:
 var a:=(Vector2(source.position)-Vector2(start,0.0))*1.2
 var b:=(Vector2(source.end)-Vector2(start,0.0))*1.2
 return Rect2i(Vector2i(floor(a.x),floor(a.y)),Vector2i(ceil(b.x)-floor(a.x),ceil(b.y)-floor(a.y))).grow(grow_by)
func screen_guard_rect(source:Rect2i,start:float)->Rect2i:
 # Keep only screen pixels fully inside the source-observed rigid surface.
 # Inward rounding excludes AA sampling from an adjacent moving blade.
 var a:=(Vector2(source.position)-Vector2(start,0.0))*1.2
 var b:=(Vector2(source.end)-Vector2(start,0.0))*1.2
 return Rect2i(Vector2i(ceil(a.x),ceil(a.y)),Vector2i(floor(b.x)-ceil(a.x),floor(b.y)-ceil(a.y)))
func changed(a:Image,b:Image,box:Rect2i)->int:
 var count:=0
 for y:int in range(box.position.y,box.end.y):
  for x:int in range(box.position.x,box.end.x):
   var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
   if maxf(absf(d.r),maxf(absf(d.g),absf(d.b)))>2.0/255.0:count+=1
 return count
func run():
 OS.low_processor_usage_mode=false
 RenderingServer.render_loop_enabled=false
 DirAccess.make_dir_recursive_absolute(out)
 var view:=SubViewport.new();view.size=Vector2i(1280,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 for group:Dictionary in GROUPS:
  if group.get("optional",false) and not group.id in only_groups:continue
  if not only_groups.is_empty() and not group.id in only_groups:continue
  var road=Road.new();road.district=group.family;road.postal=group.family=="postal";road.minute=int(capture_minute);road.size=Vector2(1600,900);road.scale=Vector2(0.8,0.8)
  view.add_child(road);road.process_mode=Node.PROCESS_MODE_DISABLED;road.set_time_of_day(capture_minute);road.world.position.x=-group.start*1.5
  var folder:String=out+group.id+"/";DirAccess.make_dir_recursive_absolute(folder)
  var data:={"id":group.id,"family":group.family,"minute":capture_minute,"camera_source_start":group.start,"targets":[],"guards":[],"frames":[]}
  for item:Array in group.targets:
   var r:Rect2i=item[1];var s:=screen_rect(r,group.start,5)
   data.targets.append({"name":item[0],"source_tip_box":[r.position.x,r.position.y,r.size.x,r.size.y],"screen_crop":[s.position.x,s.position.y,s.size.x,s.size.y]})
  for box:Rect2i in group.guards:
   var s:=screen_guard_rect(box,group.start)
   data.guards.append({"source_box":[box.position.x,box.position.y,box.size.x,box.size.y],"screen_box":[s.position.x,s.position.y,s.size.x,s.size.y],"max_changed_pixels":0})
  var first:Image
  for n:int in range(17):
   var seconds:=float(n)*0.5;road.set_weather_time(seconds);road.set_fountain_time(seconds)
   var shot:=await picture(view)
   if first==null:first=shot
   shot.save_png(folder+"normal_%02d.png"%n)
   for i:int in range(group.targets.size()):shot.get_region(screen_rect(group.targets[i][1],group.start,5)).save_png(folder+"%s_%02d.png"%[group.targets[i][0],n])
   for i:int in range(group.guards.size()):data.guards[i].max_changed_pixels=maxi(data.guards[i].max_changed_pixels,changed(first,shot,screen_guard_rect(group.guards[i],group.start)))
   data.frames.append(seconds)
  records.append(data);print("GRASS_VISIBILITY_CAPTURE ",group.id," 17 frames, roots ",data.guards)
  road.queue_free();await process_frame
 view.queue_free();await process_frame
 var result:={"method":"Actual Road scene at 1280x720, normal 0.8 UI scale and 1.2 screen px per source px. No shader-mask-derived targets. Fixed ordinary camera, specified original time-of-day art, weather time 0..8 s at 0.5 s intervals. Independent blade-pigment and edge analysis must follow; changed pixels are not claimed to prove visibility. No OS input or focus manipulation beyond no-focus fixture. No human acceptance implied.","groups":records}
 FileAccess.open(out+"capture.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("GRASS_VISIBILITY_COMPLETE ",records.size()," groups")
 quit()

