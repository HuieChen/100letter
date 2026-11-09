extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Camera=preload("res://scripts/ui/field_camera.gd")
var checks:=0
var failures:Array[String]=[]
var game:Control
var view:SubViewport
var output:="user://qa/photo-pocket/"
var open_ms:=0.0
var maximum_close_ms:=0.0
class FirstWorkerFails:
	extends "res://scripts/ui/photo_pocket_grid.gd"
	var failed:=false
	func _start_worker(path:String)->Error:
		if not failed:failed=true;return ERR_CANT_CREATE
		return super._start_worker(path)
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func grid()->GridContainer:return game.modal.find_child("PhotoGrid",true,false)
func pocket()->ScrollContainer:return game.modal.find_child("PhotoPocket",true,false)
func image_holders()->int:
	var count:=0
	for paper in game.modal.find_children("PhotoPrint","",true,false):
		if paper.image!=null:count+=1
	return count
func loaded()->void:
	await process_frame;await process_frame
	var deadline:=Time.get_ticks_msec()+5000
	while (grid()._worker!=null or not grid()._pending.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
	check(Time.get_ticks_msec()<deadline,"Visible prints finish without loading entire collection")
func shot(label:String):
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(output+label+".png")
func run():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):output=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output)
	root.unfocusable=true;Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=Host.new();game.allow_display_changes=false
	game.preferences_path="user://qa/photo-pocket/"+str(Time.get_ticks_usec())+"/preferences.json"
	view.add_child(game);game.size=Vector2(1600,900)
	game.core.save_path="user://qa/photo-pocket/"+str(Time.get_ticks_usec())+"/state.json"
	game.core.new_game();game._post_office_room()
	var directory:String=game._photo_directory();DirAccess.make_dir_recursive_absolute(directory)
	var pixels:=Image.create(1600,900,false,Image.FORMAT_RGB8)
	pixels.fill(Color("678d8a"));pixels.fill_rect(Rect2i(0,0,800,900),Color("ad8b61"))
	var bytes:=pixels.save_png_to_buffer()
	for index:int in 240:
		var path:=directory.path_join("DearSomewhere_%04d.png"%index)
		FileAccess.open(path,FileAccess.WRITE).store_buffer(bytes)
		Camera._write_caption(path,"海风 · Sea breeze %03d"%index)
	var original:=directory.path_join("DearSomewhere_0000.png")
	var original_hash:=FileAccess.get_sha256(original)
	game._bag_photos_visible=true
	var started:=Time.get_ticks_usec();game._bag();open_ms=(Time.get_ticks_usec()-started)/1000.0
	check(grid().get_child_count()==240,"Every original photo remains reachable")
	check(image_holders()==0,"Opening does not synchronously decode all original images")
	await loaded()
	check(image_holders()>0 and image_holders()<=24,"Only viewport and nearby rows hold images")
	check(grid().get_child(0).get_node("PhotoPrint").image!=null,"Latest photo is loaded first")
	await shot("01_initial")
	for offset:int in range(0,11000,800):
		pocket().scroll_vertical=offset;await loaded()
		check(image_holders()<=24,"Scrolling releases offscreen texture references at "+str(offset))
		check(game._photo_thumbnails.size()<=96,"Collection cache remains bounded at "+str(offset))
	var last:Button=grid().get_child(239)
	last.grab_focus();await process_frame;await process_frame;await loaded()
	check(pocket().scroll_vertical>9000,"Keyboard focus follows a distant photo")
	check(last.get_node("PhotoPrint").image!=null,"Distant focused print is decoded")
	await shot("02_last")
	last.pressed.emit();await process_frame
	check(game.modal.gallery_only and game.modal.gallery_paths[game.modal._review_index]==original,"Opening a streamed print retains its identity")
	game.modal._caption_editor.text="远处的海风 / A distant breeze"
	game.modal._request_close();await process_frame;await process_frame;await loaded()
	check(pocket().scroll_vertical>9000,"Album return restores previous scroll region")
	check(view.gui_get_focus_owner()==grid().get_child(239),"Album return restores the correct keyboard focus")
	check(grid().get_child(239).get_node("PhotoPrint/PhotoCaption").text=="远处的海风 / A distant breeze","Edited caption refreshes independently of cached image")
	check(FileAccess.get_sha256(original)==original_hash,"Thumbnail work preserves original photograph bytes")
	# Close while a fresh original is being decoded; no completion targets a dead panel.
	for cycle:int in 8:
		game._close();game._photo_thumbnails.clear();game._photo_thumbnail_order.clear()
		game._bag();await process_frame;await process_frame
		started=Time.get_ticks_usec();game._close()
		maximum_close_ms=maxf(maximum_close_ms,(Time.get_ticks_usec()-started)/1000.0)
		await process_frame
		check(not is_instance_valid(game.modal),"Closing during background loading removes modal "+str(cycle))
	# A missing file remains an identifiable print instead of shifting all keyboard slots.
	var broken:=directory.path_join("DearSomewhere_9999.png")
	FileAccess.open(broken,FileAccess.WRITE).store_string("deliberately invalid QA PNG")
	game.preferences.values.language="en";game._bag()
	# Reopening now intentionally restores the old scroll position. Bring the
	# newly inserted first print into view before asserting its decode feedback.
	await process_frame;await process_frame;pocket().scroll_vertical=0;await loaded()
	check(grid().get_child_count()==241,"Unavailable print does not reorder or hide other photos")
	check(grid().get_child(0).tooltip_text=="Photo unavailable","Unreadable print has localized feedback")
	check(grid().get_child(1).get_node("PhotoPrint").image!=null,"A damaged newest file does not block healthy thumbnails")
	game._close()
	var failure_scroll:=ScrollContainer.new();failure_scroll.size=Vector2(1000,400);view.add_child(failure_scroll)
	var failure_grid:=FirstWorkerFails.new();failure_grid.columns=4;failure_scroll.add_child(failure_grid)
	for index:int in 2:
		var button:=Button.new();button.custom_minimum_size=Vector2(230,170);button.set_meta("photo_path",original)
		failure_grid.add_child(button)
		var paper:=Camera.PhotoPaper.new();paper.name="PhotoPrint";paper.size=Vector2(220,151);button.add_child(paper)
		var caption:=Label.new();caption.name="PhotoCaption";button.get_node("PhotoPrint").add_child(caption)
	var deadline:=Time.get_ticks_msec()+3000
	while failure_grid.get_child(1).get_node("PhotoPrint").image==null and Time.get_ticks_msec()<deadline:await process_frame
	check(failure_grid.get_child(0).tooltip_text=="Photo unavailable","Failed thread startup gives readable feedback")
	check(failure_grid.get_child(1).get_node("PhotoPrint").image!=null,"Failed worker does not starve later photographs")
	failure_scroll.queue_free();await process_frame
	game.sound.shutdown();await create_timer(.5).timeout;game.queue_free();await process_frame
	view.queue_free();await process_frame
	var report:={"checks":checks,"failures":failures,"photos":240,"open_ms":open_ms,"maximum_close_ms":maximum_close_ms,"method":"Godot GPU simulation with isolated generated photo fixtures"}
	FileAccess.open(output+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PHOTO_POCKET_STREAMING ",checks," checks / ",failures.size()," failures; open_ms=",open_ms)
	quit(0 if failures.is_empty() else 1)
