extends SceneTree
var checks:int=0
var failures:int=0
func _initialize()->void: _run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error(label)
func _run()->void:
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var guide_script=load('res://scripts/ui/field_guidance.gd')
	var session=load('res://scripts/core/GameSession.gd').new()
	var state:Dictionary=session.state.duplicate(true)
	var catalog:Dictionary=session.catalog
	var before:String=JSON.stringify(state)
	var g:Dictionary=guide_script.resolve(state,catalog,{'view':'location'})
	check(g.stage_id=='first_arrival' and g.target_id=='entrance','first day points to real door')
	state.clues=['postal_rules']
	check(guide_script.resolve(state,catalog,{'view':'location'}).stage_id=='first_arrival','optional notice does not skip first-letter instruction')
	state.clues=[]
	var progress:Dictionary=guide_script.progress_after({},'desk_entered')
	g=guide_script.resolve(state,catalog,{'view':'desk','entered_desk':true})
	check(g.target_id=='flip_edge','desk asks actual flip')
	check(not 'community_center' in str(g),'first guidance does not leak recipient id')
	progress=guide_script.progress_after(progress,'back_seen','case01')
	check(progress.seen_backs==['case01'],'back action remembered')
	check(guide_script.progress_after(progress,'back_seen','case01').seen_backs.size()==1,'repeated flip does not duplicate progress')
	state.ui_guidance=progress
	g=guide_script.resolve(state,catalog,{'view':'desk'})
	check(g.target_id=='map','viewed back gives next action')
	state.location='community_center'
	g=guide_script.resolve(state,catalog,{'view':'location'})
	check(g.target_id=='hotspot:old_hall_plaque','on site uses actual local clue prop')
	state.clues=['old_civic_hall_name']
	g=guide_script.resolve(state,catalog,{'view':'location'})
	check(g.target_id=='deliver','known-address stage points to handoff')
	state.letters.case01.status='delivered'
	g=guide_script.resolve(state,catalog,{'view':'desk'})
	check(g.target_id=='letter:case02','handled case asks next unhandled letter')
	state.current_case='case03';state.location='residential';state.clues=[]
	g=guide_script.resolve(state,catalog,{'view':'location'})
	check(g.target_id=='bag' and g.stage_id=='repair_label','unsolved scraps do not reveal complete address')
	state.letters.case03.repair_solved=true
	g=guide_script.resolve(state,catalog,{'view':'location'})
	check(g.target_id=='hotspot:door_302','repaired address points to actual nameplate')
	state.clues=['resident_moved'];state.location='community_center'
	g=guide_script.resolve(state,catalog,{'view':'location'})
	check(g.target_id=='hotspot:forwarding_register','moved resident points to updated public record')
	state.current_case='case04';state.clues=[]
	g=guide_script.resolve(state,catalog,{'view':'location'})
	check(not 'Mira' in g.detail and not 'June' in g.detail,'unknown identities remain unrevealed')
	state.clues=['old_nameplate','event_archive','handwriting_sample']
	g=guide_script.resolve(state,catalog,{'view':'desk'})
	check(g.stage_id=='lay_out_evidence' and g.target_id=='deliver','complete independent materials lead to physical comparison')
	check(guide_script.resolve(state,catalog,{'view':'title'}).active==false,'hidden on title')
	var fresh:Dictionary=session.state.duplicate(true)
	check(JSON.stringify(fresh)==before,'resolver never mutated core state')
	var screen:=Control.new();screen.size=Vector2(1600,900)
	var theme_value:=Theme.new();theme_value.default_font=load('res://assets/fonts/SolmereSans.ttf');screen.theme=theme_value
	root.add_child(screen)
	var ui=load('res://scripts/ui/paper_ui.gd')
	var depth:Control=load('res://scripts/ui/stage_depth.gd').new();depth.configure('post_office',false,540);ui.place(depth,screen,Rect2(0,0,1600,900))
	var layout=load('res://scripts/ui/stage_layout.gd').plan('post_office')
	ui.texture(screen,'res://assets/display_user/post_office_exterior_USER_20261001_LOCKED.jpg.png',layout.building)
	var entrance:Vector2=layout.building.position+Vector2(0.322,0.79)*layout.building.size
	var door:Control=load('res://scripts/ui/scene_props.gd').new();door.clue_marker('door','走进邮局，拿起今日来信');ui.place(door,screen,Rect2(entrance-Vector2(28,40),Vector2(56,80)))
	var actor:Control=load('res://scripts/ui/stage_walker.gd').new();actor.actor_height=177;ui.place(actor,screen,Rect2(0,0,1600,900));actor.configure(null,layout.walk_bounds,layout.spawn)
	ui.label(screen,'邮局',Rect2(62,112,790,47),29)
	ui.label(screen,'窗边已经摆好杯子，门前的邮袋还没有装满。',Rect2(65,159,910,63),18)
	var guide:Control=guide_script.new();ui.place(guide,screen,Rect2(0,0,1600,900))
	guide.configure(fresh,catalog,{'view':'location','anchors':{'entrance':entrance}})
	check(guide.mouse_filter==Control.MOUSE_FILTER_IGNORE,'guidance never blocks world clicks')
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png('user://field_guidance_arrival.png')
	guide.set_overlay_open(true);check(not guide.visible,'guidance can hide beneath modal')
	guide.set_overlay_open(false);check(guide.visible,'guidance restored with scene')
	var moving:=Control.new();moving.position=Vector2(100,500);screen.add_child(moving)
	guide.configure(fresh,catalog,{'view':'desk'});guide.track('flip_edge',moving,Vector2(30,20))
	check(guide._target_point()==Vector2(130,520),'tracked marker follows local object point')
	moving.position=Vector2(160,550)
	check(guide._target_point()==Vector2(190,570),'dragged letter marker does not remain at stale coordinates')
	moving.queue_free();await process_frame
	check(guide._target_point()==null,'freed target is safely ignored')
	print('FIELD_GUIDANCE_CHECKS=',checks,' FAILURES=',failures)
	session.free();quit(0 if failures==0 else 1)

