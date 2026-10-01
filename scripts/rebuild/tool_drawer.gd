class_name PostalToolDrawer
extends RefCounted
## A physical drawer; its surfaces and tools are generated bitmap assets, never drawn art.
const Art = preload("res://scripts/rebuild/physical_art.gd")
const INNER := Rect2(1095, 674, 450, 214)
const PLACES := {
	"magnifier":Rect2(1115,692,105,143),
	"opener":Rect2(1231,688,190,40),
	"restorer":Rect2(1230,738,160,37),
	"press":Rect2(1450,764,72,65),
	"eraser":Rect2(1280,782,80,28),
	"sealer":Rect2(1430,679,100,80)}
var amount := 0.0
var opened := false
var held := false
var tools: Array[String] = []
var missing_tool := ""
var _start := Vector2.ZERO
var _before := 0.0

func configure(ids: Array[String], selected: String = "") -> void:
	tools = ids.duplicate()
	missing_tool = selected

func handle_rect() -> Rect2:
	return Rect2(1278, 821 + amount * 18, 122, 33)

func tool_rect(id: String) -> Rect2:
	return PLACES.get(id, Rect2())

func press(point: Vector2) -> String:
	if handle_rect().has_point(point):
		held = true
		_start = point
		_before = amount
		return "drawer"
	if not opened:return ""
	for id: String in tools:
		if id != missing_tool and tool_rect(id).has_point(point): return id
	return ""

func motion(point: Vector2) -> bool:
	if not held:return false
	amount = clampf(_before + (point.y - _start.y) / 44.0, 0.0, 1.0)
	opened = amount >= 0.88
	return true

func release() -> bool:
	if not held:return false
	held = false
	if amount >= 0.88:amount = 1.0;opened = true
	elif amount <= 0.12:amount = 0.0;opened = false
	return true

func paint(canvas: CanvasItem) -> void:
	if amount > 0.03:
		var visible_height := 214.0 * amount
		Art.paint(canvas, "drawer_open", Rect2(1095, 888 - visible_height, 450, visible_height))
	if opened:
		for id: String in tools:
			if id != missing_tool:Art.paint(canvas, id, tool_rect(id), Color.WHITE, true)
	if amount<=0.03:Art.paint(canvas,"drawer_front",Rect2(1085,814,468,44))
	elif opened:
		var material:Texture2D=Art.texture("drawer_open")
		if material!=null:
			canvas.draw_texture_rect_region(material,Rect2(1095,806.68,450,81.32),Rect2(0,material.get_height()*0.62,material.get_width(),material.get_height()*0.38))

func snapshot() -> Dictionary:
	var regions: Dictionary = {"handle":handle_rect(), "inner":INNER}
	for id: String in tools:regions[id] = tool_rect(id)
	return {"opened":opened,"amount":amount,"held":held,"tools":tools.duplicate(),"taken":missing_tool,"regions":regions}
