extends SceneTree
var out:=""
var checks:=0
var failures:Array=[]
func _initialize():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run():
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game=load("res://scripts/rebuild/final_playable.gd").new()
	game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.state.location="community_center";game._world("food_truck")
	await create_timer(.6).timeout
	var foot:Vector2=game.walker.foot
	game._camera();await create_timer(.2).timeout
	var camera=game.modal
	camera.lab.sliders.exposure.value=.7;camera.lab.sliders.aperture.value=2.0;camera.lab.focus_at(Vector2(.25,.45))
	camera.lab.picker.item_selected.emit(4)
	check(is_equal_approx(camera.lab.values.exposure,.7),"Switch film preserves exposure")
	check(is_equal_approx(camera.lab.values.aperture,2.0) and camera.lab.focus_point==Vector2(.25,.45),"Switch film preserves depth and focus")
	camera.lab.panel.show();check(camera._can_pan(),"Can compose outside open panel")
	camera.zoom_provider.call(.2);camera.pan_provider.call(Vector2(-90,0))
	camera._actor_button.pressed.emit();check(not game.walker.visible,"Hide actor for landscape")
	camera.lab.panel.hide();camera.instant_format=true
	var first_count:int=camera.gallery_paths.size()
	camera.take_photo()
	await create_timer(.45).timeout
	check(not camera.capture_busy and not camera._review.visible,"Print presentation never forces review or holds shutter")
	camera.take_photo();await create_timer(.45).timeout
	check(camera.gallery_paths.size()==first_count+2,"Two successive captures without a return action")
	var latest:String=camera.last_photo_path
	var metadata:Dictionary=camera.photo_metadata(latest)
	check(FileAccess.file_exists(metadata.get("original","")),"Unfiltered source retained separately")
	check(metadata.camera.recipe=="Berry" and is_equal_approx(metadata.camera.controls.exposure,.7),"Saved image records chosen settings")
	check(not camera._review.visible,"Second capture still in live view")
	camera._show_review(camera.gallery_paths.size()-1)
	camera._caption_editor.text="海边 / Seaside";check(camera._save_caption(),"Caption stored")
	camera._toggle_favorite();check(camera.photo_metadata(latest).favorite,"Favorite persisted")
	check(camera.caption_for(latest)=="海边 / Seaside","Favorite preserves note")
	camera.album_directory=out+"album"
	check(not (await camera.export_current_photo()).is_empty(),"Export produces paper with note")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"photo_review.png")
	camera.request_close();check(not camera._review.visible,"Escape from review returns to camera")
	camera._request_close();await process_frame
	check(game.walker.visible and game.walker.foot==foot,"Closing restores visible actor and world position")
	game._camera();await process_frame
	camera=game.modal;camera._show_review(camera.gallery_paths.find(latest))
	check(camera._favorite.text=="已收藏","Favorite survives reopening")
	check(camera._caption_editor.text=="海边 / Seaside","Caption survives reopening")
	camera.request_close();camera.lab._toggle_panel();await create_timer(.2).timeout
	check(camera.lab.preview_cards[0].texture!=null,"Film previews show actual current scene")
	check(not camera.lab.advanced.visible,"Only basic controls shown initially")
	check(camera.lab.panel.position.y+camera.lab.panel.size.y<850,"Controls fit canvas")
	camera.lab.sliders.exposure.grab_focus()
	var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.physical_keycode=KEY_RIGHT;key.pressed=true
	camera._input(key);check(camera._held_pan.is_empty(),"Slider keys never pan the view")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"photo_controls.png")
	camera._request_close();game._bag_photos_visible=true;game._bag();await create_timer(.3).timeout
	game.modal.find_child("PhotoFavoriteFilter",true,false).pressed.emit();await create_timer(.3).timeout
	var grid=game.modal.find_child("PhotoGrid",true,false)
	check(grid.get_child_count()==1 and grid.get_child(0).get_meta("photo_path")==latest,"Favorites filter keeps saved favorite")
	check(game.modal.find_child("PhotoPlaceFilter",true,false).item_count>=2,"Saved location available for filtering")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"photo_bag.png")
	game._close();game._street_road.field_sound.shutdown();game.sound.shutdown();await create_timer(.15).timeout;game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
