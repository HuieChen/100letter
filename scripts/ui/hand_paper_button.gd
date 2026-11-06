extends Button
## Original transparent icons and native hand-inked paper labels.
const FONT=preload("res://assets/fonts/DearRounded.tres")
var texture_normal:Texture2D
var nameplate_texture:Texture2D
var source_content_size:=Vector2.ZERO
var outline_extra:=0.0
var _icon:TextureRect
var caption:=""
var caption_size:=20
var visual_scale:=1.0:
	set(value):visual_scale=value;queue_redraw()
var lift:=0.0:
	set(value):lift=value;queue_redraw()
var _motion:Tween
var _hover:=false
func _ready()->void:
	flat=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(func():_hover=true;_animate(1.035,-2.0))
	mouse_exited.connect(func():_hover=false;_animate(1.0,0.0))
	focus_entered.connect(func():_animate(1.035,-2.0))
	focus_exited.connect(func():_animate(1.0,0.0))
	button_down.connect(func():_animate(0.91,2.0,0.07))
	button_up.connect(func():_animate(1.035 if _hover else 1.0,-2.0 if _hover else 0.0,0.17))
	resized.connect(queue_redraw)
	if texture_normal:
		_icon=TextureRect.new()
		_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_icon.texture=texture_normal
		_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		var outline:=ShaderMaterial.new()
		outline.shader=preload("res://scripts/ui/icon_white_edge.gdshader")
		outline.set_shader_parameter("radius_source_pixels",outline_extra*maxf(source_content_size.x,source_content_size.y)/60.0)
		_icon.material=outline
		add_child(_icon)
func _animate(amount:float,y:float,duration:float=0.14)->void:
	if disabled:return
	if _motion and _motion.is_valid():_motion.kill()
	_motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self,"visual_scale",amount,duration)
	_motion.tween_property(self,"lift",y,duration)
func keyboard_press()->void:_animate(0.91,2.0,0.07)
func _draw()->void:
	draw_set_transform(size*.5+Vector2(0,lift),0.0,Vector2.ONE*visual_scale)
	var base:=-size*.5
	var paper:=Rect2(base+Vector2(2,66),Vector2(size.x-4,28)) if texture_normal else Rect2(base+Vector2(3,3),size-Vector2(6,6))
	if nameplate_texture:paper.size.y=paper.size.x*nameplate_texture.get_height()/nameplate_texture.get_width()
	var tint:=Color(1,1,1,0.48) if disabled else Color.WHITE
	if texture_normal:
		var content:=source_content_size if source_content_size!=Vector2.ZERO else texture_normal.get_size()
		var ratio:=minf(60.0/content.x,60.0/content.y)
		var icon_size:=texture_normal.get_size()*ratio
		if is_instance_valid(_icon):
			_icon.size=icon_size
			_icon.scale=Vector2.ONE*visual_scale
			_icon.position=size*.5+(Vector2(size.x*.5,31)-icon_size*.5-size*.5)*visual_scale+Vector2(0,lift)
			_icon.modulate=tint
	var p:=paper.position
	var w:=paper.size.x
	var h:=paper.size.y
	var contour:=PackedVector2Array()
	var radius:=minf(h*0.44,15.0)
	# Soft, slightly unequal curved corners keep the paper feel without cut-off tips.
	var radii:=[radius,radius*0.94,radius*1.02,radius*0.97]
	for corner in range(4):
		var r:float=radii[corner]
		var center:=p+Vector2(r if corner in [0,3] else w-r,r if corner in [0,1] else h-r)
		for step in range(9):
			var angle:=PI+float(corner)*PI*.5+float(step)*PI/16.0
			var softness:=0.22*sin(float(step)*PI/4.0+float(corner))
			contour.append(center+Vector2(cos(angle),sin(angle))*(r+softness))
	contour.append(contour[0])
	if nameplate_texture:
		draw_texture_rect(nameplate_texture,paper,false,tint)
		if has_focus():draw_line(p+Vector2(w*.3,h-4),p+Vector2(w*.7,h-4),Color("546f62"),1.4,true)
	else:
		var shadow:=PackedVector2Array()
		for point in contour:shadow.append(point+Vector2(0,2))
		draw_colored_polygon(shadow,Color(0.25,0.23,0.18,0.13)*tint)
		draw_colored_polygon(contour,Color("fff3d9")*tint)
		draw_polyline(contour,Color("998266")*tint,1.1,true)
		draw_line(p+Vector2(9,h-4),p+Vector2(w*.4,h-3),Color(0.60,0.48,0.34,0.25)*tint,0.8,true)
		if has_focus():draw_polyline(contour,Color("546f62"),2.0,true)
	var text_size:=FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size)
	var at:=p+Vector2((w-text_size.x)*.5,(h-FONT.get_height(caption_size))*.5+FONT.get_ascent(caption_size))
	draw_string(FONT,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size,Color("665240")*tint)
