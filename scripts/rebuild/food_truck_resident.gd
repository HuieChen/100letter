extends Control
signal talk_requested
const Art=preload("res://scripts/rebuild/authored_dialogue_art.gd")
const UI=preload("res://scripts/ui/paper_ui.gd")
var courier:Control
var allowed:Callable
var locale:Callable
var foot:=Vector2(12260,817)
var character_id:="chef"
var art_key:="chef_chibi_source.jpg"
var actor_height:=350.0
var bubble:Control
var greeting:Label
var portrait:TextureRect
var ready_to_talk:=false
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait=Art.portrait(art_key)
	# People stay in front of the interaction cue, including the courier at z=2.
	portrait.z_index=1
	var actor_size:=portrait.texture.get_size()*actor_height/portrait.texture.get_height()
	UI.place(portrait,self,Rect2(foot-Vector2(actor_size.x*0.5,actor_height),actor_size))
	portrait.name="FoodTruckChef" if character_id=="chef" else character_id
	var hit:=Button.new();hit.flat=true;hit.name="TalkToChef";hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	UI.place(hit,self,Rect2(foot-Vector2(actor_size.x*0.5,actor_height),actor_size))
	hit.pressed.connect(_approach)
	var cat:=TextureButton.new();cat.name="ChefCatBubble"
	cat.texture_normal=Art.texture("cat_bubble.png")
	var rim:=ShaderMaterial.new();rim.shader=preload("res://scripts/rebuild/cat_bubble_rim.gdshader")
	cat.material=rim
	cat.z_index=0
	cat.ignore_texture_size=true;cat.stretch_mode=TextureButton.STRETCH_SCALE
	cat.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var hit_mask:=BitMap.new();hit_mask.create_from_image_alpha(cat.texture_normal.get_image(),0.1)
	cat.texture_click_mask=hit_mask
	cat.pressed.connect(_talk)
	cat.mouse_entered.connect(func():cat.self_modulate=Color(1.04,1.04,1.04))
	cat.mouse_exited.connect(func():cat.self_modulate=Color.WHITE)
	bubble=cat
	UI.place(bubble,self,Rect2(foot+Vector2(actor_size.x*0.5+12,-actor_height+18),Vector2(104,68.8)))
	var shadow:=TextureRect.new();shadow.texture=cat.texture_normal
	shadow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shadow.stretch_mode=TextureRect.STRETCH_SCALE
	shadow.modulate=Color(0.18,0.24,0.26,0.40);shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent=true
	UI.place(shadow,bubble,Rect2(3,4,104,68.8))
	greeting=UI.label(bubble,"...",Rect2(12,12,80,42),27,Color("4a3a32"));greeting.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;greeting.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	greeting.mouse_filter=Control.MOUSE_FILTER_IGNORE
	greeting.autowrap_mode=TextServer.AUTOWRAP_OFF
	greeting.clip_text=true
	greeting.size=Vector2(80,42)
	bubble.hide()
func _process(_delta:float)->void:
	if not is_instance_valid(courier):return
	ready_to_talk=(not allowed.is_valid() or allowed.call()) and absf(courier.foot.x-foot.x)<290.0
	bubble.visible=ready_to_talk
	portrait.modulate=courier.modulate
	greeting.text="..."
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
