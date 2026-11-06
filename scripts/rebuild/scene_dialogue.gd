extends Control
## The live scene stays behind one notebook leaf and the actual conversational cast.
signal advanced
signal chosen(id: String)
signal closed
signal cue(kind: String)
const UI = preload("res://scripts/ui/paper_ui.gd")
const Art = preload("res://scripts/rebuild/physical_art.gd")
const Authored = preload("res://scripts/rebuild/authored_dialogue_art.gd")
const ManagedSession=preload("res://scripts/rebuild/authored_dialogue_session.gd")
const WORDS := Color("493c30")
const ACCENT := Color("217b87")
const CHOICES_PER_PAGE := 4
const PAPER_SOURCE_SIZE:=Vector2(2624,745)
const PAPER_HEIGHT:=1030.0*745.0/2624.0
const SPEAKER_CENTER:=Vector2(437,93.5)
const CONTINUE_CENTER:=Vector2(1301,595)
var _speaker := ""
const SPOKEN_TEXT := "……"
var _choices: Array = []
var _showing_choices := false
var _locked := false
var _choice_page := 0
var _left_art := ""
var _right_art := ""
var locale := "zh"
var advance_name := "AdvanceDialogue"
var _leaf: TextureRect
var _speaker_label: Label
var _spoken: RichTextLabel
var _close_button: Button
var _text_rate:=0.0
var _reveal:=0.0
var _transition:Tween
var _line_transition:Tween
var _entering:=false
var _closing:=false
var _presented:=false
var _managed_session:RefCounted
var _managed_serial:=0
var _left_portrait:TextureRect
var _right_portrait:TextureRect
# Same world light as the small actors; paper remains readable UI.
var light_source:CanvasItem
var ambient_light:=Color.WHITE
func _sync_scene_light()->void:
	var light:Color=light_source.modulate if is_instance_valid(light_source) else ambient_light
	light.a=1.0
	for portrait in [_left_portrait,_right_portrait]:
		if is_instance_valid(portrait):portrait.modulate=light
func set_line(speaker:String,_line:String)->void:
	# Keep the cast and paper alive; only the ink changes between sentences.
	if _closing:return
	_locked=true
	if is_instance_valid(_line_transition):_line_transition.kill()
	_line_transition=create_tween()
	_line_transition.tween_property(_spoken,"modulate:a",0.0,0.06)
	_line_transition.tween_callback(func():
		_speaker=speaker;_speaker_label.text=speaker;_spoken.text=SPOKEN_TEXT
		_reveal=0.0;_spoken.visible_characters=0 if _text_rate>0.0 else -1
		_fit_spoken_line.call_deferred(_spoken)
		_speaker_emphasis()
	)
	_line_transition.tween_property(_spoken,"modulate:a",1.0,0.10)
	_line_transition.tween_callback(func():_locked=false)
func configure_managed_chef(index:int=0)->void:
	# Only the opened food-truck encounter uses this graph. The renderer keeps
	# its intentionally masked copy; no hidden narrative is unlocked here.
	_managed_serial+=1
	var serial:=_managed_serial
	_managed_session=ManagedSession.new()
	var line:Dictionary=await _managed_session.open(locale,index)
	if _closing or serial!=_managed_serial or not is_inside_tree():return
	if line.is_empty():finish();return
	set_meta("chef_page",int(line.index))
	set_meta("dialogue_backend","DialogueManager 4.2.0")
	if not _presented:configure(str(line.speaker),str(line.text),[],"courier_source.jpg","chef_source.jpg")
	else:set_line(str(line.speaker),str(line.text))
func _advance_managed()->void:
	_locked=true
	var serial:=_managed_serial
	var line:Dictionary=await _managed_session.advance()
	if _closing or serial!=_managed_serial or not is_inside_tree():return
	if line.is_empty():finish();return
	set_meta("chef_page",int(line.index))
	set_line(str(line.speaker),str(line.text))
func _speaker_emphasis()->void:
	var player_speaks:=_speaker in ["你","You","主角"]
	var t:=create_tween().set_parallel(true)
	if is_instance_valid(_left_portrait):t.tween_property(_left_portrait,"self_modulate",Color.WHITE if player_speaks else Color(0.84,0.86,0.88),0.16)
	if is_instance_valid(_right_portrait):t.tween_property(_right_portrait,"self_modulate",Color(0.84,0.86,0.88) if player_speaks else Color.WHITE,0.16)
func _enter_dialogue()->void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _closing:return
	_transition=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(self,"modulate:a",1.0,0.24)
	for item in [_left_portrait,_right_portrait]:
		if not is_instance_valid(item):continue
		var target:Vector2=item.position
		item.position.x+=-18.0 if item==_left_portrait else 18.0
		_transition.tween_property(item,"position",target,0.28)
	_transition.chain().tween_callback(func():_entering=false;_speaker_emphasis())
func finish()->void:
	if _closing:return
	_closing=true;_locked=true;_entering=false
	_managed_serial+=1
	if is_instance_valid(_transition):_transition.kill()
	if is_instance_valid(_line_transition):_line_transition.kill()
	_transition=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(self,"modulate:a",0.0,0.18)
	_transition.tween_callback(func():closed.emit())
func configure(speaker: String, _line: String, choices: Array = [], left_art: String = "", right_art: String = "") -> void:
	_speaker=speaker;_choices=choices.duplicate(true)
	_left_art=left_art;_right_art=right_art
	# Keep the player on the left regardless of the current speaker.
	if _right_art in ["courier_source.jpg", "CHAR_courier"]:
		_left_art=right_art;_right_art=left_art
	_showing_choices=false;_locked=false;_choice_page=0
	_render()
	if not _presented:
		_presented=true;_entering=true;modulate.a=0.0
		_enter_dialogue.call_deferred()
func _image(key:String,rect:Rect2,keep:bool=false) -> TextureRect:
	if Authored.is_character(key):
		var portrait:=Authored.portrait(key)
		portrait.name=key
		UI.place(portrait,self,rect)
		return portrait
	var image:=TextureRect.new()
	image.name=key;image.texture=Authored.texture("paper_dialogue.png",false) if key=="dialogue_notebook" else Art.texture(key)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep else TextureRect.STRETCH_SCALE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(image,self,rect)
	return image
func _render() -> void:
	z_index=100 # Entire dialogue must remain in front of the world actor layer.
	for child in get_children():remove_child(child);child.queue_free()
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.name="ConversationShade";shade.color=Color(0.12,0.17,0.19,0.18)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(shade,self,Rect2(0,0,1600,900))
	if not _left_art.is_empty():_left_portrait=_image(_left_art,Rect2(60,278,420,1040) if Authored.is_character(_left_art) else Rect2(35,180,450,720),true)
	if not _right_art.is_empty():_right_portrait=_image(_right_art,Rect2(1005,270,560,1040) if Authored.is_character(_right_art) else Rect2(1160,180,420,720),true)
	_sync_scene_light()
	_leaf=_image("dialogue_notebook",Rect2(290,900-PAPER_HEIGHT,1030,PAPER_HEIGHT));_leaf.name="DialogueLeaf"
	_close_button=_text_button("×",Rect2(1254,713,46,44))
	_close_button.name="CloseDialogue"
	_close_button.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS
	_close_button.add_theme_font_size_override("font_size",31)
	_close_button.pressed.connect(request_close)
	_speaker_label=UI.label(self,_speaker,Rect2(375,675,155,38),22,WORDS)
	_speaker_label.name="Speaker";_speaker_label.clip_text=true
	_speaker_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_speaker_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if _showing_choices:
		var first:=_choice_page*CHOICES_PER_PAGE
		for index in range(first,mini(first+CHOICES_PER_PAGE,_choices.size())):
			var choice:Dictionary=_choices[index]
			var button:=_text_button(str(choice.get("text","")),Rect2(378,696+(index-first)*37,850,36))
			button.name="Choice_"+str(choice.get("id",index));button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size",21)
			button.pressed.connect(func():_choose(str(choice.get("id",index))))
		if _choice_page>0:
			var previous:=_text_button("‹",Rect2(389,831,84,45));previous.name="ChoicePagePrevious"
			previous.pressed.connect(func():_choice_page-=1;cue.emit("flip");_render())
		if first+CHOICES_PER_PAGE<_choices.size():
			var next_page:=_text_button("›",Rect2(1178,831,84,45));next_page.name="ChoicePageNext"
			next_page.pressed.connect(func():_choice_page+=1;cue.emit("flip");_render())
	else:
		_spoken=RichTextLabel.new();_spoken.name="SpokenLine";_spoken.text=SPOKEN_TEXT;_spoken.scroll_active=true
		_spoken.add_theme_color_override("default_color",WORDS)
		_spoken.add_theme_font_size_override("normal_font_size",26)
		_spoken.add_theme_constant_override("line_separation",6)
		UI.place(_spoken,self,Rect2(378,728,840,109))
		# The supplied paper already contains its drawn down arrow.
		var next:=_text_button("",Rect2(744,835,112,42));next.name=advance_name
		next.add_theme_font_size_override("font_size",20);next.pressed.connect(_advance)
		_fit_spoken_line.call_deferred(_spoken)
		_reveal=0.0
		_spoken.visible_characters=0 if _text_rate>0.0 else -1
	_align_paper_controls()
	_focus_paper()

func _paper_point(source_point:Vector2)->Vector2:
	return _leaf.position+source_point/PAPER_SOURCE_SIZE*_leaf.size

func _align_paper_controls()->void:
	# Coordinates are registered to the supplied image after its transparent crop.
	_speaker_label.position=_paper_point(SPEAKER_CENTER)-_speaker_label.size*.5
	_close_button.position=_paper_point(Vector2(2440,170))-_close_button.size*.5
	var next:=get_node_or_null(advance_name) as Button
	if next!=null:next.position=_paper_point(CONTINUE_CENTER)-next.size*.5

func _focus_paper() -> void:
	var items:Array=[]
	for child in get_children():
		if child is Button:items.append(child)
	for i:int in items.size():
		items[i].focus_next=items[i].get_path_to(items[(i+1)%items.size()])
		items[i].focus_previous=items[i].get_path_to(items[(i-1+items.size())%items.size()])
	if _showing_choices and items.size()>1:items[1].grab_focus()
	elif has_node(advance_name):get_node(advance_name).grab_focus()

func set_text_rate(rate:float) -> void:
	_text_rate=maxf(rate,0.0);_reveal=0.0
	if is_instance_valid(_spoken):_spoken.visible_characters=0 if _text_rate>0.0 else -1

func _process(delta:float) -> void:
	_sync_scene_light()
	if _entering or _showing_choices or _locked or not is_instance_valid(_spoken) or _spoken.visible_characters<0:return
	_reveal+=delta*_text_rate
	_spoken.visible_characters=mini(int(_reveal),_spoken.get_total_character_count())
	if _spoken.visible_characters>=_spoken.get_total_character_count():_spoken.visible_characters=-1
func _fit_spoken_line(spoken:RichTextLabel) -> void:
	await get_tree().process_frame
	if not is_instance_valid(spoken) or _showing_choices:return
	# Actual wrapped glyph bounds drive the paper height, not character-count guesses.
	var height:=maxf(PAPER_HEIGHT,clampf(float(spoken.get_content_height())+124.0,230.0,330.0))
	_leaf.position.y=900-height;_leaf.size.y=height
	_align_paper_controls()
	spoken.position=_paper_point(Vector2(250,210))
	spoken.size=Vector2(2100,330)/PAPER_SOURCE_SIZE*_leaf.size
	spoken.scroll_active=float(spoken.get_content_height())>spoken.size.y
func _text_button(text:String,rect:Rect2) -> Button:
	var button:=Button.new();button.text=text;button.flat=true
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",25)
	button.add_theme_color_override("font_color",WORDS)
	button.add_theme_color_override("font_hover_color",ACCENT)
	button.add_theme_color_override("font_focus_color",ACCENT)
	for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	UI.place(button,self,rect)
	return button
func _advance() -> void:
	if _locked or _entering or _closing or _showing_choices:return
	if is_instance_valid(_spoken) and _spoken.visible_characters>=0:
		_spoken.visible_characters=-1;get_viewport().set_input_as_handled();return
	get_viewport().set_input_as_handled();cue.emit("flip")
	if _managed_session!=null:_advance_managed()
	elif _choices.is_empty():_locked=true;advanced.emit()
	else:_showing_choices=true;_render()
func _choose(id:String) -> void:
	if _locked:return
	_locked=true;get_viewport().set_input_as_handled();cue.emit("paper");chosen.emit(id)
func request_close() -> void:
	if _closing:return
	get_viewport().set_input_as_handled();cue.emit("paper");finish()
func _input(event:InputEvent) -> void:
	if not visible or _closing:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:request_close()
		elif not _showing_choices and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:_advance()
		elif _showing_choices and event.keycode>=KEY_1 and event.keycode<=KEY_9:
			var index:int=_choice_page*CHOICES_PER_PAGE+int(event.keycode)-KEY_1
			if int(event.keycode)-KEY_1<CHOICES_PER_PAGE and index<_choices.size():_choose(str(_choices[index].get("id",index)))
