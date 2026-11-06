extends Button
## Feedback follows the visible painted door; original room art stays untouched.
signal activated
const DESIGN:=Vector2(376,488)
var _outline:=PackedVector2Array([Vector2(3,3),Vector2(372,3),Vector2(372,457),Vector2(285,432),Vector2(210,410),Vector2(70,457),Vector2(3,486)])
var interaction_allowed:Callable
var warmth:=0.0
var pressure:=0.0
var _pending:=false
func _ready()->void:
	flat=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state:String in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	pressed.connect(_activate)
	visibility_changed.connect(func():warmth=0.0;pressure=0.0;queue_redraw())
func _has_point(point:Vector2)->bool:
	if size.x<=0.0 or size.y<=0.0:return false
	return Geometry2D.is_point_in_polygon(point/size*DESIGN,_outline)
func _process(delta:float)->void:
	var allowed:bool=not interaction_allowed.is_valid() or interaction_allowed.call()
	disabled=not allowed or _pending
	var target:=1.0 if visible and allowed and (is_hovered() or has_focus() or _pending) else 0.0
	var pressed_target:=1.0 if button_pressed or _pending else 0.0
	warmth=move_toward(warmth,target,delta*8.0)
	pressure=move_toward(pressure,pressed_target,delta*15.0)
	queue_redraw()
func _activate()->void:
	if _pending or (interaction_allowed.is_valid() and not interaction_allowed.call()):return
	_pending=true
	# Leave a perceptible handle response before the host changes scenes.
	await get_tree().create_timer(0.14).timeout
	if not is_inside_tree():return
	_pending=false
	if not interaction_allowed.is_valid() or interaction_allowed.call():activated.emit()
func _draw()->void:
	if warmth<0.001:return
	draw_set_transform(Vector2.ZERO,0.0,size/DESIGN)
	var cream:=Color("fff4d9")
	# The feedback sits on the painted handle, with a small press displacement.
	var a:=Vector2(330,309)+Vector2(2,3)*pressure
	var b:=Vector2(330,422)+Vector2(2,3)*pressure
	draw_line(a,b,Color(cream,0.09*warmth),26.0,true)
	draw_circle(a,13.0,Color(cream,0.09*warmth));draw_circle(b,13.0,Color(cream,0.09*warmth))
	draw_line(a,b,Color(cream,(0.16+0.18*pressure)*warmth),8.0,true)
	draw_circle(a,4.0,Color(cream,0.20*warmth));draw_circle(b,4.0,Color(cream,0.20*warmth))
