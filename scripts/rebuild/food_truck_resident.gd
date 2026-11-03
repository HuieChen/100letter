extends Control
signal talk_requested
const Art=preload("res://scripts/rebuild/authored_dialogue_art.gd")
const UI=preload("res://scripts/ui/paper_ui.gd")
var courier:Control
var allowed:Callable
var locale:Callable
var foot:=Vector2(12330,872)
var bubble:Control
var greeting:Label
var portrait:TextureRect
var ready_to_talk:=false
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait=Art.portrait("chef_chibi_source.jpg")
	UI.place(portrait,self,Rect2(foot-Vector2(80,290),Vector2(160,290)))
	portrait.name="FoodTruckChef"
	var hit:=Button.new();hit.flat=true;hit.name="TalkToChef";hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	UI.place(hit,self,Rect2(foot-Vector2(78,285),Vector2(156,285)))
	hit.pressed.connect(_approach)
	bubble=Control.new();bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(bubble,self,Rect2(foot-Vector2(130,470),Vector2(260,172)))
	var paper:=TextureRect.new();paper.texture=Art.texture("cat_bubble.png");paper.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.place(paper,bubble,Rect2(0,0,260,172))
	greeting=UI.label(bubble,"",Rect2(24,46,212,77),22,Color("4a3a32"));greeting.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;greeting.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var key:=UI.button(bubble,"E",Rect2(189,117,44,32),_talk);key.add_theme_font_size_override("font_size",18);key.name="ChefTalkKey"
	bubble.hide()
func _process(_delta:float)->void:
	if not is_instance_valid(courier):return
	ready_to_talk=(not allowed.is_valid() or allowed.call()) and absf(courier.foot.x-foot.x)<290.0
	bubble.visible=ready_to_talk
	portrait.modulate=courier.modulate
	greeting.text="Soup's ready.\nHungry?" if locale.is_valid() and locale.call()=="en" else "汤刚刚煮好，\n要来一碗吗？"
func _approach()->void:
	if allowed.is_valid() and not allowed.call():return
	if ready_to_talk:_talk()
	else:courier.walk_to(foot-Vector2(160,0),_talk)
func _talk()->void:
	if allowed.is_valid() and not allowed.call():return
	if absf(courier.foot.x-foot.x)>300:return
	courier.cancel();bubble.hide();talk_requested.emit()
func _unhandled_key_input(event:InputEvent)->void:
	if ready_to_talk and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		get_viewport().set_input_as_handled();_talk()
