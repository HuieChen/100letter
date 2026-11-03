extends SceneTree
## Isolated rendered source-space leaf tip; compares the exact original gap
## against the localized repair at changing wind times and all four paintings.
const Atmosphere=preload("res://scripts/rebuild/street_atmosphere.gd")
const OUT="res://test-results/leaf-tip-continuity-20261103/"
const TIMES=[0.0,2.0,4.0,6.0,9.68,12.0,15.0,18.0,20.0,24.0]
const CROP=Rect2i(7745,118,35,35)

func _initialize()->void:run.call_deferred()
func shot(view:SubViewport)->Image:
 await process_frame
 RenderingServer.force_draw(false,1.0/60.0)
 return view.get_texture().get_image()

func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 RenderingServer.render_loop_enabled=false
 OS.low_processor_usage_mode=false
 var view:=SubViewport.new();view.size=CROP.size*6;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var art:=TextureRect.new();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.position=-Vector2(CROP.position)*6;art.size=Vector2(9204,640)*6;view.add_child(art)
 var shader=load("res://scripts/rebuild/street_atmosphere.gdshader")
 var original:=Shader.new();original.code=shader.code.replace("float tip_bridge=leaf_tip_bridge(uv/TEXTURE_PIXEL_SIZE);","float tip_bridge=0.0;")
 var material:=ShaderMaterial.new();material.shader=shader;art.material=material
 var morning:=ImageTexture.create_from_image(Image.load_from_file("res://assets/authoring/streets_20261101/community_morning.png"))
 material.set_shader_parameter("community",true);material.set_shader_parameter("day_geometry",morning)
 Atmosphere.apply_regions(material,"community");Atmosphere.apply_rigid(material,"community")
 for period:String in Atmosphere.PERIODS:
  art.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/authoring/streets_20261101/community_%s.png"%period))
  material.set_shader_parameter("next_art",art.texture)
  for i in range(TIMES.size()):
   material.set_shader_parameter("weather_time",TIMES[i])
   for variant:String in ["before","after"]:
    material.shader=original if variant=="before" else shader
    var image:Image=await shot(view)
    image.save_png(OUT+"%s_%s_%02d.png"%[period,variant,i])
 print("LEAF_TIP_CONTINUITY rendered 80 comparison crops; source Rect2i(7745,118,35,35) at 6x, 10 wind times, 4 paintings")
 view.queue_free();await process_frame;quit()
