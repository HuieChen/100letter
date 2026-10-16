extends RigidBody2D
## Native GodotPhysics2D rigid body; forces do not overwrite the transform each frame.
var radius:=94.0
func _integrate_forces(state:PhysicsDirectBodyState2D)->void:
	# Prevent accumulated rapid taps from making a floating slice fly across the UI.
	state.linear_velocity=state.linear_velocity.limit_length(55.0)
	state.angular_velocity=clampf(state.angular_velocity,-0.13,0.13)
