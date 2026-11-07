extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/map-modality/"
var pointer:=Vector2(-1,-1)
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
func settle(seconds:float=.08)->void:
	await create_timer(seconds).timeout;await process_frame
func key(code:Key,shift:bool=false)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.shift_pressed=shift
		view.push_input(event,true);await process_frame
func move(at:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=at-pointer;pointer=at
	view.push_input(event,true);await process_frame
func press(at:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	view.push_input(event,true);await process_frame
func open_map()->Control:
	game._map();await settle(.3)
	return game.modal.find_child("Map_post_office",true,false).get_parent()
func wait_arrival()->void:
	var deadline:=Time.get_ticks_msec()+4000
	while game.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.busy,"Scene change completed")
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+label+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(out);root.unfocusable=true;Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900);game.core.new_game();game._post_office_room();await settle()
	for locale:String in ["zh","en"]:
		game.preferences.set_value("language",locale)
		var map:Control=await open_map()
		var community:Button=map.get_node("Map_community_center")
		var post:Button=map.get_node("Map_post_office")
		var chess:Button=map.get_node("Map_chess_stall")
		var at:=community.get_global_rect().get_center()
		await move(at);post.grab_focus();await process_frame
		check(map._active_destination()==community,locale+" programmatic focus does not replace fresh pointer hover")
		await key(KEY_TAB)
		check(view.gui_get_focus_owner()==chess,locale+" Tab moves actual focus to chess")
		check(map._active_destination()==chess,locale+" marker follows Tab with pointer parked over community")
		await move(at)
		check(map._active_destination()==chess,locale+" zero-displacement mouse event does not steal keyboard indication")
		await key(KEY_TAB,true)
		check(view.gui_get_focus_owner()==post and map._active_destination()==post,locale+" Shift Tab restores previous visible target")
		await key(KEY_RIGHT)
		var right:Control=view.gui_get_focus_owner()
		check(right!=post and right is Button and right.get_parent()==map,locale+" Right arrow reaches another destination")
		check(map._active_destination()==right,locale+" marker follows actual spatial keyboard focus")
		await move(at+Vector2(2,0))
		check(map._hovered_destination==community and map._active_destination()==community,locale+" small movement inside the same building restores hover")
		chess.grab_focus();await process_frame
		check(map._active_destination()==community,locale+" unrelated focus change preserves pointer mode")
		await key(KEY_TAB,true);await key(KEY_TAB)
		check(map._active_destination()==chess,locale+" repeat keyboard navigation restores correct marker")
		await shot("keyboard_over_stationary_pointer_"+locale)
		await key(KEY_ENTER);await wait_arrival()
		check(game.core.state.location=="chess_stall",locale+" Enter travels to indicated focus rather than old hovered building")
		map=await open_map();post=map.get_node("Map_post_office");community=map.get_node("Map_community_center");at=community.get_global_rect().get_center()
		post.grab_focus();await move(at);await key(KEY_TAB)
		check(map._active_destination()==map.get_node("Map_chess_stall"),locale+" second map keyboard mode is independent")
		await press(at,true)
		check(map._active_destination()==community and map._pressed_destination==community,locale+" mouse press immediately restores its own target and press feedback")
		await move(Vector2(20,20));await press(Vector2(20,20),false)
		check(not game.busy and is_instance_valid(game.modal),locale+" release outside cancels navigation")
		check(map._hovered_destination==null and map._pressed_destination==null,locale+" empty space clears hover and pressed targets")
		await move(at);await press(at,true);await press(at,false);await wait_arrival()
		check(game.core.state.location=="community_center",locale+" pointer click travels to its indicated building")
		map=await open_map();post=map.get_node("Map_post_office");community=map.get_node("Map_community_center")
		post.grab_focus();await move(community.get_global_rect().get_center());await key(KEY_TAB,true)
		var close:Control=view.gui_get_focus_owner()
		check(close is Button and close.text=="×",locale+" reverse Tab reaches map close control")
		check(map._active_destination()==null,locale+" close focus has no stale destination marker")
		await shot("close_focus_"+locale)
		var location:String=game.core.state.location
		await key(KEY_ENTER);await settle()
		check(not is_instance_valid(game.modal) and game.core.state.location==location,locale+" Enter on close dismisses without travel")
		map=await open_map();await key(KEY_ESCAPE);await settle()
		check(not is_instance_valid(game.modal),locale+" Escape still closes map")
	game.sound.shutdown();await settle(.4);game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"Production host, offscreen GPU and real viewport key/pointer events; isolated save data; not OS-input playtesting."},"  "))
	print("MAP_INPUT_MODALITY ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
