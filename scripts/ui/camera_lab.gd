extends RefCounted
const LabShader=preload("res://scripts/ui/camera_lab.gdshader")
const FontArt=preload("res://assets/fonts/DearRounded.tres")
# Original artistic recipes, inspired by instant/negative film characteristics.
# name zh/en, warmth, saturation, contrast, fade, grain, vignette
const RECIPES=[
 ["原色","Original",0.0,1.0,1.0,0.0,0.0,0.0],
 ["奶油","Cream",.30,.82,.92,.24,.12,.08],
 ["蜜糖","Honey",.65,.92,1.02,.15,.18,.12],
 ["海盐","Sea salt",-.42,.75,.91,.22,.10,.10],
 ["莓果","Berry",.12,1.15,1.07,.12,.16,.12],
 ["旧相纸","Old print",.48,.60,.86,.42,.35,.22],
 ["柔雾","Soft mist",-.10,.68,.82,.32,.12,.06],
 ["日光负片","Daylight",.24,1.08,1.10,.08,.28,.10],
 ["电影青","Cinema",-.48,.82,1.18,.12,.24,.22],
 ["金色时刻","Golden",.82,1.15,1.12,.08,.22,.18],
 ["褪色胶卷","Faded",.35,.65,.88,.50,.45,.26],
 ["银盐黑白","Silver",0.0,0.0,1.22,.05,.42,.18],
 ["黑白柔光","Mono soft",.10,0.0,.86,.25,.30,.10]
]
var owner:Control
var effect:ColorRect
var material:ShaderMaterial
var panel:PanelContainer
var toggle:Button
var values:Dictionary={"exposure":0.0,"warmth":0.0,"tint":0.0,"saturation":1.0,"contrast":1.0,"fade":0.0,"grain":0.0,"vignette":0.0,"aperture":8.0}
var sliders:Dictionary={}
var recipe:=0
var picker:OptionButton
var focus_point:=Vector2(.5,.5)
var recipe_label:Label
var preview_cards:Array[TextureRect]=[]
var advanced:VBoxContainer
var preview_busy:=false
func _init(camera:Control):
 owner=camera
 effect=ColorRect.new();effect.name="CameraColorPreview";effect.mouse_filter=Control.MOUSE_FILTER_IGNORE;effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 material=ShaderMaterial.new();material.shader=LabShader;effect.material=material;owner.add_child(effect);owner.move_child(effect,0)
func t(zh:String,en:String)->String:return en if owner.locale=="en" else zh
func build(canvas:Control):
 toggle=owner._button(t("胶片与调色","Film & light"),Rect2(90,128,300,48),24);toggle.name="CameraLabToggle"
 panel=PanelContainer.new();panel.name="CameraLabPanel";panel.position=Vector2(80,188);panel.size=Vector2(358,0);panel.mouse_filter=Control.MOUSE_FILTER_STOP
 var style=StyleBoxFlat.new();style.bg_color=Color("fff4df");style.set_corner_radius_all(18);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=14;style.content_margin_bottom=14
 panel.add_theme_stylebox_override("panel",style);canvas.add_child(panel)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(322,486);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var stack=VBoxContainer.new();stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stack.add_theme_constant_override("separation",7);scroll.add_child(stack)
 recipe_label=label(t("原色 · 即影即有 / 胶片","Original · Instant / Film"),19);stack.add_child(recipe_label)
 picker=OptionButton.new();picker.name="FilmRecipe";picker.add_theme_font_override("font",FontArt);picker.add_theme_font_size_override("font_size",21)
 for i in RECIPES.size():picker.add_item(t(RECIPES[i][0],RECIPES[i][1]),i)
 skin_button(picker);stack.add_child(picker);picker.item_selected.connect(func(index:int):select_recipe(index,true))
 var strip=ScrollContainer.new();strip.name="FilmPreviews";strip.custom_minimum_size=Vector2(310,76);strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;stack.add_child(strip)
 var cards=HBoxContainer.new();cards.add_theme_constant_override("separation",8);strip.add_child(cards)
 for i in RECIPES.size():
  var card=Button.new();card.custom_minimum_size=Vector2(76,60);card.tooltip_text=t(RECIPES[i][0],RECIPES[i][1]);cards.add_child(card);skin_button(card)
  var picture=TextureRect.new();picture.position=Vector2(3,3);picture.size=Vector2(70,54);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(picture);preview_cards.append(picture)
  card.pressed.connect(func():select_recipe(i,true))
 advanced=VBoxContainer.new();advanced.add_theme_constant_override("separation",6)
 for spec in [["exposure","曝光 EV","Exposure EV",-2.0,2.0,.1],["warmth","冷暖","Warmth",-1.0,1.0,.05],["tint","绿 / 洋红","Tint",-1.0,1.0,.05],["saturation","饱和度","Saturation",0.0,1.6,.05],["grain","颗粒","Grain",0.0,1.0,.05],["aperture","光圈 · 模拟景深","Aperture · simulated",1.4,8.0,.2]]:
  var parent:VBoxContainer=stack if spec[0] in ["exposure","aperture"] else advanced
  var row=HBoxContainer.new();parent.add_child(row)
  var title=label(t(spec[1],spec[2]),18);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
  var value=label("",18);row.add_child(value)
  var slider=HSlider.new();slider.name="Lab_"+spec[0];slider.min_value=spec[3];slider.max_value=spec[4];slider.step=spec[5];slider.value=values[spec[0]];slider.custom_minimum_size=Vector2(310,24);skin_slider(slider);parent.add_child(slider);sliders[spec[0]]=slider
  value.text=display_value(spec[0],slider.value)
  slider.value_changed.connect(func(v):values[spec[0]]=v;value.text=display_value(spec[0],v);apply())
 var expand=Button.new();expand.name="AdvancedCamera";expand.text=t("细调","More controls");skin_button(expand);stack.add_child(expand)
 stack.add_child(advanced);advanced.hide();expand.pressed.connect(func():advanced.visible=not advanced.visible;expand.text=t("收起细调","Fewer controls") if advanced.visible else t("细调","More controls");panel.set_deferred("size",Vector2(358,0)))
 var hint=label(t("右键选焦点 · f/8 全景清晰","Right-click focus · f/8 all sharp"),16);stack.add_child(hint)
 var reset=Button.new();reset.text=t("恢复当前风格","Reset this look");reset.add_theme_font_override("font",FontArt);reset.add_theme_font_size_override("font_size",20);skin_button(reset);stack.add_child(reset);reset.pressed.connect(func():select_recipe(recipe))
 var compare=Button.new();compare.name="CompareOriginal";compare.text=t("按住看原色","Hold for original");skin_button(compare);stack.add_child(compare)
 compare.button_down.connect(func():effect.hide());compare.button_up.connect(func():effect.show())
 compare.focus_exited.connect(func():effect.show())
 panel.hide();toggle.pressed.connect(_toggle_panel)
 apply()
func _toggle_panel():
 panel.visible=not panel.visible;owner._stop_pan()
 if panel.visible:refresh_previews()
func refresh_previews():
 if preview_busy or owner.capture_busy:return
 preview_busy=true
 owner.hide()
 await RenderingServer.frame_post_draw
 if not is_instance_valid(owner):return
 var pixels:Image=owner.get_viewport().get_texture().get_image()
 owner.show();preview_busy=false
 if pixels==null:return
 pixels.resize(256,144,Image.INTERPOLATE_LANCZOS)
 var texture=ImageTexture.create_from_image(pixels)
 for i in preview_cards.size():
  var m=ShaderMaterial.new();m.shader=LabShader;m.set_shader_parameter("live",false)
  var r=RECIPES[i]
  for pair in [["warmth",r[2]],["saturation",r[3]],["contrast",r[4]],["fade",r[5]],["grain",r[6]],["vignette",r[7]],["tint",.28 if i==4 else 0.0],["aperture",8.0]]:m.set_shader_parameter(pair[0],pair[1])
  preview_cards[i].texture=texture;preview_cards[i].material=m
func label(text:String,px:int)->Label:
 var node=Label.new();node.text=text;node.add_theme_font_override("font",FontArt);node.add_theme_font_size_override("font_size",px);node.add_theme_color_override("font_color",Color("665240"));return node
func display_value(key:String,v:float)->String:return "f/%.1f"%v if key=="aperture" else ("%+.1f"%v if key=="exposure" else "%d"%roundi(v*100))
func select_recipe(index:int,keep_adjustments:bool=false):
 var old_exposure:float=values.exposure
 var old_aperture:float=values.aperture
 recipe=index;picker.select(index);var r=RECIPES[index]
 values={"exposure":0.0,"warmth":r[2],"tint":.28 if index==4 else 0.0,"saturation":r[3],"contrast":r[4],"fade":r[5],"grain":r[6],"vignette":r[7],"aperture":8.0}
 if keep_adjustments:values.exposure=old_exposure;values.aperture=old_aperture
 for key in sliders:sliders[key].value=values[key]
 recipe_label.text=t("即影即有 · ","Instant · ")+t(r[0],r[1]) if index<7 else t("胶片 · ","Film · ")+t(r[0],r[1])
 apply()
func apply():
 for key in values:material.set_shader_parameter(key,values[key])
func focus_at(point:Vector2):
 focus_point=point.clamp(Vector2.ZERO,Vector2.ONE);material.set_shader_parameter("focus_point",focus_point)
func set_review(active:bool):
 effect.visible=not active
 if active:panel.hide()
 toggle.visible=not active
func render(pixels:Image)->Image:
 var viewport=SubViewport.new();viewport.disable_3d=true;viewport.size=pixels.get_size();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(viewport)
 var picture=TextureRect.new();picture.texture=ImageTexture.create_from_image(pixels);picture.size=Vector2(pixels.get_size());picture.material=material.duplicate();picture.material.set_shader_parameter("live",false);viewport.add_child(picture)
 await owner.get_tree().process_frame
 await RenderingServer.frame_post_draw
 var result=viewport.get_texture().get_image();viewport.queue_free();return result
func metadata()->Dictionary:return {"recipe":RECIPES[recipe][1],"controls":values.duplicate(),"focus_point":[focus_point.x,focus_point.y],"depth_of_field":"2D radial simulation"}

func skin_button(button:Button):
 for state in ["normal","hover","pressed","focus"]:
  var style=StyleBoxFlat.new();style.bg_color=Color("ead9bb") if state=="normal" else Color("d8c49e");style.set_corner_radius_all(10);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=6;style.content_margin_bottom=6
  button.add_theme_stylebox_override(state,style)
  button.add_theme_color_override("font_"+state+"_color",Color("554638"))
 button.add_theme_color_override("font_color",Color("554638"));button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func skin_slider(slider:HSlider):
 var rail=StyleBoxFlat.new();rail.bg_color=Color("dac9a9");rail.set_corner_radius_all(4);rail.content_margin_top=3;rail.content_margin_bottom=3
 slider.add_theme_stylebox_override("slider",rail)
 var fill=rail.duplicate();fill.bg_color=Color("82aaa4")
 slider.add_theme_stylebox_override("grabber_area",fill);slider.add_theme_stylebox_override("grabber_area_highlight",fill)
