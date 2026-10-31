extends SceneTree

const Host=preload("res://scripts/rebuild/final_playable.gd")
var checks:=0
var failures:=0
var steps:Array[String]=[]
var game:Control
var viewport:SubViewport
const OUT="res://test-results/streets_20261101/"

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func frames()->void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
func run()->void:
 root.unfocusable=true
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1920,1080)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 game=Host.new();game.allow_display_changes=false
 game.preferences_path="user://qa/streets_20261101/preferences.json"
 game.size=Vector2(1600,900);game.scale=Vector2(1.2,1.2)
 viewport.add_child(game)
 game.sound.cue_played.connect(func(kind:String,sample:String):
  if kind=="step":steps.append(sample))
 for district:String in ["community","residential"]:
  for period:Array in [[540,"morning"],[720,"noon"],[1050,"sunset"],[1200,"night"]]:
   game.core.state.location="community_center" if district=="community" else "residential"
   game.core.state.minute=period[0];game._world()
   await frames()
   var road=game.stage.get_child(0)
   check(road.source_path.contains(district+"_"+period[1]),"Correct time variant")
   check(road.art.texture.get_width()==(9204 if district=="community" else 7431),"Full original resolution")
   check(road.courier.foot.x==100,"Destination starts at street left")
   check(road.fountain==null,"Do not paste old fountain onto different geometry")
   check(road.world.size.x>10000,"Panorama not compressed into one screen")
   # Show the actual town landmark and courier, not just the empty left edge.
   road.courier.foot.x=3300 if district=="community" else 3250
   road.courier.target=road.courier.foot
   await frames()
   viewport.get_texture().get_image().save_png(OUT+district+"_"+period[1]+".png")
 # Verify all new map choices use the corresponding existing canonical location.
 for entry:Array in [["community_center","community"],["grocery","community"],["market","community"],["food_truck","community"],["residential","residential"],["lookout","residential"],["bus_stop","residential"],["record_store","coastal"],["post_office","coastal"]]:
  game._map();await frames()
  var button=game.modal.find_child("Map_"+entry[0],true,false)
  check(button!=null,"Map has actual destination "+entry[0])
  button.pressed.emit();await frames()
  check(not is_instance_valid(game.modal),"Map closes after destination")
  check(game.stage.get_child(0).district==entry[1],"Destination routes to correct street")
  check(game.walker.foot.x==100,"No teleport to middle of street")
 # Real production signal -> sound -> licensed decoded sample -> SFX bus.
 game.walker.set_process(false)
 game.sound.set_muted(false)
 await create_timer(1.0).timeout
 var start:=steps.size()
 for i in range(170):
  game.walker._advance_manual(Vector2.RIGHT,1.0/60.0)
  await create_timer(1.0/60.0).timeout
 check(steps.size()>start+2,"Walking emits audible contact cues")
 check(steps.all(func(s:String):return s.begins_with("soft_step_concrete_")),"Only softened paved footsteps outdoors")
 var last_count:=steps.size()
 for i in range(100):game.walker._advance_manual(Vector2.ZERO,1.0/60.0)
 var settled:=steps.size()
 for i in range(100):game.walker._advance_manual(Vector2.ZERO,1.0/60.0)
 check(steps.size()==settled,"No footsteps at rest")
 check(settled<=last_count+1,"Braking cannot spam footsteps")
 game._map();await frames()
 var before:=steps.size()
 game.walker.footstep.emit()
 check(steps.size()==before,"Modal blocks footstep cues")
 game._close();game.sound.set_volumes(0.5,0.0,0.5)
 check(AudioServer.is_bus_mute(AudioServer.get_bus_index(game.sound.SFX_BUS)),"SFX zero actually mutes step bus")
 game.sound.set_volumes(0.5,0.4,0.5)
 check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(game.sound.SFX_BUS)),"SFX restores after mute")
 for surface:String in ["concrete","wood"]:
  for n:int in range(1,4):
   var stream=game.sound._stream("soft_step_%s_%d.wav"%[surface,n])
   check(stream!=null and stream.get_length()>0.08 and stream.get_length()<0.4,"Short decoded licensed contact")
 game.sound.shutdown()
 game.queue_free();await frames()
 await roof_test()
 print("STREET_IMPORT_QA checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)

func roof_test()->void:
 viewport.size=Vector2i(600,500)
 var night=Image.load_from_file("res://assets/authoring/streets_20261101/community_night.png")
 var day=Image.load_from_file("res://assets/authoring/streets_20261101/community_noon.png")
 var art:=TextureRect.new();art.texture=ImageTexture.create_from_image(night)
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.size=Vector2(night.get_size())*3;art.position=-Vector2(2050,260)*3
 viewport.add_child(art);await frames()
 var original:=viewport.get_texture().get_image()
 original.save_png(OUT+"window_before.png")
 var material:=ShaderMaterial.new()
 material.shader=load("res://scripts/rebuild/community_roof_occlusion.gdshader")
 material.set_shader_parameter("day_geometry",ImageTexture.create_from_image(day))
 art.material=material;await frames()
 var fixed:=viewport.get_texture().get_image()
 fixed.save_png(OUT+"window_after.png")
 var changed:=0;var outside:=0
 for y in range(500):
  for x in range(600):
   if original.get_pixel(x,y)!=fixed.get_pixel(x,y):
    changed+=1
    if not Rect2i(264,135,75,75).has_point(Vector2i(x,y)):outside+=1
 check(changed>100,"Roof actually occludes erroneous window pixels")
 check(outside==0,"No pixels outside the small repair region change")
 var point:=Vector2i((2150-2050)*3,(319-260)*3)
 check(original.get_pixelv(point).r>original.get_pixelv(point).b,"Regression probe is originally window light over roof")
 check(fixed.get_pixelv(point).b>fixed.get_pixelv(point).r,"Roof pigment replaces warm window overlap")
 art.queue_free();await frames()
