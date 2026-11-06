extends SceneTree
const Camera = preload("res://scripts/ui/field_camera.gd")
var checks := 0
var failures: Array[String] = []
var output := "user://qa/photo_review_resilience/"
func _initialize():
	run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		printerr(label)
func key(code: Key):
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame
func run():
	root.unfocusable = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	output += str(Time.get_ticks_usec()) + "/"
	DirAccess.make_dir_recursive_absolute(output)
	var valid := output + "DearSomewhere_01.png"
	var broken := output + "DearSomewhere_02.png"
	var photo := Image.create(320, 240, false, Image.FORMAT_RGB8)
	photo.fill(Color("73a7b1"))
	photo.save_png(valid)
	FileAccess.open(broken, FileAccess.WRITE).store_string("intentional corrupt photo fixture")
	Camera._write_caption(valid, "Original note")
	Camera._write_caption(broken, "Damaged photo note")
	for locale: String in ["zh", "en"]:
		var camera = Camera.new()
		camera.locale = locale
		camera.save_directory = output
		root.add_child(camera)
		camera.size = Vector2(1600, 900)
		camera._show_review(0)
		await process_frame
		check(camera._review.visible, locale + " valid print opens")
		var original_texture = camera._review_paper.image
		camera._show_review(1)
		check(camera._review_index == 0, locale + " failed load keeps current photo identity")
		check(camera._review_paper.image == original_texture, locale + " failed load preserves visible print")
		check(not camera._caption_notice.text.is_empty(), locale + " read error is visible above review")
		camera._caption_editor.text = "Edited " + locale
		check(camera.checkpoint_for_quit(), locale + " current caption can still save")
		check(Camera.caption_for(valid) == "Edited " + locale, locale + " caption belongs to visible photo")
		check(Camera.caption_for(broken) == "Damaged photo note", locale + " unreadable photo note not overwritten")
		camera._review.get_node("BackToCamera").grab_focus()
		for step: int in 12:
			await key(KEY_TAB)
			var focus = root.gui_get_focus_owner()
			check(focus != camera.shutter and focus != camera.thumbnail, locale + " Tab stays off covered camera buttons " + str(step))
		camera._leave_review()
		check(not camera._review.visible and root.gui_get_focus_owner() == camera.shutter, locale + " return restores shutter focus")
		camera.gallery_paths.clear()
		camera.gallery_paths.append(valid)
		var original_hash := FileAccess.get_sha256(valid)
		camera._refresh_thumbnail()
		var miniature = camera.thumbnail.get_node("ThumbnailPrint").image
		check(maxf(miniature.get_width(), miniature.get_height()) <= 256, locale + " thumbnail GPU size is bounded")
		check(FileAccess.get_sha256(valid) == original_hash, locale + " thumbnail resize preserves original photo bytes")
		camera.capture_provider = func(): return photo.duplicate()
		camera.take_photo()
		camera.take_photo()
		var deadline := Time.get_ticks_msec() + 5000
		while camera.capture_busy and Time.get_ticks_msec() < deadline:
			await process_frame
		check(not camera.capture_busy and camera._review.visible, locale + " capture develops and opens review")
		check(camera.gallery_paths.size() == 2, locale + " rapid double shutter creates one photograph")
		check(FileAccess.file_exists(camera.last_photo_path), locale + " captured PNG exists")
		camera._caption_editor.text = "Sea breeze / 今天的海风"
		camera._caption_editor.grab_focus()
		await key(KEY_C)
		check(not camera.capture_busy and camera.gallery_paths.size() == 2, locale + " C while writing does not take another photo")
		for width: int in [1280, 1920, 2560]:
			root.size = Vector2i(width, width * 9 / 16)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + locale + "_" + str(width) + ".png")
			check(camera._caption_editor.is_visible_in_tree(), locale + " caption stays available at " + str(width))
		camera._request_close()
		check(Camera.caption_for(camera.last_photo_path) == "Sea breeze / 今天的海风", locale + " immediate close persists latest note")
		camera.queue_free()
		await process_frame
	# Opening a broken print directly from the bag must still show a usable exit.
	var album = Camera.new()
	album.save_directory = output
	album.gallery_only = true
	album.initial_photo_path = broken
	root.add_child(album)
	album.size = Vector2(1600, 900)
	check(album._review.visible, "failed initial album load retains review surface")
	check(not album._caption_editor.visible, "no editable note without a loaded print")
	check(not album._caption_notice.text.is_empty(), "failed initial load explains unavailable print")
	album._show_review(0)
	check(album._caption_editor.visible and album._review_paper.visible, "valid photo recovers from initial load failure")
	album.queue_free()
	await process_frame
	FileAccess.open(output + "receipt.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	print("PHOTO_REVIEW_RESILIENCE ", checks, " checks / ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
