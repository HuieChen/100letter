extends SceneTree
const Camera=preload("res://scripts/ui/field_camera.gd")
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/camera-access/"
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func gallery(folder:String,validity:Array)->Array[String]:
	DirAccess.make_dir_recursive_absolute(folder)
	var paths:Array[String]=[]
	for index:int in validity.size():
		var path:=folder.path_join("DearSomewhere_%02d.png"%index);paths.append(path)
		if validity[index]:
			var photo:=Image.create(320,180,false,Image.FORMAT_RGB8);photo.fill(Color("76a4a6"));photo.save_png(path)
		else:FileAccess.open(path,FileAccess.WRITE).store_string("intentional unreadable QA photo")
		Camera._write_caption(path,"note "+str(index))
	return paths
func open_camera(folder:String,locale:String)->Control:
	var camera:=Camera.new();camera.locale=locale;camera.save_directory=folder;camera.album_directory=out+"exports"
	camera.size=Vector2(1600,900);root.add_child(camera)
	return camera
func run():
	root.unfocusable=true;root.size=Vector2i(1600,900)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	out+=str(Time.get_ticks_usec())+"/";DirAccess.make_dir_recursive_absolute(out)
	for locale:String in ["zh","en"]:
		var folder:=out+locale+"/mixed";var files:=gallery(folder,[true,true,false,false])
		var original_hash:=FileAccess.get_sha256(files[1])
		var camera:=open_camera(folder,locale);await process_frame
		check(camera.thumbnail.visible and not camera.thumbnail.disabled,locale+" damaged latest photos do not hide gallery entry")
		camera.thumbnail.pressed.emit();await process_frame
		check(camera._review.visible and camera._review_index==1,locale+" thumbnail opens newest readable print")
		if camera._review_index==1:
			camera._caption_editor.text="今天的海风 / Sea breeze"
			camera._step_review(1);camera._step_review(1);camera._step_review(1)
			check(camera._review_index==0,locale+" browsing crosses damaged tail and wraps to healthy photo")
			check(Camera.caption_for(files[1])=="今天的海风 / Sea breeze",locale+" fallback note saved beside visible photograph")
			check(Camera.caption_for(files[2])=="note 2",locale+" damaged file note remains unchanged")
		check(FileAccess.get_sha256(files[1])==original_hash,locale+" original photograph remains byte-identical")
		camera.queue_free();await process_frame
		# The file can disappear after the miniature was drawn. The review must
		# still offer navigation back to other prints instead of trapping access.
		folder=out+locale+"/removed";files=gallery(folder,[true,true]);camera=open_camera(folder,locale)
		DirAccess.remove_absolute(files[1]);camera.thumbnail.pressed.emit();await process_frame
		check(camera._review.visible,locale+" missing selected file still opens review controls")
		check(camera._album_button.disabled and not camera._caption_editor.visible,locale+" unavailable initial print cannot be edited or exported")
		camera._step_review(-1)
		check(camera._review_index==0,locale+" previous reaches a healthy print after selected file disappeared")
		camera.queue_free();await process_frame
		folder=out+locale+"/all-bad";files=gallery(folder,[false,false]);camera=open_camera(folder,locale)
		check(camera.thumbnail.visible and not camera.thumbnail.disabled,locale+" all-bad collection retains a usable entry")
		camera.thumbnail.pressed.emit();await process_frame
		check(camera._review.visible and not camera._caption_notice.text.is_empty(),locale+" all-bad review explains why print is unavailable")
		check(camera._album_button.disabled and not camera._caption_editor.visible,locale+" all-bad collection cannot overwrite notes or export a blank print")
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+locale+"_unavailable.png")
		camera._leave_review()
		check(not camera._review.visible and root.gui_get_focus_owner()==camera.shutter,locale+" error review returns to usable shutter")
		var photo:=Image.create(320,180,false,Image.FORMAT_RGB8);photo.fill(Color("76a4a6"))
		camera.capture_provider=func():return photo.duplicate()
		camera.take_photo();var deadline:=Time.get_ticks_msec()+5000
		while camera.capture_busy and Time.get_ticks_msec()<deadline:await process_frame
		check(not camera.capture_busy and camera._review_index==2,locale+" fresh capture recovers an all-bad collection")
		check(camera.thumbnail.get_node("ThumbnailPrint").image!=null,locale+" new capture restores actual miniature")
		camera.queue_free();await process_frame
		folder=out+locale+"/empty";gallery(folder,[]);camera=open_camera(folder,locale)
		check(not camera.thumbnail.visible and camera.thumbnail.disabled,locale+" empty collection still has no dead gallery button")
		camera.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("PHOTO_CAMERA_ACCESS ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
