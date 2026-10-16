extends Control
## The live scene stays behind one notebook leaf and the actual conversational cast.
signal advanced
signal chosen(id: String)
signal closed
signal cue(kind: String)
const UI = preload("res://scripts/ui/paper_ui.gd")
const Art = preload("res://scripts/rebuild/physical_art.gd")
const WORDS := Color("493c30")
const ACCENT := Color("217b87")
const CHOICES_PER_PAGE := 4
var _speaker := ""
var _line := ""
var _choices: Array = []
var _showing_choices := false
var _locked := false
var _choice_page := 0
var _left_art := ""
var _right_art := ""
var locale := "zh"
var _leaf: TextureRect
var _speaker_label: Label
var _spoken: RichTextLabel
var _close_button: Button
func configure(speaker: String, line: String, choices: Array = [], left_art: String = "", right_art: String = "") -> void:
	_speaker=speaker;_line=line;_choices=choices.duplicate(true)
	_left_art=left_art;_right_art=right_art
	_showing_choices=false;_locked=false;_choice_page=0
	_render()
func _image(key:String,rect:Rect2,keep:bool=false) -> TextureRect:
	var image:=TextureRect.new()
	image.name=key;image.texture=Art.texture(key)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep else TextureRect.STRETCH_SCALE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(image,self,rect)
	return image
func _render() -> void:
	for child in get_children():remove_child(child);child.queue_free()
	mouse_filter=Control.MOUSE_FILTER_STOP
	if not _left_art.is_empty():_image(_left_art,Rect2(35,180,450,720),true)
	if not _right_art.is_empty():_image(_right_art,Rect2(1160,180,420,720),true)
	_leaf=_image("dialogue_notebook",Rect2(290,600,1030,300));_leaf.name="DialogueLeaf"
	_close_button=_text_button("×",Rect2(1254,657,46,44))
	_close_button.name="CloseDialogue"
	_close_button.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS
	_close_button.add_theme_font_size_override("font_size",31)
	_close_button.pressed.connect(request_close)
	_speaker_label=UI.label(self,_speaker,Rect2(354,625,222,38),22,WORDS)
	_speaker_label.name="Speaker";_speaker_label.clip_text=true
	_speaker_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if _showing_choices:
		var first:=_choice_page*CHOICES_PER_PAGE
		for index in range(first,mini(first+CHOICES_PER_PAGE,_choices.size())):
			var choice:Dictionary=_choices[index]
			var button:=_text_button(str(choice.get("text","")),Rect2(378,675+(index-first)*37,850,36))
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
		_spoken=RichTextLabel.new();_spoken.name="SpokenLine";_spoken.text=_line;_spoken.scroll_active=true
		_spoken.add_theme_color_override("default_color",WORDS)
		_spoken.add_theme_font_size_override("normal_font_size",26)
		_spoken.add_theme_constant_override("line_separation",6)
		UI.place(_spoken,self,Rect2(378,676,840,148))
		var next:=_text_button("▼",Rect2(744,835,112,42));next.name="AdvanceDialogue"
		next.add_theme_font_size_override("font_size",20);next.pressed.connect(_advance)
		_fit_spoken_line.call_deferred(_spoken)
func _fit_spoken_line(spoken:RichTextLabel) -> void:
	await get_tree().process_frame
	if not is_instance_valid(spoken) or _showing_choices:return
	# Actual wrapped glyph bounds drive the paper height, not character-count guesses.
	var height:=clampf(float(spoken.get_content_height())+151.0,300.0,405.0)
	_leaf.position.y=900-height;_leaf.size.y=height
	_speaker_label.position.y=900-height+height*0.083
	_close_button.position.y=900-height+height*0.19
	spoken.position.y=900-height+height*0.252;spoken.size.y=height*0.74-62.0
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
	if _locked or _showing_choices:return
	get_viewport().set_input_as_handled();cue.emit("flip")
	if _choices.is_empty():_locked=true;advanced.emit()
	else:_showing_choices=true;_render()
func _choose(id:String) -> void:
	if _locked:return
	_locked=true;get_viewport().set_input_as_handled();cue.emit("paper");chosen.emit(id)
func request_close() -> void:
	if _locked:return
	_locked=true;get_viewport().set_input_as_handled();cue.emit("paper");closed.emit()
func _input(event:InputEvent) -> void:
	if not visible or _locked:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:request_close()
		elif not _showing_choices and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:_advance()
		elif _showing_choices and event.keycode>=KEY_1 and event.keycode<=KEY_9:
			var index:int=_choice_page*CHOICES_PER_PAGE+int(event.keycode)-KEY_1
			if int(event.keycode)-KEY_1<CHOICES_PER_PAGE and index<_choices.size():_choose(str(_choices[index].get("id",index)))
