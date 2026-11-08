extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/bag-navigation/"
func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if not isolated:push_error("Isolated QA save required");quit(1);return
	create_timer(90).timeout.connect(func():push_error("Bag navigation timeout");quit(1))
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle():await create_timer(.25).timeout
func key(code:Key):
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;root.push_input(e,true)
	await process_frame
func tab(name:String):
	game.modal.find_child(name,true,false).grab_focus();await key(KEY_ENTER);await settle()
func pocket()->ScrollContainer:return game.modal.find_child("PhotoPocket",true,false) as ScrollContainer
func run():
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game._post_office_room();await settle()
	var directory:String=game._photo_directory();DirAccess.make_dir_recursive_absolute(directory)
	for i:int in 20:
		var picture:=Image.create(160,90,false,Image.FORMAT_RGB8);picture.fill(Color.from_hsv(float(i)/20.0,.3,.85));picture.save_png(directory.path_join("DearSomewhere_bag_%02d.png"%i))
	for locale:String in ["zh","en"]:
		game.preferences.set_value("language",locale);root.size=Vector2i(1280,720) if locale=="zh" else Vector2i(1920,1080)
		game._bag_photos_visible=false
		var opener:Control=game.stage.find_child("OpenBag",true,false);opener.grab_focus();await key(KEY_ENTER);await settle()
		await tab("BagPhotosTab")
		check(root.gui_get_focus_owner().name=="BagPhotosTab",locale+" switched tab retains focus")
		pocket().scroll_vertical=400;await settle()
		var page_id:int=game.modal.get_instance_id()
		for repeat:int in 3:
			await key(KEY_ENTER);await settle()
			check(game.modal.get_instance_id()==page_id,locale+" repeated active tab does not rebuild")
			check(pocket().scroll_vertical==400,locale+" repeated active tab keeps scroll")
		await tab("BagLettersTab")
		check(root.gui_get_focus_owner().name=="BagLettersTab",locale+" letters focus retained")
		await tab("BagPhotosTab")
		check(pocket().scroll_vertical==400,locale+" tab round trip keeps photo position")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(out+locale+"_photos.png")==OK,locale+" render evidence")
		await key(KEY_ESCAPE);await settle()
		check(root.gui_get_focus_owner()==opener,locale+" bag closes to opener")
		await key(KEY_ENTER);await settle()
		check(pocket().scroll_vertical==400,locale+" reopened bag keeps photo position")
		# A delayed tab focus must not reach a subsequently opened map.
		game._switch_bag_tab(false);game._map();await settle()
		check(game.modal.name=="MapInspection" and game.modal.is_ancestor_of(root.gui_get_focus_owner()),locale+" rapid replacement preserves new modal focus")
		await key(KEY_ESCAPE);await settle()
	# Only generated QA photos are removed. A shorter album must clamp the old scroll.
	for i:int in range(4,20):DirAccess.remove_absolute(directory.path_join("DearSomewhere_bag_%02d.png"%i))
	game._bag_photos_visible=true;game._bag();await settle()
	check(pocket().scroll_vertical==0,"shortened album clamps saved scroll")
	check(pocket().find_children("BagPhoto_*","Button",true,false).size()==4,"remaining photos stay reachable")
	game._close();await settle()
	for i:int in 4:DirAccess.remove_absolute(directory.path_join("DearSomewhere_bag_%02d.png"%i))
	game._bag();await settle()
	check(game.modal.find_child("EmptyPhotoPocket",true,false)!=null,"empty album has its existing message")
	await tab("BagLettersTab");await tab("BagPhotosTab")
	check(root.gui_get_focus_owner().name=="BagPhotosTab","empty album tab remains operable")
	game.sound.shutdown();await create_timer(.6).timeout
	game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"Isolated saves and generated QA photos, offscreen GPU and engine keyboard input; no native player acceptance."},"\t"))
	print("BAG_NAVIGATION ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
