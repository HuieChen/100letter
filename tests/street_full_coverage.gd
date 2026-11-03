extends SceneTree
## Independent object inventory from the supplied panorama, not runtime regions.
## A changed ROI alone is insufficient: only actual painted material counts.
const Road=preload("res://scripts/rebuild/coastal_road.gd")
const OUT="res://test-results/street-full-coverage-20261103/"
const TIMES=[0.0,3.34,9.68,20.0]
var checks:=0
var failures:Array[String]=[]
var entries:Array[Dictionary]=[]

func _initialize()->void:run.call_deferred()
func verify(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func add_object(label:String,kind:String,box:Rect2i,polygon:Array=[])->void:
 entries.append({"name":label,"kind":kind,"box":box,"polygon":polygon})

func inventory()->void:
 # Source-image observations, deliberately separate from implementation lists.
 var grass=[
  ["grass_left_leaf_root_380",Rect2i(366,465,34,48)],
  ["grass_fountain_left_445",Rect2i(425,486,42,27)],
  ["grass_fountain_right_675",Rect2i(647,482,57,31)],
  ["grass_cactus_root_855",Rect2i(832,486,51,27)],
  ["grass_small_1015",Rect2i(1006,479,21,34)],
  ["bush_between_flags_1860",Rect2i(1845,411,43,102)],
  ["bush_under_flags_1960",Rect2i(1918,409,87,104)],
  ["community_building_planter_2580",Rect2i(2525,448,118,65)],
  ["grass_small_2720",Rect2i(2707,491,34,22)],
  ["grass_small_3468",Rect2i(3458,486,20,27)],
  ["grass_tiny_3490",Rect2i(3483,500,16,13)],
  ["grass_group_3627",Rect2i(3618,477,23,36)],
  ["grass_tiny_3647",Rect2i(3640,501,17,12)],
  ["grass_stones_4620",Rect2i(4618,471,29,42)],
  ["grass_behind_rock_4660",Rect2i(4655,469,18,44)],
  ["grass_tree_right_4740",Rect2i(4708,448,73,65)],
  ["grass_single_4805",Rect2i(4795,463,26,48)],
  ["grass_open_4980",Rect2i(4914,442,124,71)],
  ["grass_three_blades_5180",Rect2i(5155,475,53,38)],
  ["grass_small_5340",Rect2i(5332,491,27,22)],
  ["grass_small_5450",Rect2i(5421,494,49,19)],
  ["grass_lamppost_5670",Rect2i(5585,459,157,54)],
  ["grass_small_5790",Rect2i(5782,481,30,32)],
  ["grass_pot_left_5840",Rect2i(5820,479,49,34)],
  ["grass_pots_5930",Rect2i(5900,479,66,34)],
  ["grass_main_palm_root_6030",Rect2i(6015,484,40,29)],
  ["grass_small_palm_root_6800",Rect2i(6779,488,39,25)],
  ["grass_missing_big_6890",Rect2i(6850,464,101,49)],
  ["grass_curved_7010",Rect2i(7002,472,20,41)],
  ["grass_tip_7048",Rect2i(7040,495,16,18)],
  ["grass_tip_7085",Rect2i(7076,489,21,24)]
 ]
 for e:Array in grass:add_object(e[0],"grass",e[1])
 add_object("broad_leaf_left_fountain","leaf",Rect2i(248,381,147,119))
 add_object("cactus_fountain_left","leaf",Rect2i(419,277,57,175))
 add_object("cactus_fountain_right","leaf",Rect2i(840,328,56,173))
 add_object("fountain_water_left_low","water",Rect2i(447,397,40,49))
 add_object("fountain_water_left_high","water",Rect2i(499,363,44,84))
 add_object("fountain_water_right_high","water",Rect2i(570,362,30,84))
 add_object("fountain_water_right_low","water",Rect2i(622,398,42,48))
 add_object("left_parasol_free_cloth","cloth",Rect2i(57,355,138,80))
 add_object("second_yellow_flag","yellow_flag",Rect2i(1877,359,42,72),[Vector2(1877,359),Vector2(1919,359),Vector2(1919,421),Vector2(1900,402),Vector2(1877,425)])
 add_object("third_pink_flag_exposed_cloth","pink_flag",Rect2i(1987,360,29,74),[Vector2(1987,360),Vector2(2016,360),Vector2(2016,394),Vector2(1987,434)])
 add_object("grocery_blue_free_valance","blue_cloth",Rect2i(4233,379,245,33))
 add_object("narrow_tree_4700","leaf",Rect2i(4670,375,68,125))
 add_object("main_palm_crown","leaf",Rect2i(5917,145,225,183))
 add_object("cactus_leaf_5980","leaf",Rect2i(5960,392,40,76))
 add_object("small_palm_crown","leaf",Rect2i(6738,348,94,80))
 add_object("leaning_palm_left_upper","leaf",Rect2i(7617,145,100,64))
 add_object("leaning_palm_left_lower","leaf",Rect2i(7640,205,72,93))
 add_object("leaning_palm_top_tip","leaf",Rect2i(7693,94,45,91))
 add_object("leaning_palm_right_fronds","leaf",Rect2i(7745,125,89,142))
 add_object("rv_sign_potted_leaf","leaf",Rect2i(8026,476,66,44))
 add_object("market_canopy_fringe","cloth",Rect2i(6297,342,204,26))
 # Detached gold dashes beside the stall are authored light decoration, not
 # attached fabric; only the actual continuous hanging fringe is a cloth target.
 add_object("rv_awning_free_valance","cloth",Rect2i(7980,286,340,23),[Vector2(7980,286),Vector2(8310,286),Vector2(8320,307),Vector2(7980,307)])
 add_object("beach_parasol_free_rim","cloth",Rect2i(8359,217,356,94),[Vector2(8359,237),Vector2(8556,217),Vector2(8580,221),Vector2(8630,244),Vector2(8695,291),Vector2(8714,305),Vector2(8677,310),Vector2(8585,299),Vector2(8486,282),Vector2(8405,253)])

func painted_material(c:Color,kind:String)->bool:
 match kind:
  "grass","leaf":return c.g>c.r+.025 and c.g>c.b+.02
  "cloth":return c.r>c.b+.07 and c.r>c.g+.025
  "pink_flag":return c.r>c.g+.07 and c.b>c.g+.025
  "yellow_flag":return c.r>c.b+.12 and c.g>c.b+.09
  "blue_cloth":return c.b>c.r+.25 and c.g>c.r+.12
  "water":return c.g>c.r+.22 and c.b>c.r+.28 and c.b-c.g<.16
 return false

func selected_pixels(source:Image,item:Dictionary)->Array[Vector2i]:
 var points:Array[Vector2i]=[]
 var box:Rect2i=item.box
 var polygon:=PackedVector2Array(item.polygon)
 for y in range(box.position.y,box.end.y):
  for x in range(box.position.x,box.end.x):
   if not polygon.is_empty() and not Geometry2D.is_point_in_polygon(Vector2(x,y),polygon):continue
   # Actual source material selection excludes sea pixels in empty grass boxes.
   if painted_material(source.get_pixel(x,y),item.kind):points.append(Vector2i(x,y))
 return points

func changed(a:Image,b:Image,points:Array[Vector2i])->Dictionary:
 var count:=0
 var summed:=0.0
 for p:Vector2i in points:
  var x:=a.get_pixelv(p);var y:=b.get_pixelv(p)
  var delta:=maxf(absf(x.r-y.r),maxf(absf(x.g-y.g),absf(x.b-y.b)))
  if delta>.0041:count+=1
  summed+=delta
 return {"changed_pixels":count,"mean_channel_difference":summed/maxi(1,points.size())}

func picture(view:SubViewport)->Image:
 # The render loop may pause for an invisible native window. Never let the
 # timeline advance without a real GPU render, and avoid waiting for skipped draw.
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()

func run()->void:
 inventory()
 DirAccess.make_dir_recursive_absolute(OUT)
 OS.low_processor_usage_mode=false
 RenderingServer.render_loop_enabled=false
 var road=Road.new();road.district="community";road.size=Vector2(1600,900)
 root.add_child(road);road.hide();road.set_process(false);road.courier.set_process(false)
 road.set_time_of_day(720)
 var source:Image=road.period_textures[0].get_image()
 verify(source.get_size()==Vector2i(9204,640),"Current complete community source loaded")
 var view:=SubViewport.new();view.size=Vector2i(9204,640);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var art:=TextureRect.new();art.texture=road.art.texture;art.material=road.atmosphere_material;view.add_child(art)
 # The fountain is a separate original-frame layer in the production scene.
 # Render it too; shader-only coverage would incorrectly omit that animation.
 var fountain:=TextureRect.new();fountain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 fountain.material=road.fountain.material;fountain.modulate=road.fountain.modulate
 fountain.position=road.fountain.position/1.5;fountain.size=road.fountain.size/1.5;view.add_child(fountain)
 var masks:Array=[]
 var results:Array[Dictionary]=[]
 for entry:Dictionary in entries:
  var points:=selected_pixels(source,entry)
  masks.append(points)
  var minimum:int=8 if entry.kind=="grass" else 20
  verify(points.size()>=minimum,"Actual %s pigment exists for %s (%d pixels)"%[entry.kind,entry.name,points.size()])
  results.append({"name":entry.name,"kind":entry.kind,"source_box":[entry.box.position.x,entry.box.position.y,entry.box.size.x,entry.box.size.y],"selected_material_pixels":points.size(),"minimum_changed_pixels":minimum,"max_changed_pixels":0,"samples":[]})
 var first:Image
 for seconds:float in TIMES:
  road.atmosphere_material.set_shader_parameter("weather_time",seconds)
  road.set_fountain_time(seconds);fountain.texture=road.fountain.texture
  var shot:Image=await picture(view)
  var suffix:="%04d"%roundi(seconds*100)
  shot.save_png(OUT+"panorama_"+suffix+".png")
  for quarter in range(4):
   var x:int=quarter*2301
   shot.get_region(Rect2i(x,0,2301,640)).save_png(OUT+"quarter_%d_%s.png"%[quarter,suffix])
  if first==null:first=shot
  for index in range(entries.size()):
   var item:Dictionary=entries[index]
   var diff:=changed(first,shot,masks[index])
   results[index].max_changed_pixels=maxi(results[index].max_changed_pixels,diff.changed_pixels)
   results[index].samples.append({"weather_time":seconds,"changed_pixels":diff.changed_pixels,"mean_channel_difference":diff.mean_channel_difference})
   var box:Rect2i=item.box
   var crop:=Rect2i(box.position-Vector2i(8,8),box.size+Vector2i(16,16)).intersection(Rect2i(0,0,9204,640))
   shot.get_region(crop).save_png(OUT+"%s_%s.png"%[item.name,suffix])
 for result:Dictionary in results:
  verify(result.max_changed_pixels>=result.minimum_changed_pixels,"Motion in %s: %d actual-material pixels changed; need %d"%[result.name,result.max_changed_pixels,result.minimum_changed_pixels])
  print("OBJECT_COVERAGE ",result.name," material=",result.selected_material_pixels," changed=",result.max_changed_pixels)
 var receipt={"checks":checks,"failures":failures,"objects":results,"period":"noon","weather_times":TIMES,"method":"Direct current source; fixed full-panorama camera; source-material pixels selected independently from runtime regions. Minimum 8 grass / 20 other changed pixels is an automated coverage floor, not human visibility or aesthetic acceptance."}
 var output:=FileAccess.open(OUT+"receipt.json",FileAccess.WRITE);output.store_string(JSON.stringify(receipt,"  "));output.close()
 print("STREET_FULL_COVERAGE ",entries.size()," objects, ",checks," checks, ",failures.size()," failures")
 road.queue_free();view.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
