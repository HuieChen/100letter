extends Control
## Only route annotations are procedural; the town, paper and buildings use the supplied map.
const PhysicalArt=preload("res://scripts/rebuild/physical_art.gd")
const SOURCE_REGION:=Rect2(128,12,1875,1341)
# Rectangles follow buildings in the new scroll's original source pixels.
const SOURCE_HOTSPOTS=[
	["post_office",Rect2(744,689,195,213)], ["chess_stall",Rect2(501,908,281,285)],
	["bookstore",Rect2(497,612,222,195)], ["tarot_shop",Rect2(500,378,264,179)],
	["record_store",Rect2(780,247,194,211)], ["statue",Rect2(912,463,276,271)],
	["community_center",Rect2(1020,262,284,254)], ["residential",Rect2(1240,622,228,178)],
	["grocery",Rect2(1419,340,125,166)], ["market",Rect2(1650,291,180,158)],
	["food_truck",Rect2(1530,573,233,155)], ["lookout",Rect2(1127,824,403,186)],
	["bus_stop",Rect2(1636,756,272,158)] ]
static func hotspot_entries()->Array:
	var entries:=SOURCE_HOTSPOTS.duplicate(true)
	for entry in entries:entry[1].position-=SOURCE_REGION.position
	return entries
var _focused_destination:Button
var _hovered_destination:Button
var _pressed_destination:Button
var _keyboard_navigation:=false
var _last_pointer_position:=Vector2.INF
var points:Array[Vector2]=[]
var current_index:=0
var target_index:=0
var route_progress:=0.0:
	set(value):route_progress=value;queue_redraw()
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_focus_changed.connect(_map_focus_changed)
	_focus_destination.call_deferred()
func _focus_destination()->void:
	# The host adds the hit regions after this map enters the tree.
	if not is_inside_tree():return
	var host:=_host()
	var preferred:String="Map_"+str(host.core.state.location) if host!=null else ""
	var first:Button
	for child in get_children():
		if child is Button and str(child.name).begins_with("Map_"):
			child.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
			child.mouse_entered.connect(func():_hovered_destination=child;queue_redraw())
			child.mouse_exited.connect(func():
				if _hovered_destination==child:_hovered_destination=null;queue_redraw())
			child.button_down.connect(func():_pressed_destination=child;queue_redraw())
			child.button_up.connect(func():_pressed_destination=null;queue_redraw())
			if first==null:first=child
			if str(child.name)==preferred:_focused_destination=child
	if is_instance_valid(_focused_destination):_focused_destination.grab_focus()
	elif first!=null:first.grab_focus()
func _host()->Node:
	var node:=get_parent()
	while node!=null and not node.has_method("_tr"):node=node.get_parent()
	return node
func _map_focus_changed(control:Control)->void:
	_focused_destination=control if control is Button and control.get_parent()==self and str(control.name).begins_with("Map_") else null
	queue_redraw()
func _input(event:InputEvent)->void:
	if not is_visible_in_tree():return
	# Focus can also change programmatically or on a mouse press. Only an
	# actual navigation event replaces the pointer's current target.
	if event is InputEventKey and event.pressed and event.keycode in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		_keyboard_navigation=true
		queue_redraw()
	elif event is InputEventMouseMotion:
		# Keep the hover reference while keyboard navigation is active: movement
		# within that same building must restore it without another mouse_entered.
		if event.position!=_last_pointer_position:
			_last_pointer_position=event.position
			_keyboard_navigation=false
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_keyboard_navigation=false
		queue_redraw()
func _draw()->void:
	var art:=map_texture()
	if art!=null:
		var ratio:=minf(size.x/art.get_width(),size.y/art.get_height())
		draw_texture_rect(art,Rect2((size-art.get_size()*ratio)*0.5,art.get_size()*ratio),false)
	if current_index>=0 and current_index<points.size() and target_index>=0 and target_index<points.size() and current_index!=target_index:
		var origin:Vector2=points[current_index]
		var destination:Vector2=points[target_index]
		draw_line(origin,origin.lerp(destination,clampf(route_progress,0.0,1.0)),Color("8b3e33"),3.0,true)
	# A small ink chevron identifies the target without tracing or tinting its art.
	var selected:Button=_active_destination()
	if is_instance_valid(selected):
		var at:=Vector2(selected.position.x+selected.size.x*.5,selected.position.y-10.0)
		var press:=selected==_pressed_destination
		at.y+=3.0 if press else 0.0
		var spread:=5.0 if press else 7.0
		var ink:=Color("865431") if press else Color("a76a3b")
		draw_line(at+Vector2(-spread,-4),at+Vector2(0,2),ink,3.0,true)
		draw_line(at+Vector2(0,2),at+Vector2(spread,-4),ink,3.0,true)

func _active_destination()->Button:
	if is_instance_valid(_pressed_destination):return _pressed_destination
	if _keyboard_navigation:return _focused_destination
	return _hovered_destination if is_instance_valid(_hovered_destination) else _focused_destination

func place_source_points(source_points:Array[Vector2]) -> void:
	var art:Texture2D=map_texture()
	if art==null:return
	var source_origin:Vector2=art.region.position if art is AtlasTexture else Vector2.ZERO
	var ratio:float=minf(size.x/art.get_width(),size.y/art.get_height())
	var origin:Vector2=(size-art.get_size()*ratio)*0.5
	points.clear()
	for point:Vector2 in source_points:points.append(origin+(point-source_origin)*ratio)
	queue_redraw()

static var _town_texture:Texture2D
static func map_texture()->Texture2D:
	if _town_texture==null:
		var pixels:=Image.new()
		if pixels.load("res://assets/authoring/map_20261105/scroll_map_v2.png")==OK:
			var atlas:=AtlasTexture.new()
			atlas.atlas=ImageTexture.create_from_image(pixels)
			atlas.region=SOURCE_REGION;atlas.filter_clip=true
			_town_texture=atlas
	return _town_texture

