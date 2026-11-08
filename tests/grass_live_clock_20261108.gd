extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var out:=""
var checks:=0
var failures:Array[String]=[]
func _initialize():
 if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):
  quit(1);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
 root.unfocusable=true
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 DirAccess.make_dir_recursive_absolute(out)
 var game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
 for location in ["community_center","residential","post_office","tarot_shop"]:
  game.core.state.location=location;game._world()
  await process_frame
  var road=game._street_road
  var before:float=road.weather_time
  await create_timer(.6).timeout
  check(road.weather_time>before+.3,location+" actual Host advances weather without injected clock")
  check(is_equal_approx(road.weather_time,road.atmosphere_material.get_shader_parameter("weather_time")),location+" shader receives live clock")
  check(road.atmosphere_material.get_shader_parameter("grass_count")>0,location+" ground grass is connected")
 game.sound.shutdown();await create_timer(.35).timeout
 game.queue_free();await process_frame;await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"Actual Host process frames; isolated data/offscreen GPU. No forced weather time and no human acceptance claim."},"  "))
 print("GRASS_LIVE_CLOCK_COMPLETE ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
