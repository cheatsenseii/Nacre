extends Node3D
var game: Node
var art: Node
var polish: Node
var batches: Dictionary={}
var cube:=BoxMesh.new()
var cylinder:=CylinderMesh.new()
var room_key:=""
var dust_fields: Array[CPUParticles3D]=[]

func _ready() -> void:
	game=get_parent()
	for child in game.get_children():
		if child.get_script()==preload("res://art.gd"):art=child
		if child.get_script()==preload("res://polish.gd"):polish=child
	cube.size=Vector3.ONE
	cylinder.top_radius=1;cylinder.bottom_radius=1;cylinder.height=1;cylinder.radial_segments=16
	# Recessed drainage grilles near room edges, away from interaction routes.
	var steel:=StandardMaterial3D.new();steel.albedo_color=Color("566065");steel.metallic=0.72;steel.roughness=0.44
	var cavity:=StandardMaterial3D.new();cavity.albedo_color=Color("0b1012");cavity.roughness=0.95
	var center: Vector3=game.atmosphere.mushroom_position
	for at in [Vector3(4.5,0.025,2.7),center+Vector3(-9,0.025,7),center+Vector3(8,0.025,-5),center+Vector3(8,0.025,-25)]:
		var base:=BoxMesh.new();base.size=Vector3(0.6,0.025,1.1)
		game.atmosphere.form(self,base,at,Vector3.ONE,cavity)
		var mesh:=BoxMesh.new();mesh.size=Vector3(0.54,0.015,0.035)
		var bars:=MultiMesh.new();bars.transform_format=MultiMesh.TRANSFORM_3D;bars.mesh=mesh;bars.instance_count=12
		for i in range(12):bars.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,0.025,-0.48+i*0.087)))
		var grille:=MultiMeshInstance3D.new();grille.multimesh=bars;grille.material_override=steel;grille.position=at;add_child(grille)
	finish_late_rooms()
	architecture(Vector3.ZERO,5.7,-3.5,4.5,6.5,0)
	architecture(center,13.15,-10.4,10.4,7.8,1)
	architecture(center+Vector3(0,0,-26),11.5,-14.2,13.8,5.7,2)
	architecture(game.combat.origin,11.65,-27.4,-0.6,5.7,3)
	architecture(game.simon.origin,8.65,-23.4,-0.6,5.4,4)
	flush_batches()
	# Detail the wardrobe materials without replacing their editable base colours.
	clothing(game.third_person.avatar)
	polish.practical(game.simon.origin+Vector3(-4,5.15,-7),Color("78bdb8"),2.3,13)
	polish.practical(game.simon.origin+Vector3(4,5.15,-18),Color("c79965"),2.2,13)
	polish.configure_lights(self)
	polish.configure_lights(polish)
	polish.apply_settings()

func clothing(node: Node) -> void:
	if node is MeshInstance3D and node.get_meta("look_group","") in ["haut","pantalon","sac"]:
		preload("res://material_detail.gd").apply(node.material_override,true)
	for child in node.get_children():clothing(child)

func finish_late_rooms() -> void:
	# These rooms are constructed after Art and previously missed its material pass.
	for room in [game.combat,game.simon,game.labyrinth]:
		for child in room.get_children():
			if not child is MeshInstance3D or not child.mesh is BoxMesh:continue
			if child.material_override is ShaderMaterial:continue
			var size: Vector3=child.mesh.size
			if maxf(size.x,size.z)<6 and size.y<5:continue
			var ceiling: bool=child.position.y>game.atmosphere.mushroom_position.y+5 and size.y<1
			child.material_override=art.surface(Color("536360") if not ceiling else Color("303c3c"),game.atmosphere.mushroom_position.y,not ceiling)

func instance(mesh: Mesh,mat: Material,at: Vector3,basis: Basis) -> void:
	var key:=room_key+str(mesh.get_instance_id())+"/"+str(mat.get_instance_id())
	if not batches.has(key):batches[key]={"mesh":mesh,"mat":mat,"transforms":[]}
	batches[key].transforms.append(Transform3D(basis,at))

func box(at: Vector3,size: Vector3,mat: Material) -> void:
	instance(cube,mat,at,Basis.IDENTITY.scaled(size))

func pipe(a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
	var y: Vector3=(b-a).normalized()
	var ref:=Vector3.FORWARD if absf(y.dot(Vector3.UP))>0.95 else Vector3.UP
	var x:=y.cross(ref).normalized()
	instance(cylinder,mat,(a+b)*0.5,Basis(x*radius,y*a.distance_to(b),x.cross(y)*radius))

func flush_batches() -> void:
	for key in batches:
		var batch: Dictionary=batches[key]
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=batch.mesh
		multi.instance_count=batch.transforms.size()
		for i in range(multi.instance_count):multi.set_instance_transform(i,batch.transforms[i])
		var node:=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=batch.mat
		node.visibility_range_end=55;node.visibility_range_end_margin=5
		add_child(node)
	batches.clear()

func architecture(center: Vector3,half_width: float,front: float,back: float,height: float,sector: int) -> void:
	room_key=str(sector)+":"
	var metal: Material=art.surface(Color("556d69"),center.y,false,true)
	var dark: Material=art.surface(Color("273335"),center.y,false,true)
	var ceramic: Material=art.surface(Color("4d6f70"),center.y,true)
	var brass: Material=art.surface(Color("8e7044"),center.y,false,true)
	var glow: Material=game.atmosphere.luminous(Color("8abeb3"),0.55)
	var span:=back-front
	for side in [-1.0,1.0]:
		var x: float=half_width*side
		# Layered skirting and cornice, set against walls rather than across routes.
		box(center+Vector3(x,0.19,(front+back)*0.5),Vector3(0.18,0.32,span),dark)
		box(center+Vector3(x-side*0.02,1.41,(front+back)*0.5),Vector3(0.1,0.05,span),brass)
		box(center+Vector3(x,height-0.25,(front+back)*0.5),Vector3(0.22,0.25,span),metal)
		for offset in [0.0,0.37]:
			pipe(center+Vector3(x-side*0.35,height-0.65-offset,front),center+Vector3(x-side*0.35,height-0.65-offset,back),0.105 if offset==0 else 0.065,metal)
		var count:=maxi(2,int(span/4.0))
		for i in range(count):
			var z:=lerpf(front+0.5,back-0.5,float(i)/maxf(1,count-1))
			box(center+Vector3(x, height*0.5,z),Vector3(0.2,height,0.28),ceramic)
			box(center+Vector3(x-side*0.35,height-0.8,z),Vector3(0.32,0.8,0.10),dark)
			for y in [height-0.49,height-1.1]:
				pipe(center+Vector3(x-side*0.53,y,z),center+Vector3(x-side*0.59,y,z),0.038,brass)
			# Flush wall vents: slats and recessed backing provide actual depth.
			box(center+Vector3(x-side*0.12,2.6,z),Vector3(0.08,0.7,1.1),dark)
			for slat in range(7):box(center+Vector3(x-side*0.18,2.33+slat*0.09,z),Vector3(0.045,0.033,1),metal)
		# A valve mounted high enough to keep navigation and combat clear.
		var valve_at:=center+Vector3(x-side*0.38,3.8,(front+back)*0.5)
		pipe(valve_at+Vector3(0,-0.65,0),valve_at+Vector3(0,0.65,0),0.09,metal)
		pipe(valve_at,valve_at+Vector3(-side*0.25,0,0),0.055,brass)
		var ring:=TorusMesh.new();ring.inner_radius=0.24;ring.outer_radius=0.29;ring.rings=24;ring.ring_segments=8
		instance(ring,brass,valve_at+Vector3(-side*0.3,0,0),Basis(Vector3.FORWARD,PI/2))
		for j in range(3):
			var a:=j*TAU/3
			pipe(valve_at+Vector3(-side*0.3,0,0),valve_at+Vector3(-side*0.3,cos(a)*0.25,sin(a)*0.25),0.018,brass)
		# Thin inset strips guide the eye without imitating an objective marker.
		for i in range(3):
			var z:=lerpf(front+1,back-1,float(i)/2)
			box(center+Vector3(x-side*0.12,0.5,z),Vector3(0.06,0.07,0.6),glow)
		puddle(center+Vector3(x-side*1.3,0.035,(front+back)*0.5+side*1.4),Vector2(0.65,2.0),sector+int(side))
	# Suspended cable tray and cross-members make ceilings read as a volume.
	for i in range(3):
		var z:=lerpf(front+0.6,back-0.6,float(i)/2)
		box(center+Vector3(0,height-0.25,z),Vector3(half_width*2,0.20,0.14),dark)
		for x in [-1.1,1.1]:
			pipe(center+Vector3(x,height-0.25,z),center+Vector3(x,height-0.9,z),0.024,metal)
		box(center+Vector3(0,height-0.91,z),Vector3(2.3,0.08,0.34),metal)
	for x in [-0.9,-0.6,-0.3]:pipe(center+Vector3(x,height-0.83,front),center+Vector3(x,height-0.83,back),0.035,dark)
	dust(center+Vector3(-half_width*0.45,3.5,(front+back)*0.5),sector==1)

func puddle(at: Vector3,size: Vector2,seed_value: int) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		for j in [-1,i,i+1]:
			var point:=Vector3.ZERO
			if j>=0:
				var a: float=j*TAU/48.0
				var r:=0.83+0.09*sin(a*3+seed_value)+0.06*cos(a*7)
				point=Vector3(cos(a)*size.x*r,0,sin(a)*size.y*r)
			surface.set_normal(Vector3.UP);surface.add_vertex(point)
	var node:=MeshInstance3D.new();node.mesh=surface.commit();node.position=at
	var material:=ShaderMaterial.new();material.shader=preload("res://water.gdshader")
	node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func dust(at: Vector3,organic: bool) -> void:
	var particles:=CPUParticles3D.new();particles.position=at;particles.amount=28;particles.lifetime=9
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;particles.emission_box_extents=Vector3(2.5,1.4,3)
	particles.direction=Vector3(0,-1,0);particles.gravity=Vector3.ZERO;particles.spread=22
	particles.initial_velocity_min=0.025;particles.initial_velocity_max=0.08
	particles.scale_amount_min=0.007;particles.scale_amount_max=0.018
	var mesh:=SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=6;mesh.rings=3
	mesh.material=game.atmosphere.luminous(Color("809f77") if organic else Color("798788"),0.15)
	particles.mesh=mesh;particles.visibility_aabb=AABB(Vector3(-4,-4,-5),Vector3(8,8,10))
	add_child(particles);dust_fields.append(particles)

func set_quality(level: int) -> void:
	for field in dust_fields:
		field.emitting=level>=2;field.visible=level>=2

func _process(_delta: float) -> void:
	for field in dust_fields:
		var near: bool=field.global_position.distance_squared_to(game.player.global_position)<625
		field.emitting=polish.quality>=2 and near and not game.paused
		field.visible=polish.quality>=2 and near
