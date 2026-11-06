extends SceneTree
## GPU / synthetic-pointer regression. Never writes to the player's Pictures folder.
const Camera=preload("res://scripts/ui/field_camera.gd")
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/photo_album_visual/evidence/"
var data:="user://qa/photo_album_visual/"+str(Time.get_ticks_usec())+"/"
var view:SubViewport
var saved_paths:Array[String]=[]

func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if not isolated:push_error("Isolated --final-save=user://qa/ is required");quit(1);return
	run.call_deferred()

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func settle():
	await process_frame
	await RenderingServer.frame_post_draw

func screenshot(label:String):
	await settle()
	view.get_texture().get_image().save_png(out+label+".png")

func pointer_click(at:Vector2):
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;view.push_input(motion,true)
	for down:bool in [true,false]:
		var button:=InputEventMouseButton.new();button.position=at;button.global_position=at;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=down;view.push_input(button,true)

func wait_export(camera:Control):
	var deadline:=Time.get_ticks_msec()+8000
	while camera._album_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not camera._album_busy,"Export finishes within eight seconds")
	await settle()

func ink_count(pixels:Image,area:Rect2i)->int:
	var count:=0
	var clipped:=area.intersection(Rect2i(Vector2i.ZERO,pixels.get_size()))
	for y:int in range(clipped.position.y,clipped.end.y,2):
		for x:int in range(clipped.position.x,clipped.end.x,2):
			var color:=pixels.get_pixel(x,y)
			if color.a>.9 and color.r<.65 and color.g<.55 and color.b<.45:count+=1
	return count

func run():
	root.unfocusable=true;Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(data);DirAccess.make_dir_recursive_absolute(out)
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);view.notify_mouse_entered()
	var photo:=Image.create(1600,900,false,Image.FORMAT_RGB8);photo.fill(Color("559ba9"))
	photo.fill_rect(Rect2i(0,0,160,900),Color.RED);photo.fill_rect(Rect2i(1440,0,160,900),Color.BLUE)
	var original:=data+"DearSomewhere_landscape.png";photo.save_png(original)
	var original_hash:=FileAccess.get_sha256(original)
	for language:String in ["zh","en"]:
		var camera:=Camera.new();camera.locale=language;camera.gallery_only=true;camera.save_directory=data;camera.initial_photo_path=original;camera.album_directory=data.path_join("album_"+language)
		camera.album_saved.connect(func(path:String):saved_paths.append(path))
		view.add_child(camera);camera.size=Vector2(1600,900);await settle()
		var save:Button=camera._review.get_node("SaveToAlbum")
		check(save.is_visible_in_tree() and not save.disabled,language+" reviewed photo has an enabled album action")
		var note:="今天的海风 / Sea breeze"
		camera._caption_editor.text=note
		var before:=saved_paths.size()
		pointer_click(save.get_global_rect().get_center())
		pointer_click(save.get_global_rect().get_center())
		check(camera._album_busy,language+" actual save button starts export")
		await wait_export(camera)
		check(saved_paths.size()==before+1,language+" rapid double click produces one saved print")
		if saved_paths.size()==before:
			camera.queue_free();await process_frame;continue
		var first:String=saved_paths[-1]
		check(FileAccess.file_exists(first),language+" signalled exported PNG exists")
		check(ProjectSettings.globalize_path(first).begins_with(ProjectSettings.globalize_path(data)),language+" export stays in isolated QA album")
		check(Camera.caption_for(original)==note,language+" export persists the latest written note")
		check(FileAccess.get_sha256(original)==original_hash,language+" exporting preserves captured source bytes")
		var print_image:=Image.load_from_file(first)
		check(print_image!=null and not print_image.is_empty(),language+" exported PNG decodes")
		if print_image!=null and not print_image.is_empty():
			check(print_image.get_width()>print_image.get_height(),language+" normal developed print remains landscape")
			var left:=print_image.get_pixel(140,420);var right:=print_image.get_pixel(print_image.get_width()-140,420)
			check(left.r>.85 and left.b<.15,language+" full left photo edge survives export")
			check(right.b>.85 and right.r<.15,language+" full right photo edge survives export")
			var margin:=print_image.get_pixel(1500,1160)
			check(margin.r>.9 and margin.g>.85 and margin.a>.95,language+" developed paper white margin is included")
			check(ink_count(print_image,Rect2i(100,1036,1500,150))>100,language+" actual caption glyphs are baked into the print")
			print_image.save_png(out+"export_"+language+".png")
		check(camera._album_open.visible,language+" saved print exposes a real album folder action")
		var first_hash:=FileAccess.get_sha256(first)
		var second:String=await camera.export_current_photo()
		check(not second.is_empty() and second!=first and FileAccess.file_exists(second),language+" saving again creates a distinct file")
		check(FileAccess.get_sha256(first)==first_hash,language+" repeat save never overwrites an earlier print")
		for dims:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
			view.size=dims;camera.size=Vector2(dims);await settle()
			var bounds:=Rect2(Vector2.ZERO,Vector2(dims))
			for name:String in ["SaveToAlbum","BackToCamera","OpenAlbum"]:
				var control:Button=camera._review.get_node(name)
				check(bounds.encloses(control.get_global_rect()),language+" "+name+" stays onscreen at "+str(dims.x))
				var text_width:=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
				check(text_width<=control.size.x,language+" "+name+" label fits at "+str(dims.x))
			check(not camera._review.get_node("SaveToAlbum").get_global_rect().intersects(camera._review.get_node("BackToCamera").get_global_rect()),language+" save and back actions remain separate at "+str(dims.x))
			await screenshot("review_"+language+"_"+str(dims.x))
		view.size=Vector2i(1600,900);camera.size=Vector2(1600,900)
		# A file used as a directory simulates denied/unavailable destination storage.
		var blocked:=data+"not_a_directory_"+language
		var blocker:=FileAccess.open(blocked,FileAccess.WRITE);blocker.store_string("preserve this fixture");blocker.close()
		camera.album_directory=blocked.path_join("album")
		before=saved_paths.size()
		var failed:String=await camera.export_current_photo()
		check(failed.is_empty() and saved_paths.size()==before,language+" failed storage produces no success signal or path")
		check(not camera._caption_notice.text.is_empty() and not camera._album_busy and not save.disabled,language+" failure shows feedback and leaves retry usable")
		check(FileAccess.get_file_as_string(blocked)=="preserve this fixture",language+" failed export preserves destination blocker")
		check(FileAccess.get_sha256(original)==original_hash,language+" failed export preserves source photo")
		camera.album_directory=data.path_join("album_"+language)
		# Caption beyond the editor's visible lines must not vanish from exported paper.
		camera._caption_editor.text="Sea breeze / 海风\n".repeat(10)+"The final line / 最后一行"
		var long_path:String=await camera.export_current_photo()
		check(not long_path.is_empty(),language+" long written note exports")
		if not long_path.is_empty():
			var long_print:=Image.load_from_file(long_path)
			check(long_print.get_height()>1240,language+" paper margin grows for the full note")
			check(ink_count(long_print,Rect2i(100,long_print.get_height()-150,1500,105))>30,language+" final note lines are visible near the paper bottom")
			long_print.save_png(out+"long_note_"+language+".png")
		camera._caption_editor.text=""
		var blank_path:String=await camera.export_current_photo()
		check(not blank_path.is_empty(),language+" photo without a note still exports")
		if not blank_path.is_empty():
			var blank_print:=Image.load_from_file(blank_path)
			check(ink_count(blank_print,Rect2i(100,1036,1500,150))==0,language+" editor placeholder and caret are absent from exported blank margin")
		camera.queue_free();await process_frame
	# No photo identity: export cannot fabricate a blank print.
	var empty_dir:=data+"empty";DirAccess.make_dir_recursive_absolute(empty_dir)
	var empty:=Camera.new();empty.gallery_only=true;empty.save_directory=empty_dir;empty.album_directory=data+"empty_album"
	view.add_child(empty);empty.size=Vector2(1600,900);await settle()
	check(empty._review.get_node("SaveToAlbum").disabled,"Empty album has no enabled export")
	check((await empty.export_current_photo()).is_empty(),"Empty album cannot save a fabricated photograph")
	empty.queue_free();await process_frame
	var damaged_dir:=data+"damaged";DirAccess.make_dir_recursive_absolute(damaged_dir)
	var damaged_path:=damaged_dir+"/DearSomewhere_damaged.png"
	var damaged_file:=FileAccess.open(damaged_path,FileAccess.WRITE);damaged_file.store_string("intentional corrupt fixture");damaged_file.close()
	var damaged:=Camera.new();damaged.gallery_only=true;damaged.save_directory=damaged_dir;damaged.album_directory=data+"damaged_album"
	view.add_child(damaged);damaged.size=Vector2(1600,900);await settle()
	check(damaged._review.get_node("SaveToAlbum").disabled,"Unreadable photo has no enabled export")
	check((await damaged.export_current_photo()).is_empty(),"Unreadable photo cannot produce a false successful export")
	damaged.queue_free();await process_frame
	view.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"data":data,"method":"GPU SubViewport pointer input and PNG pixel inspection; isolated QA album only; no OS input or player Pictures writes."},"  "))
	print("PHOTO_ALBUM_VISUAL ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
