extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Cast=preload("res://scripts/rebuild/authored_cast.gd")
var out:=""
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr(label)
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
 if out.is_empty() or not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
 root.unfocusable=true;run.call_deferred()
func snap(view:SubViewport,label:String):
 await create_timer(.5).timeout
 RenderingServer.force_draw(false)
 check(view.get_texture().get_image().save_png(out+label+".png")==OK,"Capture "+label)
func pigment_probe():
 var viewport:=SubViewport.new();viewport.size=Vector2i(128,64);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var source:=Image.create(4,1,false,Image.FORMAT_RGBA8)
 for i in range(4):source.set_pixel(i,0,[Color(1,1,1,1),Color(0,0,0,1),Color(1,0,0,.5),Color(1,0,0,0)][i])
 var rect:=TextureRect.new();rect.texture=ImageTexture.create_from_image(source);rect.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;rect.size=Vector2(128,64);rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 var pigment:=ShaderMaterial.new();pigment.shader=preload("res://scripts/rebuild/character_palette.gdshader");rect.material=pigment;viewport.add_child(rect)
 await process_frame;RenderingServer.force_draw(false)
 var result:=viewport.get_texture().get_image()
 var white:=result.get_pixel(16,32);var black:=result.get_pixel(48,32);var edge:=result.get_pixel(80,32);var clear:=result.get_pixel(112,32)
 check(white.r>white.b and white.r>.85,"White cloth warms without becoming muddy")
 check(black.r>0.01 and black.r<.10,"Black ink softened but remains dark")
 check(absf(edge.a-.5)<.015 and clear.a<.005,"Semitransparent edges and empty pixels preserve alpha")
 viewport.queue_free();await process_frame
func run():
 DirAccess.make_dir_recursive_absolute(out)
 await pigment_probe()
 var view:=SubViewport.new();view.size=Vector2i(1280,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var game=Host.new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900);game.scale=Vector2(.8,.8)
 for spec in [["community_center","chef"],["tarot_shop","record_clerk"],["community_center","grocer"]]:
  game.core.state.location=spec[0];game.core.state.minute=720;game._world();await process_frame
  var road=game._street_road
  road.courier.foot=Cast.RESIDENTS[spec[1]].foot-Vector2(170,0);road._follow_courier(road.courier.foot)
  road.set_weather_time(4.0)
  var initial_light:Color=road.courier.modulate
  road.set_time_of_day(1320)
  for figure:CanvasItem in road.ambient_figures:
   check(figure.modulate.is_equal_approx(road.courier.modulate) and not figure.modulate.is_equal_approx(initial_light),"Ambient neighbour follows night light "+str(figure.name))
  road.set_time_of_day(720)
  await snap(view,spec[1]+"_street")
  if spec[1]=="chef":game._chef_conversation(0)
  else:game._resident_conversation(spec[1],0)
  await snap(view,spec[1]+"_dialogue")
  check(game.modal._right_portrait.material!=null,"Resident portrait uses pigment "+spec[1])
  check(game.modal._left_portrait.modulate.is_equal_approx(road.courier.modulate),"Portrait follows world light "+spec[1])
  game._close();await process_frame
 game.core.state.minute=1320;game._world();await process_frame
 game._resident_conversation("grocer",0);await snap(view,"grocer_night_dialogue")
 check(game.modal._right_portrait.modulate.is_equal_approx(game.walker.modulate),"Night tint retained")
 game._close();await process_frame
 game.sound.shutdown();game.queue_free();await process_frame;view.queue_free();await process_frame
 var receipt:=FileAccess.open(out+"receipt.json",FileAccess.WRITE);receipt.store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"GPU palette alpha probe and production host captures; not human acceptance"},"  "));receipt.close()
 print("SCENE_TONE ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
