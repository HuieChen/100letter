extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var viewport:SubViewport
var failures:Array[String]=[]
var checks:=0
var out:="user://qa/cinematic-review/"
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func frame(name:String):
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out+name+".png")
func settle(seconds:float):await create_timer(seconds).timeout
func run():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;Engine.max_fps=60
	viewport=SubViewport.new();viewport.size=Vector2i(1600,900);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	game=Host.new();game.allow_display_changes=false
	game.preferences_path="user://qa/cinematic-review/"+str(Time.get_ticks_usec())+"/preferences.json"
	viewport.add_child(game);game.size=Vector2(1600,900)
	game.core.save_path="user://qa/cinematic-review/"+str(Time.get_ticks_usec())+"/state.json"
	game.core.new_game();game._post_office_room()
	await settle(.3)
	game._map();await settle(.4)
	await frame("01_map")
	game._visit_map_destination("food_truck")
	game._visit_map_destination("lookout")
	await settle(.14)
	check(game.busy,"input remains locked through paper cover")
	await frame("02_paper_passage")
	var deadline:=Time.get_ticks_msec()+6000
	while game.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.busy and game.core.state.location=="community_center","one chosen destination survives rapid second activation")
	check(game.get_node_or_null("SceneTransition")==null,"no transition overlay remains to swallow input")
	await settle(.4);await frame("03_arrival")
	game._chef_conversation(0);await settle(.7);await frame("04_conversation")
	check(is_instance_valid(game.modal),"existing conversation is available after arrival")
	check(not game.walker.visible,"closeup does not duplicate the small player")
	check(not game._street_road.world.get_node("Resident_chef").visible,"closeup does not duplicate the small resident")
	game._close()
	check(game.walker.visible and game._street_road.world.get_node("Resident_chef").visible,"leaving closeup restores both world actors")
	game._close();game._pause();await settle(.4)
	await frame("05_paper_menu")
	var paper=game.modal.get_node_or_null("PaperSheet")
	check(paper!=null and paper.scale.is_equal_approx(Vector2.ONE),"paper settles at authored hit geometry")
	game._close();game._map();game._close();await settle(.4)
	check(not is_instance_valid(game.modal),"closing during paper entry leaves no modal")
	game.sound.shutdown();await settle(.5);game.queue_free();await process_frame;viewport.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CINEMATIC_REVIEW ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
