extends SubViewport
## Forward-projected light bundles. Geometry is built once; the GPU updates their landing points.
const CausticsShader=preload("res://scripts/ui/settings_pool_caustics.gdshader")
const WORLD_SIZE:=Vector2(1600.0,900.0)
const OUTPUT_SIZE:=Vector2i(960,540)
const SPACING:=4.0
const COLUMNS:=400
const ROWS:=225
var surface_material:ShaderMaterial
var _light_mesh:MeshInstance2D
static var _shared_mesh:ArrayMesh

func _init()->void:
	name="SettingsPoolCaustics"
	size=OUTPUT_SIZE
	transparent_bg=true
	disable_3d=true
	gui_disable_input=true
	render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	render_target_update_mode=SubViewport.UPDATE_ALWAYS
	# Viewport has no own_world_2d boolean; a fresh World2D provides that isolation.
	world_2d=World2D.new()
	canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR

func _ready()->void:
	# The new World's canvas must be attached before RenderingServer accepts its transform.
	canvas_transform=Transform2D(Vector2(0.6,0.0),Vector2(0.0,0.6),Vector2.ZERO)
	_ensure_mesh()

func configure(heighttex:Texture2D)->void:
	_ensure_mesh()
	surface_material.set_shader_parameter("height_field",heighttex)
	if heighttex!=null:surface_material.set_shader_parameter("field_size",Vector2(heighttex.get_size()))

func update_surface(time:float,lemons:Array[Vector3])->void:
	_ensure_mesh()
	surface_material.set_shader_parameter("flow_time",time)
	if lemons.size()>0:surface_material.set_shader_parameter("lemon_large",lemons[0])
	if lemons.size()>1:surface_material.set_shader_parameter("lemon_small",lemons[1])

func _ensure_mesh()->void:
	if is_instance_valid(_light_mesh):return
	if _shared_mesh==null:_shared_mesh=_build_grid()
	surface_material=ShaderMaterial.new()
	surface_material.shader=CausticsShader
	_light_mesh=MeshInstance2D.new()
	_light_mesh.name="ProjectedWaterLight"
	_light_mesh.mesh=_shared_mesh
	_light_mesh.material=surface_material
	add_child(_light_mesh)

func _build_grid()->ArrayMesh:
	# Geometry is immutable: language changes and repeated page visits share it.
	var stride:=COLUMNS+1
	var vertices:=PackedVector2Array()
	vertices.resize(stride*(ROWS+1))
	var uvs:=PackedVector2Array()
	uvs.resize(vertices.size())
	for y:int in ROWS+1:
		for x:int in COLUMNS+1:
			var index:=y*stride+x
			var point:=Vector2(float(x)*SPACING,float(y)*SPACING)
			vertices[index]=point
			uvs[index]=point/WORLD_SIZE
	var indices:=PackedInt32Array()
	indices.resize(COLUMNS*ROWS*6)
	var cursor:=0
	for y:int in ROWS:
		for x:int in COLUMNS:
			var a:=y*stride+x
			var b:=a+1
			var c:=a+stride
			var d:=c+1
			# Alternating cell diagonals avoid a uniform diagonal bias in the light mesh.
			if (x+y)%2==0:
				indices[cursor]=a;indices[cursor+1]=b;indices[cursor+2]=d
				indices[cursor+3]=a;indices[cursor+4]=d;indices[cursor+5]=c
			else:
				indices[cursor]=a;indices[cursor+1]=b;indices[cursor+2]=c
				indices[cursor+3]=b;indices[cursor+4]=d;indices[cursor+5]=c
			cursor+=6
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh
