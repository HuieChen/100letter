extends Control
## Independent flat scenery. Supplied building and character textures are
## separate nodes above this layer; their pixels are never altered here.
const CANVAS := Vector2(1600, 900)
const INK := Color("52645e")
const SKY := Color("e1ebe4")
const SEA := Color("87b9b2")
const STONE := Color("eadabd")
const SHADOW := Color("d4c5aa")
const WALL := Color("f0dfc2")
const GREEN := Color("6d8876")
var foreground: bool = false
var location_id: String = "post_office"
var minute: int = 540

func configure(id: String, in_front: bool = false, at_minute: int = 540) -> void:
	location_id = id
	foreground = in_front
	minute = at_minute
	queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _poly(points: Array, color: Color, outline: bool = false) -> void:
	var shape := PackedVector2Array(points)
	draw_colored_polygon(shape, color)
	if outline:
		shape.append(shape[0])
		draw_polyline(shape, INK, 1.6, true)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	draw_set_transform(Vector2.ZERO, 0.0, size / CANVAS)
	if foreground: _front()
	else: _landscape()
	draw_set_transform(Vector2.ZERO)

func _landscape() -> void:
	draw_rect(Rect2(0,0,1600,900),SKY)
	_poly([Vector2(0,0),Vector2(1600,0),Vector2(1600,294),Vector2(1140,288),Vector2(820,300),Vector2(426,286),Vector2(0,301)],Color("eaf0e6"))
	_poly([Vector2(0,309),Vector2(350,310),Vector2(650,299),Vector2(1600,306),Vector2(1600,625),Vector2(0,625)],SEA)
	_poly([Vector2(0,506),Vector2(160,443),Vector2(310,459),Vector2(492,384),Vector2(662,416),Vector2(747,379),Vector2(755,618),Vector2(0,636)],Color("a4b7a5"))
	_poly([Vector2(1191,429),Vector2(1292,386),Vector2(1404,393),Vector2(1541,364),Vector2(1600,384),Vector2(1600,632),Vector2(1191,625)],Color("9cafa0"))
	for y: float in [400.0,474.0,544.0]:
		draw_line(Vector2(785,y),Vector2(1040,y-5),Color("d5e2d4"),2,true)
		draw_line(Vector2(1260,y+14),Vector2(1450,y+9),Color("d5e2d4"),2,true)
	_cloud(148,154,1.0)
	_cloud(1079,132,0.75)
	match location_id:
		"lookout": _cliffs()
		"bus_stop": _road()
		"residential": _courtyard()
		"chess_stall": _square()
		"tarot_shop": _terrace()
		"community_center": _civic()
		_: _post()
	_ground()

func _cloud(x: float, y: float, s: float) -> void:
	_poly([Vector2(x,y+29*s),Vector2(x+28*s,y+15*s),Vector2(x+41*s,y+4*s),Vector2(x+70*s,y+12*s),Vector2(x+90*s,y),Vector2(x+117*s,y+12*s),Vector2(x+158*s,y+25*s)],Color("f8f0da"))

func _house(x: float, y: float, width: float, height: float, flip: bool = false) -> void:
	var s: float = -1.0 if flip else 1.0
	_poly([Vector2(x,y),Vector2(x+width*s,y),Vector2(x+width*s,y+height),Vector2(x,y+height)],WALL,true)
	_poly([Vector2(x+width*s,y+15),Vector2(x+(width-28)*s,y+31),Vector2(x+(width-28)*s,y+height),Vector2(x+width*s,y+height)],Color("dbc7ab"))
	_poly([Vector2(x-14*s,y+12),Vector2(x+width*0.48*s,y-43),Vector2(x+(width+14)*s,y+12),Vector2(x+width*s,y+32),Vector2(x,y+32)],Color("af7963"),true)
	draw_line(Vector2(x+13*s,y+37),Vector2(x+(width-14)*s,y+37),Color("cf9b7b"),2,true)
	for i: int in range(2):
		var wx: float=x+(35+i*83)*s
		draw_rect(Rect2(minf(wx,wx+41*s),y+93,41,65),Color("789b91"))
		draw_line(Vector2(wx+20*s,y+95),Vector2(wx+20*s,y+156),INK,2,true)
		draw_line(Vector2(wx-5*s,y+91),Vector2(wx-5*s,y+158),Color("c69d78"),3,true)
		draw_line(Vector2(wx+46*s,y+91),Vector2(wx+46*s,y+158),Color("c69d78"),3,true)
	var door_x: float=x+(width-72)*s
	draw_rect(Rect2(minf(door_x,door_x+43*s),y+height-111,43,111),Color("8b9d91"))
	draw_rect(Rect2(minf(door_x+6*s,door_x+37*s),y+height-104,31,96),Color("789183"))
	draw_circle(Vector2(door_x+32*s,y+height-50),2,Color("f2d598"))
	for i: int in range(3):
		draw_line(Vector2(x+(31+i*62)*s,y+height-26),Vector2(x+(69+i*62)*s,y+height-26),Color("ddc5a3"),1.2,true)

func _wall(x: float, y: float, width: float) -> void:
	_poly([Vector2(x,y),Vector2(x+width,y-7),Vector2(x+width,y+56),Vector2(x,y+63)],Color("d4bea3"),true)
	_poly([Vector2(x-4,y-12),Vector2(x+width+4,y-19),Vector2(x+width+4,y-1),Vector2(x-4,y+6)],WALL,true)

func _cypress(x: float, y: float) -> void:
	_poly([Vector2(x,y+210),Vector2(x-33,y+95),Vector2(x-18,y+24),Vector2(x,y),Vector2(x+29,y+106),Vector2(x+21,y+211)],Color("557166"),true)

func _post() -> void:
	_house(-44,260,286,410)
	_poly([Vector2(1303,273),Vector2(1600,248),Vector2(1600,682),Vector2(1303,675)],WALL,true)
	_wall(0,586,355)
	_wall(1283,583,317)
	_cypress(1366,400)

func _civic() -> void:
	_house(-54,281,285,400)
	_house(1643,264,311,405,true)
	_wall(0,584,344)
	_wall(1280,581,320)
	_cypress(1352,405)

func _road() -> void:
	_house(-57,300,273,333)
	_poly([Vector2(0,628),Vector2(1600,609),Vector2(1600,702),Vector2(0,721)],Color("c5c9ae"))
	_wall(1240,582,360)
	_cypress(1380,394)

func _cliffs() -> void:
	_poly([Vector2(0,393),Vector2(184,340),Vector2(311,385),Vector2(393,478),Vector2(318,635),Vector2(0,634)],Color("b9aba0"),true)
	_poly([Vector2(1298,425),Vector2(1420,360),Vector2(1600,342),Vector2(1600,635),Vector2(1352,634)],Color("b9aba0"),true)
	_poly([Vector2(0,463),Vector2(193,411),Vector2(319,493),Vector2(139,570),Vector2(0,551)],Color("dcc4a5"))

func _courtyard() -> void:
	_house(-35,280,315,404)
	_poly([Vector2(1300,270),Vector2(1600,262),Vector2(1600,690),Vector2(1300,684)],WALL,true)
	_wall(0,590,351)
	_wall(1294,586,306)
	_cypress(1375,415)

func _square() -> void:
	_house(1637,273,314,410,true)
	_wall(1280,582,320)
	draw_line(Vector2(53,587),Vector2(86,105),Color("6b6256"),45,true)
	draw_line(Vector2(83,298),Vector2(266,153),Color("6b6256"),21,true)
	_poly([Vector2(0,0),Vector2(338,0),Vector2(298,103),Vector2(120,123),Vector2(0,152)],Color("526f65"))

func _terrace() -> void:
	_wall(0,551,450)
	_wall(1266,548,334)
	_cypress(1440,393)

func _ground() -> void:
	_poly([Vector2(0,626),Vector2(1600,613),Vector2(1600,900),Vector2(0,900)],STONE)
	_poly([Vector2(0,629),Vector2(1600,616),Vector2(1600,650),Vector2(0,664)],Color("f5e9d1"))
	for tile: int in range(6):
		var base_x: float=tile*290.0-35.0
		_poly([Vector2(base_x+31,715),Vector2(base_x+229,713),Vector2(base_x+248,775),Vector2(base_x+12,780)],Color("e4d1b1") if tile%2==0 else Color("f1e1c3"))
		_poly([Vector2(base_x+109,802),Vector2(base_x+268,797),Vector2(base_x+293,865),Vector2(base_x+90,872)],Color("e3d1b5") if tile%2==1 else Color("f0e0c4"))
	for y: float in [711.0,790.0,870.0]:
		draw_line(Vector2(0,y),Vector2(1600,y-13),SHADOW,2,true)
	for x: float in [71.0,313.0,567.0,839.0,1101.0,1376.0]:
		draw_line(Vector2(x,711),Vector2(x-23,789),SHADOW,2,true)
		draw_line(Vector2(x+89,791),Vector2(x+62,887),SHADOW,2,true)
	for x: float in [202.0,640.0,1023.0,1507.0]:
		draw_line(Vector2(x,879),Vector2(x+27,877),Color("cab99d"),1.5,true)

func _front() -> void:
	for side: int in [0,1]:
		var x: float=0.0 if side==0 else 1600.0
		var s: float=1.0 if side==0 else -1.0
		_poly([Vector2(x,900),Vector2(x,836),Vector2(x+39*s,815),Vector2(x+77*s,841),Vector2(x+119*s,819),Vector2(x+175*s,851),Vector2(x+190*s,900)],GREEN)
		_poly([Vector2(x,900),Vector2(x,867),Vector2(x+58*s,855),Vector2(x+103*s,883),Vector2(x+162*s,867),Vector2(x+177*s,900)],Color("4e6c61"))
