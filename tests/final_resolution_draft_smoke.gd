extends SceneTree
## Real form keyboard input with isolated public-API prerequisites; no fabricated stamp.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Store=preload("res://scripts/rebuild/resolution_draft_store.gd")
var game:Control
var checks:=0
var events:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();root.add_child(game);game.size=Vector2(1600,900)
	var slot:="user://qa/resolution-draft-"+str(Time.get_ticks_usec())+".json"
	game.core.save_path=slot;game.core.new_game()
	_ok(game.core.take_case("case01"),"fixture first object is physically carried")
	_ok(game.core.inspect_envelope("case01","front"),"fixture first envelope has been inspected")
	_ok(game.core.dispose("case01","hold_for_verification","","需现场核实旧地址。"),"fixture honest unresolved disposition")
	_check(game.core.save_game(),"fixture actual disposition is saved")
	game._counter();game._resolution("case01");await process_frame
	await _fill("Field_recipient","待确认 · Elsie")
	await _fill("Field_location","旧海阶 17 号")
	await _fill("Field_status","原封，待核实")
	var note:="门牌可能已更换；先保留信封上的地址，不把猜测当作结论。"
	await _fill("ResolutionNote",note)
	_check(game.modal.export_draft().note==note,"Unicode note is entered through keyboard input")
	_check(game._prepare_quit(),"quit preparation captures an open unstamped form")
	var draft_path:=slot+".drafts-v1.json"
	var saved:Dictionary=Store.read(draft_path)
	_check(saved.case01.note==note,"sidecar saves current text without requiring modal close")
	_check(not saved.case01.has("stamped"),"draft schema cannot pretend the form was stamped")
	_check(game.core.resolution_view("case01").is_empty(),"saving text does not create a postal resolution")
	_check(not game.core.case_state("case02").available,"draft save does not unlock the second letter")
	game.queue_free();await process_frame;await process_frame
	game=Host.new();root.add_child(game);game.size=Vector2(1600,900);game.core.save_path=slot
	game._resume();game._counter();game._resolution("case01");await process_frame
	_check(game.modal.export_draft().determination.recipient=="待确认 · Elsie","new host resumes recipient draft from disk")
	_check(game.modal.export_draft().determination.location=="旧海阶 17 号","new host resumes location draft from disk")
	_check(game.modal.export_draft().note==note,"new host resumes full note from disk")
	await _fill("ResolutionNote",note+" 已再次确认。")
	await _click("Close")
	_check(not is_instance_valid(game.modal),"real close returns to the counter after saving")
	game._save_to_title();await process_frame
	_check(game.view=="title","save and return to title succeeds with the retained draft")
	await _click("ContinueShift");game._counter();game._resolution("case01");await process_frame
	_check(game.modal.export_draft().note.ends_with("已再次确认。"),"continue preserves last closed draft")
	var good_bytes:=FileAccess.get_file_as_string(draft_path)
	var unknown:='{"format":"solmere-resolution-drafts","version":999,"future":"keep me"}'
	_write(draft_path,unknown)
	await _click("Close")
	_check(is_instance_valid(game.modal),"unknown draft version prevents destructive close")
	_check(not game.modal._closed and game.modal._note.editable,"failed close remains editable and can be retried")
	_check(FileAccess.get_file_as_string(draft_path)==unknown,"future draft bytes remain unchanged")
	_check(game.find_child("SaveFailureNotice",true,false)!=null,"failed save has a visible persistent explanation")
	_write(draft_path,good_bytes)
	await _click("Close")
	_check(not is_instance_valid(game.modal),"second real close succeeds after write boundary is repaired")
	var forged:Dictionary=saved.duplicate(true);forged.case01.stamped=true
	var before:=FileAccess.get_file_as_string(draft_path)
	_check(not Store.write(draft_path,forged).is_empty(),"injected stamp flag is rejected")
	_check(FileAccess.get_file_as_string(draft_path)==before,"rejected flag cannot overwrite a valid draft")
	forged=saved.duplicate(true);forged.case01.determination.secret_answer="author truth"
	_check(not Store.write(draft_path,forged).is_empty(),"unknown determination keys are rejected")
	forged=saved.duplicate(true);forged.case01.note="a".repeat(501)
	_check(not Store.write(draft_path,forged).is_empty(),"overlength notes fail visibly rather than silently truncating")
	var corrupt_slot:=draft_path+".recovery"
	_ok(Store.write(corrupt_slot,saved),"first atomic draft write")
	var newer:Dictionary=saved.duplicate(true);newer.case01.note="newer"
	_ok(Store.write(corrupt_slot,newer),"second write retains prior valid backup")
	_write(corrupt_slot,"{broken")
	_check(Store.read(corrupt_slot).case01.note==note,"corrupt primary recovers the last verified draft")
	_ok(Store.reset(corrupt_slot),"confirmed new shift clears both current and backup drafts")
	_write(corrupt_slot,"{broken again")
	_check(Store.read(corrupt_slot).is_empty(),"corrupt new-shift draft cannot revive the previous shift")
	var stale:Dictionary=saved.duplicate(true);stale.case01.disposition="deliver"
	_ok(Store.write(draft_path,stale),"fixture inconsistent stale draft is a syntactically valid UI record")
	game._load_resolution_drafts()
	_check(game._resolution_drafts.is_empty(),"draft with different actual disposition is not shown")
	_check(game.core.resolution_view("case01").is_empty(),"all recovery paths leave the actual stamp gate untouched")
	var report:={"suite":"final_resolution_drafts","checks":checks,"failures":failures,"input_events":events,"scope":"Real Godot keyboard and pointer inputs on the hosted form, isolated public core fixture; saved open/closed draft, resume, blocked-close retry, invalid schema and backup recovery. No OS close assertion and no complete five-case route claim.","source_sha256":{},"renderer":RenderingServer.get_current_rendering_method()}
	for path:String in ["scripts/rebuild/final_playable.gd","scripts/rebuild/resolution_draft_store.gd","scripts/rebuild/resolution_slip.gd","tests/final_resolution_draft_smoke.gd"]:report.source_sha256[path]=FileAccess.get_sha256("res://"+path)
	var out:=FileAccess.open("res://test-results/final_resolution_draft_results.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("FINAL RESOLUTION DRAFTS: %d checks, %d failures, %d input events"%[checks,failures.size(),events])
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
func _fill(id:String,text:String)->void:
	await _click(id);await _key(KEY_A,true)
	for character:String in text:
		var e:=InputEventKey.new();e.pressed=true;e.unicode=character.unicode_at(0);root.push_input(e,true);events+=1
	await process_frame
func _click(id:String)->void:
	var c:Control=game.find_child(id,true,false);_check(c!=null,"input target "+id)
	if c==null:return
	var p:=c.get_global_rect().get_center()
	for down:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);events+=1;await process_frame
func _key(code:int,ctrl:bool=false)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.pressed=down;e.ctrl_pressed=ctrl;root.push_input(e,true);events+=1;await process_frame
func _write(path:String,content:String)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(content);file.close()
func _ok(error:String,label:String)->void:_check(error.is_empty(),label+": "+error)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
