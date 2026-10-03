extends Control
## Scene remains visible. A spoken line and the response choices are separate beats.
signal advanced
signal chosen(id: String)
signal closed

const UI = preload("res://scripts/ui/paper_ui.gd")
const WORDS := Color("fff6e7")
const ACCENT := Color("f3c18e")
var _speaker := ""
var _line := ""
var _choices: Array = []
var _showing_choices := false
var _locked := false
var _choice_page: int = 0
const CHOICES_PER_PAGE := 4

func configure(speaker: String, line: String, choices: Array = []) -> void:
	_speaker = speaker
	_line = line
	_choices = choices.duplicate(true)
	_showing_choices = false
	_locked = false
	_choice_page = 0
	_render()

func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var height := 270.0 if _showing_choices else (320.0 if _line.length()>150 else 256.0)
	var top := 900.0 - height
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	fade.colors = PackedColorArray([Color(0.055,0.05,0.065,0.0), Color(0.055,0.05,0.065,0.87), Color(0.055,0.05,0.065,0.96)])
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(0,1)
	texture.width = 4
	texture.height = 256
	var ribbon := TextureRect.new()
	ribbon.texture = texture
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(ribbon, self, Rect2(0, top, 1600, height))
	var close:=_text_button("×",Rect2(1510,top+36,58,52))
	close.name="CloseDialogue"
	close.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS
	close.add_theme_font_size_override("font_size",34)
	close.pressed.connect(request_close)
	if _showing_choices:
		var first := _choice_page * CHOICES_PER_PAGE
		for index in range(first, mini(first + CHOICES_PER_PAGE, _choices.size())):
			var choice: Dictionary = _choices[index]
			var button := _text_button(str(choice.get("text", "")), Rect2(140, top + 42 + (index - first) * 43, 1320, 41))
			button.name = "Choice_" + str(choice.get("id", index))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func(): _choose(str(choice.get("id", index))))
		if _choice_page > 0:
			var previous := _text_button("‹ 前面的话题", Rect2(140, 852, 290, 40))
			previous.name = "ChoicePagePrevious"
			previous.pressed.connect(func(): _choice_page -= 1; _render())
		if first + CHOICES_PER_PAGE < _choices.size():
			var next_page := _text_button("更多话题 ›", Rect2(1190, 852, 270, 40))
			next_page.name = "ChoicePageNext"
			next_page.pressed.connect(func(): _choice_page += 1; _render())
	else:
		UI.label(self, _speaker, Rect2(126, top + 49, 1280, 40), 29, WORDS).name = "Speaker"
		var spoken:=RichTextLabel.new()
		spoken.name = "SpokenLine"
		spoken.text=_line
		spoken.scroll_active=true
		spoken.add_theme_color_override("default_color",WORDS)
		spoken.add_theme_font_size_override("normal_font_size",26)
		spoken.add_theme_constant_override("line_separation",7)
		UI.place(spoken,self,Rect2(126,top+96,1320,148 if height==320.0 else 84))
		var next := _text_button("›", Rect2(682, 839, 236, 48))
		next.name = "AdvanceDialogue"
		next.pressed.connect(_advance)

func _text_button(text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", WORDS)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_focus_color", ACCENT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	UI.place(button, self, rect)
	return button

func _advance() -> void:
	if _locked or _showing_choices: return
	get_viewport().set_input_as_handled()
	if _choices.is_empty():
		_locked = true
		advanced.emit()
	else:
		_showing_choices = true
		_render()

func _choose(id: String) -> void:
	if _locked: return
	_locked = true
	get_viewport().set_input_as_handled()
	chosen.emit(id)

func request_close() -> void:
	if _locked: return
	_locked = true
	get_viewport().set_input_as_handled()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or _locked: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			request_close()
		elif not _showing_choices and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance()
		elif _showing_choices and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index: int = _choice_page * CHOICES_PER_PAGE + int(event.keycode) - KEY_1
			if int(event.keycode) - KEY_1 < CHOICES_PER_PAGE and index < _choices.size(): _choose(str(_choices[index].get("id", index)))
