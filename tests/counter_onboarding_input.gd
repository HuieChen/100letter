extends "res://tests/core_review_input.gd"
## Newcomer route uses only visible objects and crosses, with actual viewport input.
func _run() -> void:
	root.unfocusable=true
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=dimensions;root.content_scale_size=Vector2i(1600,900)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		host=Host.new();root.add_child(host);host.size=Vector2(1600,900)
		host.core.save_path="user://qa/onboarding/"+str(Time.get_ticks_usec())+".json"
		host._title()
		await process_frame
		await _named("NewShift")
		await _wait(func():return _node("FinishBriefing")!=null,"supervisor appears")
		await process_frame;await process_frame
		var spoken: RichTextLabel=_node("SpokenLine")
		_check(spoken.text.length()<120,"first conversation gives one concise investigation purpose")
		_check(spoken.get_content_height()<=spoken.size.y,"opening NPC line fits without hidden scrolling")
		if dimensions.x==1920:await _shot("onboarding_supervisor_1920")
		await _named("CloseDialogue")
		_check(not host.busy and not is_instance_valid(host.modal),"visible cross ends briefing without shortcuts")
		var lid_point:=_desk_point((_desk_snapshot().rects.lid as Rect2).get_center())
		await _click(lid_point)
		_check(float(_desk_snapshot().lid_open)==0.0,"locked lid cannot reveal contents")
		_check(_node("PhysicalPostalDesk")._rejection>0.0,"wrong locked-lid input gives physical resistance")
		await _click(_desk_point((_desk_snapshot().rects.latch as Rect2).get_center()))
		_check(_desk_snapshot().latch_open,"visible latch releases before lid")
		await _click(lid_point)
		await _click(lid_point)
		await create_timer(0.38).timeout
		_check(float(_desk_snapshot().lid_open)>0.99,"click opens actual lid; rapid second click cannot reverse pending motion")
		await _click(_desk_point((_desk_snapshot().rects.lid as Rect2).get_center()))
		await create_timer(0.38).timeout
		_check(float(_desk_snapshot().lid_open)<0.01,"same physical lid closes by click")
		await _click(_desk_point((_desk_snapshot().rects.lid as Rect2).get_center()))
		await create_timer(0.38).timeout
		await _click(_desk_point((_desk_snapshot().rects.letter as Rect2).get_center()))
		_check(_modal_script().ends_with("mail_workbench.gd"),"single envelope click lifts actual letter into inspection")
		_check(host.core.case_state("case01").owner=="courier","click take assigns real custody once")
		if dimensions.x==1920:await _shot("onboarding_click_inspect_1920")
		await _click(Vector2(1495,60))
		_check(not is_instance_valid(host.modal),"visible cross returns to original desk")
		_check(_desk_snapshot().waiting.is_empty(),"taken envelope does not remain as duplicate scenery")
		var disk:=Core.new();disk.save_path=host.core.save_path
		_check(disk.load_game() and disk.case_state("case01").physical.inspected_front,"close checkpoints observed face and custody")
		disk.free()
		await _click(_desk_point((_desk_snapshot().rects.depart as Rect2).get_center()))
		_check(host.view=="world","physical desk exit reaches explorable scene")
		host.queue_free();await process_frame
	var report:={"suite":"counter_onboarding_input","checks":checks,"failures":failures,"screenshots":screenshots,"scope":"Actual Godot viewport clicks at three sizes, not OS input or a first-time human playtest.","source_sha256":FileAccess.get_sha256("res://scripts/rebuild/postal_desk.gd"),"host_sha256":FileAccess.get_sha256("res://scripts/rebuild/final_playable.gd")}
	var file:=FileAccess.open("res://test-results/counter_onboarding_input.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COUNTER ONBOARDING: %d checks, %d failures"%[checks,failures.size()])
	for failure:String in failures:printerr(failure)
	quit(0 if failures.is_empty() else 1)
