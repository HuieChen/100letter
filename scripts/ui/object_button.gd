extends Button
## The button is only the hit area; visible forms are physical desk objects.
var kind = "bag"
var caption = ""
var chosen = false
var index = 0
var compact: bool = false
var scene_caption: bool = false
var desk_fixture: bool = false

const INK := Color("52685e")
const LINE := Color("8d9079")
const PAPER := Color("f8efd8")
const SAGE := Color("719286")
const CLAY := Color("b47e64")
const SHADOW := Color(0.24,0.27,0.22,0.13)

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	tooltip_text = caption
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)

func _draw() -> void:
	var active: bool = is_hovered() or has_focus()
	if desk_fixture and kind in ["tools","book","deliver","map","door"]:
		_draw_desk_fixture(active)
		return
	var lift: float = -2.0 if active else 0.0
	var middle := Vector2(size.x*0.5,(31.0 if compact else 39.0)+lift)
	if kind == "letter":
		_draw_letter(active)
		return
	var object_scale: float = 0.79 if compact else 1.0
	draw_set_transform(middle,0.0,Vector2.ONE*object_scale)
	match kind:
		"map": _draw_map()
		"bag": _draw_bag()
		"book": _draw_book()
		"tools": _draw_tools()
		"deliver": _draw_delivery()
		"door": _draw_door()
		_: _draw_book()
	draw_set_transform(Vector2.ZERO)
	_draw_caption(75.0 if compact else 99.0,16 if compact else 18,active)

func _draw_desk_fixture(active: bool) -> void:
	var paper := Color("f4ead1")
	var dark := Color("55746b")
	var edge := Color("9b987e")
	var lift: float = -3.0 if active else 0.0
	if kind in ["tools","book","deliver"]:
		var base := Rect2(11,9+lift,size.x-22,size.y-20)
		if kind == "tools":
			# The repair tools are inside a real drawer, not displayed as a huge icon.
			draw_rect(base,Color("ae9777"))
			draw_rect(Rect2(base.position+Vector2(5,4),base.size-Vector2(10,12)),Color("c9b08a"))
			draw_line(Vector2(28,base.end.y-13),Vector2(size.x-28,base.end.y-13),Color("8c795e"),2,true)
			draw_rect(Rect2(size.x-59,base.position.y+24,30,13),Color("ead9b8"))
			draw_arc(Vector2(size.x-44,base.position.y+30),8,0,TAU,24,edge,1.5,true)
		elif kind == "book":
			draw_rect(Rect2(base.position+Vector2(4,6),base.size-Vector2(8,6)),Color("718d7c"))
			draw_rect(Rect2(base.position+Vector2(10,12),base.size-Vector2(20,17)),Color("e8dcc0"))
			draw_rect(Rect2(base.position+Vector2(10,12),Vector2(18,base.size.y-18)),Color("9a8168"))
			draw_line(Vector2(size.x-54,base.position.y+31),Vector2(size.x-31,base.position.y+31),edge,2,true)
		else:
			draw_rect(Rect2(base.position+Vector2(2,7),base.size-Vector2(4,10)),paper)
			draw_rect(Rect2(base.position+Vector2(2,7),base.size-Vector2(4,10)),edge,false,1.2)
			for y: float in [25.0,35.0,45.0]:
				draw_line(Vector2(size.x-86,base.position.y+y),Vector2(size.x-31,base.position.y+y),edge,1.3,true)
			draw_arc(Vector2(size.x-45,base.end.y-22),12,0,TAU,24,CLAY,2,true)
		draw_string(get_theme_font("font"),Vector2(34,size.y*0.61+lift),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-104,20,dark)
	else:
		var center := Vector2(size.x*0.5,39+lift)
		draw_set_transform(center,0.0,Vector2.ONE*0.62)
		if kind == "map": _draw_map()
		else: _draw_door()
		draw_set_transform(Vector2.ZERO)
		_draw_caption(93,17,active)
	if active:
		draw_line(Vector2(24,size.y-7),Vector2(size.x-24,size.y-7),CLAY,2,true)

func _draw_letter(active: bool) -> void:
	var width: float = minf(size.x-37.0,200.0)
	var half := width*0.5
	var center := Vector2(size.x*0.5+(3.0 if chosen else 0.0),43.0-(2.0 if active else 0.0))
	draw_set_transform(center,deg_to_rad(-0.8 if index%2==0 else 0.8))
	var rect := Rect2(-half,-31,width,64)
	draw_rect(Rect2(rect.position+Vector2(2,4),rect.size),SHADOW)
	draw_rect(rect,PAPER if chosen else Color("ede2c8"))
	draw_rect(rect,Color("acaa90"),false,1.0)
	draw_polyline(PackedVector2Array([Vector2(-half,-31),Vector2(0,7),Vector2(half,-31)]),Color("b7b397"),1.15,true)
	draw_line(Vector2(-half,33),Vector2(-half+53,0),Color("d2c7aa"),1.0,true)
	draw_line(Vector2(half,33),Vector2(half-53,0),Color("d2c7aa"),1.0,true)
	draw_rect(Rect2(half-29,-23,19,24),CLAY if index==1 else SAGE)
	draw_line(Vector2(half-25,-18),Vector2(half-15,-18),Color("dfd5b6"),1.0,true)
	draw_string(get_theme_font("font"),Vector2(-half+12,22),"%02d"%[index+1],HORIZONTAL_ALIGNMENT_LEFT,50,17,INK)
	if chosen:
		# A paperclip identifies the selected letter without an app-like tab.
		draw_arc(Vector2(-half+14,-28),7,PI,TAU,12,INK,2.0,true)
		draw_line(Vector2(-half+7,-28),Vector2(-half+7,-8),INK,2.0,true)
		draw_arc(Vector2(-half+12,-8),5,0,PI,12,INK,2.0,true)
		draw_line(Vector2(-half+17,-8),Vector2(-half+17,-27),INK,2.0,true)
	draw_set_transform(Vector2.ZERO)
	_draw_caption(101.0,17,active or chosen)

func _draw_caption(baseline: float, font_size: int, active: bool) -> void:
	var font := get_theme_font("font")
	var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var x := maxf(7.0,(size.x-width)*0.5)
	if scene_caption:
		draw_string_outline(font,Vector2(x,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-14,font_size,5,Color("f8efd8"))
	draw_string(font,Vector2(x,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-14,font_size,INK)
	if active:
		draw_line(Vector2(x,baseline+5),Vector2(minf(size.x-7,x+width),baseline+5),Color("9d8061"),1.0,true)

func _polygon(points: PackedVector2Array, color: Color, shadow: bool = true) -> void:
	if shadow:
		var shifted := PackedVector2Array()
		for point: Vector2 in points: shifted.append(point+Vector2(2,4))
		draw_colored_polygon(shifted,SHADOW)
	draw_colored_polygon(points,color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline,LINE,1.3,true)

func _draw_map() -> void:
	_polygon(PackedVector2Array([Vector2(-47,-24),Vector2(-17,-30),Vector2(13,-23),Vector2(46,-29),Vector2(43,31),Vector2(12,35),Vector2(-19,27),Vector2(-49,33)]),PAPER)
	draw_colored_polygon(PackedVector2Array([Vector2(-17,-30),Vector2(13,-23),Vector2(12,35),Vector2(-19,27)]),Color("e7ddbf"))
	draw_line(Vector2(-17,-28),Vector2(-19,27),Color("beb99b"),1.0,true)
	draw_line(Vector2(13,-23),Vector2(12,35),Color("c8c1a3"),1.0,true)
	draw_polyline(PackedVector2Array([Vector2(-39,19),Vector2(-28,-3),Vector2(-4,8),Vector2(16,-4),Vector2(35,-16)]),SAGE,2.2,true)
	draw_circle(Vector2(35,-16),4.0,CLAY)
	draw_circle(Vector2(-28,-3),2.5,INK)

func _draw_bag() -> void:
	draw_arc(Vector2(0,-18),23,PI,TAU,24,INK,3.0,true)
	_polygon(PackedVector2Array([Vector2(-37,-19),Vector2(36,-19),Vector2(40,34),Vector2(-40,34)]),SAGE)
	_polygon(PackedVector2Array([Vector2(-37,-19),Vector2(36,-19),Vector2(33,3),Vector2(-33,3)]),Color("8ca294"),false)
	draw_rect(Rect2(-5,-1,10,20),Color("c9ad79"))
	draw_rect(Rect2(-3,4,6,7),INK,false,1.0)
	draw_line(Vector2(-30,24),Vector2(-12,24),Color("abc0a4"),1.0,true)

func _draw_book() -> void:
	draw_rect(Rect2(-37,-28,79,64),SHADOW)
	draw_rect(Rect2(-34,-28,75,59),Color("ded5b9"))
	draw_line(Vector2(-25,26),Vector2(39,26),Color("b4b299"),1.0,true)
	draw_line(Vector2(-25,29),Vector2(38,29),Color("b4b299"),1.0,true)
	_polygon(PackedVector2Array([Vector2(-40,-34),Vector2(35,-34),Vector2(35,25),Vector2(-40,25)]),Color("b18f73"),false)
	draw_line(Vector2(-29,-33),Vector2(-29,25),Color("856f5a"),2.0,true)
	draw_rect(Rect2(-16,-18,40,27),PAPER)
	draw_line(Vector2(-8,-8),Vector2(15,-8),LINE,1.0,true)
	draw_line(Vector2(-8,-1),Vector2(8,-1),LINE,1.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(13,26),Vector2(22,26),Vector2(22,39),Vector2(17,35),Vector2(13,39)]),SAGE)

func _draw_tools() -> void:
	_polygon(PackedVector2Array([Vector2(-41,25),Vector2(7,-29),Vector2(23,-35),Vector2(17,-19),Vector2(-25,37)]),Color("c9d0be"))
	draw_line(Vector2(-36,29),Vector2(-16,7),Color("99795f"),10.0,true)
	draw_line(Vector2(-33,27),Vector2(-15,7),Color("bc9c77"),2.0,true)
	draw_circle(Vector2(33,20),20,SHADOW)
	draw_circle(Vector2(30,16),20,Color("c8b387"))
	draw_arc(Vector2(30,16),20,0,TAU,40,LINE,1.2,true)
	draw_circle(Vector2(30,16),10,Color("e2d5b8"))
	draw_arc(Vector2(30,16),10,0,TAU,28,LINE,1.0,true)
	draw_line(Vector2(45,28),Vector2(53,35),Color("c8b387"),7.0,true)

func _draw_delivery() -> void:
	_polygon(PackedVector2Array([Vector2(-43,-24),Vector2(37,-24),Vector2(37,27),Vector2(-43,27)]),PAPER)
	draw_polyline(PackedVector2Array([Vector2(-43,-24),Vector2(-3,2),Vector2(37,-24)]),LINE,1.2,true)
	draw_arc(Vector2(-19,12),10,0,TAU,30,SAGE,1.2,true)
	draw_line(Vector2(-34,8),Vector2(-4,8),SAGE,1.0,true)
	draw_rect(Rect2(19,-16,11,14),CLAY)
	draw_rect(Rect2(6,16,46,23),Color("dfd4b5"))
	draw_line(Vector2(13,23),Vector2(42,23),LINE,1.0,true)
	draw_line(Vector2(13,30),Vector2(34,30),LINE,1.0,true)

func _draw_door() -> void:
	_polygon(PackedVector2Array([Vector2(-28,-35),Vector2(27,-35),Vector2(27,34),Vector2(-28,34)]),Color("8fa492"))
	draw_rect(Rect2(-20,-27,39,33),Color("c2d2bf"))
	draw_line(Vector2(-1,-27),Vector2(-1,6),Color("8ba08e"),1.5,true)
	draw_line(Vector2(-20,-10),Vector2(19,-10),Color("8ba08e"),1.5,true)
	draw_rect(Rect2(-20,13,39,14),Color("7e9583"),false,1.0)
	draw_circle(Vector2(15,13),2.5,Color("e3cc9a"))
	draw_line(Vector2(-34,36),Vector2(34,36),LINE,2.0,true)
