extends Control
## Local in-game camera. The host supplies a HUD-free viewport Image.
signal closed
signal photo_saved(path:String)
signal caption_saved(path:String,text:String)
signal album_saved(path:String)
signal actor_visibility_changed(visible:bool)
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
var pan_provider:Callable
var zoom_provider:Callable
var interaction_sensitivity:float=1.0
var reset_provider:Callable
var _dragging:=false
var _held_pan:Dictionary={}
var _composition_buttons:Array[Button]=[]
var capture_busy:=false
var _capture_pending_save:=false
var _close_after_capture:=false
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
var _thumbnail_index:=-1
# Browsing may stop on an unreadable file; captions still belong to the last
# successfully decoded print, never to this independent navigation cursor.
var _review_cursor:=-1
var _print_paper:PhotoPaper
var _print_clip:Control
var _slot:Control
var _flash:ColorRect
var _closing:=false
var _animation:Tween
var _status_timer:Timer
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
var instant_format:=false
var _format_button:Button
var lab:RefCounted
var _favorite:Button
var _actor_button:Button
var include_actor:=true

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
		var square:=image!=null and image.get_width()<=image.get_height()*1.1
		var window:=Rect2(Vector2(size.x*.05,size.x*.05),Vector2(size.x*.9,size.x*.9*(1.0 if square else 9.0/16.0)))
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
	if not gallery_only:lab=preload("res://scripts/ui/camera_lab.gd").new(self)
	if pan_provider.is_valid() and not gallery_only:
		var surface:=Control.new();surface.name="CameraPanSurface"
		surface.mouse_default_cursor_shape=Control.CURSOR_DRAG
		_place(surface,canvas,Rect2(Vector2.ZERO,DESIGN));surface.gui_input.connect(_pan_surface_input)
		get_window().focus_exited.connect(_stop_pan)
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
	var heading:=_label(_t("相机","Camera"),Rect2(80,60,180,46),28)
	heading.name="CameraHeading"
	_format_button=_button(_t("横向照片  ⇄  R","Landscape  ⇄  R"),Rect2(540,60,520,50),24)
	_format_button.name="PhotoFormat";_format_button.tooltip_text=_t("切换相纸 · R","Switch format · R");_format_button.pressed.connect(_toggle_format)
	count_label=_label("",Rect2(1170,60,240,46),24,HORIZONTAL_ALIGNMENT_RIGHT)
	_label(location_caption,Rect2(250,796,360,42),22)
	shutter=ArtButton.new();shutter.name="CameraShutter";shutter.round_hit=true
	if texture:
		var button_atlas:=AtlasTexture.new();button_atlas.atlas=texture;button_atlas.region=Rect2(744,754,182,182);button_atlas.filter_clip=true;shutter.art=button_atlas
	_place(shutter,canvas,Rect2(748,724,104,104));shutter.tooltip_text=_t("拍照 · C","Take photo · C");shutter.pressed.connect(take_photo)
	_label("C",Rect2(755,831,90,26),18,HORIZONTAL_ALIGNMENT_CENTER)
	thumbnail=ArtButton.new();thumbnail.name="LastPhoto";thumbnail.tooltip_text=_t("查看照片","View photos");_place(thumbnail,canvas,Rect2(82,748,120,84));thumbnail.pressed.connect(func():_show_review(_thumbnail_index))
	status_label=_label("",Rect2(1020,798,410,42),21);status_label.hide()
	if pan_provider.is_valid() and not gallery_only:
		_label(_t("拖动取景 · 方向键微调","Drag to frame · Arrow keys"),Rect2(1080,680,380,36),19,HORIZONTAL_ALIGNMENT_CENTER)
		for spec:Array in [["ZoomOut","−",1100.0],["ResetComposition",_t("复位","Reset"),1190.0],["ZoomIn","+",1340.0]]:
			var control:=_button(str(spec[1]),Rect2(float(spec[2]),725,140 if spec[0]=="ResetComposition" else 70,48),25)
			control.name=str(spec[0]);_composition_buttons.append(control)
			if spec[0]=="ResetComposition":control.pressed.connect(func():if _can_pan() and reset_provider.is_valid():reset_provider.call())
			else:control.pressed.connect(func():
				if _can_pan() and zoom_provider.is_valid():
					zoom_provider.call((-0.1 if spec[0]=="ZoomOut" else 0.1)*interaction_sensitivity);cue.emit("paper"))
	_print_clip=Control.new();_print_clip.name="PhotoEjection";_print_clip.clip_contents=true;_print_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_print_clip,canvas,Rect2(660,646,280,244));_print_clip.hide()
	_print_paper=PhotoPaper.new();_print_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_print_paper,_print_clip,Rect2(0,-192,280,192))
	_slot=PrintSlot.new();_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_slot,canvas,Rect2(648,636,304,20));_slot.hide()
	_flash=ColorRect.new();_flash.name="ShutterFlash";_flash.color=Color("fff7df");_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_flash,canvas,Rect2(Vector2.ZERO,DESIGN));_flash.modulate.a=0.0
	for node:Node in canvas.get_children():
		if node is CanvasItem:_live_nodes.append(node)
	if lab!=null:
		lab.build(canvas)
		_actor_button=_button(_t("人物：显示","Character: on"),Rect2(420,128,300,48),24)
		_actor_button.name="CameraActor"
		_actor_button.pressed.connect(func():
			include_actor=not include_actor
			_actor_button.text=_t("人物：显示","Character: on") if include_actor else _t("人物：隐藏","Character: off")
			actor_visibility_changed.emit(include_actor))
	var close:=_button("×",Rect2(1470,48,66,60),36);close.name="CloseCamera";close.tooltip_text=_t("关闭相机","Close camera");close.pressed.connect(_request_close)
	_build_review();_refresh_count();_refresh_thumbnail()
	_favorite=_button(_t("收藏","Favorite"),Rect2(650,22,300,48),24)
	_favorite.name="FavoritePhoto";_favorite.reparent(_review)
	_favorite.pressed.connect(_toggle_favorite)
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
func _toggle_format()->void:
	if capture_busy or _album_busy or _review.visible:return
	instant_format=not instant_format
	_format_button.text=_t("竖版拍立得  ⇄  R","Instant print  ⇄  R") if instant_format else _t("横向照片  ⇄  R","Landscape  ⇄  R")
	if _frame:
		_frame.position=Vector2(374,24) if instant_format else Vector2(24,24)
		_frame.size=Vector2(852,852) if instant_format else Vector2(1552,852)
	cue.emit("paper")

func _fit_review_print()->void:
	var square:=_review_paper.image.get_width()<=_review_paper.image.get_height()*1.1
	_review_paper.position=Vector2(560,60) if square else Vector2(348,100)
	_review_paper.size=Vector2(480,650) if square else Vector2(904,620)
	_caption_editor.position=Vector2(28,490) if square else Vector2(50,518)
	_caption_editor.size=Vector2(424,132) if square else Vector2(804,78)
	_review_paper.queue_redraw()
func _control_skin(fill:Color,edge:Color=Color("c5b69b"))->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.set_corner_radius_all(14)
	style.set_border_width_all(1);style.border_color=edge
	style.shadow_color=Color(.18,.20,.17,.18);style.shadow_size=3;style.shadow_offset=Vector2(0,3)
	style.content_margin_left=14;style.content_margin_right=14
	return style
func _label(text:String,rect:Rect2,font_size:int,align:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT)->Label:
	var label:=Label.new();label.text=text;label.horizontal_alignment=align;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("514c40"))
	label.add_theme_stylebox_override("normal",_control_skin(Color("f5ecd9")))
	_place(label,canvas,rect);return label
func _button(text:String,rect:Rect2,font_size:int)->Button:
	var button:=Button.new();button.text=text;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",FONT);button.add_theme_font_size_override("font_size",font_size)
	for state:String in ["normal","hover","pressed","disabled"]:
		var fill:=Color("f5ecd9")
		if state=="hover":fill=Color("dfebd9")
		elif state=="pressed":fill=Color("bdcfb9")
		elif state=="disabled":fill=Color("ded8c9")
		button.add_theme_stylebox_override(state,_control_skin(fill))
		button.add_theme_color_override("font_"+state+"_color",Color("514c40") if state!="disabled" else Color("918b7b"))
	var focus:=_control_skin(Color(0,0,0,0),Color("54786f"));focus.set_border_width_all(3);focus.shadow_size=0
	button.add_theme_stylebox_override("focus",focus);button.add_theme_color_override("font_color",Color("514c40"));button.add_theme_color_override("font_focus_color",Color("354d46"))
	_place(button,canvas,rect);return button
func _build_review()->void:
	_review=Control.new();_review.name="PhotoReview";_review.mouse_filter=Control.MOUSE_FILTER_STOP;_place(_review,canvas,Rect2(Vector2.ZERO,DESIGN));_review.hide()
	var shade:=ColorRect.new();shade.color=Color(0.08,0.12,0.10,0.72);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(shade,_review,Rect2(Vector2.ZERO,DESIGN))
	_review_paper=PhotoPaper.new();_review_paper.name="DevelopedPhoto";_review_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(_review_paper,_review,Rect2(348,100,904,620))
	_caption_editor=TextEdit.new();_caption_editor.name="PhotoCaption";_caption_editor.placeholder_text=_t("在这里写点什么…","Write a little note…");_caption_editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	_caption_editor.add_theme_font_override("font",FONT);_caption_editor.add_theme_font_size_override("font_size",25)
	for state:String in ["normal","focus","read_only"]:_caption_editor.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_caption_editor.add_theme_color_override("font_color",Color("665240"));_caption_editor.add_theme_color_override("font_placeholder_color",Color(0.4,0.32,0.25,0.42));_caption_editor.add_theme_color_override("caret_color",Color("665240"));_caption_editor.add_theme_color_override("selection_color",Color(0.66,0.58,0.44,0.24))
	_place(_caption_editor,_review_paper,Rect2(50,518,804,78))
	_caption_editor.text_changed.connect(func():_caption_dirty=true;_caption_timer.start())
	_caption_editor.focus_exited.connect(_save_caption)
	_caption_timer=Timer.new();_caption_timer.one_shot=true;_caption_timer.wait_time=.45;add_child(_caption_timer);_caption_timer.timeout.connect(_save_caption)
	_caption_notice=_label("",Rect2(420,730,760,32),21,HORIZONTAL_ALIGNMENT_CENTER);_caption_notice.reparent(_review)
	for item:Array in [["PreviousPhoto","‹",Rect2(228,340,90,100),-1],["NextPhoto","›",Rect2(1282,340,90,100),1]]:
		var button:=_button(item[1],item[2],54);button.reparent(_review);button.name=item[0];button.pressed.connect(func():_step_review(int(item[3])))
	_album_button=_button(_t("导出照片","Export photo"),Rect2(382,774,390,64),28);_album_button.reparent(_review);_album_button.name="SaveToAlbum";_album_button.disabled=true;_album_button.pressed.connect(export_current_photo)
	_album_open=_button(_t("打开文件夹","Open folder"),Rect2(1176,730,240,36),21);_album_open.reparent(_review);_album_open.name="OpenAlbum";_album_open.hide()
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
func checkpoint_for_quit()->bool:return not _album_busy and not _capture_pending_save and _save_caption()
func wait_for_pending_save()->void:
	while _album_busy or _capture_pending_save:await pending_save_finished

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
	_update_review_controls()
	var viewport:=SubViewport.new();viewport.disable_3d=true;viewport.transparent_bg=true
	viewport.size=Vector2i(_review_paper.size*2.0);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var print_canvas:=Control.new();viewport.add_child(print_canvas)
	var paper:=PhotoPaper.new();paper.image=_review_paper.image;paper.size=_review_paper.size*2.0;print_canvas.add_child(paper)
	var note:=Label.new();note.text=_caption_original;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Rasterize at output resolution instead of scaling cached 25px glyphs.
	note.add_theme_font_override("font",FONT);note.add_theme_font_size_override("font_size",50);note.add_theme_color_override("font_color",Color("665240"))
	note.position=_caption_editor.position*2.0;note.size=_caption_editor.size*2.0;paper.add_child(note)
	await get_tree().process_frame
	# Long notes get more paper below the full-width photograph, rather than
	# being silently clipped to the editor's scrollable visible area.
	var print_height:=maxf(paper.size.y,note.position.y+note.get_minimum_size().y+48.0)
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
	_update_review_controls()
	_caption_notice.text=message;_album_button.grab_focus()
	_album_open.visible=not result.is_empty()
	if not result.is_empty():album_saved.emit(result);cue.emit("paper")
	pending_save_finished.emit()
	if _close_after_album:_close_after_album=false;_request_close()
	return result

func _refresh_count()->void:
	count_label.text=_t("照片 ","Photos ")+str(gallery_paths.size())
func _refresh_thumbnail()->void:
	_thumbnail_index=gallery_paths.size()-1
	thumbnail.disabled=gallery_paths.is_empty()
	if gallery_paths.is_empty():thumbnail.hide();return
	# A damaged newest capture must not hide access to earlier good prints.
	# The clickable miniature and its target always refer to the same image.
	var pixels:Image
	for index:int in range(gallery_paths.size()-1,-1,-1):
		var candidate:=Image.new()
		if candidate.load(gallery_paths[index])==OK and not candidate.is_empty():
			pixels=candidate;_thumbnail_index=index;break
	thumbnail.show()
	var paper:=thumbnail.get_node_or_null("ThumbnailPrint") as PhotoPaper
	if paper==null:paper=PhotoPaper.new();paper.name="ThumbnailPrint";paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(paper,thumbnail,Rect2(4,0,112,77))
	if pixels==null:
		# Keep a neutral paper entry and the error/recovery controls reachable.
		paper.image=null;paper.position=Vector2(4,0);paper.size=Vector2(112,77);paper.queue_redraw()
		thumbnail.tooltip_text=_t("照片暂时无法打开 · 查看照片","Photos unavailable · View photos")
		return
	thumbnail.tooltip_text=_t("查看照片","View photos")
	# The thumbnail occupies roughly 100 screen pixels. Keep the original PNG
	# and full-size review intact without allocating a full capture on the GPU here.
	var preview_scale:=minf(1.0,256.0/maxi(pixels.get_width(),pixels.get_height()))
	if preview_scale<1.0:pixels.resize(maxi(1,roundi(pixels.get_width()*preview_scale)),maxi(1,roundi(pixels.get_height()*preview_scale)),Image.INTERPOLATE_LANCZOS)
	paper.image=ImageTexture.create_from_image(pixels);paper.queue_redraw()
	if pixels.get_width()<=pixels.get_height()*1.1:paper.position=Vector2(32,0);paper.size=Vector2(56,77)
	else:paper.position=Vector2(4,0);paper.size=Vector2(112,77)
func _show_review(index:int)->void:
	if capture_busy or _album_busy or gallery_paths.is_empty():return
	if not _save_caption():return
	var was_visible:bool=_review.visible
	var next_index:int=wrapi(index,0,gallery_paths.size())
	_review_cursor=next_index
	# A one-photo wrap or selecting the current print has no page turn.
	if was_visible and next_index==_review_index:
		_caption_notice.text="";_update_review_controls();return
	var pixels:=Image.load_from_file(gallery_paths[next_index])
	if pixels==null or pixels.is_empty():
		var message:=_t("照片无法打开，请试试另一张","Photo unavailable. Try another print.")
		if _review_index<0:
			_caption_editor.hide();_review_paper.hide()
		# Files may disappear after the miniature loaded. Always expose previous,
		# next and back so a failed first selection cannot trap gallery access.
		_set_review_active(true)
		_caption_notice.text=message
		return
	# Commit photo identity only after decoding succeeds. Otherwise later edits
	# to the still-visible print would be saved beside the unreadable photo.
	_review_index=next_index
	_caption_original=caption_for(gallery_paths[_review_index]);_caption_editor.set_block_signals(true);_caption_editor.text=_caption_original;_caption_editor.set_block_signals(false);_caption_dirty=false;_caption_notice.text=""
	_caption_editor.show();_review_paper.show()
	_review_paper.image=ImageTexture.create_from_image(pixels);_review_paper.reveal=1.0;_set_review_active(true)
	_fit_review_print()
	_update_review_controls();_album_open.hide();_refresh_favorite()
	cue.emit("flip" if was_visible else "paper")
func _step_review(direction:int)->void:
	if _closing or _album_busy or capture_busy or gallery_paths.size()<2:return
	_show_review(_review_cursor+direction)
func _update_review_controls()->void:
	for control_name:String in ["PreviousPhoto","NextPhoto"]:
		_review.get_node(control_name).disabled=_album_busy or gallery_paths.size()<2
	_review.get_node("BackToCamera").disabled=_album_busy
	_album_button.disabled=_album_busy or _review_index<0 or _review_index>=gallery_paths.size()
func _set_review_active(active:bool)->void:
	_stop_pan()
	if lab!=null:lab.set_review(active)
	for button:Button in _composition_buttons:button.focus_mode=Control.FOCUS_NONE if active else Control.FOCUS_ALL
	var was_active:=_review.visible
	_review.visible=active
	_update_review_controls()
	# These buttons remain drawn underneath the paper, but must not take Tab
	# focus or keyboard activation through the nested review surface.
	shutter.focus_mode=Control.FOCUS_NONE if active else Control.FOCUS_ALL
	thumbnail.focus_mode=Control.FOCUS_NONE if active else Control.FOCUS_ALL
	_format_button.focus_mode=Control.FOCUS_NONE if active else Control.FOCUS_ALL
	if is_instance_valid(_actor_button):_actor_button.visible=not active
	if active and not was_active:_review.get_node("BackToCamera").grab_focus()
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
	capture_busy=true;_capture_pending_save=true;shutter.disabled=true
	_stop_pan()
	# Sound follows the accepted shutter, not disk-write completion.
	cue.emit("camera")
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
	var original:Image=pixels.duplicate()
	if lab!=null:pixels=await lab.render(pixels)
	if instant_format:
		var side:=mini(pixels.get_width(),roundi(pixels.get_height()*852.0/900.0))
		pixels=pixels.get_region(Rect2i((pixels.get_width()-side)/2,(pixels.get_height()-side)/2,side,side))
	var directory_error:=DirAccess.make_dir_recursive_absolute(save_directory)
	if directory_error!=OK:_capture_failed(_t("照片没能保存，请重试","Could not save photo. Try again."));return
	var stamp:=Time.get_datetime_string_from_system().replace(":","").replace("-","").replace("T","_")
	var stem:="DearSomewhere_"+stamp+"_"+str(Time.get_ticks_msec())
	var path:=save_directory.path_join(stem+".png")
	var suffix:=0
	while FileAccess.file_exists(path):suffix+=1;path=save_directory.path_join(stem+"_"+str(suffix)+".png")
	if pixels.save_png(path)!=OK:_capture_failed(_t("照片没能保存，请重试","Could not save photo. Try again."));return
	var original_dir:=save_directory.path_join("originals")
	var original_path:=original_dir.path_join(stem+".png")
	var original_saved:bool=DirAccess.make_dir_recursive_absolute(original_dir)==OK and original.save_png(original_path)==OK
	var metadata:=FileAccess.open(path+".json",FileAccess.WRITE)
	if metadata!=null:
		metadata.store_string(JSON.stringify({"version":2,"caption":"","favorite":false,"location":location_caption,"original":original_path if original_saved else "","camera":lab.metadata() if lab!=null else {}}))

	last_photo_path=path;gallery_paths.append(path);_refresh_count();_refresh_thumbnail();photo_saved.emit(path)
	_finish_capture_save()
	if _closing or not is_inside_tree():return
	capture_busy=false;shutter.disabled=false
	_status(_t("已保存","Saved") if original_saved else _t("照片已保存；原片备份失败","Photo saved; original backup failed"))
	_develop(ImageTexture.create_from_image(pixels))

func _capture_failed(message:String)->void:
	capture_busy=false;shutter.disabled=false;shutter.grab_focus();_status(message)
	_finish_capture_save()
func _finish_capture_save()->void:
	# An accepted shutter needs two rendered frames before its raw PNG exists.
	# Back/quit waits for those frames, not for the decorative print animation.
	_capture_pending_save=false;pending_save_finished.emit()
	if _close_after_capture:
		_close_after_capture=false;capture_busy=false;_request_close()
func _develop(texture:Texture2D)->void:
	if _animation and _animation.is_valid():_animation.kill()
	var square:=texture.get_width()<=texture.get_height()*1.1
	_print_clip.position=Vector2(660,646);_print_clip.size=Vector2(280,244)
	_print_clip.modulate.a=1.0;_print_clip.show();_slot.show()
	_print_paper.size=Vector2(140,192) if square else Vector2(280,192)
	_print_paper.position=Vector2(70 if square else 0,-192)
	_print_paper.image=texture;_print_paper.reveal=0.0
	_flash.modulate.a=0.22
	# Preserve the original slot, paper size and developing rhythm in both formats.
	# A single owned tween can be replaced by the next shot or cancelled on close.
	_animation=create_tween().set_parallel(true)
	_animation.tween_property(_flash,"modulate:a",0.0,0.18)
	_animation.tween_property(_print_paper,"position:y",20.0,1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_print_paper,"reveal",1.0,1.1).set_delay(0.3)
	_animation.chain().tween_interval(0.30)
	_animation.chain().tween_property(_print_clip,"modulate:a",0.0,0.20)
	_animation.chain().tween_callback(func():_print_clip.hide();_slot.hide())

static func photo_metadata(path:String)->Dictionary:
	if not FileAccess.file_exists(path+".json"):return {}
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	return data if data is Dictionary else {}

func _refresh_favorite()->void:
	if not is_instance_valid(_favorite) or _review_index<0:return
	_favorite.text=_t("已收藏","Favorited") if photo_metadata(gallery_paths[_review_index]).get("favorite",false) else _t("收藏","Favorite")

func _toggle_favorite()->void:
	if _album_busy or _review_index<0 or not _save_caption():return
	var path:String=gallery_paths[_review_index]
	var data:=photo_metadata(path)
	data.favorite=not bool(data.get("favorite",false))
	var temp:=path+".favorite.tmp"
	var file:=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:_caption_notice.text=_t("未保存，请重试","Not saved. Retry.");return
	file.store_string(JSON.stringify(data));file.flush();var error:=file.get_error();file.close()
	if error!=OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path+".json"))!=OK:
		_caption_notice.text=_t("未保存，请重试","Not saved. Retry.");return
	_refresh_favorite();cue.emit("paper")

func _status(message:String)->void:
	status_label.text=message;status_label.visible=not message.is_empty()
	if _status_timer==null:
		_status_timer=Timer.new();_status_timer.one_shot=true;_status_timer.wait_time=3.2;add_child(_status_timer)
		_status_timer.timeout.connect(func():status_label.text="";status_label.hide())
	_status_timer.stop()
	if not message.is_empty():_status_timer.start()
func request_close()->void:
	# Host Escape follows the same nested review/back path as local Escape.
	if gallery_only:_request_close()
	elif is_instance_valid(_review) and _review.visible:_leave_review()
	else:_request_close()
func _request_close()->void:
	_stop_pan()
	if _closing:return
	if _capture_pending_save:_close_after_capture=true;return
	if _album_busy:_close_after_album=true;return
	if not _save_caption():return
	_closing=true
	if _animation and _animation.is_valid():_animation.kill()
	cue.emit("paper")
	closed.emit()
func _input(event:InputEvent)->void:
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:_dragging=false
	if event is InputEventKey:
		var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_W,KEY_A,KEY_S,KEY_D]:
			if not event.pressed:_held_pan.erase(code)
			if _can_pan() and not _editing_controls() and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
				if event.pressed:_held_pan[code]=true
				get_viewport().set_input_as_handled();return
	if _dragging and _can_pan() and event is InputEventMouseMotion:
			pan_provider.call(event.relative/get_global_transform().get_scale()*interaction_sensitivity)
			get_viewport().set_input_as_handled();return
	# Photo notes use Tab for navigation, not indentation. Handle it before
	# TextEdit inserts a tab so keyboard users can reach the save/back controls.
	if not is_visible_in_tree() or _closing or not _review.visible:return
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode!=KEY_TAB and event.physical_keycode!=KEY_TAB:return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
	if get_viewport().gui_get_focus_owner()!=_caption_editor:return
	get_viewport().set_input_as_handled()
	var next:Control=_caption_editor.find_prev_valid_focus() if event.shift_pressed else _caption_editor.find_next_valid_focus()
	if next!=null:next.grab_focus()
func _editing_controls()->bool:
	var focus:=get_viewport().gui_get_focus_owner()
	return focus is Range or focus is OptionButton or focus is LineEdit or focus is TextEdit or (lab!=null and focus!=null and lab.panel.is_ancestor_of(focus))
func _can_pan()->bool:
	return pan_provider.is_valid() and is_visible_in_tree() and not gallery_only and not _closing and not capture_busy and not _album_busy and is_instance_valid(_review) and not _review.visible
func _stop_pan()->void:
	_dragging=false;_held_pan.clear()
func _pan_surface_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and lab!=null and not capture_busy and not _review.visible:
		var point:=get_global_mouse_position()/get_viewport_rect().size
		lab.focus_at(point)
		if _focus_marks:_focus_marks.position=point*DESIGN-_focus_marks.size*.5
		accept_event();return
	if not _can_pan() or not event is InputEventMouseButton:return
	if event.button_index==MOUSE_BUTTON_LEFT:
		_dragging=event.pressed;accept_event()
	elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if zoom_provider.is_valid():zoom_provider.call((.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -.1)*interaction_sensitivity);cue.emit("paper")
		accept_event()
func _process(delta:float)->void:
	if not _can_pan():_stop_pan();return
	var direction:=Vector2(float(_held_pan.has(KEY_RIGHT) or _held_pan.has(KEY_D))-float(_held_pan.has(KEY_LEFT) or _held_pan.has(KEY_A)),float(_held_pan.has(KEY_DOWN) or _held_pan.has(KEY_S))-float(_held_pan.has(KEY_UP) or _held_pan.has(KEY_W)))
	if direction!=Vector2.ZERO:pan_provider.call(-direction.normalized()*300.0*delta*interaction_sensitivity)
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
	if event.keycode==KEY_R and get_viewport().gui_get_focus_owner()!=_caption_editor:
		_toggle_format();get_viewport().set_input_as_handled();return
	if event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		request_close()
	elif event.keycode==KEY_C or event.physical_keycode==KEY_C:
		if gallery_only or get_viewport().gui_get_focus_owner()==_caption_editor:return
		get_viewport().set_input_as_handled();take_photo()
