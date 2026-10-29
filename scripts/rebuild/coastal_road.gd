extends Control
signal map_requested
const UI=preload("res://scripts/ui/paper_ui.gd")
var minute:=540
var art:TextureRect
var stop:=0
var motion:Tween
var left:Button
var right:Button
func _ready()->void:
 clip_contents=true
 var filename:="road_morning.png"
 if minute>=1140 or minute<360:filename="road_night.png"
 elif minute>=1020:filename="road_sunset.png"
 elif minute>=660:filename="road_noon.jpg"
 var pixels:=Image.new()
 if pixels.load("res://assets/authoring/town_20261029/"+filename)!=OK:return
 art=TextureRect.new()
 art.texture=ImageTexture.create_from_image(pixels)
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 UI.place(art,self,Rect2(0,0,900.0*pixels.get_width()/pixels.get_height(),900))
 left=UI.button(self,"‹",Rect2(25,405,72,90),func():move_to(stop-1))
 right=UI.button(self,"›",Rect2(1503,405,72,90),func():move_to(stop+1))
 for button in [left,right]:
  button.add_theme_font_size_override("font_size",60)
  button.add_theme_stylebox_override("normal",UI.style(Color("fff1df"),Color("53716a"),24))
 UI.button(self,"↩",Rect2(30,28,72,64),func():map_requested.emit()).name="RoadMapReturn"
 update_arrows()
func move_to(next:int)->void:
 stop=clampi(next,0,4)
 if motion!=null:motion.kill()
 motion=create_tween()
 motion.tween_property(art,"position:x",-float(stop)/4.0*(art.size.x-1600.0),0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 update_arrows()
func update_arrows()->void:
 left.visible=stop>0
 right.visible=stop<4
