extends Control
## A single open mail case on the desk. Letters and tools are separate clickable
## objects above it; this furniture never embeds or alters supplied artwork.
const CANVAS := Vector2(1600, 900)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / CANVAS.x, size.y / CANVAS.y))
	# Green work cloth and the open wooden case sit on the same physical desk.
	draw_colored_polygon(PackedVector2Array([Vector2(0,245),Vector2(1600,245),Vector2(1600,900),Vector2(0,900)]),Color("8a9876"))
	draw_line(Vector2(0,248),Vector2(1600,248),Color("b8b38e"),3.0,true)
	_draw_mail_case()
	# Narrow compartments keep tools attached to the furniture.
	draw_rect(Rect2(1216,266,302,436),Color("765940"))
	draw_rect(Rect2(1224,273,286,421),Color("a17b55"))
	for y: float in [288.0,418.0,548.0]:
		draw_rect(Rect2(1234,y,265,106),Color("72583e"))
		draw_rect(Rect2(1240,y+5,253,92),Color("c6b18b"))
		draw_line(Vector2(1240,y+96),Vector2(1493,y+96),Color("6b553e"),2.0,true)
	# Front ledge holds the map and the door handle in shallow slots.
	draw_rect(Rect2(316,767,885,114),Color("9a7954"))
	draw_line(Vector2(316,767),Vector2(1201,767),Color("d6b98b"),3.0,true)
	draw_line(Vector2(316,879),Vector2(1201,879),Color("6d5239"),2.0,true)
	draw_rect(Rect2(0,889,1600,11),Color("765a3f"))
	draw_set_transform(Vector2.ZERO)

func _draw_mail_case() -> void:
	# Open lid, inner lining, lower body and brass fittings read as one object.
	var lid := PackedVector2Array([Vector2(45,278),Vector2(1191,278),Vector2(1168,485),Vector2(62,485)])
	_shadow(lid,Vector2(6,12))
	draw_colored_polygon(lid,Color("735138"))
	draw_polyline(PackedVector2Array([Vector2(45,278),Vector2(1191,278),Vector2(1168,485),Vector2(62,485),Vector2(45,278)]),Color("4e3b2e"),4,true)
	draw_colored_polygon(PackedVector2Array([Vector2(69,299),Vector2(1164,299),Vector2(1144,460),Vector2(81,460)]),Color("98704d"))
	for y: float in [321.0,352.0,389.0,425.0]:
		draw_line(Vector2(105,y),Vector2(1125,y+3),Color("aa8159"),2,true)
	draw_rect(Rect2(66,421,1110,326),Color("4d3d30"))
	draw_rect(Rect2(80,437,1082,286),Color("687a5e"))
	draw_rect(Rect2(82,449,345,269),Color("637158"))
	draw_line(Vector2(446,444),Vector2(446,720),Color("a5865b"),11,true)
	draw_rect(Rect2(48,720,1142,38),Color("805d3d"))
	draw_line(Vector2(48,720),Vector2(1190,720),Color("c5a274"),5,true)
	draw_line(Vector2(61,745),Vector2(1176,745),Color("654a32"),3,true)
	for x: float in [68.0,1119.0]:
		draw_rect(Rect2(x,727,48,21),Color("c6a25f"))
		draw_line(Vector2(x+7,731),Vector2(x+41,731),Color("efd195"),2,true)
	draw_rect(Rect2(594,723,65,23),Color("c8a15e"))
	draw_arc(Vector2(626,746),22,0,TAU,40,Color("6a705e"),5,true)
	draw_line(Vector2(195,278),Vector2(220,278),Color("d1ae70"),7,true)
	draw_line(Vector2(1002,278),Vector2(1027,278),Color("d1ae70"),7,true)

func _shadow(points: PackedVector2Array, offset: Vector2) -> void:
	var shifted := PackedVector2Array()
	for point: Vector2 in points: shifted.append(point+offset)
	draw_colored_polygon(shifted,Color(0.25,0.27,0.22,0.10))
