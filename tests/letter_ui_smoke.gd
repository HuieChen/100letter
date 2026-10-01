extends SceneTree
## The object on the desk opens a real, scrollable letter page and folds shut.
const MAIN = preload("res://scenes/main.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1600,900)
	var main=MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.game.save_path="user://qa/letter_ui_smoke_save.json"
	main.game.new_game()
	main.selected="case01"
	main.game.case_state("case01")["opened"]=true
	main._desk()
	await process_frame
	var insert: Button=null
	var letters: int=0
	for child in main.screen.get_children():
		if child.get_script()!=load("res://scripts/ui/object_button.gd"): continue
		if child.kind=="insert": insert=child
		if child.kind=="letter": letters+=1
	if insert==null or letters!=5:
		push_error("mail case has no physical insert or all five selectable envelopes")
		quit(1)
		return
	insert.pressed.emit()
	await process_frame
	var sheet: Control=null
	for child in main.overlay.get_children():
		if child.get_script()==load("res://scripts/ui/letter_insert.gd"): sheet=child
	if sheet==null or sheet.text_view.text!=str(main.game.letter_data("case01").body) or not sheet.text_view.scroll_active or sheet.text_view.size.x<400 or sheet.text_view.size.y<300:
		push_error("opened envelope did not reveal a scrollable physical page")
		quit(1)
		return
	var fold: Button=null
	for child in sheet.get_children():
		if child is Button: fold=child
	if fold==null:
		push_error("folded page has no close target")
		quit(1)
		return
	fold.pressed.emit()
	await process_frame
	if is_instance_valid(main.overlay):
		push_error("folded page did not close")
		quit(1)
		return
	print("LETTER UI SMOKE: five envelopes, insert, scroll and fold passed")
	for player in main.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	await create_timer(0.35).timeout
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)
