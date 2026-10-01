extends SceneTree
const Core=preload("res://scripts/rebuild/final_case_state.gd")
const Desk=preload("res://scripts/rebuild/postal_desk.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var core:=Core.new();root.add_child(core);core.new_game()
	var desk:=Desk.new();desk.size=Vector2(1600,900);root.add_child(desk);desk.configure(core)
	check(desk.waiting==["case01"],"one real initial mail appears")
	check(core.changed.is_connected(desk.refresh),"counter actually subscribes to core changes")
	ok(core.take_case("case01"));ok(core.inspect_envelope("case01","front"))
	check(desk.waiting.is_empty(),"taken mail disappears without recreating desk")
	ok(core.dispose("case01","hold_for_verification","","QA queue fixture awaiting address verification."))
	ok(core.record_resolution("case01",{"determination":{"recipient":"未核实","location":"待现场核实","status":"完整未拆"},"disposition":"hold_for_verification","note":"QA explicit held mail resolution.","stamped":true}))
	check(desk.waiting==["case02","case03"],"actual first stamped resolution updates the same desk")
	for id:String in ["case02","case03"]:
		ok(core.take_case(id));ok(core.inspect_envelope(id,"front"));ok(core.dispose(id,"hold_for_verification","","QA queue fixture retains unresolved sealed mail."))
	ok(core.travel("community_center",15));ok(core.observe("june_current_mailpoint"));ok(core.travel("post_office",15))
	ok(core.discover_archive_box())
	check(desk.waiting==["case04"],"archive discovery updates existing container")
	ok(core.take_case("case04"));ok(core.inspect_envelope("case04","back"));ok(core.observe("case04_archive_mark"))
	ok(core.dispose("case04","archive_review","","QA traced old item kept for review."))
	check(desk.waiting.is_empty(),"processed old mail is absent before ledger clue")
	ok(core.observe("ledger_hv_repeat"))
	check(desk.waiting==["case05"],"real ledger observation immediately exposes staff sleeve on unchanged desk")
	check(core.case_state("case05").owner=="ledger_sleeve","display update does not take ownership")
	desk.configure(core)
	check(desk.waiting==["case05"],"reconfiguration keeps one subscription and one item")
	var report:={"suite":"postal_desk_live_queue","checks":checks,"failures":failures,"scope":"Public core operation fixtures plus actual core.changed subscription; not pointer or visual verification.","desk_sha256":FileAccess.get_sha256("res://scripts/rebuild/postal_desk.gd"),"core_sha256":FileAccess.get_sha256("res://scripts/rebuild/final_case_state.gd")}
	var out:=FileAccess.open("res://test-results/postal_desk_live_queue.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("POSTAL DESK LIVE QUEUE: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func ok(error:String)->void:check(error.is_empty(),"public operation accepted: "+error)
