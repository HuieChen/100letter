extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var checks:=0
var failures:Array[String]=[]
var game:Control
func _initialize():
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):
		push_error("An isolated --final-save=user://qa/ path is required");quit(1);return
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func settled(surface:Control):
	var deadline:=Time.get_ticks_msec()+4000
	while is_instance_valid(surface) and (surface._entering or surface._locked) and not surface._closing and Time.get_ticks_msec()<deadline:await process_frame
func run():
	root.unfocusable=true
	game=Host.new();game.allow_display_changes=false
	root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.state.location="community_center";game._world()
	await process_frame
	var chef:Control=game._street_road.world.get_node("Resident_chef")
	var campaign:=JSON.stringify(game.core.state.cases)
	for locale:String in ["zh","en"]:
		game.preferences.set_value("language",locale)
		game.walker.foot=chef.foot-Vector2(160,0)
		chef._talk()
		await process_frame
		check(is_instance_valid(game.modal),locale+" actual chef signal opens dialogue")
		var surface:Control=game.modal
		await settled(surface)
		check(surface.get_meta("dialogue_backend","")=="DialogueManager 4.2.0",locale+" Host uses manager backend")
		check(not game.walker.manual_enabled,locale+" speaking suspends walking")
		for page:int in 6:
			check(int(surface.get_meta("chef_page"))==page,locale+" Host maintains current turn "+str(page))
			check(surface._spoken.text=="……",locale+" hidden copy remains masked "+str(page))
			surface._spoken.visible_characters=-1
			surface._advance()
			await settled(surface)
		await create_timer(.3).timeout
		check(not is_instance_valid(game.modal),locale+" END removes Host modal")
		check(game.walker.manual_enabled,locale+" END resumes walking")
		chef._talk();await process_frame
		check(is_instance_valid(game.modal),locale+" resident re-enters after END")
		game.modal.request_close()
		await create_timer(.3).timeout
		check(not is_instance_valid(game.modal),locale+" early close removes Host modal")
		check(game.walker.manual_enabled,locale+" early close resumes walking")
	check(JSON.stringify(game.core.state.cases)==campaign,"conversation never mutates mail campaign")
	game.sound.shutdown();await create_timer(.5).timeout
	game.queue_free();await process_frame
	print("MANAGED_CHEF_HOST ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
