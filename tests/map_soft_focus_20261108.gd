extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Map=preload("res://scripts/rebuild/final_paper_map.gd")
const ORIGINAL_SHA="3ace307814071c4bb8990a6eb52b28f70cfcbaa9806f9b20a167dd53cc67d815"
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/map-soft-focus/"
var pointer:=Vector2(-1,-1)
var measurements:Dictionary={}
func _initialize()->void:
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if not isolated:push_error("Isolated --final-save required");quit(1);return
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle(seconds:float=.22)->void:await create_timer(seconds).timeout;await process_frame
func move(at:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=at-pointer;pointer=at
	view.push_input(event,true);await process_frame
func key(code:Key,shift:bool=false)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.shift_pressed=shift
		view.push_input(event,true);await process_frame
func press(at:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	view.push_input(event,true);await process_frame
func frame(name:String="")->Image:
	await RenderingServer.frame_post_draw
	var pixels:=view.get_texture().get_image()
	if not name.is_empty():pixels.save_png(out+name+".png")
	return pixels
func compare(a:Image,b:Image,area:Rect2,allowed:Rect2)->Dictionary:
	var changed:=0;var outside:=0;var darker:=0;var total_lift:=0.0
	for y:int in range(ceili(area.position.y),floori(area.end.y),3):
		for x:int in range(ceili(area.position.x),floori(area.end.x),3):
			var old:=a.get_pixel(x,y);var next:=b.get_pixel(x,y)
			var difference:=Vector3(next.r-old.r,next.g-old.g,next.b-old.b)
			if difference.length()<.008:continue
			changed+=1;total_lift+=difference.x+difference.y+difference.z
			if not allowed.has_point(Vector2(x,y)):outside+=1
			if difference.x+difference.y+difference.z<-.015:darker+=1
	return {"changed_samples":changed,"outside_samples":outside,"darker_samples":darker,"total_lift":total_lift}
func run()->void:
	DirAccess.make_dir_recursive_absolute(out);root.unfocusable=true;Engine.max_fps=60
	check(FileAccess.get_sha256("res://assets/authoring/map_20261105/scroll_map_v2.png")==ORIGINAL_SHA,"Original supplied map PNG remains byte-exact")
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900);game.core.new_game();game._post_office_room();game._map();await settle(.4)
	var map:Control=game.modal.find_child("Map_post_office",true,false).get_parent()
	var close:Button
	for child:Node in game.modal.get_children():
		if child is Button and child.text=="×":close=child
	await move(Vector2(20,20));close.grab_focus();await settle()
	var baseline:Image=await frame("neutral")
	check(map._caption.modulate.a==0.0,"No destination caption when close has focus and pointer is off map")
	for entry:Array in Map.SOURCE_HOTSPOTS:
		var id:String=entry[0];var button:Button=map.get_node("Map_"+id)
		await move(button.get_global_rect().get_center());await settle()
		var current:Image=await frame("hover_"+id)
		var allowed:=button.get_global_rect().grow(maxf(button.size.x,button.size.y)*.08+4.0)
		var delta:=compare(baseline,current,map.get_global_rect(),allowed)
		measurements[id]=delta
		check(delta.changed_samples==0,id+" original artwork stays unchanged on hover")
		check(map.material==null,id+" no lighting shader is applied to the map")
		check(map._caption.modulate.a==1.0,id+" location caption provides visible selection feedback")
		check(map._caption.text==Map.DESTINATION_NAMES[id][0],id+" caption names the exact landmark")
		check(map._caption.get_global_rect().position.y>=map.get_global_rect().end.y,id+" caption stays below supplied artwork")
		check(map._caption.focus_mode==Control.FOCUS_NONE and map._caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,id+" caption does not intercept navigation")
	var community:Button=map.get_node("Map_community_center")
	await move(community.get_global_rect().get_center());await settle()
	var focused:Image=await frame("community_focus")
	var resting_caption_y:float=map._caption.position.y
	await press(community.get_global_rect().get_center(),true);await settle(.10)
	var pressed:Image=await frame("community_pressed")
	var response:=compare(pressed,focused,map.get_global_rect(),community.get_global_rect().grow(15))
	check(response.changed_samples==0 and map._caption.position.y>resting_caption_y+1.5,"Held press moves only the paper caption while map pixels stay identical")
	await move(Vector2(20,20));await press(Vector2(20,20),false);close.grab_focus();await settle()
	check(not game.busy,"Canceled press does not travel")
	var faded:Image=await frame("neutral_after_release")
	check(compare(baseline,faded,map.get_global_rect(),Rect2()).changed_samples==0,"Canceled press preserves exact original display")
	await move(community.get_global_rect().get_center());await settle()
	var idle_one:Image=await frame();await settle(.4);var idle_two:Image=await frame()
	check(compare(idle_one,idle_two,map.get_global_rect(),Rect2()).changed_samples==0,"Original map remains static without lighting or pulse")
	for locale:String in ["zh","en"]:
		game.preferences.set_value("language",locale)
		for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
			view.size=dimensions;game.scale=Vector2(dimensions)/Vector2(1600,900);await settle()
			var bus:Button=map.get_node("Map_bus_stop");await move(bus.get_global_rect().get_center());await settle()
			var caption:Label=map._caption
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(caption.get_global_rect()),locale+str(dimensions.x)+" caption fits stage")
			check(caption.text==Map.DESTINATION_NAMES.bus_stop[1 if locale=="en" else 0],locale+str(dimensions.x)+" caption localizes")
			check(caption.get_theme_font("font").get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x<caption.size.x-12,locale+str(dimensions.x)+" full destination name fits")
			await frame(locale+"_"+str(dimensions.x))
	view.size=Vector2i(1600,900);game.scale=Vector2.ONE;await settle()
	var post:Button=map.get_node("Map_post_office");post.grab_focus();await move(community.get_global_rect().get_center());await key(KEY_TAB);await settle()
	check(map._active_destination()==map.get_node("Map_chess_stall") and map._caption.text=="Chess corner","Keyboard target and caption agree despite stationary community hover")
	await key(KEY_ESCAPE);await settle();check(not is_instance_valid(game.modal),"Escape closes the complete focus surface")
	game.sound.shutdown();await settle(.3);game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements,"source_map_sha256":ORIGINAL_SHA,"method":"Actual production Host offscreen GPU; unchanged source-art pixels during all hover/press states, real input and bilingual responsive captures. No OS-input or user aesthetic acceptance implied."},"  "))
	print("MAP_SOFT_FOCUS ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
