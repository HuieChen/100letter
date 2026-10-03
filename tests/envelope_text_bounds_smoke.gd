extends SceneTree
const Workbench=preload("res://scripts/rebuild/mail_workbench.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
    var bench:=Workbench.new()
    var theme:=Theme.new();theme.default_font=load("res://assets/fonts/SolmereSans.ttf")
    bench.theme=theme;root.add_child(bench)
    var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rebuild/final_cases.json"))
    for item:Dictionary in catalog.cases:
        for face:String in ["front","back"]:
            var writing:Array[String]=[]
            for key:String in item.envelope:
                var belongs:bool=key in ["back","archive_mark","recovered_fields"]
                if (face=="back")!=belongs:continue
                if key=="back" and item.id=="case03":continue
                if key=="recovered_fields":
                    var f:Dictionary=item.envelope[key]
                    writing.append("%s · %s\n%s\n%s — %s"%[f.original_address,f.forwarding_recipient,f.forwarding_destination,f.forwarding_valid_from,f.forwarding_valid_until])
                elif str(item.envelope[key])!="water-damaged":writing.append(str(item.envelope[key]))
            var safe:=Rect2(0,0,340,148) if face=="front" else Rect2(0,0,362,88)
            var layout:Dictionary=bench.envelope_text_layout("\n".join(writing),safe,20 if face=="front" else 17)
            _check(safe.encloses(layout.rect),str(item.id)+" "+face+" current postal writing stays on paper")
            _check(layout.font_size>=14,str(item.id)+" "+face+" remains legible at normal paper scale")
    var chinese:=bench.envelope_text_layout("艾尔西·莫兰\n索尔梅尔 · 旧码头巷十七号\n回邮：露丝·莫兰，贝尔玛",Rect2(0,0,340,148),20)
    _check(chinese.safe.encloses(chinese.rect) and chinese.font_size>=16,"Chinese postal inscription wraps without running into the stamp edge")
    print("ENVELOPE TEXT BOUNDS: ",checks," checks, ",failures.size()," failures")
    bench.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
func _check(ok:bool,label:String) -> void:
    checks+=1
    if not ok:failures.append(label);push_error(label)
