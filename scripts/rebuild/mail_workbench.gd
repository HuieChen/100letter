class_name MailWorkbench
extends Control
## Real input adapter for final-v1 paper state. No author catalog is bound to UI.
signal closed
signal cue(name: String)
signal inspection_completed(mode: String)

const Paper = preload("res://scripts/rebuild/mail_physics_state.gd")
const Art = preload("res://scripts/rebuild/physical_art.gd")
const Drawer = preload("res://scripts/rebuild/tool_drawer.gd")
const ORIGIN := Vector2(210,145)
const INK := Color("365955")
const CREAM := Color("f3efdf")
const PAPER := Color("fff8e8")
const TOOLS := ["hand","restorer","press","opener","amend","eraser","reseal","sealer"]
const LABELS := {"hand":"放下工具","restorer":"起标签","press":"压合","opener":"封口工具","amend":"查看可动内页","eraser":"擦除选定句","reseal":"折回装信","sealer":"封合"}
const READING_PAPER := Rect2(508,54,584,803)


var _hint_shade: GradientTexture2D
var _hover_tool := ""
var model = Paper.new()
var core: Node
var case_id := ""
var body_reader: RichTextLabel
var _snapshot: Dictionary = {}
var _view: Dictionary = {}
var _tool := ""
var _drag := ""
var _tool_down := false
var _last_contact := Vector2.ZERO
var _pointer := Vector2.ZERO
var _panning := false
var _pan_start := Vector2.ZERO
var _pointer_start := Vector2.ZERO
var _reading := false
var _reading_original := false
var _message := "拿住信封可以移动。右键翻面，滚轮放大；中键拖动画面。"
var _save_problem := false
var _closing := false
var _fit := 1.0
var _amending := false
var _amendment_options: Dictionary = {}
var drawer = Drawer.new()
var _magnifier := false
var _magnifier_held := false
var _magnifier_at := Vector2(950,380)
var _magnifier_offset := Vector2.ZERO
var _lens: ColorRect
var _glass_sprite: TextureRect
var _presentation_from := Rect2()
var _presentation := 1.0
var _rejection := 0.0
const EDIT_ORIGIN := Vector2(570,170)
const EDIT_ZOOM := 2.15

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter=Control.MOUSE_FILTER_STOP
	focus_mode=Control.FOCUS_ALL
	_ensure_art()
	_ensure_reader()
	_ensure_lens()
	resized.connect(_resize)
	_resize()

func configure(game: Node, id: String) -> String:
	core=game;case_id=id
	var state: Dictionary=core.case_state(id)
	if state.is_empty() or state.owner!="courier" or not str(state.disposition).is_empty(): return "请先从邮袋取出尚在保管中的邮件。"
	var error: String=model.restore_state(state.physical)
	if not error.is_empty(): return error
	if not model.changed.is_connected(_on_changed): model.changed.connect(_on_changed)
	if not model.operation_completed.is_connected(_on_completed): model.operation_completed.connect(_on_completed)
	_snapshot=model.export_state()
	if not bool(state.physical.inspected_front) and not bool(state.physical.inspected_back):model.set_inspection(1.0,Vector2(200,70))
	model.inspect_face(str(_snapshot.face))
	error=core.inspect_envelope(id,str(_snapshot.face))
	_view=core.case_view(id)
	_ensure_reader()
	_resize()
	return error

func _ensure_reader() -> void:
	if is_instance_valid(body_reader): return
	body_reader=RichTextLabel.new()
	body_reader.name="UnfoldedLetter"
	body_reader.bbcode_enabled=false
	# Author bodies are Latin-script prose; avoid CJK punctuation spacing in contractions.
	body_reader.add_theme_font_override("normal_font",ThemeDB.fallback_font)
	body_reader.add_theme_color_override("default_color",INK)
	body_reader.add_theme_font_size_override("normal_font_size",22)
	body_reader.scroll_active=true
	body_reader.visible=false
	body_reader.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(body_reader)

func _ensure_art() -> void:
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(0.08,0.15,0.13,0),Color(0.08,0.15,0.13,0.80)])
	_hint_shade=GradientTexture2D.new();_hint_shade.gradient=gradient
	_hint_shade.fill_from=Vector2(0,0);_hint_shade.fill_to=Vector2(0,1)

func _ensure_lens() -> void:
	if is_instance_valid(_lens):return
	_lens=ColorRect.new();_lens.name="PhysicalMagnifyingGlass";_lens.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear; uniform vec2 lens_center; uniform float radius=52.0; void fragment(){vec2 p=FRAGCOORD.xy-lens_center; if(length(p)>radius){COLOR=vec4(0.0);}else{vec2 uv=(lens_center+p/1.85)*SCREEN_PIXEL_SIZE; COLOR=textureLod(screen_texture,uv,0.0);}}"
	var material:=ShaderMaterial.new();material.shader=shader;_lens.material=material
	add_child(_lens)
	_glass_sprite=TextureRect.new();_glass_sprite.name="MagnifyingGlassFrame";_glass_sprite.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_glass_sprite.texture=Art.texture("magnifier");_glass_sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_glass_sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_glass_sprite);_update_lens()

func _update_lens() -> void:
	if not is_instance_valid(_lens):return
	_lens.visible=_magnifier
	_glass_sprite.visible=_magnifier
	_glass_sprite.position=_magnifier_at*_fit;_glass_sprite.size=Vector2(146,204)*_fit
	_lens.position=(_magnifier_at+Vector2(10,11))*_fit
	_lens.size=Vector2(88,88)*_fit
	_lens.material.set_shader_parameter("lens_center",global_position+(_magnifier_at+Vector2(53.55,55.15))*_fit)
	_lens.material.set_shader_parameter("radius",42.5*_fit)

func _resize() -> void:
	_fit=maxf(0.1,minf(size.x/1600.0,size.y/900.0))
	if is_instance_valid(body_reader):
		body_reader.position=Vector2(552,131)*_fit
		body_reader.size=Vector2(496,662)*_fit
		body_reader.add_theme_font_size_override("normal_font_size",maxi(13,int(22*_fit)))
	if is_instance_valid(_lens):_update_lens()
	queue_redraw()

func to_canvas(point: Vector2) -> Vector2:
	if _amending:return (EDIT_ORIGIN+(point-model.object_rect("paper").position)*EDIT_ZOOM)*_fit
	if _snapshot.is_empty(): return (ORIGIN+point)*_fit
	return (ORIGIN+Vector2(_snapshot.pan[0],_snapshot.pan[1])+point*float(_snapshot.zoom))*_fit

func _to_table(point: Vector2) -> Vector2:
	if _amending:return (model.object_rect("paper").position+(point/_fit-EDIT_ORIGIN)/EDIT_ZOOM).snapped(Vector2(0.01,0.01))
	# Remove subpixel transform noise; a drawn mouth at 560 must not become
	# 560.000061 after zoom and fail an otherwise complete insertion.
	return ((point/_fit-ORIGIN-Vector2(_snapshot.pan[0],_snapshot.pan[1]))/float(_snapshot.zoom)).snapped(Vector2(0.01,0.01))

func tool_rect(id: String) -> Rect2:
	var rect: Rect2=drawer.tool_rect(id)
	return Rect2(rect.position*_fit,rect.size*_fit)

func drawer_handle_rect() -> Rect2:
	return Rect2(drawer.handle_rect().position*_fit,drawer.handle_rect().size*_fit)

func present_from(rect:Rect2) -> void:
	_presentation_from=rect
	_presentation=0.0
	create_tween().tween_method(func(value:float):_presentation=value;queue_redraw(),0.0,1.0,0.24)

func get_workbench_snapshot() -> Dictionary:
	return {"case_id":case_id,"physical":model.export_state(),"held":_drag,"tool":_tool,"reading":_reading,"amending":_amending,"drawer":drawer.snapshot(),"magnifier_active":_magnifier,"magnifier_held":_magnifier_held,"magnifier_rect":Rect2(_magnifier_at,Vector2(146,204)),"presentation":_presentation,"art":Art.readiness(["BG_workroom","envelope_front","envelope_back","letter_paper","drawer_open","drawer_front","magnifier","opener","restorer","press","eraser","sealer","repair_label","protector","envelope_flap","attachment_photo","replacement_strip"])}

func reader_toggle_rect() -> Rect2:
	return Rect2(Vector2(882,90)*_fit,Vector2(169,29)*_fit)

func request_close() -> bool:
	# Consume before a synchronous closed handler removes this Control from its
	# viewport; otherwise the same Escape can open the host's pause menu.
	if is_inside_tree(): get_viewport().set_input_as_handled()
	if _reading:
		_close_reading()
		return false
	if _amending:
		_amending=false
		return _checkpoint(false)
	return _checkpoint(true)

func checkpoint_for_quit() -> bool:
	# Window-close saving must not stop at dismissing the reading or amendment view.
	return _checkpoint(false)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and core!=null and not _closing:
		_checkpoint(false)
		_message="物件已放稳。重新拿起工具即可继续。" if not _save_problem else _message
		queue_redraw()

func _input(event:InputEvent) -> void:
	# A held glass keeps pointer capture above the scrollable letter text.
	if not _magnifier or not is_visible_in_tree():return
	if event is InputEventMouseMotion and _magnifier_held:
		_magnifier_at=(event.position/_fit-_magnifier_offset).clamp(Vector2(35,75),Vector2(1410,690))
		_update_lens();queue_redraw();get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _magnifier_held:
			_magnifier_held=false
			if drawer.opened and Drawer.INNER.has_point(event.position/_fit):_magnifier=false
			_update_lens();queue_redraw();get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			_magnifier=false;_magnifier_held=false;_update_lens();queue_redraw();get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if _snapshot.is_empty(): return
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE:
			accept_event()
			request_close()
		elif event.keycode==KEY_R and _drag=="label":
			_feedback(model.rotate_held(-1));cue.emit("paper")
			accept_event()
		return
	if event is InputEventMouseMotion:
		_pointer=event.position
		if drawer.motion(event.position/_fit):queue_redraw();accept_event();return
		if _magnifier_held:
			_magnifier_at=(event.position/_fit-_magnifier_offset).clamp(Vector2(35,75),Vector2(1410,690))
			_update_lens();queue_redraw();accept_event();return
		_hover_tool=""
		if drawer.opened:
			for id: String in drawer.tools:
				if tool_rect(id).has_point(event.position):_hover_tool=id;break
		mouse_default_cursor_shape=Control.CURSOR_CROSS if not _tool.is_empty() else (Control.CURSOR_DRAG if not _drag.is_empty() else Control.CURSOR_ARROW)
		if _tool.is_empty() and _drag.is_empty():
			for object_id: String in _pick_order():
				if model.object_rect(object_id).has_point(_to_table(event.position)): mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;break
		if _panning:
			model.set_inspection(float(_snapshot.zoom),_pan_start+(event.position-_pointer_start)/_fit)
		elif not _drag.is_empty(): _feedback(model.drag_to(_to_table(event.position)))
		elif _tool_down: _stroke(_to_table(event.position))
		queue_redraw()
		return
	if not event is InputEventMouseButton: return
	_pointer=event.position
	var canvas: Vector2=event.position/_fit
	if event.pressed: grab_focus()
	if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if drawer.release():queue_redraw();accept_event();return
		if _magnifier_held:
			_magnifier_held=false
			if drawer.opened and Drawer.INNER.has_point(canvas):_magnifier=false
			_update_lens();queue_redraw();accept_event();return
	if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if Rect2(1420,35,145,55).has_point(canvas):
			accept_event();request_close();return
		if _reading and reader_toggle_rect().has_point(event.position):
			_reading_original=not _reading_original
			body_reader.text=core.source_body_text(case_id) if _reading_original else core.body_text(case_id)
			accept_event();queue_redraw();return
		if _magnifier and Rect2(_magnifier_at,Vector2(146,204)).has_point(canvas):
			_magnifier_held=true;_magnifier_offset=canvas-_magnifier_at;accept_event();return
		var drawer_pick:String=drawer.press(canvas)
		if drawer_pick=="drawer":queue_redraw();accept_event();return
		if not drawer_pick.is_empty():
			if drawer_pick=="magnifier":
				_take_tool("hand");_magnifier=true;_magnifier_held=true;_magnifier_at=canvas-Vector2(53.55,55.15);_magnifier_offset=Vector2(53.55,55.15);cue.emit("tool");_update_lens()
			else:
				if _reading:_close_reading()
				_take_tool(drawer_pick)
			queue_redraw();accept_event();return
	if _reading: return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		if _amending:accept_event();return
		if not _drag.is_empty() or _tool_down: return
		var point:=_to_table(event.position)
		var zoom:=clampf(float(_snapshot.zoom)+(0.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -0.2),1.0,3.0)
		model.set_inspection(zoom,canvas-ORIGIN-point*zoom)
		accept_event();return
	if event.button_index==MOUSE_BUTTON_MIDDLE:
		_panning=event.pressed
		_pan_start=Vector2(_snapshot.pan[0],_snapshot.pan[1]);_pointer_start=event.position
		accept_event();return
	var point:=_to_table(event.position)
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		if _magnifier:_magnifier=false;_magnifier_held=false;_update_lens()
		elif _drag=="label": _feedback(model.rotate_held(1))
		elif not _tool.is_empty(): _take_tool("hand")
		elif model.object_rect("envelope").has_point(point): _flip()
		accept_event();return
	if event.button_index!=MOUSE_BUTTON_LEFT: return
	if event.pressed:
		if event.double_click and model.body_is_currently_visible() and model.object_rect("paper").has_point(point):
			_open_reading();accept_event();return
		if not _tool.is_empty():
			_tool_down=true;_last_contact=point;_feedback(model.tool_contact(point));queue_redraw()
		else:
			for id: String in _pick_order():
				if model.object_rect(id).has_point(point):
					if id in ["fold_0","fold_1"] and bool(_snapshot.body_unfolded) and str(_snapshot.operation_mode)!="reseal":
						_take_tool("reseal")
						if str(_snapshot.operation_mode)!="reseal":break
					if id in ["attachment","replacement"] and _snapshot.operation_mode!="amend":
						if not _start_amend():break
					var error: String=model.begin_drag(id,point)
					if error.is_empty(): _drag=id;cue.emit("paper");break
					_feedback(error)
	else:
		if not _drag.is_empty():
			_feedback(model.release_drag());_drag="";cue.emit("paper")
		if _tool_down:
			_tool_down=false
			if _tool=="eraser":model.return_tool();_tool="";_message=_instruction()
			elif _tool!="opener" or int(_snapshot.seam_count)>=Paper.SEAM_COUNT: _take_tool("hand")
	accept_event();queue_redraw()

func _pick_order() -> Array[String]:
	var ids: Array[String]=[]
	if _amending:
		if _snapshot.attachment_location!="none":ids.append("attachment")
		if _snapshot.erase_mask==255 and not _snapshot.replacement_placed:ids.append("replacement")
		return ids
	if model.body_is_currently_visible() and _snapshot.attachment_location!="none":ids.append("attachment")
	if _snapshot.paper_location=="desk": ids.append_array(["fold_0","fold_1"])
	if _snapshot.seal_condition=="open": ids.append("paper")
	if _snapshot.operation_mode=="reseal": ids.append("flap")
	if _snapshot.operation_mode=="repair_exterior":
		if _snapshot.label_pressed: ids.append("exterior_fold")
		elif _snapshot.label_aligned: ids.append("protector")
		if _snapshot.face=="back" and _snapshot.label_lifted: ids.append("label")
	ids.append("envelope")
	return ids

func _take_tool(id: String) -> void:
	if not _drag.is_empty(): _message="先放下手中的纸件。";return
	_tool_down=false
	model.return_tool();_tool=""
	if id=="hand": _amending=false;_message=_instruction();queue_redraw();return
	if id in ["amend","eraser"]:
		if not _start_amend():return
		if id=="eraser":
			var error: String=model.select_tool("eraser")
			if not error.is_empty():_feedback(error);return
			_tool="eraser"
		_message=_instruction();queue_redraw();return
	_amending=false
	var mode: String="repair_exterior" if id in ["restorer","press"] else ("open" if id=="opener" else "reseal")
	if mode!=str(_snapshot.operation_mode):
		if not _checkpoint(false,false): return
		var error: String=core.begin_operation(case_id,mode)
		if not error.is_empty(): _message=error;queue_redraw();return
		error=model.begin_operation(mode)
		if not error.is_empty():
			model.cancel_operation();core.cancel_operation(model.export_state());_feedback(error);return
	if id!="reseal":
		var error: String=model.select_tool(id)
		if not error.is_empty(): _feedback(error);return
		_tool=id
	_message=_instruction()
	cue.emit("tool");queue_redraw()

func _stroke(point: Vector2) -> void:
	if _tool in ["opener","eraser"]:
		var current_tool:=_tool
		var pieces:=maxi(1,int(ceil(_last_contact.distance_to(point)/4.0)))
		for index: int in range(1,pieces+1):
			if _tool!=current_tool or (current_tool=="opener" and int(_snapshot.seam_count)>=Paper.SEAM_COUNT):break
			_feedback(model.tool_contact(_last_contact.lerp(point,float(index)/pieces)))
	elif not _tool.is_empty(): _feedback(model.tool_contact(point))
	_last_contact=point

func _start_amend() -> bool:
	_amendment_options=core.amendment_options(case_id)
	if _amendment_options.is_empty():
		_message="先完整抽出并展开内页；这封信只允许处理已标明的句子或原附件。";queue_redraw();return false
	if _snapshot.operation_mode!="amend":
		if not _checkpoint(false,false):return false
		var error: String=core.begin_operation(case_id,"amend")
		if not error.is_empty():_message=error;queue_redraw();return false
		error=model.begin_operation("amend")
		if not error.is_empty():model.cancel_operation();core.cancel_operation(model.export_state());_feedback(error);return false
	_feedback(model.configure_amendments(_amendment_options))
	_amending=true;_message=_instruction();queue_redraw();return true

func _flip() -> void:
	var face: String="back" if _snapshot.face=="front" else "front"
	var error: String=model.inspect_face(face)
	if not error.is_empty(): _feedback(error);return
	_feedback(core.inspect_envelope(case_id,face))
	_view=core.case_view(case_id)
	if face=="back" and _snapshot.exterior_repaired and str(_snapshot.operation_mode).is_empty(): core.observe("label_reconstructed")
	if face=="back" and case_id=="case04" and str(_snapshot.operation_mode).is_empty(): core.observe("case04_archive_mark")
	_message=_instruction();cue.emit("paper");queue_redraw()

func _checkpoint(exit_after: bool, save_now: bool=true) -> bool:
	if core==null or _snapshot.is_empty(): return false
	model.cancel_operation();_drag="";_tool="";_tool_down=false;_panning=false;_magnifier_held=false;drawer.held=false
	var error: String
	if not core.state.active_operation.is_empty(): error=core.cancel_operation(model.export_state())
	elif core.has_method("accept_inspection"): error=core.accept_inspection(case_id,model.export_state())
	else: error="纯观察保存接口尚未接入，物件暂未关闭。"
	if not error.is_empty(): _message=error;_save_problem=true;queue_redraw();return false
	if save_now and not core.save_game():
		_message="保存没有成功。物件仍在桌上，请重试离开。";_save_problem=true;queue_redraw();return false
	_save_problem=false
	if exit_after: _closing=true;closed.emit()
	return true

func _on_changed(snapshot: Dictionary) -> void:
	var previous_count: int=int(_snapshot.get("opened_count",0))
	_snapshot=snapshot
	if int(snapshot.get("opened_count",0))>previous_count and core!=null:
		# Record the physical breach immediately; completion/extraction may never
		# happen if the player puts the tool down or loses window focus.
		var error: String=core.accept_opening_breach(case_id,snapshot)
		if not error.is_empty():
			model.return_tool();_tool="";_tool_down=false
			_message=error;_save_problem=true;queue_redraw();return
	if not str(snapshot.operation_mode).is_empty(): _message=_instruction()
	queue_redraw()

func _on_completed(mode: String, snapshot: Dictionary) -> void:
	_snapshot=snapshot
	var error: String=core.finish_operation(case_id,snapshot)
	if not error.is_empty(): _message=error;_save_problem=true;return
	_tool="";_tool_down=false;_view=core.case_view(case_id)
	_message={"repair_exterior":"外标签已压平。右键翻回背面，读纸上的地址与日期。","open":"内页已展开。双击阅读；可动内页只开放指定句或原附件。","reseal":"纸页已装回，封舌已合。纸面留下的痕迹仍然保留。","amend":"这一步的纸面状态已保留。原文记录仍在；放稳纸件后再折回。"}.get(mode,"")
	if not core.save_game(): _message="操作已保留在桌上，但保存失败。请重试离开。";_save_problem=true
	inspection_completed.emit(mode);cue.emit("paper");queue_redraw()

func _open_reading() -> void:
	var text: String=core.body_text(case_id)
	if text.is_empty() or not model.body_is_currently_visible(): return
	_reading=true;body_reader.text=text;body_reader.visible=true;queue_redraw()
	_reading_original=false

func _close_reading() -> void:
	_reading=false;body_reader.hide();body_reader.text="";grab_focus();queue_redraw()

func _feedback(error: String) -> void:
	if error.is_empty(): return
	var explanations: Dictionary={"visible_crease":"纸边出现了新的折伤。停下看清封线再继续。","inspect_both_sides_on_mat_first":"先把信封拖放到垫上，并查看正反面。","align_and_protect_first":"先对齐标签，再把保护片盖到它上面。","move_to_opening_area":"右侧空间不足。先把信封向左上方移一些。","refold_before_insertion":"纸页还展开着，先沿原折线折回。","seam_not_open":"封口只松开了一部分，先完成已经开始的封线操作。","release_object_first":"先放下手中的纸件。","hand_busy":"先归还工具或放下纸件。","label_not_movable":"标签边还未托起，或已经压合。","already_unfolded":"这一轮纸页已经展开，可双击阅读或选择折回。"}
	if error in ["no_material_contact","seam_already_open","already_facing"]: return
	_message=explanations.get(error,"这一步还不能进行。先检查纸件的当前位置和折线。")
	_rejection=1.0
	cue.emit("tool")
	create_tween().tween_method(func(value:float):_rejection=value;queue_redraw(),1.0,0.0,0.18)
	queue_redraw()

func _instruction() -> String:
	if _amending or _snapshot.operation_mode=="amend":
		if _snapshot.attachment_location!="none":return "拿住原照片，拖到右下空位可取出；拖回纸中的浅框可放回。折回前先放稳。"
		if _snapshot.replacement_placed:return "替换纸条已贴在原句位置。只改变这一句，原稿仍单独保留。Esc 返回整封物件。"
		if _snapshot.erase_mask==255:return "选定句已经擦空。可把左下纸条拿起，放到原句的浅框中；也可以保留空白。"
		return "这里只能擦除选定句。按住橡皮横向擦过文字，再实际拖入替换纸条；不会改动其他段落。"
	if _snapshot.operation_mode=="repair_exterior":
		if not _snapshot.exterior_on_mat: return "把信封拖放到垫面浅框内，右键查看正反面；工具要接触纸张。"
		if not _snapshot.label_lifted: return "用起签工具接触翘起的标签边。松开后可拿起标签。"
		if not _snapshot.label_aligned: return "拿起标签，对齐原边缘；按 R 或右键旋转，再放下。"
		if not _snapshot.label_pressed: return "把右侧的薄保护片盖到标签上，再用压合工具轻触。"
		if not _snapshot.exterior_fold_aligned: return "拿住信封下缘的折痕，向下捋平。"
		return "右键翻面，复查刚刚压平的外标签。"
	if _snapshot.operation_mode=="open":
		if int(_snapshot.seam_count)<9: return ("这是内部工作件。" if case_id=="case05" else "这是私人邮件；实际动手破坏会留下越界记录。")+"按住工具，从封线左端缓缓向右移动。"
		if _snapshot.paper_location!="desk": return "归还工具，拿住右侧露出的纸边，向右抽出。"
		return "拿住折页边缘：第一折向右展开，第二折向下展开。"
	if _snapshot.operation_mode=="reseal":
		if not _snapshot.folded: return "沿原折线折回：第一折向右，第二折向下。"
		if _snapshot.paper_location!="inside": return "拿住折好的纸页，对准信封右侧开口，再向左装回。"
		if not _snapshot.flap_closed: return "把右侧封舌向下合拢，然后再拿封合工具。"
		return "用封合工具接触已合好的封舌。"
	return "拿住信封可以移动。右键翻面，滚轮放大；中键拖动画面。"

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_fit)
	Art.paint(self,"BG_workroom",Rect2(-640,-697,2880,1620))
	if _snapshot.is_empty():return
	var available:Array[String]=["magnifier","opener"]
	if case_id=="case03":available.append_array(["restorer","press"])
	if bool(_snapshot.opened):available.append("sealer")
	if _tool_is_enabled("eraser"):available.append("eraser")
	drawer.configure(available,"magnifier" if _magnifier else _tool)
	var pan:=Vector2(_snapshot.pan[0],_snapshot.pan[1])
	var zoom:float=_snapshot.zoom
	if _amending:draw_set_transform((EDIT_ORIGIN-model.object_rect("paper").position*EDIT_ZOOM)*_fit,0,Vector2.ONE*_fit*EDIT_ZOOM)
	else:draw_set_transform((ORIGIN+pan)*_fit,0,Vector2.ONE*_fit*zoom)
	if not _amending and _presentation>=1.0:_draw_envelope()
	if _snapshot.operation_mode=="repair_exterior":_draw_repair()
	if not _reading and _snapshot.seal_condition in ["open","closed_unsealed"]:_draw_paper()
	if _amending:_draw_amendments()
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_fit)
	drawer.paint(self)
	if not _tool.is_empty() and not _reading:
		Art.paint(self,_tool,Rect2(_pointer/_fit-Vector2(72,0),Vector2(110,95)),Color.WHITE,true)
	if _reading:
		draw_rect(Rect2(0,0,1600,900),Color(0.08,0.15,0.13,0.20))
		Art.paint(self,"letter_paper",READING_PAPER)
		_text("原文记录" if _reading_original else "当前纸面",Vector2(551,91),250,16,INK)
		_text("查看现稿 ↔" if _reading_original else "查看原文 ↔",Vector2(882,91),169,16,INK)
	if _presentation<1.0:
		var target:=Rect2(to_canvas(model.object_rect("envelope").position)/_fit,model.object_rect("envelope").size*float(_snapshot.zoom))
		Art.paint(self,"envelope_front",Rect2(_presentation_from.position.lerp(target.position,_presentation),_presentation_from.size.lerp(target.size,_presentation)))
	_overlay_text("×",Vector2(1460,32),70,38)
	# Routine controls are conveyed by the physical object/cursor, never a
	# narrator strip. Disk-save failure is a system problem and stays visible.
	if _save_problem:_text(_message,Vector2(50,847),1020,19,Color("ffd6c9"))
	if _rejection>0.0:
		var item:=model.object_rect("envelope")
		var at:=to_canvas(item.position)/_fit
		draw_rect(Rect2(at,item.size*float(_snapshot.zoom)).grow(3),Color(0.74,0.33,0.23,_rejection*0.55),false,2)
	draw_set_transform(Vector2.ZERO)

func _tool_is_enabled(id: String) -> bool:
	var enabled: bool=(id not in ["restorer","press"] or case_id=="case03") and (id not in ["reseal","sealer"] or _snapshot.opened)
	if id in ["amend","eraser"]:enabled=_snapshot.body_unfolded and _snapshot.paper_location=="desk" and case_id in (["case02","case04"] if id=="eraser" else ["case02","case03","case04"])
	return enabled

func _draw_table_tool(_id:String) -> void:
	# Tools live in the physical drawer, never in mode-button columns.
	pass

func _draw_sprite(id:String,rect:Rect2,tint:Color=Color.WHITE,_shadow:bool=false,keep_aspect:bool=false) -> void:
	Art.paint(self,"letter_paper" if id=="letter" else id,rect,tint,keep_aspect)

func _draw_envelope() -> void:
	var rect: Rect2=model.object_rect("envelope")
	_draw_sprite("envelope_front" if _snapshot.face=="front" else "envelope_back",rect,Color.WHITE,true)
	var lines:Array[String]=[]
	var fields:Dictionary=_view.get(str(_snapshot.face),{})
	for key:String in fields:
		if key=="recovered_fields" or (key=="back" and case_id=="case03"):continue
		if key=="address" and str(fields[key])=="water-damaged":
			for row:int in range(3):draw_line(rect.position+Vector2(32,183+row*7),rect.position+Vector2(130+row*13,185+row*7),Color(0.34,0.47,0.43,0.17),3.0,true)
			continue
		if not str(fields[key]).is_empty():lines.append(str(fields[key]))
	var safe:=Rect2(rect.position+Vector2(30,34),Vector2(340,148)) if _snapshot.face=="front" else Rect2(rect.position+Vector2(27,126),Vector2(362,88))
	if fields.has("recovered_fields"):
		var recovered:Dictionary=fields.recovered_fields
		lines.append("%s · %s\n%s\n%s — %s"%[recovered.original_address,recovered.forwarding_recipient,recovered.forwarding_destination,recovered.forwarding_valid_from,recovered.forwarding_valid_until])
	var text_layout:=envelope_text_layout("\n".join(lines),safe,20 if _snapshot.face=="front" else 17)
	(text_layout.paragraph as TextParagraph).draw(get_canvas_item(),safe.position,INK)
	if case_id=="case03" and _snapshot.face=="back" and not _snapshot.exterior_repaired:
		var label:Rect2=model.object_rect("label")
		Art.paint(self,"repair_label",label)
		_text("—  /  —",label.position+Vector2(8,12),75,14,Color("958d7e"))
	if _snapshot.operation_mode=="open":
		for index: int in range(9): draw_circle(model.seam_point(index),2.2,Color("bd8068") if index>=int(_snapshot.seam_count) else Color("547e70"))
	if _snapshot.permanent_damage>0:
		for index: int in range(mini(6,int(_snapshot.permanent_damage))): draw_line(rect.position+Vector2(35+index*21,52),rect.position+Vector2(47+index*21,65),Color("ba957b"),1.3)
	if _snapshot.seal_condition in ["open","closed_unsealed"]:_paint_envelope_flap(rect)
	if _snapshot.operation_mode=="reseal" and _snapshot.paper_location=="inside":
		var flap: Rect2=model.object_rect("flap")
		_text("↓",flap.position+Vector2(10,24),40,24,INK)

func envelope_text_layout(text:String,safe:Rect2,font_size:int) -> Dictionary:
	var paragraph:TextParagraph
	for candidate:int in range(font_size,9,-1):
		paragraph=TextParagraph.new();paragraph.width=safe.size.x
		paragraph.add_string(text,get_theme_font("font"),candidate)
		if paragraph.get_size().y<=safe.size.y:return {"paragraph":paragraph,"rect":Rect2(safe.position,paragraph.get_size()),"font_size":candidate,"safe":safe}
	# Current envelope fields are short postal inscriptions. Reject oversized
	# data in QA instead of silently drawing beyond the material's safe area.
	return {"paragraph":paragraph,"rect":Rect2(safe.position,paragraph.get_size()),"font_size":10,"safe":safe}

func _paint_envelope_flap(envelope:Rect2) -> void:
	# The generated triangle keeps its shape, hinged along the envelope's right mouth.
	var zoom:float=float(_snapshot.zoom)
	var hinge:Vector2=envelope.position+Vector2(420,105)
	var turn:float=1.0-2.0*float(_snapshot.flap_progress)
	if absf(turn)<0.02:turn=0.02
	draw_set_transform((ORIGIN+Vector2(_snapshot.pan[0],_snapshot.pan[1])+hinge*zoom)*_fit,-PI/2,Vector2(1,turn)*_fit*zoom)
	Art.paint(self,"envelope_flap",Rect2(-45,0,90,36.5))
	draw_set_transform((ORIGIN+Vector2(_snapshot.pan[0],_snapshot.pan[1]))*_fit,0,Vector2.ONE*_fit*zoom)

func _draw_repair() -> void:
	var target:Vector2=model.object_rect("envelope").position+Vector2(190,130)
	if _snapshot.label_lifted and not _snapshot.label_pressed:
		Art.paint(self,"repair_label",Rect2(target,Paper.LABEL_SIZE),Color(1,1,1,0.22))
		var rect:Rect2=model.object_rect("label")
		draw_set_transform((ORIGIN+Vector2(_snapshot.pan[0],_snapshot.pan[1])+rect.get_center()*float(_snapshot.zoom))*_fit,float(_snapshot.label_turn)*PI/2,Vector2.ONE*_fit*float(_snapshot.zoom))
		Art.paint(self,"repair_label",Rect2(-rect.size*0.5,rect.size))
		draw_set_transform((ORIGIN+Vector2(_snapshot.pan[0],_snapshot.pan[1]))*_fit,0,Vector2.ONE*_fit*float(_snapshot.zoom))
	if _snapshot.label_aligned:Art.paint(self,"protector",model.object_rect("protector"),Color(1,1,1,0.75))

func paper_display_rect() -> Rect2:
	var grab:Rect2=model.object_rect("paper")
	if _snapshot.paper_location in ["inside","partly_extracted"]:
		var mouth:Vector2=model.object_rect("envelope").position+Vector2(420,65)
		return Rect2(mouth,Vector2(maxf(28.0,grab.end.x-mouth.x),60))
	return grab
func _draw_paper() -> void:
	var rect:Rect2=model.object_rect("paper")
	if _snapshot.paper_location=="inside" and _snapshot.seal_condition!="open":return
	if _snapshot.paper_location in ["inside","partly_extracted"]:
		var visible_paper:=paper_display_rect()
		var material:Texture2D=Art.texture("letter_paper")
		if material!=null:
			var visible_fraction:float=clampf(visible_paper.size.x/248.0,0.0,1.0)
			draw_texture_rect_region(material,visible_paper,Rect2(material.get_width()*(1.0-visible_fraction),0,material.get_width()*visible_fraction,material.get_height()))
		return
	Art.paint(self,"letter_paper",rect)
	if _amending:return
	for index:int in range(2):
		var amount:float=_snapshot.fold_progress[index]
		var fold:Rect2=model.object_rect("fold_"+str(index))
		if amount<1.0:Art.paint(self,"letter_paper",Rect2(rect.position+Vector2(12,25+index*70),Vector2(160*(1-amount),45)))
		_text("→" if index==0 else "↓",fold.position+Vector2(4,7),70,18,INK)
	if model.body_is_currently_visible() and not core.body_text(case_id).is_empty():
		_text(core.body_text(case_id).left(80)+"…",rect.position+Vector2(16,18),170,11,INK)
		if _snapshot.attachment_location!="none":Art.paint(self,"attachment_photo",model.object_rect("attachment"))

func _draw_amendments() -> void:
	var paper: Rect2=model.object_rect("paper")
	if _snapshot.attachment_location!="none":
		_edit_text("随信附来的照片",paper.position+Vector2(18,18),195,12,INK)
		var slot: Rect2=model.object_rect("attachment_slot")
		draw_rect(slot,Color("a4b8b4"),false,0.8)
		var tray: Rect2=model.object_rect("attachment_tray")
		draw_rect(tray,Color(0.62,0.70,0.69,0.13))
		var photo: Rect2=model.object_rect("attachment")
		Art.paint(self,"attachment_photo",photo)
		return
	var slots: Array=_amendment_options.get("slots",[])
	if slots.is_empty():return
	var slot: Dictionary=slots[0]
	var phrase: Rect2=model.object_rect("phrase")
	_edit_text(str(slot.original),phrase.position+Vector2(3,5),190,11,INK)
	for segment: int in range(8):
		if int(_snapshot.erase_mask)&(1<<segment):_paper_patch(paper,Rect2(phrase.position+Vector2(float(segment)*phrase.size.x/8,0),Vector2(phrase.size.x/8,phrase.size.y)))
	if int(_snapshot.erase_mask)==255:
		draw_rect(phrase,Color("b5b8a7"),false,0.7)
		var replacement: Rect2=model.object_rect("replacement")
		_paint_replacement_strip(replacement)
		for option: Dictionary in slot.options:
			if option.get("operation","")=="replace":_edit_text(str(option.text),replacement.position+Vector2(8,17),180,10,INK)

func _paper_patch(paper:Rect2, patch:Rect2) -> void:
	# Erasing exposes this same generated paper, rather than cloning eight paper borders.
	var material:Texture2D=Art.texture("letter_paper")
	if material==null:return
	var uv_scale:Vector2=material.get_size()/paper.size
	draw_texture_rect_region(material,patch,Rect2((patch.position-paper.position)*uv_scale,patch.size*uv_scale))

func _paint_replacement_strip(rect:Rect2) -> void:
	# Nine regions retain the generated ink edge width while its blank writing area expands.
	var material:Texture2D=Art.texture("replacement_strip")
	if material==null:return
	var source_size:Vector2=material.get_size()
	var sx:Array[float]=[0.0,45.0,source_size.x-45.0,source_size.x]
	var sy:Array[float]=[0.0,32.0,source_size.y-32.0,source_size.y]
	var dx:Array[float]=[rect.position.x,rect.position.x+4.0,rect.end.x-4.0,rect.end.x]
	var dy:Array[float]=[rect.position.y,rect.position.y+3.0,rect.end.y-3.0,rect.end.y]
	for row:int in range(3):
		for column:int in range(3):
			draw_texture_rect_region(material,Rect2(dx[column],dy[row],dx[column+1]-dx[column],dy[row+1]-dy[row]),Rect2(sx[column],sy[row],sx[column+1]-sx[column],sy[row+1]-sy[row]))

func _overlay_text(text:String,at:Vector2,width:float,font_size:int) -> void:
	var paragraph:=TextParagraph.new();paragraph.width=width
	paragraph.add_string(text,get_theme_font("font"),font_size)
	paragraph.draw_outline(get_canvas_item(),at,3,Color("243731"))
	paragraph.draw(get_canvas_item(),at,Color("fff6dc"))
func _edit_text(text: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	# Rasterize at the displayed size instead of magnifying an eleven-pixel glyph.
	var paper_position: Vector2=model.object_rect("paper").position
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_fit)
	_text(text,EDIT_ORIGIN+(at-paper_position)*EDIT_ZOOM,width*EDIT_ZOOM,roundi(font_size*EDIT_ZOOM),color)
	draw_set_transform((EDIT_ORIGIN-paper_position*EDIT_ZOOM)*_fit,0,Vector2.ONE*_fit*EDIT_ZOOM)

func _text(text: String, at: Vector2, width: float, font_size: int, color: Color) -> float:
	var paragraph:=TextParagraph.new()
	paragraph.width=width
	paragraph.add_string(text,get_theme_font("font"),font_size)
	paragraph.draw(get_canvas_item(),at,color)
	return paragraph.get_size().y

func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color;style.border_color=border
	style.set_border_width_all(1);style.set_corner_radius_all(radius)
	return style
