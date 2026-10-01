extends SceneTree
var board:Control
var checks:int=0
var failures:int=0
var events:Array[String]=[]
var dismissals:int=0
func _initialize()->void: _run.call_deferred()
func check(value:bool, message:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func focus_action(action:String)->void:
	for attempt:int in range(20):
		if board._focused_action()==action: return
		key(KEY_TAB)
	check(false,'keyboard action available: '+action)
func activate_action(action:String)->void:
	focus_action(action)
	key(KEY_ENTER)
func click(point:Vector2)->void:
	point=board._origin()+point*board._factor()
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point
	board._gui_input(down)
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=point
	board._gui_input(up)
func drag(a:Vector2,b:Vector2)->void:
	a=board._origin()+a*board._factor()
	b=board._origin()+b*board._factor()
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=a
	board._gui_input(down)
	for i:int in range(1,9):
		var move:=InputEventMouseMotion.new()
		move.position=a.lerp(b,float(i)/8);move.button_mask=MOUSE_BUTTON_MASK_LEFT
		board._gui_input(move)
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=b
	board._gui_input(up)
func key(code:int,shift:bool=false)->void:
	var input:=InputEventKey.new();input.pressed=true;input.keycode=code;input.shift_pressed=shift
	board._gui_input(input)
func reset(id:String, data:Dictionary={})->void:
	board.configure(id,data)
	events.clear()
	click(Vector2(1040,624))
	check(events.is_empty(),id+' never grants before observations')
func finish(id:String)->void:
	check(board.ready_to_record,id+' observation complete')
	check(events.is_empty(),id+' does not auto-record')
	click(Vector2(1040,624))
	check(events==[id],id+' records exact id once')
	click(Vector2(1040,624))
	check(events==[id],id+' duplicate stamp suppressed')
func capture(name:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png('user://evidence_'+name+'.png')
func _run()->void:
	root.size=Vector2i(1180,680)
	root.content_scale_size=Vector2i(1180,680)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var theme_value:=Theme.new()
	theme_value.default_font=load('res://assets/fonts/SolmereSans.ttf')
	board=load('res://scripts/ui/visual_evidence.gd').new()
	board.size=Vector2(1180,680);board.theme=theme_value
	root.add_child(board)
	board.observed.connect(func(id:String)->void:events.append(id))
	board.dismissed.connect(func()->void:dismissals+=1)
	reset('old_civic_hall_name')
	await capture('plaque_closed')
	drag(Vector2(450,350),Vector2(450,180))
	click(Vector2(430,391));finish('old_civic_hall_name')
	await capture('plaque')
	reset('resident_moved')
	drag(Vector2(460,323),Vector2(800,323))
	click(Vector2(359,343));click(Vector2(950,294));finish('resident_moved')
	await capture('resident')
	reset('old_nameplate')
	click(Vector2(700,325));check(not board.reversed,'registry cannot open while strip caught')
	drag(Vector2(360,349),Vector2(150,349))
	click(Vector2(714,323));click(Vector2(685,379));finish('old_nameplate')
	await capture('registry')
	reset('bus_to_lookout',{'minute':840,'deadline':1080})
	click(Vector2(167,399));click(Vector2(820,266));check(not board.ready_to_record,'wrong destination not enough')
	click(Vector2(588,242));click(Vector2(820,180));check(not board.ready_to_record,'past departure invalid')
	click(Vector2(820,266));finish('bus_to_lookout')
	await capture('timetable')
	reset('bus_to_lookout',{'minute':1055,'deadline':1080})
	click(Vector2(588,242));click(Vector2(820,352));check(not board.ready_to_record,'all departures passed')
	click(Vector2(958,536));finish('bus_to_lookout')
	reset('event_archive')
	click(Vector2(680,400));check(not board.ready_to_record,'closed archive conceals names')
	drag(Vector2(603,340),Vector2(893,340))
	click(Vector2(353,391));click(Vector2(650,405));finish('event_archive')
	await capture('archive')
	reset('handwriting_sample')
	await capture('handwriting_initial')
	drag(Vector2(805,220),Vector2(255,214))
	click(Vector2(161,255));click(Vector2(236,369));finish('handwriting_sample')
	await capture('handwriting')
	reset('old_photo',{'acquired':true})
	click(Vector2(792,365));click(Vector2(855,521));click(Vector2(425,505));finish('old_photo')
	await capture('photo_back')
	reset('repair_address',{'acquired':true})
	click(Vector2(445,340));click(Vector2(825,257));finish('repair_address')
	await capture('repair')
	reset('current_postmark',{'acquired':true})
	click(Vector2(447,278));click(Vector2(825,257));finish('current_postmark')
	reset('old_civic_hall_name')
	key(KEY_TAB);key(KEY_ENTER);key(KEY_TAB);key(KEY_ENTER);key(KEY_TAB);key(KEY_ENTER)
	finish('old_civic_hall_name')
	key(KEY_ESCAPE);check(dismissals==1,'Esc dismiss supported')
	reset('event_archive')
	click(Vector2(75,625));check(board.hint_level==1,'first hint')
	click(Vector2(75,625));check(board.hint_level==2,'second hint')
	click(Vector2(75,625));check(board.hint_level==2,'hints bounded')
	check(events.is_empty(),'hints never grant clue')
	click(Vector2(1144,34));check(dismissals==2,'close button dismiss supported')
	for entry:Array in [
		['resident_moved',['cover','old_label','moving_note']],
		['old_nameplate',['cover','turn_registry','name_record']],
		['event_archive',['cover','event_date','event_names']],
		['old_photo',['photo_detail','turn_photo','photo_date']],
		['repair_address',['address','postmark']],
		['bus_to_lookout',['stop_2','departure_1']]
	]:
		reset(entry[0],{'minute':840})
		for action:String in entry[1]: activate_action(action)
		check(board.ready_to_record,entry[0]+' keyboard observations complete')
		activate_action('record')
		check(events==[entry[0]],entry[0]+' keyboard records exact clue')
	reset('handwriting_sample')
	activate_action('m_stroke');check(not board.ready_to_record,'keyboard cannot inspect unaligned strokes')
	focus_action('overlay')
	for count:int in range(27): key(KEY_LEFT)
	for count:int in range(5): key(KEY_LEFT,true)
	for count:int in range(3): key(KEY_UP,true)
	activate_action('m_stroke');activate_action('y_stroke')
	check(board.ready_to_record,'keyboard handwriting aligned and observed')
	activate_action('record');check(events==['handwriting_sample'],'keyboard handwriting record')
	board.size=Vector2(944,544)
	reset('old_civic_hall_name')
	drag(Vector2(450,350),Vector2(450,180));click(Vector2(430,391));finish('old_civic_hall_name')
	board.size=Vector2(1180,680)
	print('VISUAL_EVIDENCE_CHECKS=',checks,' FAILURES=',failures)
	quit(0 if failures==0 else 1)



