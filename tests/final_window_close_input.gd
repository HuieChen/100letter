extends "res://tests/final_five_case_input.gd"
## Child of test_window_close.ps1. Gameplay uses only routed input; the harness
## sends WM_CLOSE to this process's own HWND, then a fresh process loads the save.
## Explicit engine-close mode is supplemental generated notification coverage,
## never an OS title-bar click or native-input acceptance claim.
var close_ready := ""
var close_report := ""
var close_save := ""
var verifying := false
var external_close := false
var engine_close := false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--close-ready="): close_ready=argument.trim_prefix("--close-ready=")
		if argument.begins_with("--close-report="): close_report=argument.trim_prefix("--close-report=")
		if argument.begins_with("--final-save="): close_save=argument.trim_prefix("--final-save=")
		if argument=="--close-mode=verify": verifying=true
		if argument=="--external-close": external_close=true
		if argument=="--engine-close": engine_close=true
	if external_close and engine_close:
		push_error("External and engine-generated close routes are mutually exclusive.");quit(1);return
	if verifying: _verify_closed.call_deferred()
	else: _prepare_real_close.call_deferred()

func _prepare_real_close() -> void:
	began=Time.get_ticks_msec();initial_hashes=_source_hashes()
	route="window_close"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	root.title="Solmere isolated WM_CLOSE regression"
	if engine_close:
		root.title="Dear Somewhere isolated engine-close regression"
		root.unfocusable=true
	if external_close:
		# Background launcher flags must not leave this explicitly interactive
		# native X-click fixture hidden from the supported desktop controller.
		root.hide();root.position=Vector2i(120,80);root.show()
	host=Host.new();root.add_child(host);host.size=Vector2(1600,900)
	_check(not close_save.is_empty() and not close_ready.is_empty(),"isolated save and report destinations supplied")
	if not failures.is_empty():_write_ready({});quit(1);return
	await process_frame
	await _named("NewShift")
	await _wait(func():return _node("FinishBriefing")!=null,"short supervisor briefing appears")
	await _named("FinishBriefing")
	await _enter_counter_from_room()
	await _named("Mail_case01")
	if not is_instance_valid(host.modal):_check(false,"actual box take opens workbench");_write_ready({});quit(1);return
	var bench: Control=host.modal
	await _click(bench.to_canvas(bench.model.object_rect("envelope").get_center()),MOUSE_BUTTON_RIGHT)
	var handle: Rect2=bench.drawer_handle_rect()
	await _drag(handle.get_center(),handle.get_center()+Vector2(0,44))
	await _click(bench.tool_rect("opener").get_center())
	await _drag(bench.to_canvas(bench.model.seam_point(0)),bench.to_canvas(bench.model.seam_point(8)))
	await _move_material("paper",Vector2(110,0))
	var material: Dictionary=bench.model.export_state()
	_check(material.seam_count==9 and material.opened_count==1,"real blade movement breaches the seal once")
	_check(material.paper_location=="partly_extracted" and is_equal_approx(float(material.extraction_progress),0.5),"actual paper drag leaves the letter halfway extracted")
	var display: Rect2=bench.paper_display_rect()
	var mouth: Vector2=bench.model.object_rect("envelope").position+Vector2(420,65)
	_check(display.position.is_equal_approx(mouth),"half-extracted paper is drawn continuously from the physical mouth")
	_check(display.end.x>=bench.model.object_rect("paper").end.x and is_equal_approx(display.size.x,138.0),"half-extracted drawing covers its actual grip rather than floating as a separate strip")
	_check(not host.core.state.active_operation.is_empty(),"window close will interrupt a real active material operation")
	_check(host.core.state.opening_history.size()==1 and host.core.body_text("case01").is_empty(),"breach is recorded without falsely reading the folded body")
	await _shot("before_engine_generated_close" if engine_close else "before_os_window_close")
	_write_ready(material)
	if not failures.is_empty():quit(1);return
	if engine_close:
		# Publish readiness first, then deliver the engine notification to the
		# actual host. Its save guards/audio fence own the successful quit.
		root.call_deferred("propagate_notification",Node.NOTIFICATION_WM_CLOSE_REQUEST)
		var deadline:=Time.get_ticks_msec()+35000
		while Time.get_ticks_msec()<deadline:
			await process_frame
		_check(false,"engine-generated close did not complete the actual host quit within the bounded wait")
		_write_ready(material);quit(1);return
	# Historical routes succeed only through external WM_CLOSE, never a test quit.
	await create_timer(125.0 if external_close else 35.0).timeout
	_check(false,"external WM_CLOSE was not received within the bounded wait")
	_write_ready(material);quit(1)

func _write_ready(material: Dictionary) -> void:
	var scope:="Actual box take, seam strokes and partial paper extraction; still awaiting an OS WM_CLOSE."
	if engine_close:scope="Actual routed box/seam/partial-extraction setup; readiness published before a deferred engine-generated close notification. No OS title-bar/native input is used."
	var report:={"suite":"final_window_close_prepare","engine_pid":OS.get_process_id(),"window_handle":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"steps":steps,"input_events":input_events,"screenshots":screenshots,"expected_physical":material,"save_path":close_save,"source_sha256":initial_hashes,"source_sha256_at_ready":_source_hashes(),"elapsed_ms":Time.get_ticks_msec()-began,"scope":scope,"close_method":_close_method()}
	var file:=FileAccess.open(close_ready,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()

func _verify_closed() -> void:
	began=Time.get_ticks_msec()
	var before: Variant=JSON.parse_string(FileAccess.get_file_as_string(close_ready))
	_check(before is Dictionary and before.get("failures",[]).is_empty(),"input preparation completed without failures")
	var disk:=Core.new();disk.save_path=close_save
	_check(disk.load_game(),"fresh process loads the window-close checkpoint")
	var actual: Dictionary=disk.case_state("case01").get("physical",{})
	var expected: Dictionary=before.get("expected_physical",{})
	var close_label:="Engine-generated close" if engine_close else "WM_CLOSE"
	for key: String in ["seam_count","opened_count","seal_condition","tampering_started","privacy_violation","paper_location","extraction_progress","paper_position","body_exposed"]:
		_check(actual.get(key)==expected.get(key),close_label+" preserves material field: "+key)
	_check(disk.state.active_operation.is_empty(),"quit checkpoint clears input operation rather than serializing a live grab")
	_check(disk.state.opening_history.size()==1 and disk.remaining_openings()==2,"Engine-generated close cannot refund an actual private opening" if engine_close else "OS close cannot refund an actual private opening")
	_check(disk.case_state("case01").owner=="courier" and disk.body_text("case01").is_empty(),"custody survives while folded body stays unread")
	_check(before.get("source_sha256",{})==_source_hashes(),"runtime and test sources remain stable across generated close and reload" if engine_close else "runtime and test sources remain stable across actual window close and reload")
	var scope:="Fresh-process Core.load_game after an external native X click." if external_close else "Fresh-process Core.load_game after the owning harness Win32 event."
	if engine_close:scope="Fresh-process Core.load_game after an engine-generated close notification exercised the actual host save/audio-drain path; not OS caption/native input."
	var report:={"suite":"final_window_close_verify","checks":checks,"failures":failures,"steps":steps,"elapsed_ms":Time.get_ticks_msec()-began,"source_sha256":_source_hashes(),"scope":scope,"close_method":_close_method(),"limits":["Automated input, not independent human usability.","No artwork acceptance or audio listening is implied."]}
	var file:=FileAccess.open(close_report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	disk.free()
	print("FINAL WINDOW CLOSE RELOAD ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _close_method()->String:
	if engine_close:return "engine-generated close notification (supplemental; no OS/native input)"
	return "external native X click" if external_close else "exact-owning-harness Win32 event"

func _source_hashes() -> Dictionary:
	var result:Dictionary=super._source_hashes()
	result["tests/final_window_close_input.gd"]=FileAccess.get_sha256("res://tests/final_window_close_input.gd")
	return result
