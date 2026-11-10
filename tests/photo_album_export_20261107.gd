extends SceneTree
const Camera=preload("res://scripts/ui/field_camera.gd")
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/photo_album_export/"
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func settle():
	await process_frame
	await RenderingServer.frame_post_draw
func run():
	root.unfocusable=true;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	out+=str(Time.get_ticks_usec())+"/";DirAccess.make_dir_recursive_absolute(out)
	var gallery:=out+"photos/";DirAccess.make_dir_recursive_absolute(gallery)
	var source:=gallery+"DearSomewhere_01.png"
	var pixels:=Image.create(1600,900,false,Image.FORMAT_RGB8);pixels.fill(Color("579ba9"))
	pixels.fill_rect(Rect2i(0,0,160,900),Color.RED);pixels.fill_rect(Rect2i(1440,0,160,900),Color.BLUE);pixels.save_png(source)
	var original_hash:=FileAccess.get_sha256(source)
	for locale:String in ["zh","en"]:
		var camera:=Camera.new();camera.locale=locale;camera.save_directory=gallery;camera.album_directory=out+locale;camera.gallery_only=true
		root.add_child(camera);camera.size=Vector2(1600,900);await settle()
		check(not camera._album_button.disabled,locale+" valid print enables export")
		check(camera._album_button.text==("导出照片" if locale=="zh" else "Export photo"),locale+" translated export control")
		camera._caption_editor.text="今天的海风 / Sea breeze"
		var exported:String=await camera.export_current_photo()
		check(not exported.is_empty() and FileAccess.file_exists(exported),locale+" saved PNG exists")
		check(Camera.caption_for(source)=="今天的海风 / Sea breeze",locale+" immediate current caption persisted before export")
		check(FileAccess.get_sha256(source)==original_hash,locale+" original photo bytes remain unchanged")
		var print_pixels:=Image.load_from_file(exported)
		check(print_pixels.get_width()==1808 and print_pixels.get_height()==1240,locale+" landscape print resolution")
		var left:=print_pixels.get_pixel(140,400);var right:=print_pixels.get_pixel(1668,400)
		check(left.r>.9 and left.b<.1,locale+" full left edge retained")
		check(right.b>.9 and right.r<.1,locale+" full right edge retained")
		check(print_pixels.get_pixel(20,620).r>.9,locale+" paper border retained")
		var ink:=0
		for y:int in range(1036,1120):
			for x:int in range(100,1500):
				var color:=print_pixels.get_pixel(x,y)
				if color.r<.6 and color.a>.9:ink+=1
		check(ink>400,locale+" bilingual caption is rendered into exported bitmap")
		var saved_hash:=FileAccess.get_sha256(exported)
		var duplicate:String=await camera.export_current_photo()
		check(duplicate!=exported and FileAccess.file_exists(duplicate),locale+" repeated intentional export uses new filename")
		check(FileAccess.get_sha256(exported)==saved_hash,locale+" previous export is never overwritten")
		camera._caption_editor.text="A longer note / 海风与记忆。\n".repeat(6)
		var long_path:String=await camera.export_current_photo();var long_print:=Image.load_from_file(long_path)
		check(long_print.get_height()>1240,locale+" long note extends white paper instead of clipping")
		check(long_print.get_width()>long_print.get_height(),locale+" moderate long note retains landscape format")
		var blocked:=out+"blocked_"+locale;FileAccess.open(blocked,FileAccess.WRITE).store_string("fixture")
		camera.album_directory=blocked+"/album"
		var failed:String=await camera.export_current_photo()
		check(failed.is_empty() and not camera._album_busy,locale+" unwritable directory fails without stuck controls")
		check(not camera._caption_notice.text.is_empty() and not camera._album_button.disabled,locale+" failure visible and retry available")
		camera.album_directory=out+locale
		camera._caption_editor.text="Rapid click / 快速点击"
		var before:=DirAccess.get_files_at(camera.album_directory).size()
		camera.export_current_photo();camera.export_current_photo()
		check(camera._album_busy and camera._album_button.disabled,locale+" render disables duplicate submission")
		check(not camera.checkpoint_for_quit(),locale+" application quit waits for in-flight export")
		var old_index:int=camera._review_index;camera._show_review(1)
		check(camera._review_index==old_index,locale+" photo identity cannot switch mid-export")
		var deadline:=Time.get_ticks_msec()+5000
		while camera._album_busy and Time.get_ticks_msec()<deadline:await process_frame
		check(DirAccess.get_files_at(camera.album_directory).size()==before+1,locale+" rapid clicks create exactly one PNG")
		check(root.gui_get_focus_owner()==camera._album_button,locale+" export restores usable keyboard focus")
		for width:int in [1280,1920,2560]:
			root.size=Vector2i(width,width*9/16);await settle()
			check(not camera._album_button.get_global_rect().intersects(camera._review.get_node("BackToCamera").get_global_rect()),locale+" action buttons distinct "+str(width))
			root.get_texture().get_image().save_png(out+locale+"_"+str(width)+".png")
		camera.export_current_photo();camera._request_close()
		check(camera._close_after_album and not camera._closing,locale+" close safely waits for export")
		deadline=Time.get_ticks_msec()+5000
		while camera._album_busy and Time.get_ticks_msec()<deadline:await process_frame
		check(camera._closing and FileAccess.file_exists(camera.last_album_path),locale+" requested close completes after saved print")
		camera.queue_free();await process_frame
	var empty:=Camera.new();empty.save_directory=out+"empty";empty.gallery_only=true;empty.album_directory=out+"unused"
	root.add_child(empty);empty.size=Vector2(1600,900);await settle()
	check(empty._album_button.disabled,"empty album has no active export affordance")
	check((await empty.export_current_photo()).is_empty(),"empty album export is safely rejected")
	empty.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"Offscreen GPU export, decoded PNG pixels and persisted files; no OS input or human acceptance."},"  "))
	print("PHOTO_ALBUM_EXPORT ",checks," checks / ",failures.size()," failures; ",ProjectSettings.globalize_path(out))
	quit(0 if failures.is_empty() else 1)
