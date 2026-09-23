extends Node3D
# Environment-only pass: gives each room a stronger visual story without changing gameplay.
var game: Node3D
var built := false
var micro_props: Array[Node3D] = []

func _ready() -> void:
	game=get_parent()
	call_deferred("late_build")

func late_build() -> void:
	if built:return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if game==null or game.atmosphere==null:return
	build_departure()
	build_garden()
	build_silence()
	build_labyrinth()
	build_combat()
	build_simon()
	build_torture()
	build_horrors()
	built=true

func mat(color: Color, metallic: float=0.0, roughness: float=0.82) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	result.metallic=metallic
	result.roughness=roughness
	return result

func box(at: Vector3,size: Vector3,material: Material,rotation: Vector3=Vector3.ZERO,micro: bool=false) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.rotation=rotation;node.material_override=material
	add_child(node)
	if micro:micro_props.append(node)
	return node

func cylinder(at: Vector3,radius: float,height: float,material: Material,rotation: Vector3=Vector3.ZERO,micro: bool=false) -> MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.rotation=rotation;node.material_override=material
	add_child(node)
	if micro:micro_props.append(node)
	return node

func rod(a: Vector3,b: Vector3,radius: float,material: Material,micro: bool=false) -> MeshInstance3D:
	var direction:=b-a
	var node:=cylinder((a+b)*0.5,radius,direction.length(),material,Vector3.ZERO,micro)
	node.quaternion=Quaternion(Vector3.UP,direction.normalized())
	return node

func sign_text(words: String,at: Vector3,yaw: float=0.0,size: int=34,color: Color=Color("b9c5ba")) -> Label3D:
	var label:=Label3D.new();label.text=words;label.font_size=size;label.pixel_size=0.0032
	label.position=at;label.rotation.y=yaw;label.modulate=color;label.outline_size=3;label.outline_modulate=Color("0a1112")
	add_child(label);return label

func warning_stripes(center: Vector3,width: float,z: float,y: float=0.018) -> void:
	var amber:=mat(Color("a66a24"),0.05,0.72)
	var dark:=mat(Color("1d2423"),0.0,0.9)
	for i in range(10):
		var x:=-width*0.45+float(i)*width/9.0
		var stripe:=box(center+Vector3(x,y,z),Vector3(width/13.0,0.012,0.42),amber if i%2==0 else dark,Vector3(0,0.38,0),true)
		stripe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func wall_panel(at: Vector3,size: Vector2,yaw: float,title: String,accent: Color) -> void:
	var dark:=mat(Color("182021"),0.45,0.7)
	var metal:=mat(Color("53615c"),0.65,0.5)
	box(at,Vector3(size.x,size.y,0.07),dark,Vector3(0,yaw,0))
	for x in [-size.x*0.43,size.x*0.43]:
		for y in [-size.y*0.42,size.y*0.42]:
			var offset:=Vector3(x,y,-0.045).rotated(Vector3.UP,yaw)
			cylinder(at+offset,0.028,0.05,metal,Vector3(PI/2,0,yaw),true)
	var label:=sign_text(title,at+Vector3(0,0,-0.052).rotated(Vector3.UP,yaw),yaw,31 if size.y>1.0 else 25,accent)
	label.no_depth_test=false

func old_bench(at: Vector3,yaw: float) -> void:
	var frame:=mat(Color("4b5752"),0.7,0.55);var seat:=mat(Color("3b4b46"),0.05,0.9)
	box(at+Vector3(0,0.56,0),Vector3(2.5,0.14,0.55),seat,Vector3(0,yaw,0))
	for x in [-1.05,1.05]:
		var leg_offset:=Vector3(x,0.26,0).rotated(Vector3.UP,yaw)
		box(at+leg_offset,Vector3(0.10,0.52,0.42),frame,Vector3(0,yaw,0),true)

func service_cart(at: Vector3,yaw: float) -> void:
	var steel:=mat(Color("596761"),0.72,0.46);var dark:=mat(Color("242b2b"),0.3,0.82)
	box(at+Vector3(0,0.72,0),Vector3(1.55,0.10,0.74),steel,Vector3(0,yaw,0))
	box(at+Vector3(0,1.25,0),Vector3(1.55,0.08,0.74),steel,Vector3(0,yaw,0))
	for x in [-0.66,0.66]:
		for z in [-0.27,0.27]:
			var p:=Vector3(x,0.65,z).rotated(Vector3.UP,yaw)
			rod(at+p,at+p+Vector3.UP*0.62,0.035,steel,true)
			cylinder(at+Vector3(x,0.18,z).rotated(Vector3.UP,yaw),0.09,0.07,dark,Vector3(PI/2,0,yaw),true)

func ceiling_service(center: Vector3,half_width: float,z_start: float,z_end: float,height: float,seed: float) -> void:
	var steel:=mat(Color("46524f"),0.72,0.52)
	var cable:=mat(Color("171d1e"),0.05,0.93)
	for z in [z_start,lerpf(z_start,z_end,0.5),z_end]:
		rod(center+Vector3(-half_width,height,z),center+Vector3(half_width,height,z),0.055,steel,true)
	for x in [-half_width*0.72,half_width*0.15]:
		var last:=center+Vector3(x,height,z_start)
		for i in range(1,7):
			var t:=float(i)/6.0
			var next:=center+Vector3(x+sin(seed+i)*0.15,height-0.10-absf(sin(t*PI))*0.18,lerpf(z_start,z_end,t))
			rod(last,next,0.018,cable,true);last=next

func build_departure() -> void:
	var origin:=Vector3.ZERO
	old_bench(origin+Vector3(4.5,0,-0.1),PI/2)
	wall_panel(origin+Vector3(5.72,3.0,-1.5),Vector2(2.2,1.3),-PI/2,"PLAN D'ÉVACUATION\nNIVEAU -1",Color("d7aa62"))
	warning_stripes(origin,4.2,-3.5)
	ceiling_service(origin,4.6,3.8,-3.2,6.55,1.2)

func build_garden() -> void:
	var center: Vector3=game.atmosphere.mushroom_position
	var dark:=mat(Color("283330"),0.45,0.75)
	service_cart(center+Vector3(-10.9,0,6.8),0.12)
	wall_panel(center+Vector3(12.78,3.3,5.8),Vector2(2.4,1.15),PI/2,"CULTURE 04\nQUARANTAINE",Color("78b999"))
	for i in range(4):
		var z:=-7.5+i*4.4
		box(center+Vector3(-12.7,1.1,z),Vector3(0.45,2.1,2.2),dark,Vector3.ZERO,true)
	ceiling_service(center,8.8,8.8,-8.8,6.45,3.4)

func build_silence() -> void:
	if game.silence==null:return
	var center: Vector3=game.silence.origin
	var metal:=mat(Color("56635f"),0.76,0.5)
	for x in [-9.8,9.8]:
		for z in [-10.2,-3.2,4.6,11.0]:
			cylinder(center+Vector3(x,2.0,z),0.32,3.7,metal,Vector3.ZERO,true)
			cylinder(center+Vector3(x-signf(x)*0.42,3.35,z),0.08,0.75,metal,Vector3(0,0,PI/2),true)
	wall_panel(center+Vector3(-10.7,3.25,-11.4),Vector2(2.0,1.0),PI/2,"RÉSEAU HYDRAULIQUE\nPRESSION INSTABLE",Color("d8a966"))
	ceiling_service(center,9.5,12.0,-12.5,5.25,5.1)

func build_labyrinth() -> void:
	if game.labyrinth==null:return
	var origin: Vector3=game.labyrinth.origin
	var bone:=mat(Color("465048"),0.15,0.92)
	for cell in [Vector2i(0,1),Vector2i(7,1),Vector2i(1,6),Vector2i(6,6)]:
		var at: Vector3=game.labyrinth.cell_at(cell)
		for h in [1.0,2.15,3.3]:
			rod(at+Vector3(-0.55,h,0),at+Vector3(0.55,h,0),0.045,bone,true)
	wall_panel(origin+Vector3(-7.8,3.7,-2.0),Vector2(2.1,0.95),PI/2,"ZONE TECHNIQUE\nACCÈS CONDAMNÉ",Color("b06e55"))

func build_combat() -> void:
	if game.combat==null:return
	var origin: Vector3=game.combat.origin
	service_cart(origin+Vector3(9.8,0,-24.5),PI/2)
	service_cart(origin+Vector3(-9.9,0,-12.0),PI/2)
	wall_panel(origin+Vector3(11.72,3.4,-17.0),Vector2(2.5,1.2),-PI/2,"FOSSE 04\nNETTOYAGE SUSPENDU",Color("c96e53"))
	warning_stripes(origin,5.5,-27.2)
	ceiling_service(origin,10.1,-2.0,-26.0,5.45,7.3)

func build_simon() -> void:
	if game.simon==null:return
	var origin: Vector3=game.simon.origin
	var frame:=mat(Color("46524e"),0.7,0.5);var glass:=mat(Color("162524"),0.15,0.22)
	for side in [-1.0,1.0]:
		box(origin+Vector3(side*7.6,2.7,-11),Vector3(0.16,3.4,5.8),frame,Vector3.ZERO,true)
		box(origin+Vector3(side*7.48,2.7,-11),Vector3(0.04,2.9,5.1),glass,Vector3.ZERO,true)
	wall_panel(origin+Vector3(0,4.45,-22.5),Vector2(3.2,0.8),0,"PROTOCOLE MÉMOIRE\nSESSION INTERROMPUE",Color("80a9a3"))

func build_torture() -> void:
	if game.torture==null:return
	var origin: Vector3=game.torture.origin
	var steel:=mat(Color("55625d"),0.75,0.52);var dark:=mat(Color("242b29"),0.22,0.9)
	for side in [-1.0,1.0]:
		var x:=side*9.8
		for z in [-4.0,-12.0,-20.0,-25.0]:
			rod(origin+Vector3(x,0.4,z),origin+Vector3(x,5.0,z),0.08,steel,true)
			box(origin+Vector3(x-side*0.18,3.15,z),Vector3(0.20,1.2,0.8),dark,Vector3.ZERO,true)
	wall_panel(origin+Vector3(-10.72,3.4,-13.5),Vector2(2.2,1.15),PI/2,"TRAITEMENT 06\nDOSAGE MANUEL",Color("b5c46f"))
	ceiling_service(origin,9.3,-2.0,-26.5,5.25,9.5)

func build_horrors() -> void:
	if game.horrors==null:return
	var origin: Vector3=game.horrors.origin
	var frame:=mat(Color("393f3b"),0.62,0.67)
	for z in [-5.5,-14.5,-23.5]:
		for side in [-1.0,1.0]:
			var x:=side*9.9
			box(origin+Vector3(x,2.1,z),Vector3(0.35,3.6,3.0),frame,Vector3.ZERO,true)
	wall_panel(origin+Vector3(10.72,3.5,-24.0),Vector2(2.3,1.25),-PI/2,"SECTEUR 07\nÉVACUATION INCOMPLÈTE",Color("b06e5d"))
	warning_stripes(origin,5.2,-29.1)
	ceiling_service(origin,9.6,-2.0,-28.0,5.2,11.7)

func _process(_delta: float) -> void:
	if not built:return
	var polish:=game.get_node_or_null("Polish")
	var quality:=1
	if polish!=null:quality=int(polish.get("quality"))
	for node in micro_props:
		if is_instance_valid(node):node.visible=quality>0
