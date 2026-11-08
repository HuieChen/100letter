extends Node
## Settings-only feedback. Native control geometry and value mapping stay fixed.
const INK:=Color("0059ae")
const HOVER_INK:=Color("1278bd")
const PRESS_INK:=Color("004881")
const CREAM:=Color("fff4ba")
var _buttons:Dictionary={}
var _sliders:Dictionary={}
var _connections:Array=[]
var _menus:Array=[]
var _prune_timer:=0.0

func _hook(source:Signal,callback:Callable)->void:
	source.connect(callback)
	_connections.append([source,callback])

func bind_button(button:Button,arrow:Label=null)->void:
	var id:=button.get_instance_id()
	if _buttons.has(id):return
	var style:StyleBoxFlat
	var original:=button.get_theme_stylebox("normal")
	if original is StyleBoxFlat:
		style=original.duplicate() as StyleBoxFlat
		# One mutable local style prevents native hover states jumping ahead of
		# the interpolation, without altering the focus ring or click rectangle.
		for state:String in ["normal","hover","pressed","hover_pressed"]:
			button.add_theme_stylebox_override(state,style)
	var base_color:=button.get_theme_color("font_color")
	var data:Dictionary={"control":weakref(button),"arrow":weakref(arrow) if arrow!=null else null,
		"style":style,"hover":false,"focus":button.has_focus(),"down":false,"expanded":false,
		"active":0.0,"press":0.0,"turn":0.0,"base_color":base_color,"last_color":Color(-1,-1,-1,-1),
		"base_fill":style.bg_color if style!=null else INK}
	_buttons[id]=data
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if arrow!=null:
		arrow.pivot_offset=arrow.size*0.5
	_hook(button.mouse_entered,func():data.hover=true)
	_hook(button.mouse_exited,func():data.hover=false)
	_hook(button.focus_entered,func():data.focus=true)
	_hook(button.focus_exited,func():data.focus=false;data.down=false)
	_hook(button.button_down,func():data.down=true)
	_hook(button.button_up,func():data.down=false)

func set_expanded(button:Button,expanded:bool)->void:
	if not is_instance_valid(button):return
	var id:=button.get_instance_id()
	if _buttons.has(id):_buttons[id].expanded=expanded

func bind_slider(slider:HSlider,value_label:Label)->void:
	var id:=slider.get_instance_id()
	if _sliders.has(id):return
	var data:Dictionary={"control":weakref(slider),"label":weakref(value_label),
		"hover":false,"focus":slider.has_focus(),"down":false,"active":0.0,"press":0.0,"pulse":0.0,
		"base_color":value_label.get_theme_color("font_color"),"base_scale":value_label.scale,
		"last_color":Color(-1,-1,-1,-1)}
	_sliders[id]=data
	value_label.pivot_offset=value_label.size*0.5
	_hook(slider.mouse_entered,func():data.hover=true)
	_hook(slider.mouse_exited,func():data.hover=false)
	_hook(slider.focus_entered,func():data.focus=true)
	_hook(slider.focus_exited,func():data.focus=false;data.down=false)
	_hook(slider.drag_started,func():data.down=true)
	_hook(slider.drag_ended,func(_changed:bool):data.down=false;data.pulse=1.0)
	_hook(slider.value_changed,func(_value:float):data.pulse=0.75)

func menu_open(box:Control,upward:bool=false)->void:
	# Four pixels of travel convey the opening direction; no scale means text
	# stays crisp and rows keep their full native size throughout the reveal.
	var home:=box.position
	box.position=home+Vector2(0,4 if upward else -4)
	box.modulate.a=0.0
	var tween:=box.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(box,"position",home,0.14)
	tween.tween_property(box,"modulate:a",1.0,0.12)
	_menus.append(tween)

func _process(delta:float)->void:
	var blend:=1.0-exp(-minf(delta,0.1)*20.0)
	var press_blend:=1.0-exp(-minf(delta,0.1)*30.0)
	for id:int in _buttons.keys():
		var data:Dictionary=_buttons[id]
		var button:=data.control.get_ref() as Button
		if not is_instance_valid(button) or button.is_queued_for_deletion():
			_buttons.erase(id);continue
		var active:bool=(data.hover or data.focus or data.expanded) and not button.disabled
		var down:bool=data.down and not button.disabled
		data.active=lerpf(data.active,1.0 if active else 0.0,blend)
		data.press=lerpf(data.press,1.0 if down else 0.0,press_blend)
		var light_surface:bool=button.get_meta("light_surface",false)
		var fill:Color=data.base_fill.lerp(CREAM,data.active*.4).lerp(Color("eadbc5"),data.press*.5) if light_surface else data.base_fill.lerp(HOVER_INK,data.active).lerp(PRESS_INK,data.press)
		if data.style!=null and not data.style.bg_color.is_equal_approx(fill):data.style.bg_color=fill
		var target_color:Color=HOVER_INK if light_surface else (CREAM if data.focus or data.expanded else Color.WHITE)
		var color:Color=data.base_color.lerp(target_color,data.active)
		color=color.lerp(PRESS_INK if light_surface else CREAM,data.press)
		if not color.is_equal_approx(data.last_color):
			data.last_color=color
			for state:String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
				button.add_theme_color_override(state,color)
		if data.arrow!=null:
			var arrow:=data.arrow.get_ref() as Label
			if is_instance_valid(arrow):
				data.turn=lerpf(data.turn,PI if data.expanded else 0.0,blend)
				arrow.rotation=data.turn
	for id:int in _sliders.keys():
		var data:Dictionary=_sliders[id]
		var slider:=data.control.get_ref() as HSlider
		if not is_instance_valid(slider) or slider.is_queued_for_deletion():
			_sliders.erase(id);continue
		var active:bool=(data.hover or data.focus or data.down) and slider.editable
		data.active=lerpf(data.active,1.0 if active else 0.0,blend)
		data.press=lerpf(data.press,1.0 if data.down else 0.0,press_blend)
		data.pulse=move_toward(data.pulse,0.0,minf(delta,0.1)*5.0)
		var label:=data.label.get_ref() as Label
		if is_instance_valid(label):
			var color:Color=data.base_color.lerp(CREAM,data.active)
			if not color.is_equal_approx(data.last_color):
				data.last_color=color;label.add_theme_color_override("font_color",color)
	for index:int in range(_menus.size()-1,-1,-1):
		if not _menus[index].is_valid():_menus.remove_at(index)
	_prune_timer+=delta
	if _prune_timer>0.5:
		_prune_timer=0.0
		# Dropdown rows are short-lived. Drop their closed-over state instead of
		# accumulating signal callbacks for the entire lifetime of Settings.
		for index:int in range(_connections.size()-1,-1,-1):
			var source:Signal=_connections[index][0]
			if not is_instance_valid(source.get_object()):_connections.remove_at(index)

func reset()->void:
	for connection:Array in _connections:
		var source:Signal=connection[0]
		var owner:=source.get_object()
		if is_instance_valid(owner) and source.is_connected(connection[1]):source.disconnect(connection[1])
	_connections.clear()
	for tween:Tween in _menus:
		if tween.is_valid():tween.kill()
	_menus.clear();_buttons.clear();_sliders.clear()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT or what==NOTIFICATION_WM_MOUSE_EXIT:
		for data:Dictionary in _buttons.values():data.down=false;data.hover=false
		for data:Dictionary in _sliders.values():data.down=false;data.hover=false

func _exit_tree()->void:
	reset()
