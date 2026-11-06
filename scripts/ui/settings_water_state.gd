extends RefCounted
## A shallow surface-wave field, coupled to the authored floating slices.
## Height is dimensionless; internal velocity is height per fixed 60 Hz tick.
const W:=160
const H:=90
const SIZE:=Vector2(1600,900)
const CELL:=10.0
const FIXED_STEP:=1.0/60.0
const PROPAGATION:=0.1225 # (210 world px/s * FIXED_STEP / CELL)^2
const VELOCITY_DAMP:=0.9769367839 # exp(-1.4 / 60)
var height:=PackedFloat32Array()
var velocity:=PackedFloat32Array()
var next_height:=PackedFloat32Array()
var solids:=PackedByteArray()
var texture:ImageTexture
var ambient_enabled:=true
var steps:=0
var taps:=0
var strokes:=0
var body_disturbances:=0
var _occupied:=PackedInt32Array()
var _edge_decay:=PackedFloat32Array()
var _accumulator:=0.0
var _ambient_clock:=0.0
var _texture_dirty:=false

func _init()->void:
	height.resize(W*H);height.fill(0.0)
	velocity.resize(W*H);velocity.fill(0.0)
	next_height.resize(W*H);next_height.fill(0.0)
	solids.resize(W*H);solids.fill(0)
	_edge_decay.resize(W*H)
	for y:int in H:
		for x:int in W:
			var edge:=minf(minf(x+0.5,W-x-0.5),minf(y+0.5,H-y-0.5))
			var absorb:=maxf(0.0,1.0-edge/6.0)
			_edge_decay[y*W+x]=exp(-0.20*absorb*absorb)
	texture=ImageTexture.create_from_image(Image.create_from_data(W,H,false,Image.FORMAT_RF,height.to_byte_array()))

func set_obstacles(bodies:Array)->void:
	# Rasterize only the two circle bounding boxes. The old occupied-cell list
	# also bounds the work of finding cells exposed by a moving slice.
	var previous_solids:=solids
	var previous_occupied:=_occupied
	solids=PackedByteArray();solids.resize(W*H);solids.fill(0)
	_occupied=PackedInt32Array()
	for body in bodies:
		if not is_instance_valid(body):continue
		var depth:float=float(body.get("press_depth"))
		var center:Vector2=body.position+Vector2(0,depth)
		var radius:float=float(body.get("radius"))
		var radius_squared:=radius*radius
		var x0:=clampi(int(floor((center.x-radius)/CELL)),0,W-1)
		var x1:=clampi(int(floor((center.x+radius)/CELL)),0,W-1)
		var y0:=clampi(int(floor((center.y-radius)/CELL)),0,H-1)
		var y1:=clampi(int(floor((center.y+radius)/CELL)),0,H-1)
		for y:int in range(y0,y1+1):
			var dy:float=(y+0.5)*CELL-center.y
			for x:int in range(x0,x1+1):
				var dx:float=(x+0.5)*CELL-center.x
				if dx*dx+dy*dy>radius_squared:continue
				var i:=y*W+x
				if solids[i]==0:_occupied.append(i)
				solids[i]=1;height[i]=0.0;velocity[i]=0.0;next_height[i]=0.0
	for i:int in previous_occupied:
		if solids[i]!=0:continue
		var x:=i%W
		var total:=0.0;var count:=0
		# Only previously wet cells contribute, so the fill is independent of
		# the traversal order of a newly exposed strip.
		if x>0 and previous_solids[i-1]==0 and solids[i-1]==0:total+=height[i-1];count+=1
		if x<W-1 and previous_solids[i+1]==0 and solids[i+1]==0:total+=height[i+1];count+=1
		if i>=W and previous_solids[i-W]==0 and solids[i-W]==0:total+=height[i-W];count+=1
		if i<W*(H-1) and previous_solids[i+W]==0 and solids[i+W]==0:total+=height[i+W];count+=1
		height[i]=total/float(count) if count>0 else 0.0
		velocity[i]=0.0;next_height[i]=height[i]
	_texture_dirty=true

func advance(delta:float=FIXED_STEP)->void:
	_accumulator+=clampf(delta,0.0,0.1333333333)
	var count:=0
	while _accumulator+0.000000001>=FIXED_STEP and count<8:
		_accumulator=maxf(0.0,_accumulator-FIXED_STEP)
		if ambient_enabled:
			_ambient_clock+=FIXED_STEP
			if _ambient_clock+0.000000001>=1.0:
				_ambient_clock-=1.0
				# A small incoming disturbance at the exposed left edge, not a
				# screen-wide time warp. It propagates by the same wave equation.
				_deposit_pressure(Vector2(65,420),43.0,0.018)
		_step();count+=1
	if count>0 or _texture_dirty:
		texture.update(Image.create_from_data(W,H,false,Image.FORMAT_RF,height.to_byte_array()))
		_texture_dirty=false

func _step()->void:
	steps+=1
	for y:int in H:
		var row:=y*W
		for x:int in W:
			var i:=row+x
			if solids[i]!=0:next_height[i]=0.0;velocity[i]=0.0;continue
			var here:float=height[i]
			# Neumann (zero normal gradient) on moving solids. No temporary
			# neighbour Array or Dictionary is allocated in this inner loop.
			var left:float=height[i-1] if x>0 and solids[i-1]==0 else here
			var right:float=height[i+1] if x<W-1 and solids[i+1]==0 else here
			var above:float=height[i-W] if y>0 and solids[i-W]==0 else here
			var below:float=height[i+W] if y<H-1 and solids[i+W]==0 else here
			var edge:float=_edge_decay[i]
			var v:=clampf((velocity[i]+(left+right+above+below-4.0*here)*PROPAGATION)*VELOCITY_DAMP*edge,-0.35,0.35)
			velocity[i]=v
			next_height[i]=clampf((here+v)*0.999*edge,-1.0,1.0)
	var previous:=height;height=next_height;next_height=previous

func tap(point:Vector2,strength:float=1.0)->void:
	taps+=1
	_deposit_pressure(point,24.0,clampf(strength,0.0,1.0)*0.42)

func _deposit_pressure(point:Vector2,radius:float,amount:float)->void:
	# A smooth positive centre and soft negative ring. Balance their discrete
	# sums over wet cells, including clipped edges and partially covered taps.
	if absf(amount)<0.0000001:return
	var support:=radius*2.8
	var x0:=clampi(int(floor((point.x-support)/CELL)),0,W-1)
	var x1:=clampi(int(floor((point.x+support)/CELL)),0,W-1)
	var y0:=clampi(int(floor((point.y-support)/CELL)),0,H-1)
	var y1:=clampi(int(floor((point.y+support)/CELL)),0,H-1)
	var ids:=PackedInt32Array();var weights:=PackedFloat32Array()
	var positive:=0.0;var negative:=0.0
	var inverse_radius:=1.0/(radius*radius)
	for y:int in range(y0,y1+1):
		var dy:float=(y+0.5)*CELL-point.y
		for x:int in range(x0,x1+1):
			var i:=y*W+x
			if solids[i]!=0:continue
			var dx:float=(x+0.5)*CELL-point.x
			var q:float=(dx*dx+dy*dy)*inverse_radius
			if q>7.84:continue
			var weight:float=(1.0-q)*exp(-q)
			ids.append(i);weights.append(weight)
			if weight>0.0:positive+=weight
			else:negative-=weight
	if positive<0.00001 or negative<0.00001:return
	var balance:=positive/negative
	for k:int in ids.size():
		var weight:float=weights[k]
		var pressure:float=weight if weight>=0.0 else weight*balance
		var i:int=ids[k]
		height[i]=clampf(height[i]+pressure*amount,-1.0,1.0)
	_texture_dirty=true

func stroke(from:Vector2,to:Vector2,speed:float,dragging:bool=false)->void:
	if not dragging:return
	var distance:=from.distance_to(to)
	if distance<0.001:return
	strokes+=1
	var travel:=minf(distance,180.0)
	var direction:Vector2=(to-from)/distance
	var count:=clampi(int(ceil(travel/18.0)),1,10)
	var amount:=clampf(speed/1200.0,0.03,1.0)*0.055*travel/(18.0*count)
	for k:int in count:
		var point:=from+direction*travel*(float(k)+0.5)/count
		_deposit_lobes(point+direction*11.0,point-direction*11.0,16.0,amount)

func _gaussian_lobe(point:Vector2,radius:float)->Dictionary:
	var ids:=PackedInt32Array();var weights:=PackedFloat32Array();var total:=0.0
	var support:=radius*2.6
	var x0:=clampi(int(floor((point.x-support)/CELL)),0,W-1)
	var x1:=clampi(int(floor((point.x+support)/CELL)),0,W-1)
	var y0:=clampi(int(floor((point.y-support)/CELL)),0,H-1)
	var y1:=clampi(int(floor((point.y+support)/CELL)),0,H-1)
	var inverse_radius:=1.0/(radius*radius)
	for y:int in range(y0,y1+1):
		var dy:float=(y+0.5)*CELL-point.y
		for x:int in range(x0,x1+1):
			var i:=y*W+x
			if solids[i]!=0:continue
			var dx:float=(x+0.5)*CELL-point.x
			var q:float=(dx*dx+dy*dy)*inverse_radius
			if q>6.76:continue
			var weight:=exp(-q)
			ids.append(i);weights.append(weight);total+=weight
	return {"ids":ids,"weights":weights,"sum":total}

func _deposit_lobes(positive:Vector2,negative:Vector2,radius:float,amount:float)->void:
	if absf(amount)<0.0000001:return
	var front:=_gaussian_lobe(positive,radius)
	var back:=_gaussian_lobe(negative,radius)
	if front.sum<0.00001 or back.sum<0.00001:return
	# Equal deposited volume on both sides, even beside an obstacle.
	var pressure:float=amount*minf(front.sum,back.sum)
	for k:int in front.ids.size():
		var i:int=front.ids[k]
		height[i]=clampf(height[i]+float(front.weights[k])*pressure/float(front.sum),-1.0,1.0)
	for k:int in back.ids.size():
		var i:int=back.ids[k]
		height[i]=clampf(height[i]-float(back.weights[k])*pressure/float(back.sum),-1.0,1.0)
	_texture_dirty=true

func disturb_body(center:Vector2,radius:float,delta_position:Vector2,delta_depth:float)->void:
	var distance:=delta_position.length()
	var depth:=clampf(delta_depth,-0.7,0.7)
	if distance<0.0001 and absf(depth)<0.0001:return
	body_disturbances+=1
	if distance>=0.0001:
		var direction:=delta_position/distance
		_deposit_lobes(center+direction*(radius+13.0),center-direction*(radius+13.0),18.0,minf(distance,1.5)*0.015)
	if absf(depth)>=0.0001:
		var amount:=depth*0.024
		for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			_deposit_lobes(center+direction*(radius+13.0),center+direction*(radius+38.0),15.0,amount)

func _sample(data:PackedFloat32Array,point:Vector2)->float:
	var grid:=point/CELL-Vector2(0.5,0.5)
	grid=grid.clamp(Vector2.ZERO,Vector2(W-1,H-1))
	var x:=int(floor(grid.x));var y:=int(floor(grid.y))
	var right:=mini(x+1,W-1);var below:=mini(y+1,H-1)
	var fx:=grid.x-x;var fy:=grid.y-y
	return lerpf(lerpf(data[y*W+x],data[y*W+right],fx),lerpf(data[below*W+x],data[below*W+right],fx),fy)

func sample_height(point:Vector2)->float:return _sample(height,point)
func sample_velocity(point:Vector2)->float:return _sample(velocity,point)/FIXED_STEP
func sample_slope(point:Vector2)->Vector2:
	return Vector2(sample_height(point+Vector2(CELL,0))-sample_height(point-Vector2(CELL,0)),sample_height(point+Vector2(0,CELL))-sample_height(point-Vector2(0,CELL)))/(2.0*CELL)

func current_at(point:Vector2)->Vector2:
	# A steady, smooth divergence-free field in world px/s. Spatial variation
	# carries the slices in one coherent current; no time sinusoid drives them.
	return Vector2(6.0+1.5*sin(point.x/600.0)*cos(point.y/250.0),-0.625*cos(point.x/600.0)*sin(point.y/250.0))

func snapshot()->Dictionary:
	var energy:=0.0;var peak:=0.0;var volume:=0.0
	for i:int in height.size():
		var value:float=height[i]
		energy+=value*value+velocity[i]*velocity[i];peak=maxf(peak,absf(value));volume+=value
	return {"engine":"fixed_step_surface_wave","width":W,"height":H,"cells":W*H,"energy":energy,"peak":peak,"volume":volume,
		"steps":steps,"taps":taps,"strokes":strokes,"body_disturbances":body_disturbances,"solid_cells":_occupied.size(),"ambient_enabled":ambient_enabled}
