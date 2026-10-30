extends SceneTree
func _initialize()->void:call_deferred("check")
func check()->void:
 var road=load("res://scripts/rebuild/coastal_road.gd").new()
 root.add_child(road)
 assert(road.courier._poses.size()>=6)
 assert(road.fountain_frames.size()==3)
 var w=road.courier
 w.manual_enabled=false
 w.configure(null,Rect2(0,872,10000,0),Vector2(100,872))
 for i in range(120):w._advance_manual(Vector2.RIGHT,1.0/120.0)
 var normal=w.foot.x
 w.configure(null,Rect2(0,872,10000,0),Vector2(100,872))
 var shift=InputEventKey.new();shift.keycode=KEY_SHIFT;shift.physical_keycode=KEY_SHIFT;shift.pressed=true;w._input(shift)
 for i in range(120):w._advance_manual(Vector2.RIGHT,1.0/120.0)
 assert(w.foot.x>normal*1.3)
 shift.pressed=false;w._input(shift)
 for i in range(100):w._advance_manual(Vector2.ZERO,1.0/120.0)
 assert(w.velocity.length()<0.01)
 road.queue_free();await process_frame
 var post=load("res://scripts/rebuild/coastal_road.gd").new();post.postal=true;root.add_child(post)
 assert(post.world.size.x>9000)
 post.courier.foot.x=post.world.size.x*0.376;post._process(0.01);assert(post.entry_ready)
 post.courier.foot.x=100;post._process(0.01);assert(not post.entry_ready)
 print("STREET_QA_PASS: six poses, fountain frames, shift speed, braking, postal proximity")
 post.queue_free();await process_frame;quit()
