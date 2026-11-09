extends RefCounted
## Temporary scene transform. Never moves the player or changes save coordinates.
var target:Control
var original_position:Vector2
var original_scale:Vector2
var zoom:=1.0
const VIEW:=Vector2(1600,900)
func _init(node:Control)->void:
	target=node;original_position=node.position;original_scale=node.scale
func pan(delta:Vector2)->void:
	if not is_instance_valid(target):return
	target.position+=delta;_clamp()
func magnify(amount:float)->void:
	if not is_instance_valid(target):return
	var anchor:Vector2=(VIEW*.5-target.position)/target.scale
	zoom=clampf(zoom+amount,1.0,1.8)
	target.scale=original_scale*zoom
	target.position=VIEW*.5-anchor*target.scale
	_clamp()
func _clamp()->void:
	var extent:Vector2=target.size*target.scale
	target.position.x=clampf(target.position.x,minf(0.0,VIEW.x-extent.x),0.0)
	target.position.y=clampf(target.position.y,minf(0.0,VIEW.y-extent.y),0.0)
func reset()->void:
	zoom=1.0
	if is_instance_valid(target):target.position=original_position;target.scale=original_scale
func restore()->void:reset()
