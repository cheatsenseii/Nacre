extends Node3D

const SURFACE_SHADER := preload("res://surface.gdshader")
const CRUST_SHADER := preload("res://crust.gdshader")

var game: Node3D
var built := false
var material_cache: Dictionary = {}
var accents: Array[Light3D] = []

func _ready() -> void:
	game=get_parent()
	call_deferred("late_build")

func late_build() -> void:
	if built:return
	await get_tree().process_frame
	await get_tree().process_frame
	if game==null or game.atmosphere==null:return
	tune_surfaces(game)
	build_marks()
	build_lighting_identity()
	built=true

func anchor(node: Variant, property_name: String, fallback: Vector3) -> Vector3:
	if node==null:return fallback
	var value: Variant=node.get(property_name)
	return value if value is Vector3 else fallback

func profile_index(at: Vector3) -> int:
	var mushroom: Vector3=game.atmosphere.mushroom_position
	var anchors: Array[Vector3]=[
		Vector3.ZERO,
		mushroom,
		mushroom+Vector3(0,0,-26),
		anchor(game.labyrinth,"origin",mushroom+Vector3(0,0,-54)),
		anchor(game.combat,"origin",mushroom+Vector3(0,0,-96)),
		anchor(game.simon,"origin",mushroom+Vector3(0,0,-128)),
		anchor(game.torture,"origin",mushroom+Vector3(0,0,-156)),
		anchor(game.horrors,"origin",mushroom+Vector3(0,0,-186)),
		anchor(game.silence,"origin",mushroom+Vector3(0,0,-72))
	]
	var best:=0
	var best_distance:=INF
	for i in range(anchors.size()):
		var delta:=Vector2(at.x-anchors[i].x,at.z-anchors[i].z)
		var distance:=delta.length_squared()
		if distance<best_distance:
			best_distance=distance;best=i
	return best

func profile(id: int) -> Dictionary:
	match id:
		1:return {"grime":0.62,"wet":1.0,"rust":0.32,"algae":0.95,"mineral":0.52,"wear":0.58,"seed":2.1}
		2:return {"grime":0.78,"wet":0.72,"rust":1.05,"algae":0.18,"mineral":0.68,"wear":0.84,"seed":4.7}
		3:return {"grime":0.86,"wet":0.58,"rust":0.58,"algae":0.34,"mineral":0.72,"wear":0.9,"seed":6.2}
		4:return {"grime":0.72,"wet":0.34,"rust":1.15,"algae":0.08,"mineral":0.42,"wear":1.0,"seed":8.4}
		5:return {"grime":0.56,"wet":0.26,"rust":0.48,"algae":0.05,"mineral":0.5,"wear":0.7,"seed":10.3}
		6:return {"grime":0.92,"wet":0.44,"rust":1.18,"algae":0.04,"mineral":0.46,"wear":1.15,"seed":12.8}
		7:return {"grime":1.0,"wet":0.72,"rust":0.86,"algae":0.28,"mineral":0.82,"wear":1.2,"seed":15.2}
		8:return {"grime":0.64,"wet":0.92,"rust":0.42,"algae":0.38,"mineral":0.9,"wear":0.62,"seed":17.9}
		_:return {"grime":0.5,"wet":0.38,"rust":0.72,"algae":0.1,"mineral":0.38,"wear":0.62,"seed":0.8}

func tuned_material(source: ShaderMaterial,id: int) -> ShaderMaterial:
	var key:=str(source.get_instance_id())+":"+str(id)
	if material_cache.has(key):return material_cache[key]
	var mat:=source.duplicate(true) as ShaderMaterial
	var values:=profile(id)
	mat.set_shader_parameter("grime_amount",values.grime)
	mat.set_shader_parameter("wetness",values.wet)
	mat.set_shader_parameter("rust_amount",values.rust)
	mat.set_shader_parameter("algae_amount",values.algae)
	mat.set_shader_parameter("mineral_amount",values.mineral)
	mat.set_shader_parameter("wear_amount",values.wear)
	mat.set_shader_parameter("surface_seed",values.seed)
	material_cache[key]=mat
	return mat

func tune_surfaces(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh:=child as MeshInstance3D
			var mat:=mesh.material_override
			if mat is ShaderMaterial and mat.shader==SURFACE_SHADER:
				mesh.material_override=tuned_material(mat,profile_index(mesh.global_position))
		tune_surfaces(child)

func crust_material(color: Color,density: float,seed: float) -> ShaderMaterial:
	var mat:=ShaderMaterial.new();mat.shader=CRUST_SHADER
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("density",density)
	mat.set_shader_parameter("seed",seed)
	return mat

func patch(at: Vector3,size: Vector2,rotation: Vector3,color: Color,density: float,seed: float) -> void:
	var quad:=QuadMesh.new();quad.size=size
	var node:=MeshInstance3D.new();node.mesh=quad;node.position=at;node.rotation=rotation
	node.material_override=crust_material(color,density,seed)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end=38
	add_child(node)

func wall_marks(center: Vector3,half_width: float,front: float,back: float,base_y: float,color: Color,seed: float) -> void:
	for side in [-1.0,1.0]:
		for i in range(3):
			var t:=float(i+1)/4.0
			var z:=lerpf(front,back,t)+sin(seed+i)*0.8
			patch(center+Vector3(side*(half_width-0.025),base_y+0.75+0.55*i,z),Vector2(1.1+0.35*i,0.75+0.22*i),Vector3(0,side*PI/2,0),color,0.76,seed+i*2.3)
	for i in range(3):
		var x:=lerpf(-half_width*0.6,half_width*0.6,float(i)/2.0)
		var z:=lerpf(front+1.0,back-1.0,0.25+0.25*i)
		patch(center+Vector3(x,0.024,z),Vector2(0.85+0.25*i,1.4),Vector3(-PI/2,0,0),color.darkened(0.18),0.7,seed+9+i)

func build_marks() -> void:
	var mushroom: Vector3=game.atmosphere.mushroom_position
	wall_marks(Vector3.ZERO,5.95,-3.8,4.5,0.0,Color("465a51"),1.0)
	wall_marks(mushroom,13.0,-10.1,10.1,mushroom.y,Color("315444"),3.0)
	wall_marks(mushroom+Vector3(0,0,-26),11.35,-13.9,13.5,mushroom.y,Color("6d442b"),5.0)
	var combat_origin:=anchor(game.combat,"origin",mushroom+Vector3(0,0,-96))
	wall_marks(combat_origin,11.45,-27.0,-0.9,combat_origin.y,Color("714331"),7.0)
	var simon_origin:=anchor(game.simon,"origin",mushroom+Vector3(0,0,-128))
	wall_marks(simon_origin,8.45,-23.0,-1.0,simon_origin.y,Color("4d5550"),9.0)

func accent(at: Vector3,color: Color,energy: float,reach: float) -> void:
	var light:=OmniLight3D.new();light.position=at
	light.light_color=color;light.light_energy=energy;light.omni_range=reach
	light.shadow_enabled=false;light.distance_fade_enabled=true
	light.distance_fade_begin=maxf(10.0,reach*1.2);light.distance_fade_length=8
	light.add_to_group("nacre_dynamic_light");light.set_meta("nacre_light_priority",0)
	add_child(light);accents.append(light)

func build_lighting_identity() -> void:
	var mushroom: Vector3=game.atmosphere.mushroom_position
	accent(Vector3(0,2.2,1.5),Color("c47a3d"),0.32,5.5)
	accent(mushroom+Vector3(4.8,1.2,1.5),Color("55a77e"),0.42,6.5)
	accent(mushroom+Vector3(-5.5,2.0,-26),Color("b45d32"),0.38,7.0)
	var combat_origin:=anchor(game.combat,"origin",mushroom+Vector3(0,0,-96))
	accent(combat_origin+Vector3(0,1.1,-15),Color("8d382b"),0.34,6.0)
	var simon_origin:=anchor(game.simon,"origin",mushroom+Vector3(0,0,-128))
	accent(simon_origin+Vector3(0,1.8,-11),Color("6e8f8a"),0.28,5.5)

func _process(_delta: float) -> void:
	if not built:return
	var polish:=game.get_node_or_null("Polish")
	var quality:=1
	if polish!=null:quality=int(polish.get("quality"))
	for light in accents:
		if is_instance_valid(light):light.visible=quality>0 and not game.paused
