extends SceneTree
const A=preload("res://scripts/rebuild/street_atmosphere.gd")
const Road=preload("res://scripts/rebuild/coastal_road.gd")
# Candidate grass rectangles also overlap painted rigid objects. These two
# contain crates/building base and palm fruit/supports, not loose grass; they
# must remain stationary instead of satisfying a blanket motion threshold.
const STATIONARY_CANDIDATES={
 Vector4(4435,458,4540,515):"crates and building base",
 Vector4(6090,470,6160,515):"palm fruit and supports"
}
var failures:=0
func _initialize()->void:run.call_deferred()
func run()->void:
 var road=Road.new();road.district="community";road.size=Vector2(1600,900);root.add_child(road)
 road.set_process(false);road.hide();road.set_time_of_day(720)
 var v:=SubViewport.new();v.size=Vector2i(9204,640);v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
 var art:=TextureRect.new();art.texture=road.period_textures[1];art.material=road.atmosphere_material;v.add_child(art)
 road.atmosphere_material.set_shader_parameter("weather_time",0.0)
 await process_frame;await RenderingServer.frame_post_draw
 var before:Image=v.get_texture().get_image()
 road.atmosphere_material.set_shader_parameter("weather_time",1.25)
 await process_frame;await RenderingServer.frame_post_draw
 var after:Image=v.get_texture().get_image()
 for kind:String in ["grass","trees","sea"]:
  for r:Vector4 in A.REGIONS.community[kind]:
   var changed:=0
   var changed_samples:Array[Vector2i]=[]
   for y in range(int(r.y),int(r.w),2):
    for x in range(int(r.x),int(r.z),2):
     if before.get_pixel(x,y)!=after.get_pixel(x,y):
      changed+=1
      if changed_samples.size()<24:changed_samples.append(Vector2i(x,y))
   print(kind," ",r," changed_pixels=",changed)
   if kind=="grass" and STATIONARY_CANDIDATES.has(r):
    if changed>0:print("STATIONARY_CHANGED_SAMPLES ",STATIONARY_CANDIDATES[r]," ",changed_samples)
    if changed>0:failures+=1;push_error("Stationary "+STATIONARY_CANDIDATES[r]+" moved "+str(r)+" pixels="+str(changed))
   elif changed<8:failures+=1;push_error("Motion missing from painted "+kind+str(r))
 # Independently observed critical fixtures must remain protected. Additional
 # guards are allowed; an old fixed total must not require deleting repairs.
 var rigid_count:=int(road.atmosphere_material.get_shader_parameter("rigid_count"))
 var rigid_regions:Array[Vector4]=[]
 rigid_regions.assign(road.atmosphere_material.get_shader_parameter("rigid_regions"))
 for required:Vector4 in [Vector4(7526,330,7654,397),Vector4(7578,390,7602,516),Vector4(1776,438,1785,516),Vector4(480,65,655,358),Vector4(390,444,700,515)]:
  if not required in rigid_regions.slice(0,rigid_count):failures+=1;push_error("Required painted rigid fixture guard missing: "+str(required))
 var fixtures:=0
 for index in range(rigid_count):
  var r:Vector4=rigid_regions[index]
  var changed:=0
  for y in range(int(r.y)+4,int(r.w)-4,2):
   for x in range(int(r.x)+4,int(r.z)-4,2):
    if before.get_pixel(x,y)!=after.get_pixel(x,y):changed+=1
  fixtures+=1
  if changed>0:failures+=1;push_error("Rigid fixture moved "+str(r)+" pixels="+str(changed))
 print("RIGID_FIXTURES ",fixtures," checked, including all 8 lamp heads/poles and the flag pole")
 road.set_time_of_day(1200)
 # This test owns a separate TextureRect; update its base texture too so the
 # night assertions inspect the night painting, not the retained noon image.
 art.texture=road.art.texture
 road.atmosphere_material.set_shader_parameter("weather_time",0.0)
 await process_frame;await RenderingServer.frame_post_draw
 var night_a:Image=v.get_texture().get_image()
 road.atmosphere_material.set_shader_parameter("weather_time",9.0)
 await process_frame;await RenderingServer.frame_post_draw
 var night_b:Image=v.get_texture().get_image()
 for index in range(rigid_count):
  var r:Vector4=rigid_regions[index]
  for y in range(int(r.y)+4,int(r.w)-4,2):
   for x in range(int(r.x)+4,int(r.z)-4,2):
    if night_a.get_pixel(x,y)!=night_b.get_pixel(x,y):failures+=1;push_error("Night fixture moved "+str(r));break
 print("NIGHT_RIGID_FIXTURES ",rigid_count," checked, including all 8 lamps and the flag pole")
 var floor_changed:=0
 for y in range(521,630,3):
  for x in range(0,9204,4):
   if before.get_pixel(x,y)!=after.get_pixel(x,y):floor_changed+=1
 if floor_changed>0:failures+=1;push_error("Ground moved")
 print("VISIBLE_MOTION regions=",A.REGIONS.community.grass.size()+A.REGIONS.community.trees.size()+A.REGIONS.community.sea.size()," ground_changed=",floor_changed," failures=",failures)
 road.queue_free();v.queue_free();await process_frame;quit(1 if failures else 0)
