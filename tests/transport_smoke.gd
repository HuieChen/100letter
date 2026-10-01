extends SceneTree
## Timetable and route previews use game minutes; no wall-clock waiting.
## Run --headless --path . --script res://tests/transport_smoke.gd.

const Session = preload("res://scripts/core/GameSession.gd")
var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Session.new()
	root.add_child(game)
	game.save_path = "user://qa/transport_smoke_save.json"
	game.new_game()
	var departures: Array = game.catalog.get("travel_service", {}).get("departures", [])
	_check(departures.size() == 3 and int(departures[0]) == 790 and int(departures[1]) == 910 and int(departures[2]) == 1000, "bus uses the established13:10/15:10/16:40 departures")
	_check(int(game.catalog.get("travel_service", {}).get("ride_minutes", 0)) == 15, "supplemental bus ride duration is explicit catalog data")
	var initial: Dictionary = game.state.duplicate(true)
	var nearby: Array = game.travel_options("community_center")
	_check(nearby.size() == 1 and nearby[0].mode == "walk", "ordinary routes offer walking rather than an invented bus network")
	_check(nearby[0].minutes == game.travel_cost("community_center") and nearby[0].arrive_minute == 565, "walking preview retains the established destination cost")
	for preview in range(20):
		game.travel_options("lookout")
		game.travel_options("community_center")
	_check(game.state == initial, "repeated preview and cancellation do not spend time or alter state")
	_check(game.travel_options("missing_place").is_empty(), "unknown destination does not produce a plausible route")
	_check(not game.travel_options("post_office")[0].available, "current location is visibly unavailable for redundant departure")
	game.travel("lookout", "bus")
	_check(game.state == initial, "bus cannot be boarded from a location without its stop")
	game.travel("community_center")
	_check(game.state.minute == 565 and game.state.location == "community_center", "default travel still means the original walking route")
	game.travel("post_office")
	_check(game.state.minute == 590, "the walking return journey still has its established cost")
	_at_stop(780)
	var options: Array = game.travel_options("lookout")
	var bus: Dictionary = _mode(options, "bus")
	_check(options.size() == 2 and options[0].mode == "walk", "bus-stop lookout route presents both explicit choices with walking first")
	_check(bus.available and bus.wait_minutes == 10 and bus.ride_minutes == 15 and bus.minutes == 25, "bus preview includes ten minutes waiting plus fifteen riding")
	_check(bus.depart_minute == 790 and bus.arrive_minute == 805, "route preview displays scheduled departure and actual arrival")
	game.travel("lookout", "bus")
	_check(game.state.minute == 805 and game.state.location == "lookout", "confirmed bus departure charges waiting and riding exactly once")
	_check("等车 10 分钟" in str(game.state.journal[-1].text), "travel journal explains the paid waiting time")
	game.travel("lookout", "bus")
	_check(game.state.minute == 805, "repeated confirmation after arrival cannot charge a second journey")
	_check(game.load_game() and game.state.minute == 805 and game.state.location == "lookout", "completed bus journey survives save and resume")
	_check(game.travel_options("bus_stop").size() == 1, "unspecified return timetable is not invented")
	_at_stop(930)
	options = game.travel_options("lookout")
	bus = _mode(options, "bus")
	_check(bus.available and bus.minutes == 85 and _mode(options, "walk").minutes == 40, "missed bus can be slower than walking and the preview reveals the difference")
	game.travel("lookout")
	_check(game.state.minute == 970, "default confirmation never automatically chooses a slower bus")
	_at_stop(930)
	game.travel("lookout", "bus")
	_check(game.state.minute == 1015, "an explicitly selected slower bus honors its complete waiting cost")
	_at_stop(1000)
	bus = _mode(game.travel_options("lookout"), "bus")
	_check(bus.available and bus.wait_minutes == 0 and bus.arrive_minute == 1015, "the exact last departure minute remains boardable")
	_at_stop(1001)
	var after_last: Dictionary = game.state.duplicate(true)
	bus = _mode(game.travel_options("lookout"), "bus")
	_check(not bus.available and bus.depart_minute == -1 and "16:40" in bus.reason, "after the last departure the bus is disabled with an exact timetable reason")
	var refusal: String = game.travel("lookout", "bus")
	_check(not refusal.is_empty() and game.state == after_last, "unavailable bus neither teleports nor spends time")
	game.travel("lookout", "tram")
	_check(game.state == after_last, "unknown transportation mode cannot silently become a walking journey")
	game.travel("lookout", "walk")
	_check(game.state.minute == 1041, "walking remains available after bus service ends")
	_at_stop(1090)
	game.travel("lookout", "walk")
	game.choose("case02", "deliver", "mira_vale")
	_check(game.case_state("case02").late and game.is_handled("case02"), "transport remains usable after the urgent deadline without blocking delivery")
	_at_stop(900)
	game.begin_physical("case04", "open")
	game.complete_open("case04", "safe", 8)
	for option in game.travel_options("lookout"):
		_check(not option.available, "failure screen cannot expose a usable " + str(option.mode) + " departure")
	var failed_minute: int = int(game.state.minute)
	game.travel("lookout", "bus")
	_check(game.state.minute == failed_minute and game.state.location == "bus_stop", "failure blocks transport mutation until checkpoint recovery")
	print("TRANSPORT SMOKE: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _at_stop(minute: int) -> void:
	game.new_game()
	game.travel("bus_stop")
	game.state.minute = minute

func _mode(options: Array, mode: String) -> Dictionary:
	for option in options:
		if option.mode == mode:
			return option
	return {}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
