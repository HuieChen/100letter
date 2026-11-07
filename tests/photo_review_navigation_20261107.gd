extends SceneTree
const Camera=preload("res://scripts/ui/field_camera.gd")
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/photo_navigation/"
var camera:Control
func _initialize():run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr(label)
func key(code:Key,shift:bool=false)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down;event.shift_pressed=shift
		root.push_input(event,true);await process_frame
func click(control:Control)->void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
func make_gallery(path:String,validity:Array)->Array[String]:
	DirAccess.make_dir_recursive_absolute(path)
	var paths:Array[String]=[]
	for index:int in validity.size():
		var file:=path.path_join("DearSomewhere_%02d.png"%index);paths.append(file)
		if validity[index]:
			var pixels:=Image.create(160,90,false,Image.FORMAT_RGB8);pixels.fill(Color.RED if index==0 else Color.BLUE);pixels.save_png(file)
		else:FileAccess.open(file,FileAccess.WRITE).store_string("intentional broken PNG fixture")
		Camera._write_caption(file,"original "+str(index))
	return paths
func open_gallery(path:String,locale:String,initial:String="")->void:
	camera=Camera.new();camera.locale=locale;camera.save_directory=path;camera.gallery_only=true;camera.initial_photo_path=initial;camera.album_directory=out+"exports/"+locale
	root.add_child(camera);camera.size=Vector2(1600,900);await process_frame
func close_gallery()->void:
	camera.queue_free();await process_frame
func run()->void:
	root.unfocusable=true;root.size=Vector2i(1600,900)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	out+=str(Time.get_ticks_usec())+"/";DirAccess.make_dir_recursive_absolute(out)
	for locale:String in ["zh","en"]:
		var gallery:=out+locale+"/mixed";var files:=make_gallery(gallery,[true,false,true])
		await open_gallery(gallery,locale,files[0])
		var next:Button=camera._review.get_node("NextPhoto");var previous:Button=camera._review.get_node("PreviousPhoto")
		camera._caption_editor.text="今天的海风 / Sea breeze"
		await click(next)
		check(camera._review_index==0 and camera._review_cursor==1,locale+" failed load advances browsing cursor only")
		check(Camera.caption_for(files[0])=="今天的海风 / Sea breeze",locale+" outgoing visible note is saved")
		check(Camera.caption_for(files[1])=="original 1",locale+" broken print note remains unchanged")
		check(not camera._caption_notice.text.is_empty(),locale+" broken print has a visible error")
		await click(next)
		check(camera._review_index==2 and camera._caption_editor.text=="original 2",locale+" next mouse click reaches print beyond damaged file")
		await click(previous);await click(previous)
		check(camera._review_index==0,locale+" reverse traversal also passes damaged file")
		next.grab_focus();await key(KEY_ENTER)
		check(camera._review_index==0 and root.gui_get_focus_owner()==next,locale+" failed keyboard turn retains active next control")
		await key(KEY_ENTER)
		check(camera._review_index==2 and root.gui_get_focus_owner()==next,locale+" repeated keyboard turn reaches following print")
		await click(next)
		check(camera._review_index==0,locale+" normal last-to-first wrap works")
		camera._caption_editor.text="No indentation / 不要缩进";camera._caption_editor.grab_focus()
		await key(KEY_TAB)
		check(root.gui_get_focus_owner()!=camera._caption_editor,locale+" Tab leaves caption")
		check(camera._caption_editor.text=="No indentation / 不要缩进",locale+" Tab does not alter note")
		check(Camera.caption_for(files[0])==camera._caption_editor.text,locale+" Tab checkpoints caption")
		camera._caption_editor.grab_focus();await key(KEY_TAB,true)
		check(root.gui_get_focus_owner()!=camera._caption_editor,locale+" Shift Tab leaves caption")
		check(camera._caption_editor.text=="No indentation / 不要缩进",locale+" Shift Tab preserves note")
		for step:int in 14:
			await key(KEY_TAB)
			var focus:=root.gui_get_focus_owner()
			check(focus!=null and focus!=camera.shutter and focus!=camera.thumbnail,locale+" review focus remains usable "+str(step))
		# A failed checkpoint must neither lose text nor move either identity.
		var blocker:=files[0]+".json.tmp";DirAccess.make_dir_absolute(blocker)
		camera._caption_editor.text="Unsaved / 尚未保存";camera._caption_editor.grab_focus()
		await click(next)
		check(camera._review_index==0 and camera._review_cursor==0,locale+" save failure blocks both cursors")
		check(camera._caption_editor.text=="Unsaved / 尚未保存",locale+" save failure retains editor text")
		check(Camera.caption_for(files[1])=="original 1",locale+" save failure cannot modify broken note")
		DirAccess.remove_absolute(blocker)
		await click(next);await click(next)
		check(camera._review_index==2 and Camera.caption_for(files[0])=="Unsaved / 尚未保存",locale+" retry saves before continuing traversal")
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+locale+"_review.png")
		await close_gallery()
		# A broken initial selection has a meaningful next/previous origin.
		await open_gallery(gallery,locale,files[1]);await click(camera._review.get_node("NextPhoto"))
		check(camera._review_index==2,locale+" initial bad selection can reach its actual next print")
		await close_gallery()
		var all_bad:=out+locale+"/all_bad";var bad_files:=make_gallery(all_bad,[false,false])
		await open_gallery(all_bad,locale,bad_files[1])
		for step:int in 3:
			await click(camera._review.get_node("NextPhoto"))
			check(camera._review_index==-1 and not camera._caption_editor.visible and camera._album_button.disabled,locale+" all-bad traversal stays bounded and uneditable "+str(step))
		check(camera._review_cursor==0,locale+" all-bad navigation advances instead of sticking")
		var closed:Array[bool]=[];camera.closed.connect(func():closed.append(true))
		await click(camera._review.get_node("BackToCamera"))
		check(closed.size()==1,locale+" all-bad gallery still exits")
		await close_gallery()
		for count:int in [0,1]:
			var sparse:=out+locale+"/sparse_"+str(count);make_gallery(sparse,[] if count==0 else [true])
			await open_gallery(sparse,locale)
			check(camera._review.get_node("PreviousPhoto").disabled and camera._review.get_node("NextPhoto").disabled,locale+" sparse navigation disabled "+str(count))
			check(camera._album_button.disabled==(count==0),locale+" sparse export follows loaded print "+str(count))
			if count==1:
				await click(camera._album_button)
				var deadline:=Time.get_ticks_msec()+5000
				while camera._album_busy and Time.get_ticks_msec()<deadline:await process_frame
				check(not camera.last_album_path.is_empty(),locale+" single print exports successfully")
				check(camera._review.get_node("PreviousPhoto").disabled and camera._review.get_node("NextPhoto").disabled,locale+" export completion keeps single-print navigation disabled")
				check(camera._album_open.visible,locale+" upstream open-album affordance remains available")
			await close_gallery()
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"Offscreen GPU with real engine mouse/key input and isolated photo files; no OS input."},"  "))
	print("PHOTO_REVIEW_NAVIGATION ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
