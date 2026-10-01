class_name MapController
extends Control
## A folded route map. Animation is visual and never advances the game clock.
var points: Array=[]
var place_ids: Array[String]=[]
var current_index=0
var target_index=0
var route_progress=0.0:
	set(value):
		route_progress=value
		queue_redraw()
const ROADS=[[0,1],[0,4],[1,5],[1,2],[2,3],[2,4],[2,6],[4,6]]

func route_indices() -> Array:
	if current_index==target_index: return [current_index]
	var queue: Array=[[current_index]]
	var visited: Array=[current_index]
	while not queue.is_empty():
		var path: Array=queue.pop_front()
		var tail: int=path.back()
		for edge in ROADS:
			var next: int=edge[1] if edge[0]==tail else (edge[0] if edge[1]==tail else -1)
			if next<0 or next in visited: continue
			var branch=path.duplicate()
			branch.append(next)
			if next==target_index: return branch
			visited.append(next)
			queue.append(branch)
	return [current_index]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e9e6cc"))
	var coast=PackedVector2Array([Vector2(705,0),Vector2(734,96),Vector2(863,149),Vector2(796,244),Vector2(828,361),Vector2(926,450),Vector2(908,550),Vector2(1000,550),Vector2(1000,0)])
	draw_colored_polygon(coast,Color("b7d6cf"))
	for pair in [[Vector2(838,47),Vector2(910,50)],[Vector2(876,293),Vector2(969,296)],[Vector2(938,395),Vector2(985,397)]]:
		draw_line(pair[0],pair[1],Color("dfebe0"),2.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(26,29),Vector2(302,23),Vector2(327,153),Vector2(260,184),Vector2(47,165)]),Color("d9dfbf"))
	draw_colored_polygon(PackedVector2Array([Vector2(78,459),Vector2(247,398),Vector2(344,532),Vector2(90,529)]),Color("dbdcb5"))
	for edge in ROADS:
		if edge[0]>=points.size() or edge[1]>=points.size(): continue
		draw_line(points[edge[0]],points[edge[1]],Color("d4c6a2"),17,true)
		draw_line(points[edge[0]],points[edge[1]],Color("f5efd8"),13,true)
	for i: int in range(mini(points.size(),place_ids.size())):
		_draw_landmark(points[i],place_ids[i])
	for x in [333,666]:
		draw_line(Vector2(x,12),Vector2(x,size.y-12),Color(0.49,0.48,0.37,0.10),1.0,true)
	var route=route_indices()
	var distance=0.0
	for i in range(1,route.size()):
		if route[i]>=points.size(): continue
		var start: Vector2=points[route[i-1]]
		var end: Vector2=points[route[i]]
		distance+=start.distance_to(end)
		for step in range(0,int(start.distance_to(end)),14):
			var length=start.distance_to(end)
			draw_line(start.lerp(end,step/length),start.lerp(end,minf(step+7,length)/length),Color("a06b51"),2.4,true)
	if not points.is_empty():
		var current: Vector2=points[current_index]
		draw_circle(current,8,Color("315e58"))
		draw_circle(current,3,Color("fff7e0"))
		draw_arc(current,13,0,TAU,28,Color("789890"),1.5,true)
		# The pin already identifies the current stop; its name is a separate child.
		# Keep this small annotation above the marker rather than over the place name.
		draw_string(get_theme_font("font"),current+Vector2(-104,-1),"当前位置",HORIZONTAL_ALIGNMENT_LEFT,86,15,Color("315e58"))
		if route.size()>1:
			var remaining=distance*route_progress
			var marker: Vector2=current
			for i in range(1,route.size()):
				var a: Vector2=points[route[i-1]]
				var b: Vector2=points[route[i]]
				var length=a.distance_to(b)
				marker=a.lerp(b,minf(remaining/length,1.0))
				if remaining<=length: break
				remaining-=length
			if route_progress>0:
				draw_circle(marker+Vector2(2,3),11,Color(0.28,0.32,0.25,0.15))
				draw_circle(marker,10,Color("b67b5b"))
				draw_circle(marker,4,Color("fff8e6"))
	draw_string(get_theme_font("font"),Vector2(813,528),"S O L M E R E",HORIZONTAL_ALIGNMENT_LEFT,180,17,Color("65877e"))

func _draw_landmark(point: Vector2, id: String) -> void:
	# Map symbols are a single illustrated vocabulary. Tiny versions of the
	# seven locked scene paintings looked like unrelated screenshots on paper.
	var at: Vector2=point+Vector2(0,-48)
	draw_set_transform(at)
	var ink:=Color("48675f")
	var wall:=Color("f3e4ca")
	var roof:=Color("ae7761")
	draw_rect(Rect2(-39,-22,78,54),wall)
	draw_rect(Rect2(-39,-22,78,54),ink,false,1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-47,-20),Vector2(0,-48),Vector2(47,-20)]),roof)
	draw_polyline(PackedVector2Array([Vector2(-47,-20),Vector2(0,-48),Vector2(47,-20)]),ink,1.6,true)
	match id:
		"post_office":
			draw_rect(Rect2(-13,0,26,32),Color("729a91"))
			draw_string(get_theme_font("font"),Vector2(-16,-4),"邮",HORIZONTAL_ALIGNMENT_LEFT,32,20,ink)
		"community_center":
			draw_rect(Rect2(-12,-62,24,40),wall)
			draw_circle(Vector2(0,-46),8,Color("e1dbc0"))
			draw_line(Vector2(0,-46),Vector2(0,-51),ink,1.5,true)
		"bus_stop":
			draw_rect(Rect2(-31,-11,62,3),ink)
			draw_line(Vector2(-27,-8),Vector2(-27,31),ink,2,true)
			draw_line(Vector2(27,-8),Vector2(27,31),ink,2,true)
		"lookout":
			draw_line(Vector2(-24,20),Vector2(25,-11),ink,5,true)
			draw_circle(Vector2(25,-11),7,Color("c6b88f"))
		"residential":
			for x: float in [-22.0,8.0]: draw_rect(Rect2(x,-10,14,16),Color("7d9d94"))
		"chess_stall":
			draw_rect(Rect2(-25,-8,50,12),Color("7c9c90"))
			draw_line(Vector2(-18,5),Vector2(-18,30),ink,2,true)
			draw_line(Vector2(18,5),Vector2(18,30),ink,2,true)
		"tarot_shop":
			draw_circle(Vector2(0,-27),11,Color("cfb578"))
			draw_rect(Rect2(-12,2,24,29),Color("74998e"))
	draw_set_transform(Vector2.ZERO)
