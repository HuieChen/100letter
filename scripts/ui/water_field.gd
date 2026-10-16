extends RefCounted
## Height/velocity integration adapted from Evan Wallace's MIT water.js.
## Pinned bytes and license: third_party/webgl-water. No JS/demo assets executed.
## Fixed 60Hz surface waves, not a general CFD solver. Native rigid bodies are separate.
const W:=96
const H:=54
const SIZE:=Vector2(1600,900)
var height:=PackedFloat32Array()
var velocity:=PackedFloat32Array()
var next_height:=PackedFloat32Array()
var solids:=PackedByteArray()
var texture:ImageTexture
var steps:=0
var taps:=0
var strokes:=0
func _init()->void:
	height.resize(W*H);height.fill(0);velocity.resize(W*H);velocity.fill(0);next_height.resize(W*H);next_height.fill(0);solids.resize(W*H);solids.fill(0)
	texture=ImageTexture.create_from_image(Image.create_from_data(W,H,false,Image.FORMAT_RF,height.to_byte_array()))
func _drop(point:Vector2,radius:float,strength:float)->void:
	var center:=point/SIZE*Vector2(W,H)
	var min_x:=maxi(1,int(center.x-radius)-1);var max_x:=mini(W-2,int(center.x+radius)+1)
	var min_y:=maxi(1,int(center.y-radius)-1);var max_y:=mini(H-2,int(center.y+radius)+1)
	for y:int in range(min_y,max_y+1):
		for x:int in range(min_x,max_x+1):
			var i:=y*W+x
			if solids[i]:continue
			var falloff:=maxf(0.0,1.0-Vector2(x,y).distance_to(center)/radius)
			falloff=0.5-cos(falloff*PI)*0.5
			height[i]=clampf(height[i]+falloff*strength,-0.95,0.95)
func tap(point:Vector2,strength:float=1.0)->void:
	taps+=1;_drop(point,2.6,clampf(strength,0,1)*0.8)
func stroke(from:Vector2,to:Vector2,speed:float,dragging:bool=false)->void:
	if from.distance_to(to)<1.0:return
	strokes+=1;var direction:Vector2=(to-from).normalized()
	var strength:=clampf(speed/1100.0,0.02,0.48)*(1.3 if dragging else 1.0)
	var samples:=clampi(int(from.distance_to(to)/12.0),1,12)
	for i:int in samples:
		var point:=from.lerp(to,float(i+1)/samples)
		_drop(point+direction*9.0,1.7,strength)
		_drop(point-direction*11.0,1.9,-strength*0.72)
func set_obstacles(bodies:Array)->void:
	for y:int in H:
		for x:int in W:
			var point:=Vector2(x+0.5,y+0.5)/Vector2(W,H)*SIZE;var index:=y*W+x;solids[index]=0
			for body in bodies:
				if point.distance_squared_to(body.position)<body.radius*body.radius:solids[index]=1;break
func advance()->void:
	steps+=1
	for y:int in H:
		for x:int in W:
			var i:=y*W+x;var here:=height[i]
			if solids[i]:next_height[i]=0;velocity[i]=0;continue
			var average:=0.0
			for neighbor:int in [y*W+maxi(0,x-1),y*W+mini(W-1,x+1),maxi(0,y-1)*W+x,mini(H-1,y+1)*W+x]:
				average+=here if solids[neighbor] else height[neighbor]
			average*=0.25
			velocity[i]=(velocity[i]+(average-here)*0.108)*0.981
			next_height[i]=clampf(here+velocity[i],-0.95,0.95)
	var old:=height;height=next_height;next_height=old
	texture.update(Image.create_from_data(W,H,false,Image.FORMAT_RF,height.to_byte_array()))
func snapshot()->Dictionary:
	var energy:=0.0;var peak:=0.0
	for value:float in height:energy+=value*value;peak=maxf(peak,absf(value))
	return {"energy":energy,"peak":peak,"steps":steps,"taps":taps,"strokes":strokes,"cells":W*H}
