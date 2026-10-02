class_name FinalPostalDesk
extends Control
## Counter container: physical lid and envelope movements, no case menu or game-state shortcuts.
signal mail_taken(case_id: String, source_rect: Rect2)
signal handbook_requested
signal registry_requested
signal archive_requested
signal depart_requested
signal cue(name: String)
const Art = preload("res://scripts/rebuild/physical_art.gd")
const CAMERA := Rect2(-640,-697,2880,1620)
const BOX_BASE := Rect2(500,490,620,250)
const LETTER := Rect2(617,509,390,112)
const INSPECTION := Rect2(340,145,900,650)
const BOOK := Rect2(155,511,220,273)
const SLIP := Rect2(1285,444,143,210)
const LATCH := Rect2(777,618,71,52)
var caption_suppressed: bool = false:
	set(value):
		caption_suppressed=value
		queue_redraw()
var core: Node
var waiting: Array[String] = []
var latch_open := false
var _latch_pose := 0.0
var lid_open := 0.0
var held := ""
var letter_rect := LETTER
var _drag_start := Vector2.ZERO
var _offset := Vector2.ZERO
var _lid_start := 0.0
var _fit := 1.0
var _message := ""
var _message_left := 0.0
var _pending := false

func configure(game:Node) -> void:
	if is_instance_valid(core) and core.changed.is_connected(refresh):core.changed.disconnect(refresh)
	core=game
	if not core.changed.is_connected(refresh):core.changed.connect(refresh)
	refresh()
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(func():_fit=minf(size.x/1600.0,size.y/900.0);queue_redraw())
	_fit=minf(size.x/1600.0,size.y/900.0)

func refresh() -> void:
	waiting.clear()
	if core != null:
		for id: String in core.CASE_IDS:
			var item: Dictionary = core.case_state(id)
			if item.available and str(item.disposition).is_empty() and item.owner in ["desk_b","archive_box","ledger_sleeve"]:
				waiting.append(id)
	_pending=false
	letter_rect=LETTER
	queue_redraw()

func _process(delta: float) -> void:
	_message_left=maxf(0.0,_message_left-delta)
	_latch_pose=move_toward(_latch_pose,1.0 if latch_open else 0.0,delta*7.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if _pending:return
	if event is InputEventMouseMotion:
		var p:Vector2=event.position/_fit
		if held=="lid":lid_open=clampf(_lid_start+(_drag_start.y-p.y)/230.0,0,1)
		elif held=="letter":letter_rect.position=(p-_offset).clamp(Vector2(40,50),Vector2(1170,590))
		mouse_default_cursor_shape=Control.CURSOR_DRAG if not held.is_empty() else (Control.CURSOR_POINTING_HAND if _any_target(p) else Control.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var p:Vector2=event.position/_fit
		if event.pressed:
			grab_focus()
			if lid_open>0.88 and not waiting.is_empty() and LETTER.has_point(p):
				held="letter";_drag_start=p;_offset=p-letter_rect.position;cue.emit("paper")
			elif LATCH.has_point(p) and lid_open<0.1:
				latch_open=not latch_open;cue.emit("tool");_say("扣已经松开。拿住箱盖向上掀。" if latch_open else "锁扣合上了。")
			elif _lid_rect().has_point(p):
				if latch_open:held="lid";_drag_start=p;_lid_start=lid_open
				else:_say("先松开箱子前面的锁扣。")
			elif BOOK.has_point(p):handbook_requested.emit()
			elif SLIP.has_point(p):registry_requested.emit()
			elif Rect2(16,50,157,285).has_point(p):archive_requested.emit()
			elif Rect2(26,767,148,73).has_point(p):depart_requested.emit()
		else:
			var previous:=held;held=""
			if previous=="lid":
				if lid_open>0.88:lid_open=1.0;cue.emit("door");_say("从箱里取出一封，放到面前。" if not waiting.is_empty() else "箱里暂时没有待取件。")
				elif lid_open<0.08:lid_open=0.0
			elif previous=="letter":
				if p.distance_to(_drag_start)>95 and INSPECTION.has_point(p) and not LETTER.has_point(p):
					_pending=true;mail_taken.emit(waiting[0],Rect2(letter_rect.position,Vector2(390,219)))
				else:letter_rect=LETTER;cue.emit("paper")
		accept_event();queue_redraw()

func _any_target(p:Vector2) -> bool:
	return LATCH.has_point(p) or _lid_rect().has_point(p) or BOOK.has_point(p) or SLIP.has_point(p) or (lid_open>0.88 and LETTER.has_point(p))

func _lid_rect() -> Rect2:
	var edge:=lerpf(627,289,lid_open)
	return Rect2(501,minf(edge,490),620,maxf(6,absf(edge-490)))

func _paint_lid() -> void:
	var rect:=_lid_rect()
	if lid_open<0.405:
		draw_set_transform(Vector2(0,rect.position.y+rect.end.y)*_fit,0,Vector2(_fit,-_fit))
	Art.paint(self,"mail_box_lid",rect)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_fit)

func _paint_latch() -> void:
	# The upper cylinder is the hinge; a single generated hasp rotates clear of its receiver.
	draw_set_transform(Vector2(810,611)*_fit,lerpf(0.0,-1.72,_latch_pose),Vector2.ONE*_fit)
	Art.paint(self,"mail_box_latch",Rect2(-10,-4,20,58),Color.WHITE,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_fit)
func _say(message:String) -> void:
	_message=message;_message_left=4.5

func get_desk_snapshot() -> Dictionary:
	return {"waiting":waiting.duplicate(),"latch_open":latch_open,"lid_open":lid_open,"held":held,"pending":_pending,
		"rects":{"lid":_lid_rect(),"latch":LATCH,"letter":letter_rect,"inspection":INSPECTION,"book":BOOK,"slip":SLIP,"archive":Rect2(16,50,157,285),"depart":Rect2(26,767,148,73)},
		"art":Art.readiness(["BG_workroom","mail_box_base","mail_box_lid","mail_box_latch","envelope_front","handbook_closed","resolution_slip"])}

func _draw() -> void:
	if _fit<=0:return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_fit)
	Art.paint(self,"BG_workroom",CAMERA)
	# Lid is a separate asset whose lower edge is the hinge. All motion is input-driven.
	if lid_open>0.405:_paint_lid()
	Art.paint(self,"mail_box_base",BOX_BASE)
	if lid_open>0.82:
		for index:int in range(waiting.size()-1,-1,-1):
			if index==0 and held=="letter":continue
			Art.paint(self,"envelope_front",Rect2(LETTER.position+Vector2(index*7,-index*8),Vector2(390,219)))
		var base:Texture2D=Art.texture("mail_box_base")
		if base!=null:
			var fraction:=0.525
			draw_texture_rect_region(base,Rect2(BOX_BASE.position+Vector2(0,BOX_BASE.size.y*fraction),Vector2(BOX_BASE.size.x,BOX_BASE.size.y*(1-fraction))),Rect2(0,base.get_height()*fraction,base.get_width(),base.get_height()*(1-fraction)))
	if lid_open<=0.405:_paint_lid()
	_paint_latch()
	Art.paint(self,"handbook_closed",BOOK)
	Art.paint(self,"resolution_slip",SLIP)
	if held=="letter":Art.paint(self,"envelope_front",Rect2(letter_rect.position,Vector2(390,219)))
	var font:Font=get_theme_font("font")
	draw_string(font,Vector2(35,813),"← 门外",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ede4ca"))
	if _message_left>0 and not caption_suppressed:
		draw_string(font,Vector2(355,867),_message,HORIZONTAL_ALIGNMENT_LEFT,1030,22,Color("f5ebd1"))
	draw_set_transform(Vector2.ZERO)
