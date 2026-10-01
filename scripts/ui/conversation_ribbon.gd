extends Control
## Conversation belongs to the location. This only supplies a readable lower
## text ground; speaker figures stay in the world, without portrait frames.

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for row in range(48):
		var alpha=float(row)/48.0
		draw_rect(Rect2(0,598+row*1.3,1600,1.5),Color(0.97,0.95,0.88,alpha*0.96))
	draw_rect(Rect2(0,660,1600,240),Color("f7f2e3"))
	draw_line(Vector2(919,673),Vector2(919,851),Color("d6d6bf"),1.0,true)
	draw_line(Vector2(76,690),Vector2(134,690),Color("b57b60"),2.0,true)
