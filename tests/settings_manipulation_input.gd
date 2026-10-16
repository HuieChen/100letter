extends "res://tests/core_review_input.gd"
## Real letter extraction and wheel events prove the preference affects the object.
func _run() -> void:
	root.unfocusable=true;root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	host=Host.new();host.preferences_path="user://qa/sensitivity/"+run_id+".json";root.add_child(host);host.size=Vector2(1600,900)
	host.core.save_path="user://qa/sensitivity/"+run_id+"-story.json";host.core.new_game();host._counter()
	host.preferences.set_value("sensitivity",0.5)
	await _click(_desk_point((_desk_snapshot().rects.latch as Rect2).get_center()))
	await _click(_desk_point((_desk_snapshot().rects.lid as Rect2).get_center()));await create_timer(0.36).timeout
	await _click(_desk_point((_desk_snapshot().rects.letter as Rect2).get_center()))
	_check(_modal_script().ends_with("mail_workbench.gd"),"real letter opens its normal inspector")
	var bench:Control=host.modal
	_check(bench.manipulation_sensitivity==0.5,"preference reaches actual mail handling")
	await _move(bench.to_canvas(bench.model.object_rect("envelope").get_center()))
	await _button(MOUSE_BUTTON_WHEEL_UP,true);await _button(MOUSE_BUTTON_WHEEL_UP,false);await create_timer(0.18).timeout
	_check(is_equal_approx(float(bench.model.export_state().zoom),1.1),"half sensitivity gives a real 0.1 zoom step")
	await _click(Vector2(1495,60));host.preferences.set_value("sensitivity",2.0);host._workbench("case01")
	await create_timer(0.22).timeout;bench=host.modal
	_check(bench.manipulation_sensitivity==2.0,"next inspection uses updated preference")
	var start:float=bench.model.export_state().zoom
	await _move(bench.to_canvas(bench.model.object_rect("envelope").get_center()))
	await _button(MOUSE_BUTTON_WHEEL_UP,true);await _button(MOUSE_BUTTON_WHEEL_UP,false);await create_timer(0.18).timeout
	_check(is_equal_approx(float(bench.model.export_state().zoom),start+0.4),"double sensitivity gives a real 0.4 zoom step")
	await _click(Vector2(1495,60))
	_check(not is_instance_valid(host.modal),"same visible cross returns after sensitivity change")
	host.queue_free();await process_frame;await process_frame
	print("SETTINGS MANIPULATION: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
