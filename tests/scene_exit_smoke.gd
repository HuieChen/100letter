extends SceneTree
## Exercises a real on-scene path sign, including walking and the travel clock.
const MAIN = preload("res://scenes/main.tscn")
const EXIT = preload("res://scripts/ui/scene_exit.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1600,900)
	var main = MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.game.save_path = "user://qa/scene_exit_smoke_save.json"
	main._start_fresh()
	await process_frame
	var opening_signs: int = 0
	for child in main.world.get_children():
		if child.get_script() == EXIT: opening_signs += 1
	if opening_signs != 0:
		push_error("opening route signs compete with the first post-office action")
		quit(1)
		return
	main._desk()
	main._location()
	await process_frame
	var route: Button = null
	for child in main.world.get_children():
		if child.get_script() == EXIT and child.destination == "社区中心":
			route = child
	if route == null:
		push_error("the community center scene path is missing")
		quit(1)
		return
	var before: int = int(main.game.state.minute)
	var expected: int = main.game.travel_cost("community_center")
	main.walker.foot = Vector2(1380,780)
	main.walker.target = main.walker.foot
	route.pressed.emit()
	await create_timer(1.1).timeout
	var valid: bool = main.game.state.location == "community_center" and int(main.game.state.minute) == before+expected and main.current_view == "location" and not is_instance_valid(main.overlay)
	if not valid:
		push_error("scene path did not arrive through ordinary game travel")
		quit(1)
		return
	print("SCENE EXIT SMOKE: opening focus and walkable route passed")
	for player in main.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await create_timer(0.35).timeout
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)
