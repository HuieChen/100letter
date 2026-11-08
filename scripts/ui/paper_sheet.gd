extends Control
## Content-sized paper dialogs. Long records scroll independently of their actions.
const UI=preload("res://scripts/ui/paper_ui.gd")
var _body:RichTextLabel
var _backing:Panel
var _actions:Array[Button]=[]
var _close_button:Button
var _heading:Label
var _width:=860.0
var _rounded_actions:=false

func configure(title:String,copy:String,actions:Array,close_action:Callable,rounded_actions:bool=false)->void:
	_rounded_actions=rounded_actions
	name="PaperSheet"
	_width=660.0 if copy.is_empty() else 860.0
	_backing=UI.panel(self,Rect2(0,0,_width,400),Color("f7efdc"))
	_backing.add_theme_stylebox_override("panel",preload("res://scripts/ui/paper_presentation.gd").backing(Color("f7efdc")))
	_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_heading=UI.label(self,title,Rect2(42,32,_width-164,60),32)
	_heading.name="SheetHeading"
	_close_button=UI.button(self,"×",Rect2(_width-82,26,54,54),close_action)
	_close_button.name="CloseSheet"
	if not copy.is_empty():
		_body=UI.body(self,copy,Rect2(42,112,_width-84,200),23)
		_body.name="SheetBody"
		_body.focus_mode=Control.FOCUS_ALL
		var focus_line:=StyleBoxFlat.new();focus_line.bg_color=Color.TRANSPARENT
		focus_line.border_color=Color("49745b");focus_line.border_width_bottom=2
		_body.add_theme_stylebox_override("focus",focus_line)
	for i:int in range(actions.size()):
		var button:Button
		if _rounded_actions:
			button=preload("res://scripts/ui/confirmation_paper_button.gd").new()
			button.text=str(actions[i][0])
			UI.place(button,self,Rect2((_width-550)*.5,0,550,110))
			button.pressed.connect(actions[i][1])
		else:button=UI.button(self,str(actions[i][0]),Rect2(42,0,_width-84,54),actions[i][1],i==0)
		button.name="SheetAction_"+str(i)
		button.add_theme_font_size_override("font_size",23)
		_actions.append(button)
	_layout()
	_layout.call_deferred()
	_focus_primary.call_deferred()
	preload("res://scripts/ui/paper_presentation.gd").enter.call_deferred(self)

func _layout()->void:
	if not is_inside_tree():return
	var y:=maxf(108.0,32.0+_heading.get_minimum_size().y+24.0)
	var step:=124.0 if _rounded_actions else 64.0
	var action_height:=float(_actions.size())*step-10.0 if not _actions.is_empty() else 0.0
	if _body!=null:
		var body_height:=clampf(float(_body.get_content_height())+8.0,64.0,minf(330.0,740.0-y-action_height-68.0))
		_body.position.y=y
		_body.size.y=body_height
		_body.focus_mode=Control.FOCUS_ALL if _body.get_content_height()>body_height else Control.FOCUS_NONE
		y+=body_height+24.0
	for button:Button in _actions:
		button.position.y=y;y+=step
	if not _actions.is_empty():y-=10.0
	var height:=y+36.0
	size=Vector2(_width,height)
	pivot_offset=size*.5
	position=(Vector2(1600,900)-size)*.5
	_backing.size=size

func _focus_primary()->void:
	if not is_inside_tree():return
	if not _actions.is_empty():_actions[0].grab_focus()
	else:_close_button.grab_focus()
