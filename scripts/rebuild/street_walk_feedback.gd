extends Control
var road:Control
var target:=Vector2.ZERO
var active:=false
var alpha:=0.0
var age:=0.0
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	road.world.gui_input.connect(_ground_input)
func _ground_input(event:InputEvent)->void:
	if road.can_walk.is_valid() and not road.can_walk.call():return
	if not event is InputEventMouseButton or not event.pressed:return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		road.courier.cancel();active=false;road.world.accept_event();return
	if event.button_index!=MOUSE_BUTTON_LEFT or event.position.y<760:return
	target=Vector2(clampf(event.position.x,100.0,road.world.size.x-100.0),872)
	age=0;active=true;alpha=1.0
	road.courier.walk_to(target,func():active=false)
	road.world.accept_event()
func _process(delta:float)->void:
	if not is_instance_valid(road.courier):return
	if active:
		age+=delta
		if road.courier.target.distance_to(target)>2 or road.courier.foot.distance_to(target)<8 or (road.can_walk.is_valid() and not road.can_walk.call()):active=false
	alpha=move_toward(alpha,1.0 if active else 0.0,delta*5.0)
	queue_redraw()
func _draw()->void:
	if alpha<=0:return
	var radius:=13.0+8.0*exp(-age*9.0)
	var color:=Color(.35,.32,.26,alpha*.7)
	for side in [-1,1]:
		draw_line(target+Vector2(side*radius,-3),target+Vector2(side*(radius+7),0),color,2,true)
		draw_line(target+Vector2(side*radius,3),target+Vector2(side*(radius+7),0),color,2,true)
	draw_circle(target,2.5,color)
