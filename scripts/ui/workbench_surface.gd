extends Control
## Independent vector desk, drawn behind the working cards.
const CANVAS := Vector2(1600, 900)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / CANVAS.x, size.y / CANVAS.y))
	# The slightly sloping back edge belongs to the room above it.
	draw_colored_polygon(PackedVector2Array([Vector2(0,245),Vector2(1020,245),Vector2(1600,263),Vector2(1600,900),Vector2(0,900)]),Color("d9c9ac"))
	draw_polyline(PackedVector2Array([Vector2(0,245),Vector2(1020,245),Vector2(1600,263)]),Color("aa987a"),2.0,true)
	draw_line(Vector2(298,258),Vector2(1164,258),Color("e8ddc5"),2.0,true)
	# An uninterrupted blotter keeps the current letter visually primary.
	var blotter := PackedVector2Array([Vector2(333,275),Vector2(1184,280),Vector2(1180,757),Vector2(329,752)])
	_shadow(blotter,Vector2(3,5))
	draw_colored_polygon(blotter,Color("9aa89a"))
	draw_polyline(PackedVector2Array([Vector2(333,275),Vector2(1184,280),Vector2(1180,757),Vector2(329,752),Vector2(333,275)]),Color("879383"),1.0,true)
	draw_line(Vector2(345,738),Vector2(1166,743),Color("bcc4ad"),1.0,true)
	_draw_incoming_tray()
	# A narrow cloth holds the actual record and tool objects, with no UI frame.
	draw_colored_polygon(PackedVector2Array([Vector2(1244,279),Vector2(1503,285),Vector2(1497,697),Vector2(1239,692)]),Color("cabb9c"))
	draw_line(Vector2(1491,296),Vector2(1486,682),Color("b5a689"),1.0,true)
	# The desk lip is deliberately asymmetric.
	draw_colored_polygon(PackedVector2Array([Vector2(0,889),Vector2(347,883),Vector2(1600,886),Vector2(1600,900),Vector2(0,900)]),Color("b9a584"))
	draw_line(Vector2(351,883),Vector2(1600,886),Color("ad9879"),1.5,true)
	draw_set_transform(Vector2.ZERO)

func _draw_incoming_tray() -> void:
	var outside := Rect2(24,252,270,550)
	draw_rect(Rect2(outside.position+Vector2(4,7),outside.size),Color(0.25,0.24,0.20,0.12))
	draw_rect(outside,Color("b29b79"))
	draw_rect(Rect2(32,260,253,528),Color("c9b796"))
	draw_line(Vector2(32,263),Vector2(32,787),Color("a18c6b"),1.0,true)
	draw_line(Vector2(285,260),Vector2(285,789),Color("e0d0ae"),2.0,true)
	draw_rect(Rect2(24,787,270,15),Color("b9a17e"))
	draw_line(Vector2(24,787),Vector2(294,787),Color("e1cfad"),2.0,true)
	draw_line(Vector2(129,794),Vector2(181,794),Color("897a61"),3.0,true)

func _shadow(points: PackedVector2Array, offset: Vector2) -> void:
	var shifted := PackedVector2Array()
	for point: Vector2 in points: shifted.append(point+offset)
	draw_colored_polygon(shifted,Color(0.25,0.27,0.22,0.10))
