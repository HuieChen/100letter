extends SceneTree
var failures:Array=[]
var checks:=0
var out:=""
func _initialize():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func click_ground(road:Control,x:float,button:int=MOUSE_BUTTON_LEFT):
	var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=true;e.position=Vector2(x,872);road.world.gui_input.emit(e)
func run():
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.state.location="community_center";game._world("grocery");await create_timer(.3).timeout
	var road=game._street_road;var original:Vector2=game.walker.foot
	click_ground(road,original.x+350);await create_timer(.15).timeout
	check(game.walker.walking and game.walker.foot.x>original.x,"Ground click moves courier")
	check(road.world.get_node("WalkTarget").active,"Selected ground position visible")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"walk_target.png")
	click_ground(road,original.x-200);check(game.walker.target.x==original.x-200,"New click replaces destination")
	click_ground(road,original.x,MOUSE_BUTTON_RIGHT);check(not game.walker.walking,"Right click cancels queued walk")
	game._camera();click_ground(road,original.x+500);check(not game.walker.walking,"Modal prevents ground movement")
	game.modal._request_close();await process_frame
	check(game._nearest_landmark()=="grocery","Current marker follows actual landmark")
	game._map();await create_timer(.4).timeout
	var map=game.modal.find_child("Map_grocery",true,false).get_parent()
	check(map.current_destination=="grocery","Map keeps precise location rather than district alias")
	var target=map.get_node("Map_market");target.mouse_entered.emit();await create_timer(.3).timeout
	check(map._caption.text=="集市" and map._caption.position.distance_to(target.position)<350,"Destination label beside selected building")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"map_target.png")
	var minute:int=game.core.state.minute
	game._visit_map_destination("food_truck");await create_timer(1.7).timeout
	check(game._nearest_landmark()=="food_truck" and int(game.core.state.minute)==minute,"Map arrives at selected landmark with no added time cost")
	game._bag();await process_frame
	var tab=game.modal.find_child("BagRecordingsTab",true,false);check(tab!=null,"Recordings accessible from bag")
	tab.pressed.emit();await process_frame
	check(game.modal.name=="FieldRecorder" and game.modal.library.get_parent().visible,"Bag opens recording library")
	game.modal.request_close();await process_frame
	check(game.modal.name=="MailBag","Closing recordings returns to bag")
	game._close();await process_frame
	game._street_road.field_sound.shutdown();game.sound.shutdown();await create_timer(.2).timeout;game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
