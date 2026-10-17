extends SceneTree
## Godot MovieWriter captures actual engine rendering and mixer, not native mouse footage.
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var pointer:Label
var observations:Array[Dictionary]=[]
var failures:Array[String]=[]
var movie_fps:=24
func _initialize()->void:_run.call_deferred()
func _run()->void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--film-fps="):movie_fps=int(argument.trim_prefix("--film-fps="))
	if movie_fps not in [24,60]:push_error("Supported MovieWriter rates are24 or60.");quit(1);return
	root.unfocusable=true;root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();game.allow_display_changes=false;game.preferences_path="user://qa/settings-film/"+str(Time.get_ticks_usec())+".json";root.add_child(game);game.size=Vector2(1600,900);game._settings_page()
	pointer=Label.new();pointer.text="↖";pointer.add_theme_font_size_override("font_size",25);pointer.add_theme_color_override("font_color",Color.WHITE);pointer.add_theme_color_override("font_outline_color",Color("315569"));pointer.add_theme_constant_override("outline_size",3);pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.add_child(pointer);pointer.position=Vector2(1290,530)
	var previous_event_frame:=-1
	for rendered_frame:int in int(528*movie_fps/24):
		# Keep the exact gesture schedule in seconds while rendering more frames.
		# Dispatch each recorded event once, rather than repeating every click.
		var frame:int=int(floor(float(rendered_frame)*24.0/float(movie_fps)))
		if frame==previous_event_frame:await process_frame;continue
		previous_event_frame=frame
		if frame==12:_click(Vector2(1290,660)) # near the small lemon, actual delayed wave impulse
		if frame==36:_click(Vector2(1290,660)) # same location, slightly different footprint and strength
		if frame==85:_motion(Vector2(1245,300),Vector2.ZERO,0)
		if frame>=86 and frame<=113:_motion(Vector2(1245+(frame-85)*2,300),Vector2(2,0),48)
		if frame==146:_motion(Vector2(1220,400),Vector2.ZERO,0)
		if frame>=147 and frame<=153:_motion(Vector2(1220+(frame-146)*31,400),Vector2(31,0),744)
		if frame==181:_button(Vector2(280,555),true)
		if frame>=182 and frame<=191:_motion(Vector2(280+(frame-181)*14,555),Vector2(14,0),336,true)
		if frame==192:_button(Vector2(420,555),false)
		if frame==224:_button(Vector2(972,498),true)
		if frame>=225 and frame<=244:_motion(Vector2(972-(frame-224)*4,498),Vector2(-4,0),96,true)
		if frame==245:_button(Vector2(892,498),false)
		if frame==276:_click(game.modal.controls.language.get_global_rect().get_center())
		if frame==288:_click(game.modal.find_child("Option_language_1",true,false).get_global_rect().get_center());game.move_child(pointer,game.get_child_count()-1)
		if frame==320:_click(Vector2(325,170)) # near the heavier lemon
		if frame==346:_button(game.modal.surface.bodies[1].position,true) # centre held pressure
		if frame==375:_button(Vector2(1290,570),false) # release away from the fruit
		if frame==414:_button(game.modal.surface.bodies[1].position+Vector2(72,0),true) # edge torque
		if frame==438:_button(Vector2(1290,570),false)
		if frame==478:_button(game.modal.surface.bodies[0].position+Vector2(80,65),true) # heavier slice
		if frame==494:_button(Vector2(335,320),false)
		if frame in [365,400,430,470,489,504]:
			var index:int=0 if frame>=478 else 1
			var state:Dictionary=game.modal.surface.snapshot().bodies[index].press
			observations.append({"frame":frame,"lemon":index,"press":state})
			var expected:bool=frame in [365,430,489]
			if bool(state.pressed)!=expected or (expected and state.depth<=2.0):failures.append("Film press state at frame "+str(frame))
		if frame==516:_click(game.modal.find_child("CloseSettings",true,false).get_global_rect().get_center())
		await process_frame
	game.queue_free();await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute("res://test-results/coastal-film-r5")
	var report:=FileAccess.open("res://test-results/coastal-film-r5/interaction-states.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"observations":observations,"failures":failures,"movie_fps":movie_fps,"event_schedule_fps":24,"rendered_interaction_frames":int(528*movie_fps/24)},"\t"));report.close()
	print("SETTINGS FILM: ",root.size,"; actual ",int(528*movie_fps/24)," frames at",movie_fps,"fps. Identical gesture times; varied near-lemon clicks; slow skim; fast swipe; held drag; live music slider; rounded English menu; small centre hold/rebound; edge press/torque; heavier slice press; return arrow. Test pointer is an annotation, not native mouse footage or real-time FPS.")
	print("FILM PRESS STATES: ",observations.size()," observations / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _click(point:Vector2)->void:_button(point,true);_button(point,false)
func _button(point:Vector2,down:bool)->void:
	pointer.position=point-Vector2(3,8)
	var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
func _motion(point:Vector2,relative:Vector2,speed:float,held:bool=false)->void:
	pointer.position=point-Vector2(3,8)
	var e:=InputEventMouseMotion.new();e.position=point;e.global_position=point;e.relative=relative;e.velocity=relative.normalized()*speed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(e,true)
