extends Control
## Only route annotations are procedural; the town, paper and buildings are a generated texture.
const PhysicalArt=preload("res://scripts/rebuild/physical_art.gd")
var points:Array[Vector2]=[]
var current_index:=0
var target_index:=0
var route_progress:=0.0:
	set(value):route_progress=value;queue_redraw()
func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw()->void:
	PhysicalArt.paint(self,"town_map",Rect2(Vector2.ZERO,size),Color.WHITE,true)
	if current_index>=0 and current_index<points.size() and target_index>=0 and target_index<points.size() and current_index!=target_index:
		var origin:Vector2=points[current_index]
		var destination:Vector2=points[target_index]
		draw_line(origin,origin.lerp(destination,clampf(route_progress,0.0,1.0)),Color("8b3e33"),3.0,true)

func place_source_points(source_points:Array[Vector2]) -> void:
	var art:Texture2D=PhysicalArt.texture("town_map")
	if art==null:return
	var source_origin:Vector2=art.region.position if art is AtlasTexture else Vector2.ZERO
	var ratio:float=minf(size.x/art.get_width(),size.y/art.get_height())
	var origin:Vector2=(size-art.get_size()*ratio)*0.5
	points.clear()
	for point:Vector2 in source_points:points.append(origin+(point-source_origin)*ratio)
	queue_redraw()
