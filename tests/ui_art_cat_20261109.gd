extends SceneTree
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:=""
var meows:=0
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	create_timer(80).timeout.connect(func():push_error("UI test timed out");quit(1))
	run.call_deferred()
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func click(button:BaseButton)->void:
	var at:=button.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new();move.position=at;view.push_input(move,true)
	await process_frame
	for held:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=held;view.push_input(e,true);await process_frame
	await create_timer(.2).timeout
func frame(filename:String)->void:
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+filename+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(out);root.unfocusable=true
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	await create_timer(.5).timeout
	game.core.new_game()
	game._save()
	for language:String in ["zh","en"]:
		game.preferences.values.language=language;game._title();await create_timer(.3).timeout
		game._start();await create_timer(.4).timeout
		var paper:Control=game.modal.get_node("PaperSheet")
		for id:int in [0,1]:
			var button:Button=paper.get_node("SheetAction_"+str(id))
			check(button.get_script().resource_path.ends_with("confirmation_paper_button.gd"),"new journey uses generated paper")
			check(button.get_theme_stylebox("focus") is StyleBoxEmpty,"no old pink divider")
			check(button.get_global_rect().end.y<900,"actions stay on screen")
		check(view.gui_get_focus_owner()==paper.get_node("SheetAction_0"),"continue is safe default")
		await frame(language+"_new_journey")
		await click(paper.get_node("CloseSheet"))
		game._request_quit();await create_timer(.4).timeout
		await frame(language+"_quit")
		await click(game.modal.get_node("PaperSheet/SheetAction_0"))
		check(not is_instance_valid(game.modal),"keep playing cancels quit")
	game.preferences.values.language="zh";game.core.state.location="post_office";game._world();await create_timer(.7).timeout
	var road:Control=game._street_road
	game.walker.foot=Vector2(5875,872);road._follow_courier(game.walker.foot);await create_timer(.3).timeout
	var cat:Control=road.world.get_node("RooftopCatHotspot")
	cat.meowed.connect(func():meows+=1)
	check(cat.bubble.size.x<104 and cat.bubble.size.y<68.8,"cat bubble smaller than residents")
	check(cat.bubble.position.y+cat.bubble.size.y<0,"bubble is above original painted cat")
	await frame("cat_idle")
	await click(cat.bubble)
	check(meows==1 and cat.caption.text=="喵～","bubble click meows once")
	await frame("cat_meow")
	await click(cat.get_node("CatBody"));check(meows==1,"rapid repeat cannot stack meows")
	await create_timer(1.3).timeout
	await click(cat.get_node("CatBody"));check(meows==2,"painted cat remains clickable")
	game.busy=true;await create_timer(1.3).timeout;cat._meow()
	check(meows==2 and not cat.bubble.visible,"busy interaction gate blocks cat")
	game.busy=false;road.locale="en";cat._meow()
	check(cat.caption.text=="Meow!","cat caption follows language")
	game.core.state.location="beach";game._world();await create_timer(.5).timeout
	game._resident_conversation("record_clerk",0);await create_timer(.5).timeout
	var portrait:AtlasTexture=game.modal._right_portrait.texture
	check(portrait.atlas.get_size()==Vector2(439,1200),"record clerk uses supplied formal portrait")
	var street=load("res://scripts/rebuild/authored_dialogue_art.gd").texture("cast/record_clerk_chibi.png")
	check(street.get_size()==Vector2(532,1305),"street chibi keeps original supplied crop")
	await frame("record_clerk_portrait")
	game.queue_free();await process_frame;await process_frame
	view.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("UI_ART_CAT_CHECKS ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
