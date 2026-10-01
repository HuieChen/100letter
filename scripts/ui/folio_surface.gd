class_name FolioSurface
extends Control
## Physical backing for the tool drawer, archive ledger and delivery slip.
## Existing controls remain interactive on top of these paper objects.

var mode: String = "tools"
var action_count: int = 0

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x<=0 or size.y<=0: return
	match mode:
		"directory": _ledger()
		"decision": _form()
		_: _drawer()

func _drawer() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("785a3e"))
	draw_rect(Rect2(11,10,size.x-22,size.y-24),Color("b58f65"))
	draw_rect(Rect2(23,22,size.x-46,size.y-57),Color("6b806b"))
	draw_rect(Rect2(27,27,size.x-54,size.y-65),Color("f5ecd4"))
	draw_line(Vector2(28,143),Vector2(size.x-28,143),Color("c7b99b"),1.5,true)
	for y: float in [183.0,253.0,323.0]:
		draw_rect(Rect2(40,y,825,54),Color("f9f1dc"))
		draw_rect(Rect2(40,y,825,54),Color("b6a889"),false,1.0)
		draw_circle(Vector2(68,y+27),8,Color("bd9d6a"))
	draw_line(Vector2(28,size.y-45),Vector2(size.x-28,size.y-45),Color("c7b99b"),1.5,true)
	# Metal tweezers, thread and sealing spool lie along the free edge.
	draw_line(Vector2(size.x-151,size.y-114),Vector2(size.x-103,size.y-62),Color("8c9b8b"),5,true)
	draw_line(Vector2(size.x-141,size.y-119),Vector2(size.x-97,size.y-69),Color("c9cfc2"),3,true)
	draw_circle(Vector2(size.x-68,size.y-87),25,Color("bb9d6b"))
	draw_circle(Vector2(size.x-68,size.y-87),12,Color("eadab8"))
	draw_line(Vector2(size.x*0.45,size.y-18),Vector2(size.x*0.55,size.y-18),Color("6b5038"),5,true)

func _ledger() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("536d5f"))
	draw_rect(Rect2(10,9,size.x-20,size.y-23),Color("dfcfad"))
	draw_rect(Rect2(18,15,214,size.y-40),Color("fbf3df"))
	draw_rect(Rect2(244,15,size.x-262,size.y-40),Color("f7eed9"))
	draw_line(Vector2(238,140),Vector2(238,size.y-27),Color("9e967b"),4,true)
	for y: float in [84.0,146.0,208.0,270.0,332.0,394.0,456.0,518.0]:
		draw_line(Vector2(24,y),Vector2(size.x-22,y),Color("d9d2ba"),1,true)
	draw_rect(Rect2(size.x-20,102,20,67),Color("b47e65"))
	draw_rect(Rect2(size.x-20,180,20,67),Color("a5b397"))
	draw_line(Vector2(14,size.y-18),Vector2(size.x-14,size.y-18),Color("405d52"),3,true)

func _form() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("b8a47f"))
	draw_rect(Rect2(10,10,size.x-20,size.y-23),Color("fff6df"))
	draw_rect(Rect2(10,10,size.x-20,size.y-23),Color("ad9a7b"),false,1.5)
	for y: float in [75.0,145.0,222.0,315.0,565.0]:
		draw_line(Vector2(28,y),Vector2(size.x-28,y),Color("d4c5aa"),1.0,true)
	for index: int in range(action_count):
		var x: float=40.0+float(index%2)*500.0
		var y: float=381.0+float(index/2)*69.0
		draw_rect(Rect2(x,y,477,55),Color("fbf2dc"))
		draw_rect(Rect2(x,y,477,55),Color("c8baa0"),false,1.0)
		draw_rect(Rect2(x+14,y+17,20,20),Color("a69878"),false,1.2)
	draw_line(Vector2(24,29),Vector2(24,size.y-42),Color("c4b395"),1.2,true)
	draw_circle(Vector2(size.x-81,43),13,Color("b27c62"),false)
	draw_arc(Vector2(size.x-81,43),13,0,TAU,32,Color("b27c62"),2,true)
	draw_line(Vector2(size.x-94,size.y-42),Vector2(size.x-37,size.y-42),Color("a99577"),1.5,true)
