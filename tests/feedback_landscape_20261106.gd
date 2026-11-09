extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Camera=preload("res://scripts/ui/field_camera.gd")
const Map=preload("res://scripts/rebuild/final_paper_map.gd")
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/feedback_landscape/"
func _initialize():
	var isolated:=false
	for a:String in OS.get_cmdline_user_args():
		if a.begins_with("--final-save=user://qa/"):isolated=true
	if not isolated:
		push_error("QA-only --final-save is required");quit(1);return
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle(t:float=.12):await create_timer(t).timeout;await process_frame
func hover(at:Vector2):
	var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;view.push_input(e,true);await settle()
func press(at:Vector2,down:bool):
	var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;view.push_input(e,true);await process_frame
func shot(label:String):
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+label+".png")
func run():
	for a:String in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900);game.core.new_game();game._post_office_room();await settle()
	var door:Button=game.stage.get_node("PostOfficeExit")
	check(door.tooltip_text.is_empty(),"No floating tooltip obscures painted door")
	await hover(door.get_global_rect().get_center());await shot("door_hover")
	await press(door.get_global_rect().get_center(),true);await settle(.1);await shot("door_pressed")
	await press(door.get_global_rect().get_center(),false)
	await settle(.27);await shot("exit_covered")
	check(game.busy,"Exit remains input-locked while scene changes")
	var deadline:=Time.get_ticks_msec()+4000
	while game.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.busy and game.view=="world","Exit finishes at exterior")
	check(game.get_node_or_null("SceneTransition")==null,"Transition cover is removed")
	await shot("exit_arrived")
	game._map();await settle()
	for entry:Array in Map.hotspot_entries():
		var b:Button=game.modal.find_child("Map_"+entry[0],true,false)
		await hover(b.get_global_rect().get_center() if entry[0]!="statue" else b.get_global_rect().end-Vector2(24,20))
		check(b.get_parent()._active_destination()==b,"Mouse chooses "+entry[0])
		check(b.text.is_empty() and b.tooltip_text.is_empty(),"No added map text "+entry[0])
		check(b.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"Hand cursor "+entry[0])
		if entry[0]=="community_center":await shot("map_community_hover")
	var map:Control=game.modal.find_child("Map_post_office",true,false).get_parent()
	await hover(Vector2(20,20))
	var book:Button=map.get_node("Map_bookstore");book.grab_focus();await settle()
	check(map._active_destination()==book,"Keyboard focus has matching destination feedback")
	game._close()
	# Color landmarks at both image edges catch the old square center crop.
	var pixels:=Image.create(1600,900,false,Image.FORMAT_RGB8);pixels.fill(Color("579ba9"))
	pixels.fill_rect(Rect2i(0,0,160,900),Color.RED);pixels.fill_rect(Rect2i(1440,0,160,900),Color.BLUE)
	var path:=out+"DearSomewhere_test.png";pixels.save_png(path)
	for language:String in ["zh","en"]:
		var camera:=Camera.new();camera.locale=language;camera.save_directory=out;camera.gallery_only=true;camera.initial_photo_path=path
		view.add_child(camera);camera.size=Vector2(1600,900);await settle()
		var paper:Control=camera._review_paper
		check(paper.size.x>paper.size.y,"Landscape print "+language)
		check(Rect2(Vector2.ZERO,paper.size).encloses(camera._caption_editor.get_rect()),"Writing remains inside white margin "+language)
		camera._caption_editor.text="海风 / Sea breeze"
		check(camera.checkpoint_for_quit(),"Photo note saves "+language)
		check(Camera.caption_for(path)=="海风 / Sea breeze","Photo note survives reload "+language)
		for dims:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
			view.size=dims;camera.size=Vector2(dims);await settle()
			var bounds:=Rect2(Vector2.ZERO,Vector2(dims))
			check(bounds.encloses(paper.get_global_rect()),"Print contained "+language+str(dims))
			check(paper.get_global_rect().encloses(camera._caption_editor.get_global_rect()),"Writing contained "+language+str(dims))
			await shot("landscape_"+language+"_"+str(dims.x))
		view.size=Vector2i(1600,900);camera.size=Vector2(1600,900);await settle()
		await shot("landscape_"+language)
		var frame:=view.get_texture().get_image()
		var left:=frame.get_pixelv(Vector2i(paper.position+Vector2(70,200)))
		var right:=frame.get_pixelv(Vector2i(paper.position+Vector2(paper.size.x-70,200)))
		check(left.r>.85 and left.b<.15,"Full left composition retained "+language)
		check(right.b>.85 and right.r<.15,"Full right composition retained "+language)
		camera.queue_free();await process_frame
	# Real camera capture, print animation and the bag all use the same landscape paper.
	game._post_office_room();await settle();game._camera();await settle()
	var camera:Control=game.modal
	camera.take_photo();deadline=Time.get_ticks_msec()+7000
	while camera.capture_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not camera.capture_busy and camera._review.visible,"Actual shutter completes print and review")
	check(camera._print_paper.size.x>camera._print_paper.size.y,"Ejected paper is landscape")
	await shot("actual_landscape_photo")
	camera._caption_editor.text="邮局的午后";camera._request_close();await settle()
	game._bag_photos_visible=true;game._bag();await settle();await shot("bag_landscape")
	var print_node:Control=game.modal.find_child("PhotoPrint",true,false)
	check(print_node!=null and print_node.size.x>print_node.size.y,"Bag print is landscape too")
	var caption:Control=print_node.get_node("PhotoCaption")
	check(print_node.get_global_rect().encloses(caption.get_global_rect()),"Bag note stays on photo white margin")
	game._close();game.sound.shutdown();await settle(.5);game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"GPU SubViewport mouse input, full-width photo pixel checks, actual capture and disk note persistence; not OS-input acceptance."},"  "))
	print("FEEDBACK_LANDSCAPE ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
