extends SceneTree
## Isolated public-API fixtures plus genuine GUI clicks; not a complete player route.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Core=preload("res://scripts/rebuild/final_case_state.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();root.add_child(game);game.size=Vector2(1600,900)
	var slot:="user://qa/host-boundary-"+str(Time.get_ticks_usec())+".json"
	game.core.save_path=slot;game.core.new_game()
	_ok(game.core.take_case("case01"),"fixture physically owned first letter")
	_ok(game.core.inspect_envelope("case01","front"),"fixture read first envelope")
	_ok(game.core.dispose("case01","hold_for_verification","","未核实旧地址，留待当班查证。"),"fixture legitimate first disposition")
	var record:={"determination":{"recipient":"待核实","location":"邮局","status":"留待核实"},"disposition":"hold_for_verification","note":"保留原记录","stamped":true}
	_ok(game.core.record_resolution("case01",record),"fixture real first resolution unlocks next mail")
	game._counter();game._registry();await process_frame
	var before:=JSON.stringify(game.core.state)
	await _click("Register_case02")
	_check(game.core.case_state("case02").owner=="desk_b","registry cannot take a letter through text")
	_check(JSON.stringify(game.core.state)==before,"blocked registry leaves custody and all core progress unchanged")
	_check(game.view=="counter" and not is_instance_valid(game.modal),"blocked registration returns to actual physical box")
	game._workbench("case02")
	_check(not is_instance_valid(game.modal) and game.core.case_state("case02").owner=="desk_b","direct workbench entry cannot substitute for real box pickup")
	game._bag();await process_frame
	_check(game.find_child("Envelope_case02",true,false)==null,"bag has no uncollected letter")
	game._close();game._registry();await process_frame
	await _click("RecordedResolution_case01")
	_check(_count_editors(game.modal)==0,"completed resolution is a read-only paper")
	_check(game.core.resolution_view("case01").note=="保留原记录","reading cannot overwrite stamped content")
	game._close()
	_ok(game.core.take_case("case02"),"fixture courier owns a second actual object")
	game._bag();await process_frame;await _click("Envelope_case02")
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=Vector2(1495,60);e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true);await process_frame
	await create_timer(0.22).timeout
	_check(not is_instance_valid(game.modal),"actual envelope inspection closes before onward journey")
	_ok(game.core.travel("community_center",15),"fixture reaches real cubby location")
	game._world();await process_frame
	await _click("MailCubby")
	for i in range(700):
		if not game.walker.walking:break
		await process_frame
	_check(game.core.case_state("case02").disposition=="" and game.core.case_state("case02").owner=="courier","cubby never impersonates a person for another mail type")
	_check(game.carried=="case02","rejected cubby leaves the same physical letter in hand")
	game._title()
	var future_path:=slot+".future"
	var future:=JSON.stringify({"format":Core.FORMAT,"version":999,"payload_json":"future data retained"})
	var f:=FileAccess.open(future_path,FileAccess.WRITE);f.store_string(future);f.close()
	game.core.save_path=future_path
	await _click("NewShift")
	_check(game.view=="title" and not game._briefing_pending,"unwritable future slot does not start an unsavable shift")
	_check(is_instance_valid(game.modal) and _text(game.modal).contains("暂时无法开始"),"new-shift save failure is visibly explained")
	_check(FileAccess.get_file_as_string(future_path)==future,"future save bytes are preserved exactly")
	game._close();game.core.save_path=slot;game.core.new_game()
	_ok(game.core.take_case("case01"),"fixture owned paper for exit integration")
	game._counter();game._workbench("case01");await process_frame
	var bench:Control=game.modal
	_check(bench.has_method("checkpoint_for_quit"),"hosted workbench exposes stable quit checkpoint")
	_check(game._prepare_quit(),"host quit preparation persists actual physical component")
	var loaded:=Core.new();root.add_child(loaded);loaded.save_path=slot
	_check(loaded.load_game() and loaded.case_state("case01").owner=="courier","quit preparation can resume the same object from disk")
	game.core.save_path=future_path
	_check(not game._prepare_quit(),"window close is blocked when safe checkpoint cannot write")
	_check(game.modal==bench and is_instance_valid(bench),"failed close keeps the current workbench visible")
	_check(game.find_child("SaveFailureNotice",true,false)!=null,"failed close has a visible persistent explanation")
	_check(FileAccess.get_file_as_string(future_path)==future,"failed quit never downgrades an unknown save")
	print("FINAL HOST BOUNDARY: %d checks, %d failures"%[checks,failures.size()])
	loaded.queue_free();game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
func _click(name:String)->void:
	var c:Control=game.find_child(name,true,false);_check(c!=null,"real input target "+name)
	if c==null:return
	var point:=c.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true);await process_frame
func _count_editors(node:Node)->int:
	var n:=1 if node is LineEdit or node is TextEdit else 0
	for child in node.get_children():n+=_count_editors(child)
	return n
func _text(node:Node)->String:
	var s:=str(node.text) if node is Label or node is RichTextLabel else ""
	for child in node.get_children():s+=_text(child)
	return s
func _ok(error:String,label:String)->void:_check(error.is_empty(),label+": "+error)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
