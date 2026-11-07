extends SceneTree
## Independent original-art postal blade inventory; real GLES framebuffer checks.
## This fixture does not change saves, inputs, window focus, art, or production state.
const Atmosphere=preload("res://scripts/rebuild/street_atmosphere.gd")
const TIMES=[0.0,1.5,3.0,6.0,9.0,20.0]
const OBJECTS={"postal":[
 ["bent_lime_blade",Rect2i(1865,449,29,45)],
 ["lamp_left",Rect2i(2959,496,14,14)],
 ["lamp_right",Rect2i(2983,499,8,11)],
 ["isolated_upright",Rect2i(2999,484,19,28)],
 ["short_upright",Rect2i(3022,497,18,15)],
 ["tall_upright",Rect2i(3049,471,17,35)],
 ["right_fork",Rect2i(3068,490,20,20)]]}
const GUARDS={"postal":[Rect2i(2975,430,7,65),Rect2i(1893,483,15,22),Rect2i(1860,508,25,8),Rect2i(2950,517,145,5)]}
var output:="res://test-results/postal-open-grass-20261107/"
var checks:=0
var failures:Array[String]=[]
var records:Array[Dictionary]=[]
func _initialize()->void:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=").replace("\\","/").trim_suffix("/")+"/"
 run.call_deferred()
func verify(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func picture(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()
func texture(path:String)->ImageTexture:
 return ImageTexture.create_from_image(Image.load_from_file(path))
func phase_path(_family:String,phase:String)->String:
 return "res://assets/authoring/town_20261029/post_v2_"+phase+".png"
func difference(a:Color,b:Color)->float:
 return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func selected(c:Color)->bool:
 return (c.g-c.r>.025 and c.g-c.b>.035) or (c.g-c.r>-.055 and minf(c.r,c.g)-c.b>.12)
func points(image:Image,box:Rect2i)->Array[Vector2i]:
 var result:Array[Vector2i]=[]
 for y in range(box.position.y,box.end.y):
  for x in range(box.position.x,box.end.x):
   if selected(image.get_pixel(x,y)):result.append(Vector2i(x,y))
 return result
func changed(a:Image,b:Image,selected_points:Array[Vector2i])->int:
 var total:=0
 for p:Vector2i in selected_points:
  if difference(a.get_pixelv(p),b.get_pixelv(p))>2.0/255.0:total+=1
 return total
func run()->void:
 root.unfocusable=true
 OS.low_processor_usage_mode=false
 RenderingServer.render_loop_enabled=false
 DirAccess.make_dir_recursive_absolute(output)
 var full:=SubViewport.new();full.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(full)
 var art:=TextureRect.new();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;full.add_child(art)
 var normal:=SubViewport.new();normal.size=Vector2i(1280,720);normal.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(normal)
 var normal_art:=TextureRect.new();normal_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;normal.add_child(normal_art)
 for family:String in OBJECTS:
  var noon:=Image.load_from_file(phase_path(family,"noon"))
  var material:=ShaderMaterial.new();material.shader=load("res://scripts/rebuild/street_atmosphere.gdshader")
  material.set_shader_parameter("community",false)
  material.set_shader_parameter("day_geometry",texture(phase_path(family,"morning")))
  material.set_shader_parameter("foregrass_original_art",texture(phase_path(family,"morning")))
  Atmosphere.apply_regions(material,family);Atmosphere.apply_rigid(material,family)
  art.material=material;normal_art.material=material
  full.size=noon.get_size();art.size=Vector2(full.size)
  normal_art.size=Vector2(full.size)*1.2
  var inventory:Array=[]
  for item:Array in OBJECTS[family]:
   var point_list:=points(noon,item[1]);inventory.append(point_list)
   verify(point_list.size()>=8,"Original grass pigment exists: "+family+"/"+item[0])
  for phase:String in Atmosphere.PERIODS:
   var selected_texture:=texture(phase_path(family,phase))
   art.texture=selected_texture;normal_art.texture=selected_texture
   material.set_shader_parameter("next_art",selected_texture)
   material.set_shader_parameter("light_mix",0.0)
   var first:Image
   var maxima:Array[int]=[];maxima.resize(OBJECTS[family].size());maxima.fill(0)
   for seconds:float in TIMES:
    material.set_shader_parameter("weather_time",seconds)
    var shot:=await picture(full)
    if first==null:first=shot
    for index in range(inventory.size()):maxima[index]=maxi(maxima[index],changed(first,shot,inventory[index]))
    var ground_changed:=0
    for x in range(0,noon.get_width(),4):
     for y in range(517,527):
      if difference(first.get_pixel(x,y),shot.get_pixel(x,y))>1.0/255.0:ground_changed+=1
    verify(ground_changed==0,"Flat ground stays still %s/%s %.1f"%[family,phase,seconds])
    for box:Rect2i in GUARDS[family]:
     var rigid_changed:=0
     for y in range(box.position.y,box.end.y):
      for x in range(box.position.x,box.end.x):
       if difference(first.get_pixel(x,y),shot.get_pixel(x,y))>1.0/255.0:rigid_changed+=1
     verify(rigid_changed==0,"Observed support/stiff plant stays still %s/%s %s %.1f"%[family,phase,box,seconds])
   for index in range(OBJECTS[family].size()):
    var item:Array=OBJECTS[family][index]
    verify(maxima[index]>=8,"Grass moves at original pixels %s/%s/%s: %d"%[family,phase,item[0],maxima[index]])
    var box:Rect2i=item[1]
    normal_art.position=Vector2(640.0-float(box.get_center().x)*1.2,20.0)
    var normal_first:Image
    var normal_max:=0
    var screen_points:Array[Vector2i]=[]
    for p:Vector2i in inventory[index]:screen_points.append(Vector2i(Vector2(p)*1.2+normal_art.position))
    for seconds:float in [0.0,3.0,6.0]:
     material.set_shader_parameter("weather_time",seconds)
     var frame:=await picture(normal)
     if normal_first==null:normal_first=frame
     normal_max=maxi(normal_max,changed(normal_first,frame,screen_points))
     var name:="%s_%s_%s_%d"%[family,phase,item[0],roundi(seconds)]
     var crop:=Rect2i(Vector2i(Vector2(box.position)*1.2+normal_art.position)-Vector2i(12,12),Vector2i(Vector2(box.size)*1.2)+Vector2i(24,24))
     frame.get_region(crop).save_png(output+name+".png")
     if index==0:frame.save_png(output+family+"_"+phase+"_normal_"+str(roundi(seconds))+".png")
    verify(normal_max>=5,"Grass visible in 1280 GPU crop %s/%s/%s: %d"%[family,phase,item[0],normal_max])
    records.append({"family":family,"phase":phase,"object":item[0],"source_pixels":inventory[index].size(),"source_changed":maxima[index],"normal_changed":normal_max})
  art.material=null;normal_art.material=null
 full.queue_free();normal.queue_free();await process_frame
 var result={"checks":checks,"failures":failures,"objects":records,"method":"Actual GLES framebuffer; independent original pigment inventory; four phases; 6 source times; 1280 viewport at production 1.2 source-pixel scale. Changed counts are coverage evidence, not human aesthetic acceptance."}
 var file:=FileAccess.open(output+"receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("POSTAL_OPEN_GRASS checks=",checks," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)
