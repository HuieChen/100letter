extends SceneTree
## Independent rendered regression for the user-reported flag / shrub / lamp faults.
## Coordinates and pixel classifications come from source artwork, never REGIONS/RIGID.
const Road = preload("res://scripts/rebuild/coastal_road.gd")
const OUT = "res://test-results/object-boundaries-20261103/"
const LAMP_CENTERS = [1092, 1646, 2916, 3702, 5091, 5697, 7128, 7589]
const TIMES = [0.0, 1.25, 9.0, 20.0]
const PERIODS = [["morning", 540.0, 0], ["noon", 720.0, 1], ["night", 1200.0, 3]]
var failures: Array[String] = []
var checks := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
 run.call_deferred()

func verify(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures.append(label)
  push_error(label)

func error_rgb(a: Color, b: Color) -> float:
 return maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))

func is_flag(c: Color) -> bool:
 return c.r > c.g + .12 and c.b > c.g + .025

func is_leaf(c: Color) -> bool:
 return c.g > c.r + .08 and c.g > c.b + .08

func interior(image: Image, p: Vector2i, flag: bool) -> bool:
 for dy in range(-2, 3):
  for dx in range(-2, 3):
   var c := image.get_pixel(p.x+dx, p.y+dy)
   if not (is_flag(c) if flag else is_leaf(c)):
    return false
 return true

func source_points(image: Image, box: Rect2i, flag: bool, eroded: bool) -> Array[Vector2i]:
 var points: Array[Vector2i] = []
 for y in range(box.position.y, box.end.y):
  for x in range(box.position.x, box.end.x):
   var c := image.get_pixel(x,y)
   if (is_flag(c) if flag else is_leaf(c)) and (not eroded or interior(image, Vector2i(x,y), flag)):
    points.append(Vector2i(x,y))
 return points

func lamp_points(noon: Image, center: int) -> Array[Vector2i]:
 var selected: Dictionary = {}
 # Painted brown / orange lamp pixels, including antialiased outlines. This
 # independent broad search spans the real head, collar, stem and foot.
 for y in range(326, 516):
  var half_width := 65 if y < 398 else 13
  # This pole's foot is hidden behind the grass. The wider bottom search
  # otherwise misclassifies ochre antialias pixels on adjacent grass tips.
  if center==5697 and y>475:
   half_width=5
  for x in range(center-half_width, center+half_width+1):
   var c := noon.get_pixel(x,y)
   if c.r > c.g+.035 and c.g > c.b+.015:
    for dy in range(-1, 2):
     for dx in range(-1, 2):
      selected[Vector2i(x+dx,y+dy)] = true
 var points: Array[Vector2i] = []
 for point: Vector2i in selected:
  points.append(point)
 return points

func changed_pixels(a: Image, b: Image, points: Array[Vector2i]) -> int:
 var changed := 0
 for p: Vector2i in points:
  if error_rgb(a.get_pixelv(p),b.get_pixelv(p)) > .0041:
   changed += 1
 return changed

func palm_edge_runs(shot: Image) -> Array[int]:
 # These independent scan lines cross the user-reported upper frond's right
 # edge. Blue-channel contrast detects even sky-colored antialias remnants,
 # which a green-pigment classification misses. One edge must stay one run.
 var counts: Array[int] = []
 for scan: Vector2i in [Vector2i(6075,180),Vector2i(6065,200),Vector2i(6055,220)]:
  var sky := shot.get_pixel(6149,scan.y).b
  var runs := 0
  var previous := false
  for x in range(scan.x,6140):
   var ink := sky-shot.get_pixel(x,scan.y).b > 4.0/255.0
   if ink and not previous:
    runs += 1
   previous=ink
  counts.append(runs)
 return counts

func support_points(morning: Image, boxes: Array[Rect2i]) -> Array[Vector2i]:
 var selected: Dictionary = {}
 for box: Rect2i in boxes:
  for y in range(box.position.y,box.end.y):
   for x in range(box.position.x,box.end.x):
    var c := morning.get_pixel(x,y)
    # Independent conservative opaque pigment selection plus its immediate
    # antialias neighbors; no production guard helper or region list is used.
    if c.r>c.g+.025 and c.r>c.b+.035:
     for dy in range(-1,2):
      for dx in range(-1,2):
       var neighbor:=morning.get_pixel(x+dx,y+dy)
       # A neighboring green leaf/vine/grass pixel is a separate moving
       # object, not the wood's blue-background antialias fringe.
       if neighbor.g>neighbor.r+.025 and neighbor.g>neighbor.b+.025:
        continue
       selected[Vector2i(x+dx,y+dy)]=true
 var points: Array[Vector2i] = []
 for p: Vector2i in selected:
  points.append(p)
 return points

func snapshot(view: SubViewport) -> Image:
 await process_frame
 await RenderingServer.frame_post_draw
 return view.get_texture().get_image()

func save_crops(shot: Image, suffix: String) -> void:
 shot.get_region(Rect2i(1725,335,185,185)).save_png(OUT+"flag_shrub_"+suffix+".png")
 shot.get_region(Rect2i(7025,315,220,210)).save_png(OUT+"reported_lamp_"+suffix+".png")
 shot.get_region(Rect2i(7505,315,175,210)).save_png(OUT+"eighth_lamp_"+suffix+".png")
 shot.get_region(Rect2i(5900,120,250,250)).save_png(OUT+"palm_"+suffix+".png")

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT)
 var road = Road.new()
 road.district = "community"
 road.size = Vector2(1600,900)
 root.add_child(road)
 road.set_process(false)
 road.courier.set_process(false)
 road.hide()
 var morning: Image = road.period_textures[0].get_image()
 var noon: Image = road.period_textures[1].get_image()
 verify(morning.get_size()==Vector2i(9204,640), "Full-resolution community artwork is loaded")
 var lamp_masks: Array = []
 for center: int in LAMP_CENTERS:
  var points := lamp_points(noon,center)
  lamp_masks.append(points)
  verify(points.size()>300, "Independent lamp silhouette exists at x=%d"%center)
 var pole_points: Array[Vector2i] = []
 for y in range(438,511):
  for x in range(1778,1783):
   var c := noon.get_pixel(x,y)
   if c.r < .65 and c.r > c.g+.08:
    pole_points.append(Vector2i(x,y))
 verify(pole_points.size()>80, "Independent flag pole silhouette exists")
 var flag_box := Rect2i(1753,357,53,108)
 var shrub_box := Rect2i(1786,430,90,82)
 var flag_points := source_points(morning,flag_box,true,false)
 var shrub_points := source_points(morning,shrub_box,false,false)
 var flag_inside := source_points(morning,flag_box,true,true)
 var shrub_inside := source_points(morning,shrub_box,false,true)
 verify(flag_inside.size()>500, "Flag interior is independently identified")
 verify(shrub_inside.size()>500, "Shrub interior is independently identified")
 var view := SubViewport.new()
 view.size = Vector2i(9204,640)
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var painted := TextureRect.new()
 painted.material = road.atmosphere_material
 view.add_child(painted)
 for period: Array in PERIODS:
  var label: String = period[0]
  road.set_time_of_day(period[1])
  painted.texture = road.art.texture
  road.atmosphere_material.set_shader_parameter("motion_strength",0.0)
  var still: Image = await snapshot(view)
  road.atmosphere_material.set_shader_parameter("motion_strength",1.0)
  var first: Image
  var max_flag_moved := 0
  var max_shrub_moved := 0
  for seconds: float in TIMES:
   road.atmosphere_material.set_shader_parameter("weather_time",seconds)
   var shot: Image = await snapshot(view)
   var row := {"period":label,"weather_time":seconds,"lamp_changed":[],"pole_changed":0,"flag_green_pixels":0,"shrub_pink_pixels":0}
   for index in range(LAMP_CENTERS.size()):
    var moved := changed_pixels(still,shot,lamp_masks[index])
    row.lamp_changed.append(moved)
    if moved>0:
     var examples: Array[Vector2i] = []
     for p: Vector2i in lamp_masks[index]:
      if error_rgb(still.get_pixelv(p),shot.get_pixelv(p))>.0041 and examples.size()<6:
       examples.append(p)
     print("LAMP_CHANGED_SAMPLES ",label," t=",seconds," x=",LAMP_CENTERS[index]," ",examples)
    verify(moved==0, "%s t=%s lamp x=%d stable against zero-motion reference; moved=%d"%[label,seconds,LAMP_CENTERS[index],moved])
   row.pole_changed = changed_pixels(still,shot,pole_points)
   verify(row.pole_changed==0, "%s t=%s flag pole stable; moved=%d"%[label,seconds,row.pole_changed])
   for p: Vector2i in flag_inside:
    var c := shot.get_pixelv(p)
    if c.g > c.r+.02:
     row.flag_green_pixels += 1
   for p: Vector2i in shrub_inside:
    var c := shot.get_pixelv(p)
    if c.r > c.g+.10:
     row.shrub_pink_pixels += 1
     if row.shrub_pink_pixels<5:
      print("SHRUB_COLOR_SAMPLE ",label," t=",seconds," p=",p," rendered=",c," still=",still.get_pixelv(p))
   verify(row.flag_green_pixels==0, "%s t=%s no green shrub pixels transported into flag interior; bad=%d"%[label,seconds,row.flag_green_pixels])
   verify(row.shrub_pink_pixels==0, "%s t=%s no pink flag pixels transported into shrub interior; bad=%d"%[label,seconds,row.shrub_pink_pixels])
   row.palm_edge_runs=palm_edge_runs(shot)
   verify(row.palm_edge_runs==[1,1,1], "%s t=%s palm contour has one edge, including antialias; runs=%s"%[label,seconds,row.palm_edge_runs])
   if first==null:
    first=shot
   else:
    max_flag_moved=maxi(max_flag_moved,changed_pixels(first,shot,flag_points))
    max_shrub_moved=maxi(max_shrub_moved,changed_pixels(first,shot,shrub_points))
   save_crops(shot,"%s_%04d"%[label,roundi(seconds*100)])
   results.append(row)
  verify(max_flag_moved>12, "%s flag has its own visible motion; changed=%d"%[label,max_flag_moved])
  verify(max_shrub_moved>12, "%s adjacent shrub moves independently; changed=%d"%[label,max_shrub_moved])
  print("OBJECT_MOTION ",label," flag=",max_flag_moved," shrub=",max_shrub_moved)
 # The rendered ending exposed a different antialias failure around fixed
 # wood and fruit, so check their real painted edges against zero motion too.
 var supports: Array[Dictionary] = [
  {"name":"leaning_palm_wood_and_fruit","points":support_points(morning,[Rect2i(7694,215,67,60),Rect2i(7739,268,71,180)])},
  {"name":"main_palm_trunk","points":support_points(morning,[Rect2i(6008,307,45,202)])},
  {"name":"main_palm_yellow_fruit","points":support_points(morning,[Rect2i(6023,316,54,70)])},
  {"name":"main_palm_pots","points":support_points(morning,[Rect2i(5867,453,120,59)])}
 ]
 for support: Dictionary in supports:
  verify(support.points.size()>100,"Independent support edge mask exists: "+support.name)
 for period: Array in [["noon",720.0],["night",1200.0]]:
  var label: String=period[0]
  road.set_time_of_day(period[1])
  painted.texture=road.art.texture
  road.atmosphere_material.set_shader_parameter("motion_strength",0.0)
  var still: Image=await snapshot(view)
  road.atmosphere_material.set_shader_parameter("motion_strength",1.0)
  for seconds: float in [0.0,9.0,20.0,56.0]:
   road.atmosphere_material.set_shader_parameter("weather_time",seconds)
   var shot: Image=await snapshot(view)
   var row: Dictionary={"period":label,"weather_time":seconds,"supports":{}}
   for support: Dictionary in supports:
    var changed:=changed_pixels(still,shot,support.points)
    row.supports[support.name]=changed
    verify(changed==0,"%s t=%s fixed %s including antialias; moved=%d"%[label,seconds,support.name,changed])
    if changed>0:
     var examples: Array[Vector2i]=[]
     for p: Vector2i in support.points:
      if error_rgb(still.get_pixelv(p),shot.get_pixelv(p))>.0041 and examples.size()<6:
       examples.append(p)
     print("SUPPORT_CHANGED_SAMPLES ",label," t=",seconds," ",support.name," ",examples)
   var suffix:="%s_%04d"%[label,roundi(seconds*100)]
   shot.get_region(Rect2i(7670,190,160,280)).save_png(OUT+"leaning_support_"+suffix+".png")
   shot.get_region(Rect2i(5860,260,315,255)).save_png(OUT+"main_support_"+suffix+".png")
   results.append(row)
 var receipt := {"checks":checks,"failures":failures,"samples":results,"lamp_centers":LAMP_CENTERS,"method":"Current production source, full-size GPU render. Independent source-art pixel masks. Automated checks do not establish visual acceptance."}
 var file := FileAccess.open(OUT+"receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 print("STREET_OBJECT_BOUNDARIES ",checks," checks, ",failures.size()," failures")
 road.queue_free()
 view.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
