extends "res://tests/final_five_case_input.gd"
## Targeted hosted integration after legitimate teaching-mail completion.
## Uses real material input and in-scene dialogue, never core completion calls.
var bench: Control

func _initialize() -> void:
	route = "amended_handoff"
	_run.call_deferred()
	create_timer(180.0).timeout.connect(func():
		if not report_written:
			_check(false,"targeted amendment route watchdog")
			_finish_five())

func _continue_five() -> void:
	await _inspect_bag_case("case02")
	bench = host.modal
	var original := ""
	_check(host.core.body_text("case02").is_empty(),"sealed urgent letter does not expose amendment content")
	await _material_tool("opener")
	await _drag(bench.to_canvas(bench.model.seam_point(0)),bench.to_canvas(bench.model.seam_point(8)))
	_check(bench.model.export_state().seam_count==9 and host.core.body_text("case02").is_empty(),"real seam opening precedes private reading")
	await _move_material("paper",Vector2(220,0))
	await _move_material("fold_0",Vector2(120,0))
	await _move_material("fold_1",Vector2(0,120))
	original = host.core.source_body_text("case02")
	_check(not original.is_empty() and host.core.body_text("case02")==original and host.core.remaining_openings()==2,"actual unfolding reveals original and spends exactly one opening")
	await _material_tool("eraser")
	await _shot("selected_original_phrase")
	var phrase: Rect2 = bench.model.object_rect("phrase")
	await _drag(bench.to_canvas(phrase.position+Vector2(3,12)),bench.to_canvas(phrase.position+Vector2(phrase.size.x-3,12)))
	_check(bench.model.export_state().erase_mask==255,"actual eraser crosses every selected phrase segment")
	await _move_material("replacement",phrase.position-bench.model.object_rect("replacement").position)
	_check(bench.model.export_state().replacement_placed and host.core.body_text("case02")!=original,"actual replacement changes only the carried version")
	_check(host.core.source_body_text("case02")==original,"immutable authored body survives physical amendment")
	await _shot("replacement_placed")
	await _key(KEY_ESCAPE)
	await _click(bench.to_canvas(bench.model.object_rect("fold_0").get_center()))
	await _move_material("fold_0",Vector2(120,0))
	await _move_material("fold_1",Vector2(0,120))
	var mouth: Vector2 = bench.model.object_rect("envelope").position+Vector2(420,65)
	await _move_material("paper",mouth-bench.model.object_rect("paper").position)
	await _move_material("flap",Vector2(0,90))
	await _material_tool("sealer")
	await _click(bench.to_canvas(bench.model.object_rect("flap").get_center()))
	_check(host.core.case_state("case02").physical.resealed,"amended letter is actually folded inserted and resealed")
	await _key(KEY_ESCAPE)
	await _travel("lookout")
	await _carry_case("case02")
	await _named("Talk_mira_vale")
	await _wait(func():return is_instance_valid(host.modal),"reach Mira for actual amended handoff")
	await _named("AdvanceDialogue")
	await _named("Choice_deliver")
	_check(host.core.case_state("case02").owner=="mira_vale","actual amended object changes custody to Mira")
	_check(host.core.recipient_feedback("case02").is_empty(),"handoff alone does not disclose an unseen reading reaction")
	await _named("AdvanceDialogue")
	await _named("Choice_reading_case02")
	_check(host.core.recipient_feedback("case02").is_empty() and _node("Speaker").text=="你","player request precedes witnessed recipient response")
	await _named("AdvanceDialogue")
	var receipt: Dictionary = host.core.case_state("case02").alterations.receipt
	_check(receipt.get("status")=="witnessed" and "case02_request_changed" in receipt.get("consequence_ids",[]),"actual in-scene reading sees the received altered phrase")
	_check(not host.core.recipient_feedback("case02").is_empty() and _node("SpokenLine").text==host.core.recipient_feedback("case02"),"visible NPC line matches witnessed consequence without advance disclosure")
	await _shot("mira_witnessed_reaction")
	await _named("AdvanceDialogue")
	await _named("Choice_leave")
	await _return_counter()
	await _record_case("case02","Mira Vale","Lookout","Amended paper delivered and recipient reading witnessed")
	_check(host.core.resolution_view("case02").get("stamped",false),"amended actual delivery still requires its own physical postal stamp")

func _material_tool(id: String) -> void:
	if not bench.get_workbench_snapshot().drawer.opened:
		var handle: Rect2 = bench.drawer_handle_rect()
		await _drag(handle.get_center(),handle.get_center()+Vector2(0,44))
	await _click(bench.tool_rect(id).get_center())

func _finish_five() -> void:
	if report_written:return
	report_written=true
	var final_hashes:=_source_hashes()
	_check(initial_hashes==final_hashes,"sources remained unchanged throughout targeted amendment integration")
	var report:={"suite":"final_amended_handoff_input","checks":checks,"failures":failures,"steps":steps,"input_events":input_events,"screenshots":screenshots,"elapsed_ms":Time.get_ticks_msec()-began,"source_sha256":initial_hashes,"source_sha256_at_finish":final_hashes,"receipt":host.core.case_state("case02").alterations.receipt,"scope":"Actual hosted teaching-mail completion, Case02 physical opening/limited replacement/reseal, on-site handoff, witnessed NPC reaction, and manually stamped resolution.","limits":["Targeted integration, not a second full five-case route.","No human usability, artwork acceptance or audio listening claim."]}
	var file:=FileAccess.open("res://test-results/final_amended_handoff_input.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FINAL AMENDED HANDOFF INPUT ",checks," checks / ",failures.size()," failures")
	for player:Node in host.find_children("*","AudioStreamPlayer",true,false):player.stop();player.stream=null
	await create_timer(0.15).timeout
	host.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)

func _source_hashes() -> Dictionary:
	var result:Dictionary=super._source_hashes()
	result["tests/final_amended_handoff_input.gd"]=FileAccess.get_sha256("res://tests/final_amended_handoff_input.gd")
	return result
