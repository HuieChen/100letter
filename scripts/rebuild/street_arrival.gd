extends RefCounted
## Landmarks measured against the unchanged panoramic paintings, in source pixels.
## Map aliases share a road, but each selection must arrive at its own landmark.
const SOURCE_X={
 "chess_stall":550.0,"bookstore":3860.0,
 "tarot_shop":650.0,"record_store":2360.0,"statue":4300.0,
 "community_center":2190.0,"grocery":4350.0,"market":6400.0,
 "residential":2200.0,"lookout":4470.0,"bus_stop":6500.0
}

static func place(road:Control,destination:String)->void:
 if not is_instance_valid(road.courier):return
 var x:float
 if destination=="post_office":
  # Use the same door anchor as the existing E-to-enter interaction.
  x=road.world.size.x*.376
 elif destination=="food_truck":
  # Stand beside the actual chef, within the existing conversation distance.
  x=12100.0
 elif SOURCE_X.has(destination):
  x=float(SOURCE_X[destination])*1.5-180.0
 else:return
 road.courier.foot=Vector2(clampf(x,100.0,road.world.size.x-100.0),872.0)
 road.courier.target=road.courier.foot
 road._follow_courier(road.courier.foot)
