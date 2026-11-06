extends Node
## Keep keyboard navigation on the currently open surface, then return to its opener.
var _host:Control
var _active:Control
var _active_id:=0
var _return_focus:WeakRef
var _blocked:Array=[]

func _ready()->void:
	_host=get_parent()
	get_viewport().gui_focus_changed.connect(_focus_changed)

func _focus_changed(control:Control)->void:
	if not is_instance_valid(_host.modal) and is_instance_valid(control):
		_return_focus=weakref(control)

func _process(_delta:float)->void:
	var current:Control=_host.modal if is_instance_valid(_host.modal) else null
	var current_id:=current.get_instance_id() if current!=null else 0
	if current_id!=_active_id:
		_restore_background()
		_active=current
		_active_id=current_id
		if current!=null:
			_block_background(_host)
		else:
			# The quickbar becomes visible in its own later process callback.
			# Restore after that visibility update, not while its opener is hidden.
			_restore_opener.call_deferred()
	if is_instance_valid(current):
		var focused:=get_viewport().gui_get_focus_owner()
		if focused==null or not current.is_ancestor_of(focused):
			var target:=_first_focusable(current)
			if target!=null:target.grab_focus()

func _restore_opener()->void:
	if not is_inside_tree() or not is_instance_valid(_host) or is_instance_valid(_host.modal):return
	# A subsequent action may already have chosen focus. Never steal it back.
	if get_viewport().gui_get_focus_owner()!=null:return
	var previous:Control=_return_focus.get_ref() if _return_focus!=null else null
	if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree() and previous.focus_mode!=Control.FOCUS_NONE:
		if not previous is BaseButton or not previous.disabled:previous.grab_focus()

func _block_background(node:Node)->void:
	if node==_active:return
	if node is Control and node.focus_mode!=Control.FOCUS_NONE:
		_blocked.append([weakref(node),node.focus_mode])
		node.focus_mode=Control.FOCUS_NONE
	for child:Node in node.get_children():_block_background(child)

func _restore_background()->void:
	for record:Array in _blocked:
		var control:Control=record[0].get_ref()
		if is_instance_valid(control):control.focus_mode=record[1]
	_blocked.clear()

func _first_focusable(node:Node)->Control:
	if node is Control and node.is_visible_in_tree() and node.focus_mode==Control.FOCUS_ALL:
		if not node is BaseButton or not node.disabled:return node
	for child:Node in node.get_children():
		var target:=_first_focusable(child)
		if target!=null:return target
	return null
