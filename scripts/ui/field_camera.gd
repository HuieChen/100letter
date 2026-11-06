extends Control
## Local in-game camera. The host supplies a HUD-free viewport Image.
signal closed
signal photo_saved(path:String)
signal caption_saved(path:String,text:String)
signal album_saved(path:String)
signal pending_save_finished
signal cue(kind:String)
const FONT=preload("res://assets/fonts/DearRounded.tres")
const ART="res://assets/authoring/camera_20261105/viewfinder.png"
const DESIGN:=Vector2(1600,900)
var locale:="zh"
var clock_caption:=""
var location_caption:=""
var save_directory:="user://photos"
var album_directory:=""
var gallery_only:=false
var initial_photo_path:=""
var capture_provider:Callable
var capture_busy:=false
var gallery_paths:Array[String]=[]
var last_photo_path:=""
var canvas:Control
var shutter:Button
var thumbnail:Button
var status_label:Label
var count_label:Label
var _frame:NinePatchRect
var _focus_marks:TextureRect
var _review:Control
var _review_paper:PhotoPaper
var _review_index:=-1
var _print_paper:PhotoPaper
var _print_clip:Control
var _slot:Control
var _flash:ColorRect
var _closing:=false
var _animation:Tween
var _status_serial:=0
var _caption_editor:TextEdit
var _caption_notice:Label
var _caption_timer:Timer
var _caption_dirty:=false
var _caption_original:=""
var _live_nodes:Array[CanvasItem]=[]
var _album_button:Button
var _album_open:Button
var _album_busy:=false
var _close_after_album:=false
var last_album_path:=""

class ArtButton extends Button:
	var art:Texture2D
	var round_hit:=false
	var visual:=1.0
	func _ready()->void:
		flat=true;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state:String in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	func _has_point(point:Vector2)->bool:
		return point.distance_to(size*.5)<=minf(size.x,size.y)*.5 if round_hit else Rect2(Vector2.ZERO,size).has_point(point)
	func _process(delta:float)->void:
		var target:=0.91 if button_pressed else (1.045 if is_hovered() or has_focus() else 1.0)
		visual=lerpf(visual,target,1.0-exp(-18.0*delta));queue_redraw()
	func _draw()->void:
		if art==null:return
		draw_set_transform(size*.5,0.0,Vector2.ONE*visual)
		draw_texture_rect(art,Rect2(-size*.5,size),false,Color(1,1,1,0.48 if disabled else 1.0))

class PhotoPaper extends Control:
	var image:Texture2D
	var reveal:=1.0:
		set(value):reveal=value;queue_redraw()
	func _draw()->void:
		var paper:=PackedVector2Array([Vector2(2,3),Vector2(size.x-3,1),Vector2(size.x,5),Vector2(size.x-1,size.y-3),Vector2(4,size.y),Vector2(0,size.y-5)])
		var shadow:=PackedVector2Array()
		for point:Vector2 in paper:shadow.append(point+Vector2(3,5))
		draw_colored_polygon(shadow,Color(0.14,0.13,0.10,0.16))
		draw_colored_polygon(paper,Color("fffaf0"))
		var edge:=paper.duplicate();edge.append(paper[0])
		draw_polyline(edge,Color("e5d9c5"),1.5,true)
		var window:=Rect2(Vector2(size.x*.05,size.x*.05),Vector2(size.x*.9,size.x*.9*9.0/16.0))
		draw_rect(window,Color("ddd8cb"))
		if image:
			var source:=Rect2(Vector2.ZERO,image.get_size())
			# Keep the full captured composition; never crop a landscape photo to square.
			var fit:=minf(window.size.x/source.size.x,window.size.y/source.size.y)
			var fitted:=Rect2(window.position+(window.size-source.size*fit)*.5,source.size*fit)
			draw_texture_rect_region(image,fitted,source,Color(1,1,1,reveal))
		var line_color:=Color(0.63,0.57,0.46,0.14)
		draw_line(Vector2(size.x*.08,size.y-8),Vector2(size.x*.41,size.y-9),line_color,1.0,true)

class PrintSlot extends Control:
	func _draw()->void:
		var center:=size*.5
		draw_line(Vector2(7,center.y+3),Vector2(size.x-7,center.y+3),Color(0.15,0.17,0.14,0.24),12.0,true)
		draw_line(Vector2(7,center.y),Vector2(size.x-7,center.y),Color("fff1d6"),12.0,true)
		draw_circle(Vector2(7,center.y),6.0,Color("fff1d6"));draw_circle(Vector2(size.x-7,center.y),6.0,Color("fff1d6"))
		draw_line(Vector2(12,center.y),Vector2(size.x-12,center.y),Color("716652"),4.0,true)

func _ready()->void:
	name="FieldCamera";mouse_filter=Control.MOUSE_FILTER_STOP;z_index=100
	# The host places this modal on its authored 1600x900 stage.
	canvas=Control.new();canvas.name="CameraCanvas";canvas.size=DESIGN;canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas)
	_load_gallery()
	var pixels:=Image.new()
	var image_error:=pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(ART))
	var texture:Texture2D=ImageTexture.create_from_image(pixels) if image_error==OK and not pixels.is_empty() else null
	if texture:
		# Nine-patch keeps the original rounded brush corners while enlarging the
		# frame to safe screen edges. Its center is transparent, with focus marks separate.
		var frame_atlas:=AtlasTexture.new();frame_atlas.atlas=texture;frame_atlas.region=Rect2(104,77,1462,676);frame_atlas.filter_clip=true
		_frame=NinePatchRect.new();_frame.name="HandInkViewfinder";_frame.texture=frame_atlas;_frame.draw_center=false;_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_frame.patch_margin_left=70;_frame.patch_margin_right=70;_frame.patch_margin_top=70;_frame.patch_margin_bottom=70
		_place(_frame,canvas,Rect2(24,24,1552,852))
		var focus_atlas:=AtlasTexture.new();focus_atlas.atlas=texture;focus_atlas.region=Rect2(638,285,388,262);focus_atlas.filter_clip=true
		_focus_marks=TextureRect.new();_focus_marks.name="FocusMarks";_focus_marks.texture=focus_atlas;_focus_marks.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_focus_marks.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_place(_focus_marks,canvas,Rect2(645,345,310,209))
	var heading:=_label(_t("相机","Camera"),Rect2(80,60,300,42),30)
	heading.name="CameraHeading"
	count_label=_label("",Rect2(1130,60,280,42),24,HORIZONTAL_ALIGNMENT_RIGHT)
	_label(location_caption,Rect2(270,800,430,38),22)
	shutter=ArtButton.new();shutter.name="CameraShutter";shutter.round_hit=true
	if texture:
		var button_atlas:=AtlasTexture.new();button_atlas.atlas=texture;button_atlas.region=Rect2(744,754,182,182);button_atlas.filter_clip=true;shutter.art=button_atlas
	_place(shutter,canvas,Rect2(748,724,104,104));shutter.tooltip_text=_t("拍照 · C","Take photo · C");shutter.pressed.connect(take_photo)
	_label("C",Rect2(755,831,90,26),18,HORIZONTAL_ALIGNMENT_CENTER)
	thumbnail=ArtButton.new();thumbnail.name="LastPhoto";thumbnail.tooltip_text=_t("查看照片","View photos");_place(thumbnail,canvas,Rect2(82,760,120,84));thumbnail.pressed.connect(func():_show_review(gallery_paths.size()-1))
	status_label=_label("",Rect2(950,788,450,42),23)
	_print_clip=Control.new();_print_clip.name="PhotoEjection";_print_clip.clip_contents=true;_print_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_print_clip,canvas,Rect2(660,646,280,244));_print_clip.hide()
	_print_paper=PhotoPaper.new();_print_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_print_paper,_print_clip,Rect2(0,-192,280,192))
	_slot=PrintSlot.new();_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_slot,canvas,Rect2(648,636,304,20));_slot.hide()
	_flash=ColorRect.new();_flash.name="ShutterFlash";_flash.color=Color("fff7df");_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_flash,canvas,Rect2(Vector2.ZERO,DESIGN));_flash.modulate.a=0.0
	for node:Node in canvas.get_children():
		if node is CanvasItem:_live_nodes.append(node)
	var close:=_button("×",Rect2(1470,42,74,68),42);close.name="CloseCamera";close.tooltip_text=_t("关闭相机","Close camera");close.pressed.connect(_request_close)
	_build_review();_refresh_count();_refresh_thumbnail()
	resized.connect(_layout);_layout()
	if gallery_only:
		for node:CanvasItem in _live_nodes:node.hide()
		if not gallery_paths.is_empty():_show_review(gallery_paths.find(initial_photo_path) if initial_photo_path in gallery_paths else gallery_paths.size()-1)
		else:_set_review_active(true);_caption_editor.hide();_review_paper.hide();_caption_notice.text=_t("还没有照片","No photos yet")
	else:shutter.grab_focus()

func _place(node:Control,parent:Node,rect:Rect2)->void:
	parent.add_child(node);node.position=rect.position;node.size=rect.size
func _layout()->void:
	if canvas==null:return
	var factor:=minf(size.x/DESIGN.x,size.y/DESIGN.y)
	canvas.scale=Vector2.ONE*factor;canvas.position=(size-DESIGN*factor)*.5
func _t(zh:String,en:String)->String:return en if locale=="en" else zh
func _label(text:String,rect:Rect2,font_size:int,align:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT)->Label:
	var label:=Label.new();label.text=text;label.horizontal_alignment=align;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("fff5dc"));label.add_theme_color_override("font_shadow_color",Color(0.25,0.25,0.19,0.8));label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",2)
	_place(label,canvas,rect);return label
func _button(text:String,rect:Rect2,font_size:int)->Button:
	var button:=Button.new();button.text=text;button.flat=true;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",FONT);button.add_theme_font_size_override("font_size",font_size)
	for state:String in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Color("fff5dc"));button.add_theme_color_override("font_hover_color",Color("c8e8ce"));button.add_theme_color_override("font_pressed_color",Color("e1ca9d"));button.add_theme_color_override("font_focus_color",Color("c8e8ce"));button.add_theme_color_override("font_outline_color",Color("5a6151"));button.add_theme_constant_override("outline_size",2)
	_place(button,canvas,rect);return button
func _build_review()->void:
	_review=Control.new();_review.name="PhotoReview";_review.mouse_filter=Control.MOUSE_FILTER_STOP;_place(_review,canvas,Rect2(Vector2.ZERO,DESIGN));_review.hide()
	var shade:=ColorRect.new();shade.color=Color(0.08,0.12,0.10,0.72);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(shade,_review,Rect2(Vector2.ZERO,DESIGN))
	_review_paper=PhotoPaper.new();_review_paper.name="DevelopedPhoto";_review_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_review_paper,_review,Rect2(348,100,904,620))
	_caption_editor=TextEdit.new();_caption_editor.name="PhotoCaption";_caption_editor.placeholder_text=_t("在这里写点什么…","Write a little note…");_caption_editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	_caption_editor.add_theme_font_override("font",FONT);_caption_editor.add_theme_font_size_override("font_size",25)
	for state:String in ["normal","focus","read_only"]:_caption_editor.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_caption_editor.add_theme_color_override("font_color",Color("665240"));_caption_editor.add_theme_color_override("font_placeholder_color",Color(0.4,0.32,0.25,0.42));_caption_editor.add_theme_color_override("caret_color",Color("665240"));_caption_editor.add_theme_color_override("selection_color",Color(0.66,0.58,0.44,0.24))
	_place(_caption_editor,_review,Rect2(398,618,804,78))
	_caption_editor.text_changed.connect(func():_caption_dirty=true;_caption_timer.start())
	_caption_editor.focus_exited.connect(_save_caption)
	_caption_timer=Timer.new();_caption_timer.one_shot=true;_caption_timer.wait_time=.45;add_child(_caption_timer);_caption_timer.timeout.connect(_save_caption)
	_caption_notice=_label("",Rect2(420,730,760,32),21,HORIZONTAL_ALIGNMENT_CENTER);_caption_notice.reparent(_review)
	for item:Array in [["PreviousPhoto","‹",Rect2(228,340,90,100),-1],["NextPhoto","›",Rect2(1282,340,90,100),1]]:
		var button:=_button(item[1],item[2],54);button.reparent(_review);button.name=item[0];button.pressed.connect(func():_show_review(_review_index+int(item[3])))
	_album_button=_button(_t("保存到相册","Save to album"),Rect2(382,774,390,64),28);_album_button.reparent(_review);_album_button.name="SaveToAlbum";_album_button.disabled=true;_album_button.pressed.connect(export_current_photo)
	_album_open=_button(_t("查看相册","Open album"),Rect2(1176,730,240,36),21);_album_open.reparent(_review);_album_open.name="OpenAlbum";_album_open.hide()
	_album_open.pressed.connect(func():
		if not last_album_path.is_empty() and OS.shell_open(ProjectSettings.globalize_path(last_album_path).get_base_dir())!=OK:_caption_notice.text=_t("相册无法打开，请在图片目录查看","Open Pictures / Dear Somewhere to find your photo."))
	var back:=_button(_t("返回背包","Back to bag") if gallery_only else _t("继续拍摄","Back to camera"),Rect2(828,774,390,64),28);back.reparent(_review);back.name="BackToCamera";back.pressed.connect(_leave_review)
	# The same one-click X stays above the review overlay.
	canvas.move_child(canvas.get_node("CloseCamera"),canvas.get_child_count()-1)
func _load_gallery()->void:
	gallery_paths=photo_paths(save_directory)
	if not gallery_paths.is_empty():last_photo_path=gallery_paths[-1]
static func photo_paths(directory_path:String)->Array[String]:
	var result:Array[String]=[]
	var directory:=DirAccess.open(directory_path)
	if directory==null:return result
	for filename:String in directory.get_files():
		if filename.begins_with("DearSomewhere_") and filename.ends_with(".png"):result.append(directory_path.path_join(filename))
	result.sort();return result
static func caption_for(photo_path:String)->String:
	for suffix:String in [".json",".json.bak"]:
		if not FileAccess.file_exists(photo_path+suffix):continue
		var payload:Variant=JSON.parse_string(FileAccess.get_file_as_string(photo_path+suffix))
		if payload is Dictionary:return str(payload.get("caption",""))
	return ""
static func _write_caption(photo_path:String,text:String)->bool:
	if not FileAccess.file_exists(photo_path):return false
	var target:=ProjectSettings.globalize_path(photo_path+".json")
	var temporary:=target+".tmp";var backup:=target+".bak"
	var payload:Dictionary={"version":1,"caption":text}
	if FileAccess.file_exists(target):
		var prior:Variant=JSON.parse_string(FileAccess.get_file_as_string(target))
		if prior is Dictionary:payload=prior.duplicate();payload.caption=text;payload.version=1
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(payload,"\t"));file.flush();var error:=file.get_error();file.close()
	if error!=OK:return false
	var had_original:=FileAccess.file_exists(target)
	if had_original:
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK:return false
		if DirAccess.rename_absolute(target,backup)!=OK:return false
	if DirAccess.rename_absolute(temporary,target)!=OK:
		if had_original:DirAccess.rename_absolute(backup,target)
		return false
	return true
func _save_caption()->bool:
	# TextEdit batches text_changed; a close in the same frame must still save
	# the editor's current text instead of relying on that deferred notification.
	if not is_instance_valid(_caption_editor):return true
	if _caption_editor.text==_caption_original:_caption_dirty=false;return true
	if _review_index<0 or _review_index>=gallery_paths.size():return false
	var path:String=gallery_paths[_review_index]
	if not _write_caption(path,_caption_editor.text):
		_caption_notice.text=_t("文字还没保存，请再试一次","Note not saved. Please try again.");return false
	_caption_original=_caption_editor.text;_caption_dirty=false;_caption_notice.text="";caption_saved.emit(path,_caption_editor.text);return true
func checkpoint_for_quit()->bool:return not _album_busy and _save_caption()
func wait_for_pending_save()->void:
	if _album_busy:await pending_save_finished

func export_current_photo()->String:
	if _album_busy or _closing or _review_index<0 or _review_index>=gallery_paths.size() or not _review.visible:return ""
	if not _save_caption():return ""
	var destination:=album_directory
	if destination.is_empty():
		var pictures:=OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if pictures.is_empty():
			_caption_notice.text=_t("找不到图片文件夹，照片仍保存在背包中","Pictures folder unavailable. Your photo is still in the bag.");return ""
		destination=pictures.path_join("Dear Somewhere")
	if DirAccess.make_dir_recursive_absolute(destination)!=OK:
		_caption_notice.text=_t("没能存到相册，请检查图片文件夹后重试","Could not save to album. Check your Pictures folder and retry.");return ""
	var source_path:String=gallery_paths[_review_index]
	# Freeze this print and its saved note across the two render frames. The
	# source image/sidecar stay untouched, and repeated clicks cannot race.
	_album_busy=true;_album_button.disabled=true;_caption_editor.editable=false;_album_open.hide()
	_caption_notice.text=_t("正在保存…","Saving…")
	for control_name:String in ["PreviousPhoto","NextPhoto","BackToCamera"]:_review.get_node(control_name).disabled=true
	var viewport:=SubViewport.new();viewport.disable_3d=true;viewport.transparent_bg=true
	viewport.size=Vector2i(1808,1240);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var print_canvas:=Control.new();viewport.add_child(print_canvas)
	var paper:=PhotoPaper.new();paper.image=_review_paper.image;paper.size=Vector2(1808,1240);print_canvas.add_child(paper)
	var note:=Label.new();note.text=_caption_original;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Rasterize at output resolution instead of scaling cached 25px glyphs.
	note.add_theme_font_override("font",FONT);note.add_theme_font_size_override("font_size",50);note.add_theme_color_override("font_color",Color("665240"))
	note.position=Vector2(100,1036);note.size=Vector2(1608,156);paper.add_child(note)
	await get_tree().process_frame
	# Long notes get more paper below the full-width photograph, rather than
	# being silently clipped to the editor's scrollable visible area.
	var print_height:=maxf(1240.0,note.position.y+note.get_minimum_size().y+48.0)
	var result:=""
	var message:=""
	if print_height>8192.0:
		message=_t("题字太长，缩短一些后再保存；原文已保留","This note is too long to export. Shorten it and retry; the original is saved.")
	else:
		paper.size.y=print_height;viewport.size.y=ceili(print_height)
		await RenderingServer.frame_post_draw
		var pixels:=viewport.get_texture().get_image()
		var stem:=source_path.get_file().get_basename()+"_print"
		var path:=destination.path_join(stem+".png");var suffix:=1
		while FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path+".tmp"):
			path=destination.path_join(stem+"_"+str(suffix)+".png");suffix+=1
		var temporary:=path+".tmp"
		var written:=pixels!=null and not pixels.is_empty() and pixels.save_png(temporary)==OK
		if written and DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))==OK:
			result=path;last_album_path=path
			message=_t("已保存到 图片 / Dear Somewhere","Saved to Pictures / Dear Somewhere")
		else:
			if FileAccess.file_exists(temporary):DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			message=_t("照片没能存到相册，请重试","Could not save photo to album. Please retry.")
	viewport.queue_free()
	_album_busy=false;_album_button.disabled=false;_caption_editor.editable=true
	for control_name:String in ["PreviousPhoto","NextPhoto","BackToCamera"]:_review.get_node(control_name).disabled=false
	_caption_notice.text=message;_album_button.grab_focus()
	_album_open.visible=not result.is_empty()
	if not result.is_empty():album_saved.emit(result);cue.emit("paper")
	pending_save_finished.emit()
	if _close_after_album:_close_after_album=false;_request_close()
	return result

func _refresh_count()->void:
	count_label.text=_t("照片 ","Photos ")+str(gallery_paths.size())
func _refresh_thumbnail()->void:
	thumbnail.disabled=gallery_paths.is_empty()
	if gallery_paths.is_empty():thumbnail.hide();return
	var pixels:=Image.load_from_file(gallery_paths[-1])
	if pixels==null or pixels.is_empty():thumbnail.hide();return
	# The thumbnail occupies roughly 100 screen pixels. Keep the original PNG
	# and full-size review intact without allocating a full capture on the GPU here.
	var preview_scale:=minf(1.0,256.0/maxi(pixels.get_width(),pixels.get_height()))
	if preview_scale<1.0:pixels.resize(maxi(1,roundi(pixels.get_width()*preview_scale)),maxi(1,roundi(pixels.get_height()*preview_scale)),Image.INTERPOLATE_LANCZOS)
	thumbnail.show()
	# A real miniature print, no placeholder photo.
	var paper:=thumbnail.get_node_or_null("ThumbnailPrint") as PhotoPaper
	if paper==null:paper=PhotoPaper.new();paper.name="ThumbnailPrint";paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(paper,thumbnail,Rect2(4,0,112,77))
	paper.image=ImageTexture.create_from_image(pixels);paper.queue_redraw()
func _show_review(index:int)->void:
	if capture_busy or _album_busy or gallery_paths.is_empty():return
	if not _save_caption():return
	var was_visible:bool=_review.visible
	var next_index:int=wrapi(index,0,gallery_paths.size())
	# A one-photo wrap or selecting the current print has no page turn.
	if was_visible and next_index==_review_index:return
	var pixels:=Image.load_from_file(gallery_paths[next_index])
	if pixels==null or pixels.is_empty():
		var message:=_t("照片无法打开，请试试另一张","Photo unavailable. Try another print.")
		if was_visible or gallery_only:
			if _review_index<0:
				_caption_editor.hide();_review_paper.hide()
			_set_review_active(true)
			_caption_notice.text=message
		else:_status(message)
		return
	# Commit photo identity only after decoding succeeds. Otherwise later edits
	# to the still-visible print would be saved beside the unreadable photo.
	_review_index=next_index
	_caption_original=caption_for(gallery_paths[_review_index]);_caption_editor.set_block_signals(true);_caption_editor.text=_caption_original;_caption_editor.set_block_signals(false);_caption_dirty=false;_caption_notice.text=""
	_caption_editor.show();_review_paper.show()
	_review_paper.image=ImageTexture.create_from_image(pixels);_review_paper.reveal=1.0;_set_review_active(true)
	_album_button.disabled=false;_album_open.hide()
	cue.emit("flip" if was_visible else "paper")
func _set_review_active(active:bool)->void:
	_review.visible=active
	# These buttons remain drawn underneath the paper, but must not take Tab
	# focus or keyboard activation through the nested review surface.
	shutter.focus_mode=Control.FOCUS_NONE if active else Control.FOCUS_ALL
	thumbnail.focus_mode=Control.FOCUS_NONE if active else Control.FOCUS_ALL
	if active:_review.get_node("BackToCamera").grab_focus()
func _leave_review()->void:
	if _album_busy:return
	if gallery_only:_request_close();return
	if not _save_caption():return
	_set_review_active(false);cue.emit("paper");shutter.grab_focus()

func take_photo()->void:
	if capture_busy or _album_busy or _closing or gallery_only:return
	if _review.visible and get_viewport().gui_get_focus_owner()==_caption_editor:return
	if _review.visible:_leave_review()
	if _review.visible:return
	capture_busy=true;shutter.disabled=true
	_status("")
	hide()
	await RenderingServer.frame_post_draw
	if not is_inside_tree():return
	var pixels:Image
	if capture_provider.is_valid():pixels=await capture_provider.call()
	else:pixels=get_viewport().get_texture().get_image()
	if not is_inside_tree() or _closing:return
	show()
	if pixels==null or pixels.is_empty():_capture_failed(_t("没有拍到，再试一次","Could not capture. Try again."));return
	var directory_error:=DirAccess.make_dir_recursive_absolute(save_directory)
	if directory_error!=OK:_capture_failed(_t("照片没能保存，请重试","Could not save photo. Try again."));return
	var stamp:=Time.get_datetime_string_from_system().replace(":","").replace("-","").replace("T","_")
	var stem:="DearSomewhere_"+stamp+"_"+str(Time.get_ticks_msec())
	var path:=save_directory.path_join(stem+".png")
	var suffix:=0
	while FileAccess.file_exists(path):suffix+=1;path=save_directory.path_join(stem+"_"+str(suffix)+".png")
	if pixels.save_png(path)!=OK:_capture_failed(_t("照片没能保存，请重试","Could not save photo. Try again."));return
	last_photo_path=path;gallery_paths.append(path);_refresh_count();_refresh_thumbnail();photo_saved.emit(path);cue.emit("camera")
	await _develop(ImageTexture.create_from_image(pixels))
	if not is_inside_tree():return
	capture_busy=false;shutter.disabled=false;_show_review(gallery_paths.size()-1)

func _capture_failed(message:String)->void:
	capture_busy=false;shutter.disabled=false;shutter.grab_focus();_status(message)
func _develop(texture:Texture2D)->void:
	_print_paper.image=texture;_print_paper.reveal=0.0;_print_paper.position=Vector2(0,-192);_print_clip.modulate.a=1.0;_print_clip.show();_slot.show()
	_flash.modulate.a=0.22
	_animation=create_tween().set_parallel(true)
	_animation.tween_property(_flash,"modulate:a",0.0,0.18)
	_animation.tween_property(_print_paper,"position:y",20.0,1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_print_paper,"reveal",1.0,1.1).set_delay(0.3)
	await _animation.finished
	await get_tree().create_timer(0.30).timeout
	if not is_inside_tree():return
	_animation=create_tween();_animation.tween_property(_print_clip,"modulate:a",0.0,0.20);await _animation.finished
	_print_clip.hide();_slot.hide()
func _status(message:String)->void:
	_status_serial+=1;status_label.text=message
	if message.is_empty():return
	var serial:=_status_serial
	await get_tree().create_timer(3.2).timeout
	if is_inside_tree() and serial==_status_serial:status_label.text=""
func request_close()->void:
	# Host Escape follows the same nested review/back path as local Escape.
	if gallery_only:_request_close()
	elif is_instance_valid(_review) and _review.visible:_leave_review()
	else:_request_close()
func _request_close()->void:
	if _closing:return
	if _album_busy:_close_after_album=true;return
	if not _save_caption():return
	_closing=true
	if _animation and _animation.is_valid():_animation.kill()
	cue.emit("paper")
	closed.emit()
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		request_close()
	elif event.keycode==KEY_C or event.physical_keycode==KEY_C:
		if gallery_only or get_viewport().gui_get_focus_owner()==_caption_editor:return
		get_viewport().set_input_as_handled();take_photo()
