extends SceneTree
## Automated actual Host/root.push_input layout and GPU proof. This is not native
## desktop input, listening, novice comprehension or final aesthetic acceptance.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const OUT="res://test-results/coastal-layout_20261017/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
var measurements:Array[Dictionary]=[]
var foreground_images:Dictionary={}
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for dimensions:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions
		game=Host.new();game.allow_display_changes=false
		game.preferences_path="user://qa/coastal-layout/"+str(Time.get_ticks_usec())+".json"
		root.add_child(game);game.size=Vector2(1600,900);await process_frame;await process_frame
		for language:String in ["zh","en"]:
			await _open()
			if language=="en":await _choose_language(1)
			_check(game.preferences.values.language==language,"actual requested UI language "+language)
			await process_frame;await process_frame
			_check_page(language,dimensions)
			await _shot(language+"_"+str(dimensions.x),dimensions)
			for key:String in ["language","display_mode","resolution","text_speed"]:
				await _click_named("Setting_"+key)
				await process_frame
				_check_dropdown(key,language,dimensions)
				if dimensions.x==1920:await _shot(language+"_dropdown_"+key+"_1920",dimensions)
				# The overlay must not intercept the reserved return target. One
				# ordinary click closes the current mode, with no preliminary click.
				await _click_named("CloseSettings")
				_check(not is_instance_valid(game.modal),"one return click works over "+key+" dropdown "+language+" "+str(dimensions.x))
				_check(game.find_child("OpenSettings",true,false)!=null,"dropdown return reaches the actual title")
				await _open()
			await _click_named("Setting_language")
			await _key(KEY_ESCAPE)
			_check(is_instance_valid(game.modal) and game.modal.find_child("SettingsDropdown",true,false)==null,"first Esc dismisses only nested selector "+language+" "+str(dimensions.x))
			await _key(KEY_ESCAPE)
			_check(not is_instance_valid(game.modal),"second Esc safely returns from Settings "+language+" "+str(dimensions.x))
		game.queue_free();await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var report:=FileAccess.open(OUT+"result.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":images,"measurements":measurements,
		"scope":"Actual Host/root.push_input zh/en at 1280x720, 1920x1080 and 2560x1440. Active glyph metrics, original paper sampling, physical return/selector/row rectangles, all four dropdowns, one-click return and nested Esc. Automated GPU; not native OS input or user acceptance."},"\t"));report.close()
	print("COASTAL LAYOUT INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _check_page(language:String,dimensions:Vector2i)->void:
	var page:Control=game.modal
	var scene:=page.get_global_rect()
	var back:Button=page.get_node("CloseSettings")
	var back_rect:=back.get_global_rect()
	_check(back.text=="←","return uses the matching arrow instead of a square cross")
	_check(back.flat and back.get_theme_stylebox("focus") is StyleBoxEmpty,"return has no boxed system focus decoration")
	_check(_contains(scene,back_rect),"return stays within the scene")
	_check(back_rect.position.y>=112.0 and back_rect.end.y<=165.0,"actual return hit target stays inside reserved header strip")
	for key:String in page.controls:
		var control:Control=page.controls[key]
		var caption:Label=page.find_child("SettingLabel_"+key,true,false)
		_check(caption!=null,"real caption exists "+key)
		if caption==null:continue
		var caption_rect:=caption.get_global_rect();var control_rect:=control.get_global_rect()
		var caption_font:Font=caption.get_theme_font("font")
		var caption_glyph:Vector2=caption_font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size"))
		var caption_writing:=_glyph_rect(caption,caption_glyph)
		_check(not caption_rect.intersects(control_rect),"caption and physical control do not overlap "+key)
		_check(caption_writing.end.x+10.0<=control_rect.position.x,"actual caption writing has a readable gap before selector or slider "+key)
		_check(not back_rect.intersects(control_rect),"return hit target cannot overlap "+key)
		_check(_contains(scene,control_rect),"actual control stays in the scene "+key)
		if language=="zh":
			_check(absf(caption_rect.position.x-580.0)<0.1 and absf(caption_rect.end.x-801.0)<0.1,"Chinese caption shares the common physical column "+key)
			_check(caption.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"Chinese caption centers in its adapted column "+key)
			_check(caption.get_theme_font_size("font_size")>=30,"Chinese caption remains legible without tiny translated copy "+key)
		if control is Button:_check_button_text(control,"selector "+key)
	for label:Label in _labels(page):
		if label.text.is_empty():continue
		var font:Font=label.get_theme_font("font");var size:int=label.get_theme_font_size("font_size")
		var glyph:Vector2=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
		var outline:int=label.get_theme_constant("outline_size")
		var rectangle:=label.get_global_rect()
		_check(glyph.x+outline*2.0<=rectangle.size.x+0.5,"active glyph width fits its real label "+label.name)
		_check(glyph.y<=rectangle.size.y+0.5,"active font line height fits its real label "+label.name)
		var painted:=_glyph_rect(label,glyph)
		_check(_contains(scene,painted),"label writing stays inside the scene "+label.name)
		if label.name!="SettingsHeading":
			_check(_on_stationery(painted),"writing remains inside the original menu paper "+label.name)
			# The large headline deliberately layers over its header tape in the
			# supplied composition. Ordinary menu writing must avoid illustrations;
			# measure its actual glyph line, not the empty surrounding label box.
			for key:String in ["settings_postcards","settings_tape"]:
				_check(not _overlaps_foreground(painted,key),"actual writing avoids original "+key+" "+label.name)
		measurements.append({"language":language,"width":dimensions.x,"item":str(label.name),"text":label.text,"font_size":size,
			"control":_rect_record(rectangle),"glyph":_rect_record(painted)})
	if language=="zh":
		_check(page.get_node("SettingsHeading").get_theme_font_size("font_size")==72,"Chinese headline has its own adapted size")
		for key:String in ["language","display_mode","resolution","text_speed"]:
			_check(page.controls[key].get_theme_font_size("font_size")==21,"Chinese selector has its own readable size "+key)
func _check_dropdown(key:String,language:String,dimensions:Vector2i)->void:
	var box:Panel=game.modal.find_child("SettingsOptionsPanel",true,false)
	_check(box!=null,"actual "+key+" dropdown opens")
	if box==null:return
	var back:Control=game.modal.get_node("CloseSettings")
	var back_rect:=back.get_global_rect();var box_rect:=box.get_global_rect()
	_check(not box_rect.intersects(back_rect),"physical dropdown panel does not cover return "+key)
	_check(_contains(game.modal.get_global_rect(),box_rect),"physical dropdown panel remains within the scene "+key)
	var rows:Array[Button]=[]
	for child:Node in box.get_children():
		if child is Button:rows.append(child)
	_check(rows.size()>=2,"selector exposes its real choices "+key)
	for row:Button in rows:
		var row_rect:=row.get_global_rect()
		_check(not row_rect.intersects(back_rect),"actual row hit target avoids return "+row.name)
		_check(_contains(box_rect,row_rect),"actual row stays inside its rounded panel "+row.name)
		_check_button_text(row,"dropdown "+row.name)
		for other:Button in rows:
			if other==row:continue
			_check(not row_rect.intersects(other.get_global_rect()),"actual row targets do not overlap "+row.name+" / "+other.name)
		for state:String in ["normal","hover","pressed","focus"]:
			var style:StyleBox=row.get_theme_stylebox(state)
			_check(style is StyleBoxFlat and style.corner_radius_top_left>=8 and style.corner_radius_bottom_right>=8,"rounded row state "+row.name+" "+state)
		measurements.append({"language":language,"width":dimensions.x,"item":str(row.name),"control":_rect_record(row_rect),"return":_rect_record(back_rect)})
func _check_button_text(button:Button,label:String)->void:
	var font:Font=button.get_theme_font("font");var size:int=button.get_theme_font_size("font_size")
	var glyph:Vector2=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
	var style:StyleBox=button.get_theme_stylebox("normal")
	var available:=button.size-Vector2(style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT),style.get_content_margin(SIDE_TOP)+style.get_content_margin(SIDE_BOTTOM))
	_check(glyph.x<=available.x+0.5,"active button writing leaves its reserved arrow/padding "+label)
	_check(glyph.y<=available.y+0.5,"active button writing fits the available height "+label)
func _glyph_rect(label:Label,glyph:Vector2)->Rect2:
	var rectangle:=label.get_global_rect();var origin:=rectangle.position
	if label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER:origin.x+=(rectangle.size.x-glyph.x)*0.5
	elif label.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT:origin.x+=rectangle.size.x-glyph.x
	if label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER:origin.y+=(rectangle.size.y-glyph.y)*0.5
	elif label.vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM:origin.y+=rectangle.size.y-glyph.y
	return Rect2(origin,glyph)
func _on_stationery(rectangle:Rect2)->bool:
	var paper:TextureRect=game.modal.get_node("PDF_settings_stationery")
	var pixels:Image=paper.texture.get_image()
	var points:Array[Vector2]=[rectangle.position+Vector2(0.5,0.5),Vector2(rectangle.end.x-0.5,rectangle.position.y+0.5),rectangle.end-Vector2(0.5,0.5),Vector2(rectangle.position.x+0.5,rectangle.end.y-0.5),rectangle.get_center()]
	for point:Vector2 in points:
		var local:Vector2=point-paper.global_position
		var uv:=local/paper.size
		if uv.x<0.0 or uv.y<0.0 or uv.x>=1.0 or uv.y>=1.0:return false
		var pixel:Color=pixels.get_pixelv(Vector2i(uv*Vector2(pixels.get_size())))
		if minf(pixel.r,minf(pixel.g,pixel.b))>=0.975:return false
	return true
func _labels(parent:Node)->Array[Label]:
	var result:Array[Label]=[]
	for child:Node in parent.get_children():
		if child is Label:result.append(child)
		if child is SubViewport:continue
		result.append_array(_labels(child))
	return result
func _overlaps_foreground(rectangle:Rect2,key:String)->bool:
	if not foreground_images.has(key):foreground_images[key]=Art.texture(key).get_image()
	var pixels:Image=foreground_images[key]
	var scale:=Vector2(pixels.get_size())/Vector2(1600,900)
	var from:=Vector2i((rectangle.position*scale).floor()).clamp(Vector2i.ZERO,pixels.get_size()-Vector2i.ONE)
	var to:=Vector2i((rectangle.end*scale).ceil()).clamp(Vector2i.ZERO,pixels.get_size())
	for y:int in range(from.y,to.y):
		for x:int in range(from.x,to.x):
			var color:=pixels.get_pixel(x,y)
			if minf(color.r,minf(color.g,color.b))<0.975:return true
	return false
func _contains(outer:Rect2,inner:Rect2)->bool:
	return inner.position.x>=outer.position.x-0.1 and inner.position.y>=outer.position.y-0.1 and inner.end.x<=outer.end.x+0.1 and inner.end.y<=outer.end.y+0.1
func _rect_record(rectangle:Rect2)->Array:return [rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y]
func _open()->void:
	await _click_named("OpenSettings");await process_frame;await process_frame
	_check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),"actual title opens Settings")
func _choose_language(index:int)->void:
	await _click_named("Setting_language");await _click_named("Option_language_"+str(index));await process_frame;await process_frame
func _click_named(name:String)->void:
	var control:Control=game.find_child(name,true,false)
	_check(control!=null,"visible control "+name)
	if control==null:return
	var point:=control.get_global_rect().get_center();await _button(point,true);await _button(point,false)
func _button(point:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;root.push_input(event,true);await process_frame
func _key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true);await process_frame
func _shot(label:String,expected:Vector2i)->void:
	await process_frame;RenderingServer.force_draw(false)
	var image:Image=root.get_texture().get_image();_check(image.get_size()==expected,"original-resolution screenshot "+label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path:=OUT+label+".png";_check(image.save_png(path)==OK,"actual screenshot "+label);images.append(path)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
