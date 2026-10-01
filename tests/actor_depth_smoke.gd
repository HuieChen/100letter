extends SceneTree
## Actual Main regression: walk depth, ground boundary and original hit paths.
var main:Control
var checks:int=0
var failures:int=0
const OUT='res://test-results/actor_depth_after/'
func _initialize()->void:_run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func settle()->void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func shot(name:String)->void:
	await settle()
	root.get_texture().get_image().save_png(OUT+name+'.png')
func walk(point:Vector2)->void:
	main.walker.walk_to(point,Callable())
	var spent:float=0.0
	while main.walker.walking and spent<12.0:
		await create_timer(0.05).timeout;spent+=0.05
	await create_timer(0.12).timeout
	check(not main.walker.walking,'actual walk reaches the bounded destination')
func click(control:Control)->void:
	var point:Vector2=control.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point
	root.push_input(move,true)
	await process_frame
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
	root.push_input(down,true);await process_frame
	var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=point;up.global_position=point
	root.push_input(up,true);await process_frame
func await_overlay()->void:
	var spent:float=0.0
	while not is_instance_valid(main.overlay) and spent<12:
		await create_timer(0.05).timeout;spent+=0.05
	check(is_instance_valid(main.overlay),'original scene hit target opens after physical approach')
func _run()->void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main=load('res://scenes/main.tscn').instantiate();root.add_child(main)
	await process_frame
	main.game.save_path='user://qa/actor_depth_smoke.json';main.sound.muted=true;main.game.new_game()
	main.game.travel('bus_stop');main._location();await create_timer(0.8).timeout
	var npc:Control=main.scene_actors.chenyuan
	check(main.walker.get_parent()==main.actor_layer and npc.get_parent()==main.actor_layer,'courier and NPC share their own scene actor layer')
	check(main.actor_layer.get_parent()==main.world and main.world_hud.get_parent()==main.screen,'actor sorting remains isolated from the HUD')
	check(main.actor_layer.mouse_filter==Control.MOUSE_FILTER_IGNORE and main.walker.mouse_filter==Control.MOUSE_FILTER_IGNORE,'actor layer does not intercept scene clicks')
	check(main.actor_layer.z_index==0 and main.walker.z_index==0 and npc.z_index==0,'no elevated z-index can cross HUD or conversation layers')
	var foreground:Control
	for node:Node in main.world.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with('/stage_depth.gd') and node.foreground:foreground=node
	check(is_instance_valid(foreground) and foreground.get_index()>main.actor_layer.get_index(),'painted foreground stays above the sorted actors')
	await walk(Vector2(1021,711))
	check(main.walker.foot==Vector2(1021,711),'formerly failing behind-NPC point is still reachable')
	check(main.walker.get_index()<npc.get_index(),'courier north of NPC draws behind that person')
	await shot('bus_behind_npc')
	await walk(Vector2(1021,785))
	check(main.walker.get_index()>npc.get_index(),'crossing south of the NPC reverses the occlusion')
	await shot('bus_in_front_of_npc')
	main.walker.foot=Vector2(1021,711)
	check(main.walker.get_index()<npc.get_index(),'direct handoff foot placement also updates occlusion immediately')
	var talk:Control=main.guidance_targets['npc:chenyuan'].node.get_ref()
	check(talk.get_parent()==main.world,'NPC click target retains its original world plane')
	await click(talk);await await_overlay();await create_timer(0.5).timeout
	check(main.dialogue_npc=='chenyuan','real NPC click still enters the intended conversation')
	var feet:Vector2=main.stage_plan.npc_feet.chenyuan
	check(absf(main.walker.foot.x-feet.x)>=100 and absf(main.walker.foot.y-feet.y)<=8,'conversation stands beside the NPC without overlapping silhouettes')
	check(not main.world_hud.visible and main.overlay.get_parent()==main,'dialogue stays above the scene and the HUD hides normally')
	await shot('bus_conversation_separation')
	main._close_overlay();await create_timer(0.5).timeout
	check(main.world_hud.visible and main.walker.manual_enabled,'conversation exit restores HUD and walking')
	var prop:Control=main.guidance_targets['hotspot:route_seventeen'].node.get_ref()
	check(prop.get_parent()==main.world and prop.get_index()<main.actor_layer.get_index(),'evidence paper remains on the building plane below people')
	await click(prop);await await_overlay()
	check(not main.guidance.visible and is_instance_valid(main.overlay),'real timetable target remains clickable beneath input-transparent actor layer')
	main._close_overlay()
	main.game.travel('residential');main._location();await create_timer(0.8).timeout
	await walk(Vector2(904,705))
	check(main.walker.foot==Vector2(904,738),'old air-conditioner point clamps to pavement y738')
	check(main.stage_plan.walk_bounds.position.y==738 and main.stage_plan.spawn.y==780 and main.stage_plan.entrance.y==742,'residential correction preserves arrival and doorway coordinates')
	check(main.walker.foot.y>main.stage_plan.visible_building.end.y,'courier shoes remain below the building silhouette')
	await shot('residential_grounded')
	main.walker._advance_manual(Vector2(0,-1),0.5)
	check(main.walker.foot.y==738,'northward manual movement also stops at the corrected floor boundary')
	check(main.actor_layer.z_index==0 and main.world_hud.is_visible_in_tree(),'residential depth correction does not cover the HUD')
	print('ACTOR_DEPTH_SMOKE: %d checks, %d failures'%[checks,failures])
	main.queue_free();await process_frame;await process_frame
	quit(0 if failures==0 else 1)
