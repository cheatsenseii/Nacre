extends Node3D
var game: Node
var avatar: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var blade: Node3D
var staff: Node3D
var camera_distance := 3.6
var clock := 0.0
var last_player_position := Vector3.ZERO
var camera_shape := SphereShape3D.new()
var camera_query := PhysicsShapeQueryParameters3D.new()
var shake_time := 0.0
var shake_duration := 0.16
var shake_strength := 0.0
var shake_clock := 0.0

func part(parent: Node3D,at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var mesh:=CapsuleMesh.new();mesh.radius=0.5;mesh.height=2
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at
	node.scale=Vector3(size.x,size.y/2,size.z);node.material_override=game.material(color)
	parent.add_child(node);return node

func limb(at: Vector3,length: float,color: Color) -> Node3D:
	var pivot:=Node3D.new();pivot.position=at;avatar.add_child(pivot)
	part(pivot,Vector3(0,-length/2,0),Vector3(0.15,length,0.17),color)
	return pivot

func _ready() -> void:
	game=get_parent();process_physics_priority=20
	avatar=Node3D.new();game.player.add_child(avatar);avatar.name="Personnage"
	avatar.scale.z=1.3
	var suit:=Color("292b2d");var trousers:=Color("343536");var shoes:=Color("202124")
	tailored(avatar,[[0.78,0.205,0.13],[0.84,0.215,0.14],[1.02,0.225,0.145],[1.22,0.25,0.14],[1.31,0.21,0.115],[1.37,0.09,0.085]],suit)
	part(avatar,Vector3(0,0.74,0),Vector3(0.37,0.24,0.28),trousers)
	# Collar, zipper, pockets and shoulder straps give the outfit a readable construction.
	oval(avatar,Vector3(0,1.37,0),Vector3(0.14,0.16,0.14),Color("c49c7e"))
	for x in [-0.07,0.07]:
		var collar: MeshInstance3D=game.combat.shape(avatar,Vector3(x,1.36,-0.085),Vector3(0.1,0.08,0.06),Color("353638"))
		collar.rotation.z=signf(x)*0.3
	game.combat.shape(avatar,Vector3(0,1.07,-0.154),Vector3(0.012,0.49,0.012),Color("1b1c1d"))
	for x in [-0.14,0.14]:
		var pocket: MeshInstance3D=game.combat.shape(avatar,Vector3(x,0.88,-0.127),Vector3(0.13,0.018,0.02),Color("242526"))
		pocket.rotation.z=signf(x)*0.32
	build_outfit_details()
	build_face()
	left_leg=limb(Vector3(-0.13,0.74,0),0.61,trousers)
	right_leg=limb(Vector3(0.13,0.74,0),0.61,trousers)
	for leg in [left_leg,right_leg]:
		part(leg,Vector3(0,-0.64,-0.06),Vector3(0.19,0.15,0.3),shoes)
		game.combat.shape(leg,Vector3(0,-0.69,-0.065),Vector3(0.18,0.035,0.26),Color("646b70"))
	for leg in [left_leg,right_leg]:
		for y in [-0.22,-0.26,-0.48]:
			stroke(leg,[Vector3(-0.052,y,-0.077),Vector3(0,y-0.015,-0.089),Vector3(0.05,y-0.005,-0.077)],0.003,Color("454952"))
		for y in [-0.58,-0.61,-0.64]:
			stroke(leg,[Vector3(-0.053,y,-0.175),Vector3(0.053,y,-0.175)],0.004,Color("b1b0a5"))
	left_arm=limb(Vector3(-0.3,1.28,0),0.52,suit)
	right_arm=limb(Vector3(0.3,1.28,0),0.52,suit)
	for arm in [left_arm,right_arm]:
		part(arm,Vector3(0,-0.45,0),Vector3(0.154,0.065,0.18),Color("303133"))
		oval(arm,Vector3(0,-0.54,0),Vector3(0.12,0.17,0.12),Color("c59c7e"))
	for arm in [left_arm,right_arm]:
		for y in [-0.2,-0.24,-0.4]:
			stroke(arm,[Vector3(-0.05,y,-0.06),Vector3(0,y-0.015,-0.087),Vector3(0.05,y,-0.06)],0.003,Color("252628"))
		for x in [-0.034,-0.012,0.012,0.034]:
			oval(arm,Vector3(x,-0.6,-0.015),Vector3(0.022,0.07,0.033),Color("c59c7e"))
	build_maintenance_kit()
	blade=game.combat.make_sword(right_arm);blade.position=Vector3(0,-0.54,-0.04);blade.scale=Vector3.ONE*0.65
	staff=game.feeding.make_stick(right_arm);staff.position=Vector3(0,-0.54,-0.04);staff.scale=Vector3.ONE*0.8
	blade.hide();staff.hide()
	game.torch.reparent(game.player)
	game.camera.near=0.08
	last_player_position=game.player.position

func update_camera(delta: float) -> void:
	var crouched: bool=game.actions.crouched
	var anchor:=Vector3(0,0.85 if game.sliding else (0.95 if crouched else 1.4),0)
	var distance:=2.15 if game.sliding else 3.6
	var desired: Vector3=anchor+game.camera.basis.z*distance+game.camera.basis.x*0.45
	var from: Vector3=game.player.to_global(anchor)
	var to: Vector3=game.player.to_global(desired)
	camera_shape.radius=0.2
	var query:=camera_query;query.shape=camera_shape
	query.transform=Transform3D(Basis.IDENTITY,from);query.motion=to-from
	query.collision_mask=1;query.exclude=[game.player.get_rid()]
	var length: float=(to-from).length()
	var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	# Check the anchor before sweeping.  A camera sphere that starts inside a
	# pillar otherwise receives a full sweep fraction and pops through geometry.
	var overlapping: Array[Dictionary]=space.intersect_shape(query,1)
	var allowed: float=0.08 if not overlapping.is_empty() else length
	if overlapping.is_empty():
		var fractions: PackedFloat32Array=space.cast_motion(query)
		allowed=maxf(0.05,length*fractions[0]-0.06) if fractions.size()>0 else length
	var teleported: bool=game.player.position.distance_to(last_player_position)>3
	# Retract immediately at obstacles; ease out when the space opens again.
	camera_distance=allowed if teleported or allowed<camera_distance else move_toward(camera_distance,allowed,delta*5)
	var base_position:=anchor+(desired-anchor).normalized()*camera_distance
	var shake_offset:=camera_shake_offset(delta)
	# Screen shake is applied after the main boom sweep. Sweep that final motion
	# too, otherwise a hit beside a wall briefly reveals the outside of the map.
	if shake_offset.length_squared()>0.000001:
		query.transform=Transform3D(Basis.IDENTITY,game.player.to_global(base_position))
		query.motion=game.player.global_basis*shake_offset
		if not space.intersect_shape(query,1).is_empty():shake_offset=Vector3.ZERO
		else:
			var shake_cast: PackedFloat32Array=space.cast_motion(query)
			if shake_cast.size()>0:shake_offset*=maxf(0,shake_cast[0]-0.01)
	game.camera.position=base_position+shake_offset
	game.torch.position=Vector3(0.34,anchor.y,-0.2)
	game.torch.rotation=game.camera.rotation
	if not game.sliding:
		var target_fov: float=82.0 if Input.is_action_pressed("sprint") else 78.0
		game.camera.fov=lerpf(game.camera.fov,target_fov,1.0-exp(-delta*8.0))
	last_player_position=game.player.position

func shake(strength: float, duration: float = 0.16) -> void:
	shake_strength=maxf(shake_strength,clampf(strength,0.0,0.5))
	shake_duration=maxf(shake_duration,duration)
	shake_time=maxf(shake_time,duration)

func camera_shake_offset(delta: float) -> Vector3:
	if shake_time<=0.0:
		shake_strength=move_toward(shake_strength,0.0,delta*2.8)
		return Vector3.ZERO
	shake_time=maxf(0.0,shake_time-delta)
	shake_clock+=delta*31.0
	var factor:=clampf(shake_time/maxf(shake_duration,0.001),0.0,1.0)
	var amount:=shake_strength*factor
	return Vector3(sin(shake_clock*1.7),cos(shake_clock*2.1),sin(shake_clock*2.7)*0.35)*amount

func reset_after_teleport(destination: Vector3) -> void:
	last_player_position=destination
	camera_distance=3.6
	shake_time=0.0
	shake_strength=0.0
	if game != null and game.camera != null:
		game.camera.reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	game.actions.hands.hide();game.combat.sword.hide();game.feeding.stick.hide()
	avatar.visible=not game.editor.active
	if game.editor.active or game.front_end.active:return
	if game.paused:return
	update_camera(delta)
	clock+=delta
	var speed:=Vector2(game.player.velocity.x,game.player.velocity.z).length()
	var moving: bool=speed>0.1 and game.player.is_on_floor()
	var stride: float=sin(clock*(10 if speed>3 else 7))*0.55 if moving else 0.0
	left_leg.rotation.x=stride;right_leg.rotation.x=-stride
	left_arm.rotation.x=-stride*0.6;right_arm.rotation.x=stride*0.6
	left_arm.rotation.z=0;right_arm.rotation.z=0
	avatar.rotation.x=0;avatar.rotation.z=0
	avatar.scale.y=0.7 if game.actions.crouched else 1.0
	avatar.position.y=absf(sin(clock*7))*0.025 if moving else 0.0
	blade.visible=game.combat.inside() and game.combat.equipped
	staff.visible=game.feeding.inside() and game.feeding.equipped and not game.puzzle.solved
	if blade.visible or staff.visible:right_arm.rotation.x=-0.65
	if game.combat.guarding and blade.visible:
		right_arm.rotation.x=-1.65;left_arm.rotation.x=-1.3
	elif game.combat.charging and blade.visible:right_arm.rotation.x=-2.3
	elif blade.visible and game.combat.cooldown>0:right_arm.rotation.x=-0.5-sin(clampf(game.combat.cooldown/0.8,0,1)*PI)*1.8
	elif staff.visible and game.feeding.cooldown>0:right_arm.rotation.x=-0.5-sin(game.feeding.cooldown/0.45*PI)*1.8
	elif game.actions.push_time>0:right_arm.rotation.x=-1.4;left_arm.rotation.x=-1.4
	if not game.player.is_on_floor():left_leg.rotation.x=-0.3;right_leg.rotation.x=0.25
	if game.sliding:
		avatar.scale.y=0.7;left_leg.rotation.x=-1.1;right_leg.rotation.x=-1.1
		left_arm.rotation.x=-0.8;right_arm.rotation.x=-0.8
	if game.horrors!=null and game.horrors.fear_weight>0:
		var fear: float=game.horrors.fear_weight
		avatar.rotation.x=-0.12*fear
		avatar.rotation.z=sin(clock*31)*0.018*fear
		avatar.scale.y*=1.0-0.07*fear
		left_arm.rotation.x=lerpf(left_arm.rotation.x,1.35,fear)
		right_arm.rotation.x=lerpf(right_arm.rotation.x,1.15,fear)
		left_arm.rotation.z=0.32*fear;right_arm.rotation.z=-0.3*fear

func oval(parent: Node3D,at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var mesh:=SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=32;mesh.rings=20
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.scale=size
	node.material_override=game.material(color);parent.add_child(node);return node

func build_face() -> void:
	var face:=Node3D.new();face.name="Visage";face.position=Vector3(0,1.57,0);avatar.add_child(face)
	var skin:=Color("cfa889");var hair:=Color("7f6241");var beard:=Color("765335")
	oval(face,Vector3.ZERO,Vector3(0.27,0.34,0.265),skin)
	oval(face,Vector3(0,-0.07,-0.024),Vector3(0.235,0.2,0.23),skin)
	for side in [-1,1]:
		oval(face,Vector3(side*0.137,-0.009,0),Vector3(0.045,0.09,0.045),skin)
		oval(face,Vector3(side*0.145,-0.005,-0.014),Vector3(0.018,0.05,0.014),Color("b38370"))
	# A close-cropped cap follows the upper skull instead of a hat.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		for j in range(36):
			var corners: Array[Vector3]=[]
			for ij in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var a: float=float(ij.y)/36*TAU
				var t: float=float(ij.x)/10*(1.42+0.64*maxf(0,sin(a)))
				corners.append(Vector3(sin(t)*cos(a)*0.139,cos(t)*0.173+0.004,sin(t)*sin(a)*0.137))
			for index in [0,1,2,0,2,3]:surface.add_vertex(corners[index])
	surface.generate_normals();var scalp:=MeshInstance3D.new();scalp.mesh=surface.commit();scalp.material_override=game.material(hair)
	scalp.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;face.add_child(scalp)
	# Defined jaw beard, moustache, nose, brows and eyes remain legible at game scale.
	oval(face,Vector3(0,-0.102,-0.087),Vector3(0.235,0.185,0.16),beard)
	for side in [-1,1]:
		oval(face,Vector3(side*0.106,-0.042,-0.085),Vector3(0.048,0.14,0.064),beard)
		oval(face,Vector3(side*0.052,0.015,-0.124),Vector3(0.063,0.032,0.022),Color("8d6550"))
		oval(face,Vector3(side*0.052,0.013,-0.134),Vector3(0.049,0.019,0.01),Color("d8d5c4"))
		oval(face,Vector3(side*0.052,0.014,-0.141),Vector3(0.017,0.017,0.006),Color("68746c"))
		oval(face,Vector3(side*0.052,0.014,-0.144),Vector3(0.008,0.011,0.004),Color("1b2427"))
		var brow:=oval(face,Vector3(side*0.055,0.039,-0.128),Vector3(0.08,0.018,0.018),hair)
		brow.rotation.z=side*0.12
	oval(face,Vector3(0,-0.008,-0.137),Vector3(0.036,0.086,0.051),skin)
	oval(face,Vector3(0,-0.045,-0.16),Vector3(0.052,0.032,0.04),Color("c99a7d"))
	for side in [-1,1]:
		var mustache:=oval(face,Vector3(side*0.029,-0.067,-0.167),Vector3(0.075,0.035,0.028),hair)
		mustache.rotation.z=side*0.18
	oval(face,Vector3(0,-0.092,-0.166),Vector3(0.07,0.017,0.013),Color("9e6d5d"))
	for i in range(9):
		var tuft:=oval(face,Vector3((i-4)*0.018,-0.14+absf(i-4)*0.004,-0.148),Vector3(0.02,0.054,0.015),hair if i%3==0 else beard)
		tuft.rotation.z=(i-4)*0.06

# Elliptical ring topology gives garments an actual shoulder and waist silhouette.
func tailored(parent: Node3D,rings: Array,color: Color) -> MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size()-1):
		for j in range(32):
			var points: Array[Vector3]=[]
			for ij in [Vector2i(r,j),Vector2i(r+1,j),Vector2i(r+1,j+1),Vector2i(r,j+1)]:
				var ring: Array=rings[ij.x];var a: float=ij.y*TAU/32
				points.append(Vector3(cos(a)*ring[1],ring[0],sin(a)*ring[2]))
			for k in [0,2,1,0,3,2]:st.add_vertex(points[k])
	for ring_index in [0,rings.size()-1]:
		var edge: Array=rings[ring_index]
		for j in range(32):
			st.add_vertex(Vector3(0,edge[0],0))
			for k in [j,j+1]:st.add_vertex(Vector3(cos(k*TAU/32)*edge[1],edge[0],sin(k*TAU/32)*edge[2]))
	st.generate_normals();var node:=MeshInstance3D.new();node.mesh=st.commit()
	node.material_override=game.material(color);node.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
	parent.add_child(node);return node

func stroke(parent: Node3D,points: Array,radius: float,color: Color) -> void:
	for i in range(points.size()-1):
		var a: Vector3=points[i];var b: Vector3=points[i+1];var direction:=b-a
		var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=direction.length();mesh.radial_segments=8
		var node:=MeshInstance3D.new();node.mesh=mesh;node.position=(a+b)*0.5
		node.quaternion=Quaternion(Vector3.UP,direction.normalized());node.material_override=game.material(color);parent.add_child(node)

func build_outfit_details() -> void:
	var dark:=Color("222a31");var seam:=Color("63717a");var fabric:=Color("333d45")
	# Fitted backpack with a layered shell, padded back, raised piping and hardware.
	var pack:=Node3D.new();pack.name="Sac_detaille";avatar.add_child(pack);pack.position=Vector3(0,0,0.225)
	tailored(pack,[[0.87,0.14,0.07],[0.9,0.18,0.09],[1.14,0.185,0.1],[1.27,0.15,0.08],[1.3,0.07,0.045]],dark)
	oval(pack,Vector3(0,1.05,0.07),Vector3(0.31,0.38,0.12),fabric)
	stroke(pack,[Vector3(-0.13,0.91,0.115),Vector3(-0.156,1.02,0.115),Vector3(-0.145,1.19,0.105),Vector3(-0.09,1.26,0.085),Vector3(0,1.28,0.072),Vector3(0.09,1.26,0.085),Vector3(0.145,1.19,0.105),Vector3(0.156,1.02,0.115),Vector3(0.13,0.91,0.115)],0.004,seam)
	part(pack,Vector3(0,0.98,0.13),Vector3(0.26,0.18,0.075),Color("28323a"))
	stroke(pack,[Vector3(-0.11,1.045,0.15),Vector3(0,1.053,0.171),Vector3(0.11,1.045,0.15)],0.004,Color("929a98"))
	stroke(pack,[Vector3(-0.06,1.29,0),Vector3(-0.05,1.355,0),Vector3(0.05,1.355,0),Vector3(0.06,1.29,0)],0.012,dark)
	for side in [-1,1]:
		var x: float=side*0.165
		stroke(avatar,[Vector3(x,0.92,-0.155),Vector3(x,1.17,-0.158),Vector3(x,1.31,-0.115),Vector3(x,1.355,0),Vector3(x,1.28,0.22)],0.022,dark)
		stroke(avatar,[Vector3(x+side*0.014,0.96,-0.174),Vector3(x+side*0.014,1.2,-0.168),Vector3(x,1.34,-0.045)],0.0025,seam)
		game.combat.shape(avatar,Vector3(x,0.995,-0.18),Vector3(0.057,0.036,0.015),seam)
		game.combat.shape(avatar,Vector3(x,0.995,-0.19),Vector3(0.034,0.018,0.008),dark)
		stroke(pack,[Vector3(side*0.177,0.94,0.025),Vector3(side*0.186,1.06,0.035)],0.014,Color("171f25"))
		stroke(pack,[Vector3(side*0.145,1.17,0.105),Vector3(side*0.14,1.125,0.14)],0.006,Color("a2a6a0"))
		for y in [0.87,0.91,1.18]:
			stroke(avatar,[Vector3(side*0.07,y,0.13),Vector3(side*0.15,y-0.014,0.116),Vector3(side*0.205,y+0.01,0.07)],0.003,Color("aa7275"))
	# Woven patch and rows of stitching are geometry, visible without textures.
	game.combat.shape(pack,Vector3(0,1.15,0.135),Vector3(0.08,0.049,0.012),Color("9e9480"))
	for x in [-0.023,0.0,0.023]:
		stroke(pack,[Vector3(x,1.135,0.144),Vector3(x,1.164,0.144)],0.003,dark)
	for i in range(19):
		var x: float=(i-9)*0.019
		var z: float=sqrt(maxf(0,1-pow(x/0.21,2)))*0.134
		stroke(avatar,[Vector3(x,0.801,z),Vector3(x+0.007,0.801,z)],0.0018,Color("e0aba5"))
	# Hood folds frame the neck and remain readable from the gameplay camera.
	oval(avatar,Vector3(0,1.295,0.12),Vector3(0.27,0.14,0.12),Color("af797d"))
	stroke(avatar,[Vector3(-0.11,1.33,0.135),Vector3(-0.07,1.265,0.177),Vector3(0,1.25,0.184),Vector3(0.07,1.265,0.177),Vector3(0.11,1.33,0.135)],0.006,Color("d09a98"))
	for x in [-0.055,0.055]:
		stroke(avatar,[Vector3(x,1.34,-0.105),Vector3(x*1.15,1.22,-0.16)],0.003,Color("e8c5b6"))

func badge(parent: Node3D,words: String,at: Vector3,back: bool=false) -> void:
	var label:=Label3D.new();label.text=words;label.font_size=40;label.pixel_size=0.00075
	label.position=at;label.rotation.y=0 if back else PI
	label.modulate=Color("c2d3c5");label.outline_size=2
	label.no_depth_test=false;parent.add_child(label)

func build_maintenance_kit() -> void:
	var rubber:=Color("252e31");var teal:=Color("548e89");var silver:=Color("b0b9b3")
	var amber:=Color("c49559");var stitching:=Color("a9aaa0")
	# A maintenance uniform, with large readable layers before tiny hardware.
	tailored(avatar,[[0.77,0.211,0.147],[0.82,0.219,0.15]],rubber)
	game.combat.shape(avatar,Vector3(0,0.797,-0.159),Vector3(0.075,0.044,0.022),silver)
	game.combat.shape(avatar,Vector3(0,0.797,-0.173),Vector3(0.045,0.024,0.01),rubber)
	for side in [-1.0,1.0]:
		# Raised chest pockets with a contrasting flap and a press stud.
		part(avatar,Vector3(side*0.101,1.16,-0.149),Vector3(0.125,0.13,0.047),Color("aa7275"))
		game.combat.shape(avatar,Vector3(side*0.101,1.205,-0.176),Vector3(0.115,0.025,0.015),Color("e0a8a3"))
		oval(avatar,Vector3(side*0.101,1.2,-0.188),Vector3.ONE*0.011,silver)
		stroke(avatar,[Vector3(side*0.04,1.28,-0.14),Vector3(side*0.12,1.285,-0.14),Vector3(side*0.21,1.25,-0.105)],0.007,teal)
		# Small loops and a clipped pouch follow the waist contour.
		game.combat.shape(avatar,Vector3(side*0.16,0.81,-0.105),Vector3(0.022,0.075,0.022),Color("aa7275"))
	badge(avatar,"NACRE",Vector3(-0.098,1.155,-0.181))
	# Radio and curled lead mounted on the right shoulder strap.
	part(avatar,Vector3(0.177,1.15,-0.188),Vector3(0.059,0.105,0.047),rubber)
	stroke(avatar,[Vector3(0.193,1.19,-0.196),Vector3(0.192,1.285,-0.195)],0.004,rubber)
	for i in range(3):game.combat.shape(avatar,Vector3(0.174,1.168-i*0.013,-0.216),Vector3(0.032,0.004,0.006),silver)
	game.combat.shape(avatar,Vector3(0.174,1.121,-0.216),Vector3(0.027,0.016,0.004),teal)
	var cable: Array=[]
	for i in range(20):cable.append(Vector3(0.179+sin(i*1.8)*0.008,1.09-i*0.006,-0.182))
	stroke(avatar,cable,0.0025,rubber)
	for index in range(2):
		var leg: Node3D=left_leg if index==0 else right_leg
		var arm: Node3D=left_arm if index==0 else right_arm
		var side: float=-1 if index==0 else 1
		# Cargo pockets, layered knee pads, ankle gaiters and substantial toe caps.
		part(leg,Vector3(side*0.083,-0.16,0.005),Vector3(0.065,0.17,0.13),Color("454952"))
		game.combat.shape(leg,Vector3(side*0.114,-0.10,0.005),Vector3(0.025,0.035,0.125),rubber)
		part(leg,Vector3(0,-0.36,-0.087),Vector3(0.145,0.15,0.059),rubber)
		part(leg,Vector3(0,-0.356,-0.12),Vector3(0.103,0.106,0.025),Color("65716e"))
		stroke(leg,[Vector3(-0.045,-0.39,-0.137),Vector3(0,-0.4,-0.139),Vector3(0.045,-0.39,-0.137)],0.003,stitching)
		part(leg,Vector3(0,-0.53,0),Vector3(0.175,0.09,0.19),rubber)
		part(leg,Vector3(0,-0.644,-0.149),Vector3(0.185,0.075,0.13),rubber)
		for z in [-0.145,-0.07,0.015]:
			game.combat.shape(leg,Vector3(0,-0.711,z),Vector3(0.186,0.025,0.032),rubber)
		stroke(leg,[Vector3(-0.081,-0.67,0.02),Vector3(-0.082,-0.67,-0.13),Vector3(0,-0.67,-0.20),Vector3(0.082,-0.67,-0.13),Vector3(0.081,-0.67,0.02)],0.003,amber)
		# Elbow patches and fingerless work gloves stay attached to animated limbs.
		part(arm,Vector3(0,-0.26,0.063),Vector3(0.127,0.125,0.065),rubber)
		part(arm,Vector3(0,-0.475,0),Vector3(0.17,0.045,0.19),teal)
		part(arm,Vector3(0,-0.535,0),Vector3(0.128,0.085,0.131),rubber)
		for x in [-0.03,0.0,0.03]:
			oval(arm,Vector3(x,-0.526,0.062),Vector3(0.022,0.037,0.018),Color("65716e"))
		part(arm,Vector3(side*0.035,-0.055,0.015),Vector3(0.16,0.13,0.17),Color("af797d"))
		stroke(arm,[Vector3(-0.07,-0.11,0.067),Vector3(0,-0.11,0.092),Vector3(0.07,-0.11,0.067)],0.006,amber)
	# A watch face sits on the exposed side of the left wrist.
	game.combat.shape(left_arm,Vector3(-0.073,-0.465,-0.006),Vector3(0.023,0.046,0.05),silver)
	game.combat.shape(left_arm,Vector3(-0.087,-0.465,-0.006),Vector3(0.007,0.032,0.036),teal)
	var pack: Node3D=avatar.get_node("Sac_detaille")
	# Broad back badge replaces the anonymous patch: legible in third person.
	game.combat.shape(pack,Vector3(0,1.15,0.144),Vector3(0.19,0.08,0.016),rubber)
	badge(pack,"NACRE",Vector3(0,1.158,0.156),true)
	badge(pack,"MAINTENANCE",Vector3(0,1.13,0.156),true)
	for side in [-1.0,1.0]:
		stroke(pack,[Vector3(side*0.136,0.925,0.15),Vector3(side*0.145,1.08,0.143)],0.008,teal)
		for y in [0.96,1.02,1.08]:game.combat.shape(pack,Vector3(side*0.105,y,0.165),Vector3(0.048,0.014,0.014),rubber)
	# A rolled emergency cover and flask change the silhouette from the back.
	var roll:=CylinderMesh.new();roll.top_radius=0.053;roll.bottom_radius=0.053;roll.height=0.39;roll.radial_segments=24
	var roll_node: MeshInstance3D=game.atmosphere.form(pack,roll,Vector3(0,0.87,0.08),Vector3.ONE,game.material(Color("548e89")))
	roll_node.rotation.z=PI/2
	for x in [-0.11,0.11]:
		stroke(pack,[Vector3(x,0.9,0.03),Vector3(x,0.923,0.08),Vector3(x,0.9,0.132),Vector3(x,0.845,0.132),Vector3(x,0.818,0.08)],0.009,rubber)
	part(pack,Vector3(-0.209,1.025,0.025),Vector3(0.076,0.18,0.082),Color("65716e"))
	game.combat.shape(pack,Vector3(-0.209,1.127,0.025),Vector3(0.043,0.026,0.047),rubber)
	stroke(pack,[Vector3(-0.24,1.01,-0.005),Vector3(-0.249,1.01,0.06),Vector3(-0.181,1.01,0.06)],0.009,rubber)
	# Three stitched waves are NACRE's recurring mark, also visible without the pack.
	for row in range(3):
		var wave: Array=[]
		for i in range(9):wave.append(Vector3((i-4)*0.019,1.18-row*0.021+sin(i*0.85)*0.01,0.151))
		stroke(avatar,wave,0.0035,teal)
