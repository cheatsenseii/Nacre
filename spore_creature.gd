extends Node3D
# Shared three-dimensional interpretation of the user's fungal humanoid drawing.
static var shared_sphere: SphereMesh
var game: Node
var rig: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var clock := 0.0
var skin: StandardMaterial3D
var dark: StandardMaterial3D
var ivory: StandardMaterial3D
var red: StandardMaterial3D
var moss: StandardMaterial3D

func material(color: Color,glow: float=0) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=0.64
	if glow>0:mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=glow
	return mat

func orb(parent: Node3D,at: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	if shared_sphere==null:
		shared_sphere=SphereMesh.new();shared_sphere.radius=0.5;shared_sphere.height=1;shared_sphere.radial_segments=24;shared_sphere.rings=12
	var mesh:=shared_sphere
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.scale=size;node.material_override=mat;parent.add_child(node)
	return node

func tube(parent: Node3D,points: Array[Vector3],radii: Array[float],mat: Material) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array]=[]
	for i in range(points.size()):
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var axis:=Vector3.RIGHT if absf(tangent.dot(Vector3.UP))>0.9 else Vector3.UP
		var u:=tangent.cross(axis).normalized();var v:=tangent.cross(u).normalized()
		var ring:=PackedVector3Array()
		for j in range(12):ring.append(points[i]+radii[i]*(cos(j*TAU/12)*u+sin(j*TAU/12)*v))
		rings.append(ring)
	for i in range(rings.size()-1):
		for j in range(12):
			var k: int=(j+1)%12
			# Godot uses clockwise front faces: expose the outside of the limb.
			for vertex in [rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][j],rings[i+1][k],rings[i][k]]:surface.add_vertex(vertex)
	for end in [0,rings.size()-1]:
		for j in range(12):
			var k: int=(j+1)%12
			var rim: Array=[rings[end][j],rings[end][k]] if end==0 else [rings[end][k],rings[end][j]]
			surface.add_vertex(points[end]);surface.add_vertex(rim[0]);surface.add_vertex(rim[1])
	surface.generate_normals()
	var node:=MeshInstance3D.new();node.mesh=surface.commit();node.material_override=mat;parent.add_child(node)

func mushroom(parent: Node3D,at: Vector3,size: float,green: bool=false) -> void:
	var root:=Node3D.new();parent.add_child(root);root.position=at
	tube(root,[Vector3.ZERO,Vector3(-0.015,0.18*size,0),Vector3(0,0.32*size,0)],[0.025*size,0.024*size,0.02*size],ivory)
	orb(root,Vector3(0,0.33*size,0),Vector3(0.37,0.15,0.29)*size,moss if green else red)
	if not green:
		for x in [-0.1,0.08]:orb(root,Vector3(x,0.39,-0.035)*size,Vector3.ONE*0.035*size,ivory)

func build(owner_game: Node,size: float=1) -> void:
	game=owner_game
	skin=material(Color("625f50"));dark=material(Color("1c1a12"));ivory=material(Color("d5cda3"))
	preload("res://material_detail.gd").apply(skin,false)
	red=material(Color("8e161a"));moss=material(Color("65752e"))
	rig=Node3D.new();add_child(rig);rig.scale=Vector3.ONE*size
	rig.scale.z*=1.3
	# Uneven legs and a heavy, soft torso.
	tube(rig,[Vector3(-0.25,1.05,0),Vector3(-0.31,0.63,0),Vector3(-0.32,0.08,-0.04)],[0.2,0.14,0.14],skin)
	tube(rig,[Vector3(0.27,1.04,0),Vector3(0.43,0.39,-0.01),Vector3(0.4,0.08,-0.04)],[0.19,0.14,0.12],skin)
	for side in [-1,1]:
		for j in range(3):
			var x: float=side*0.35+(j-1)*0.08
			tube(rig,[Vector3(x,0.1,-0.05),Vector3(x-0.03,0.035,-0.23)],[0.024,0.014],dark)
	orb(rig,Vector3(0,1.5,0),Vector3(1.12,1.43,0.68),skin)
	# Back muscles and growth make the silhouette readable from every angle.
	orb(rig,Vector3(-0.25,1.95,0.16),Vector3(0.48,0.5,0.4),skin)
	orb(rig,Vector3(0.26,1.94,0.17),Vector3(0.46,0.49,0.39),skin)
	mushroom(rig,Vector3(-0.23,1.77,0.31),0.62,true)
	mushroom(rig,Vector3(0.2,1.47,0.32),0.45)
	# Dark inset-looking abdomen, exposed crimson organ and dangling root.
	orb(rig,Vector3(0.1,1.55,-0.327),Vector3(0.48,0.57,0.09),dark)
	orb(rig,Vector3(0.11,1.55,-0.38),Vector3(0.27,0.33,0.1),material(Color("511b1b")))
	tube(rig,[Vector3(0.09,1.4,-0.4),Vector3(0.1,1.17,-0.4),Vector3(0.16,0.98,-0.35),Vector3(0.12,0.9,-0.3)],[0.012,0.01,0.009,0.014],red)
	orb(rig,Vector3(-0.3,1.14,-0.29),Vector3(0.24,0.16,0.045),dark)
	orb(rig,Vector3(0.4,1.94,-0.22),Vector3(0.16,0.28,0.055),dark)
	mushroom(rig,Vector3(0.03,1.75,-0.4),0.95)
	mushroom(rig,Vector3(0.27,1.51,-0.39),0.55,true)
	mushroom(rig,Vector3(-0.29,1.46,-0.32),0.55,true)
	mushroom(rig,Vector3(-0.4,2.04,-0.17),0.42,true)
	# The asymmetric pose from the drawing: one arm trails down, the other reaches up.
	left_arm=Node3D.new();left_arm.position=Vector3(-0.44,2.03,0);rig.add_child(left_arm)
	tube(left_arm,[Vector3.ZERO,Vector3(-0.25,-0.43,0),Vector3(-0.42,-0.94,0),Vector3(-0.39,-1.45,-0.04)],[0.18,0.13,0.095,0.04],skin)
	mushroom(left_arm,Vector3(-0.16,-0.32,-0.09),0.44,true)
	for j in range(4):tube(left_arm,[Vector3(-0.39+(j-1.5)*0.035,-1.43,-0.04),Vector3(-0.49+(j-1.5)*0.07,-1.66,-0.12)],[0.02,0.012],dark)
	right_arm=Node3D.new();right_arm.position=Vector3(0.41,2.03,0);rig.add_child(right_arm)
	tube(right_arm,[Vector3.ZERO,Vector3(0.27,0.25,0),Vector3(0.38,0.57,0),Vector3(0.36,0.81,0)],[0.2,0.14,0.09,0.05],skin)
	mushroom(right_arm,Vector3(0.17,0.12,-0.15),0.42)
	for j in range(3):tube(right_arm,[Vector3(0.35+(j-1)*0.06,0.81,0),Vector3(0.42+(j-1)*0.13,1.05,-0.07)],[0.024,0.014],dark)
	head=Node3D.new();head.position=Vector3(-0.03,2.43,0);rig.add_child(head)
	orb(head,Vector3(0,0.17,0),Vector3(0.7,0.78,0.62),skin)
	orb(head,Vector3(-0.18,0.3,0.015),Vector3(0.43,0.54,0.53),skin)
	orb(head,Vector3(0,-0.09,-0.27),Vector3(0.47,0.32,0.12),dark)
	for i in range(6):
		var x: float=(i-2.5)*0.071
		tube(head,[Vector3(x,-0.01,-0.343),Vector3(x+0.015,-0.18-0.025*sin(i),-0.348)],[0.011,0.01],ivory)
	var eye_mat:=material(Color("ff3824"),2.4)
	orb(head,Vector3(-0.18,0.28,-0.287),Vector3(0.12,0.12,0.07),eye_mat)
	orb(head,Vector3(0.14,0.23,-0.298),Vector3(0.075,0.075,0.06),eye_mat)
	tube(head,[Vector3(-0.08,0.53,-0.2),Vector3(-0.04,0.4,-0.29),Vector3(-0.07,0.24,-0.31)],[0.009,0.009,0.008],dark)
	mushroom(head,Vector3(-0.24,0.52,0),0.9)
	tube(rig,[Vector3(-0.13,2.24,-0.2),Vector3(-0.14,2.05,-0.34),Vector3(-0.11,1.92,-0.36)],[0.015,0.012,0.009],dark)

func _process(delta: float) -> void:
	if game==null or game.paused or game.editor.active or not is_visible_in_tree():return
	if global_position.distance_squared_to(game.player.global_position)>2025:return
	clock+=delta
	head.rotation.z=sin(clock*1.1)*0.045
	left_arm.rotation.z=sin(clock*1.7)*0.04
	right_arm.rotation.z=sin(clock*1.3+1)*0.065
