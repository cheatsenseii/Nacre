extends Node3D
## A lit, articulated character facing +Z. Details are merged per joint/material.
## Reference cues: swept black hair, beard, wide eyes, crooked grin, knotted navy tee.
var torso: Node3D
var head: Node3D
var jaw: Node3D
var arms: Array[Node3D]=[]
var elbows: Array[Node3D]=[]
var legs: Array[Node3D]=[]
var knees: Array[Node3D]=[]
var eyes: Array[MeshInstance3D]=[]
var materials: Dictionary={}
var batches: Dictionary={}
var phase:=0.0
var clock:=0.0
var pressure:=0.0
var gait:=0.0
var triangle_count:=0
var sphere:=SphereMesh.new()
var cylinder:=CylinderMesh.new()

func joint(label: String,at: Vector3,parent: Node3D) -> Node3D:
	var node:=Node3D.new();node.name=label;node.position=at;parent.add_child(node);return node

func material(key: String,color: String,woven: bool=false) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=0.7
	if key in ["skin","fabric","denim"]:preload("res://material_detail.gd").apply(mat,woven)
	if key=="skin":mat.normal_scale=0.07;mat.roughness=0.66;mat.uv1_scale=Vector3.ONE*5.0
	if key in ["fabric","denim"]:mat.normal_scale=0.16;mat.uv1_scale=Vector3.ONE*8.0
	if key=="hair":mat.roughness=0.51
	materials[key]=mat;return mat

func bake(parent: Node3D,mesh: Mesh,at: Vector3,size: Vector3,mat: Material,rotation: Quaternion=Quaternion.IDENTITY) -> void:
	var key:=str(parent.get_instance_id())+":"+str(mat.get_instance_id())
	if not batches.has(key):
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key]={"surface":surface,"parent":parent,"material":mat}
	batches[key].surface.append_from(mesh,0,Transform3D(Basis(rotation)*Basis.from_scale(size),at))

func oval(parent: Node3D,at: Vector3,size: Vector3,mat: Material) -> void:
	bake(parent,sphere,at,size,mat)

func tube(parent: Node3D,a: Vector3,b: Vector3,radius: float,mat: Material,tip: float=-1.0) -> void:
	var mesh: CylinderMesh=cylinder
	if tip>=0:
		mesh=cylinder.duplicate();mesh.top_radius=tip/maxf(radius,0.001)*0.5
	bake(parent,mesh,(a+b)*0.5,Vector3(radius*2,a.distance_to(b),radius*2),mat,Quaternion(Vector3.UP,(b-a).normalized()))

func stroke(parent: Node3D,points: Array,radius: float,mat: Material) -> void:
	for i in range(points.size()-1):tube(parent,points[i],points[i+1],radius,mat)

func loft(parent: Node3D,rings: Array,mat: Material,wrinkles: float=0.0) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size()-1):
		for j in range(32):
			for ij in [Vector2i(r,j),Vector2i(r+1,j+1),Vector2i(r+1,j),Vector2i(r,j),Vector2i(r,j+1),Vector2i(r+1,j+1)]:
				var ring: Array=rings[ij.x];var a: float=ij.y*TAU/32
				var fold: float=1.0+sin(a*9+ring[0]*10)*wrinkles
				surface.set_uv(Vector2(float(ij.y)/32,float(ij.x)/rings.size()))
				surface.add_vertex(Vector3(cos(a)*ring[1]*fold,ring[0],sin(a)*ring[2]*fold))
	surface.generate_normals();surface.generate_tangents();surface.index();bake(parent,surface.commit(),Vector3.ZERO,Vector3.ONE,mat)

func build() -> void:
	sphere.radius=0.5;sphere.height=1;sphere.radial_segments=20;sphere.rings=12
	cylinder.top_radius=0.5;cylinder.bottom_radius=0.5;cylinder.height=1;cylinder.radial_segments=10
	var skin:=material("skin","a89f8d")
	var crease:=material("crease","605958")
	var hair:=material("hair","10131c")
	var hair_light:=material("hair_light","252a35")
	var fabric:=material("fabric","263c58",true)
	var stitch:=material("stitch","52667a")
	var denim:=material("denim","1c2c40",true)
	var rubber:=material("rubber","121b20")
	var lip:=material("lip","68505b")
	var mouth:=material("mouth","130e1d")
	var tooth:=material("tooth","d0d1be");tooth.roughness=0.32
	var wet:=material("tongue","a3657c");wet.roughness=0.37
	var metal:=material("metal","687879");metal.metallic=0.75;metal.roughness=0.26
	torso=joint("Buste",Vector3.ZERO,self)
	# Abdomen and shoulder anatomy; the shirt is gathered above the navel.
	loft(torso,[[1.06,0.23,0.14],[1.22,0.245,0.155],[1.48,0.215,0.145],[1.75,0.26,0.165],[1.93,0.32,0.18],[2.13,0.32,0.16],[2.22,0.16,0.12]],skin)
	loft(torso,[[1.70,0.25,0.16],[1.79,0.29,0.18],[1.96,0.34,0.195],[2.14,0.36,0.185],[2.23,0.17,0.12]],fabric,0.025)
	oval(torso,Vector3(0.04,1.78,0.18),Vector3(0.16,0.13,0.13),fabric)
	for side in [-1,1]:
		var fold:=Vector3(side*0.20,1.90,0.15)
		stroke(torso,[Vector3(side*0.29,2.08,0.13),fold,Vector3(0.04,1.78,0.24)],0.007,stitch)
		oval(torso,Vector3(side*0.10,1.72,0.17),Vector3(0.17,0.13,0.055),fabric)
		stroke(torso,[Vector3(side*0.15,2.20,0.11),Vector3(0,2.02,0.20)],0.013,stitch)
		stroke(torso,[Vector3(side*0.07,1.23,0.145),Vector3(side*0.145,1.37,0.143)],0.006,crease)
	oval(torso,Vector3(0.018,1.41,0.145),Vector3(0.032,0.05,0.017),crease)
	loft(torso,[[1.03,0.25,0.15],[1.15,0.26,0.165],[1.20,0.255,0.16]],denim)
	loft(torso,[[1.18,0.26,0.167],[1.23,0.258,0.164]],stitch)
	for x in [-0.20,-0.11,0.11,0.20]:tube(torso,Vector3(x,1.15,0.137),Vector3(x,1.225,0.15),0.012,denim)
	oval(torso,Vector3(0,1.19,0.176),Vector3(0.028,0.028,0.014),metal)
	# Real side/back seams and pockets: no camera-facing photo plane.
	for side in [-1,1]:
		stroke(torso,[Vector3(side*0.06,1.11,-0.146),Vector3(side*0.13,1.03,-0.159),Vector3(side*0.21,1.11,-0.138)],0.007,stitch)
		stroke(torso,[Vector3(side*0.29,1.86,-0.09),Vector3(side*0.31,2.10,-0.12)],0.006,stitch)
	oval(torso,Vector3(0,2.27,0),Vector3(0.18,0.26,0.18),skin)
	head=joint("Visage",Vector3(0,2.59,0.025),torso)
	oval(head,Vector3(0,0.035,-0.015),Vector3(0.56,0.71,0.49),skin)
	oval(head,Vector3(0,-0.21,0.003),Vector3(0.405,0.32,0.42),skin)
	for side in [-1.0,1.0]:
		oval(head,Vector3(side*0.271,-0.016,-0.013),Vector3(0.083,0.16,0.08),skin)
		oval(head,Vector3(side*0.295,-0.009,0.01),Vector3(0.032,0.102,0.026),lip)
		oval(head,Vector3(side*0.17,-0.072,0.171),Vector3(0.12,0.125,0.067),skin)
		oval(head,Vector3(side*0.121,0.085,0.221),Vector3(0.179,0.141,0.067),crease)
		oval(head,Vector3(side*0.121,0.100,0.221),Vector3(0.141,0.109,0.085),tooth)
		var iris:=MeshInstance3D.new();iris.name="Iris";iris.mesh=sphere;iris.position=Vector3(side*0.117,0.105,0.264);iris.scale=Vector3(0.056,0.066,0.017)
		var eye_mat:=StandardMaterial3D.new();eye_mat.albedo_color=Color("617d79");eye_mat.roughness=0.23;eye_mat.emission_enabled=true;eye_mat.emission=Color("659797");eye_mat.emission_energy_multiplier=0.35
		iris.material_override=eye_mat;head.add_child(iris);eyes.append(iris)
		oval(head,Vector3(side*0.117,0.105,0.275),Vector3(0.022,0.042,0.008),mouth)
		oval(head,Vector3(side*0.117-0.012,0.12,0.281),Vector3(0.014,0.012,0.006),tooth)
		stroke(head,[Vector3(side*0.043,0.178,0.224),Vector3(side*0.113,0.208,0.217),Vector3(side*0.199,0.163,0.18)],0.017,hair)
		stroke(head,[Vector3(side*0.047,0.029,0.244),Vector3(side*0.112,0.015,0.247),Vector3(side*0.183,0.025,0.210)],0.007,lip)
		stroke(head,[Vector3(side*0.070,-0.05,0.256),Vector3(side*0.119,-0.104,0.235),Vector3(side*0.153,-0.13,0.22)],0.006,crease)
	# Nose bridge, wings and nostrils stay distinct in profile.
	oval(head,Vector3(0,0.009,0.242),Vector3(0.074,0.19,0.112),skin)
	oval(head,Vector3(0,-0.050,0.299),Vector3(0.115,0.072,0.083),skin)
	for side in [-1,1]:oval(head,Vector3(side*0.043,-0.069,0.305),Vector3(0.035,0.020,0.021),mouth)
	oval(head,Vector3(0,-0.163,0.225),Vector3(0.365,0.230,0.125),mouth)
	var upper: Array=[]
	var lower: Array=[]
	for i in range(13):
		var a: float=i*PI/12
		upper.append(Vector3(cos(a)*0.177,-0.165+sin(a)*0.105,0.271-absf(cos(a))*0.025))
		lower.append(Vector3(-cos(a)*0.177,-0.165-sin(a)*0.105,0.262-absf(cos(a))*0.014))
	stroke(head,upper,0.012,lip)
	jaw=joint("Machoire",Vector3(0,-0.16,0),head)
	for i in range(lower.size()):lower[i]-=jaw.position
	stroke(jaw,lower,0.014,lip)
	for i in range(10):
		var x: float=(i-4.5)*0.03
		oval(head,Vector3(x,-0.119+absf(x)*0.13,0.292-absf(x)*0.20),Vector3(0.029,0.033,0.04),tooth)
		oval(jaw,Vector3(x,-0.073+absf(x)*0.17,0.28-absf(x)*0.16),Vector3(0.026,0.031,0.033),tooth)
	oval(jaw,Vector3(-0.039,-0.037,0.328),Vector3(0.16,0.043,0.16),wet)
	stroke(jaw,[Vector3(-0.032,-0.014,0.3),Vector3(-0.047,-0.014,0.38)],0.003,lip)
	# Beard follows the cheek and jaw instead of masking the whole lower face.
	for side in [-1,1]:
		oval(head,Vector3(side*0.213,-0.151,0.122),Vector3(0.09,0.255,0.114),hair)
		stroke(head,[Vector3(side*0.014,-0.089,0.299),Vector3(side*0.070,-0.077,0.294),Vector3(side*0.142,-0.111,0.26)],0.014,hair)
		for i in range(13):
			var t: float=i/12.0
			var at:=Vector3(side*(0.207-0.09*t),-0.16-t*0.16,0.138+t*0.035)
			tube(head,at,at+Vector3(side*0.015,-0.033,0.016),0.012,hair if i%3 else hair_light,0.001)
	oval(head,Vector3(0,-0.325,0.099),Vector3(0.258,0.105,0.22),hair)
	for i in range(13):
		var x: float=(i-6)*0.019
		tube(head,Vector3(x,-0.294,0.178),Vector3(x*0.92,-0.369,0.15),0.012,hair_light if i%4==0 else hair,0.002)
	# Swept scalp and tapered locks; silhouette remains recognizable from behind.
	oval(head,Vector3(0,0.269,-0.040),Vector3(0.56,0.27,0.45),hair)
	for i in range(47):
		var a: float=i*2.399963;var radius:=sqrt(float(i)/47)
		var at:=Vector3(cos(a)*0.26*radius,0.29+0.083*(1-radius),sin(a)*0.205*radius-0.038)
		var bend:=at+Vector3(-0.075,0.08,0.024)
		var end:=bend+Vector3(-0.05,0.012+0.025*sin(i*2.0),-0.033)
		tube(head,at,bend,0.029,hair_light if i%6==0 else hair,0.014)
		tube(head,bend,end,0.014,hair,0.002)
	for side in [-1,1]:
		stroke(head,[Vector3(side*0.247,0.20,-0.015),Vector3(side*0.265,0.07,-0.013),Vector3(side*0.239,-0.04,0.06)],0.026,hair)
	var earring:=TorusMesh.new();earring.inner_radius=0.021;earring.outer_radius=0.034;earring.rings=20;earring.ring_segments=8
	bake(head,earring,Vector3(-0.29,-0.077,0.017),Vector3.ONE,metal,Quaternion(Vector3.RIGHT,PI/2))
	for side in [-1.0,1.0]:
		var arm:=joint("Bras_gauche" if side<0 else "Bras_droit",Vector3(side*0.35,2.125,0),torso);arms.append(arm)
		oval(arm,Vector3(0,-0.12,0),Vector3(0.215,0.30,0.235),fabric)
		tube(arm,Vector3(0,-0.18,0),Vector3(0,-0.53,0),0.087,skin,0.065)
		oval(arm,Vector3(0,-0.50,0),Vector3(0.145,0.15,0.14),skin)
		var elbow:=joint("Coude",Vector3(0,-0.51,0),arm);elbows.append(elbow)
		tube(elbow,Vector3.ZERO,Vector3(0,-0.61,0.035),0.067,skin,0.042)
		oval(elbow,Vector3(0,-0.66,0.036),Vector3(0.116,0.185,0.084),skin)
		for finger in range(4):
			var at:=Vector3((finger-1.5)*0.03,-0.70,0.055)
			var tip:=at+Vector3((finger-1.5)*0.018,-0.145+absf(finger-1.5)*0.015,0.025)
			tube(elbow,at,tip,0.016,skin,0.011)
			oval(elbow,tip+Vector3(0,0.01,0.010),Vector3(0.015,0.030,0.010),tooth)
		tube(elbow,Vector3(side*0.047,-0.635,0.049),Vector3(side*0.092,-0.716,0.076),0.024,skin,0.014)
		var leg:=joint("Jambe_gauche" if side<0 else "Jambe_droite",Vector3(side*0.135,1.09,0),self);legs.append(leg)
		tube(leg,Vector3(0,-0.025,0),Vector3(0,-0.51,0),0.128,denim,0.092)
		var knee:=joint("Genou",Vector3(0,-0.49,0),leg);knees.append(knee)
		tube(knee,Vector3.ZERO,Vector3(0,-0.41,0),0.092,denim,0.077)
		oval(knee,Vector3(0,-0.48,0.064),Vector3(0.195,0.155,0.32),rubber)
		oval(knee,Vector3(0,-0.539,0.061),Vector3(0.197,0.035,0.31),stitch)
		for y in [-0.39,-0.425,-0.46]:stroke(knee,[Vector3(-0.064,y,0.155),Vector3(0.064,y,0.155)],0.005,stitch)
		for y in [-0.18,-0.23,-0.38]:stroke(leg,[Vector3(-0.078,y,0.058),Vector3(0,y-0.016,0.118),Vector3(0.086,y-0.008,0.056)],0.005,stitch)
		stroke(knee,[Vector3(side*0.087,0,-0.01),Vector3(side*0.069,-0.4,-0.01)],0.005,stitch)
	for entry in batches.values():
		entry.surface.index()
		var mesh: ArrayMesh=entry.surface.commit()
		var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=entry.material;entry.parent.add_child(instance)
		triangle_count+=mesh.surface_get_array_index_len(0)/3
	batches.clear()
	set_meta("reference_features",["cheveux_noirs","barbe","yeux_ecarquilles","sourire_langue","tee_shirt_noue","jean","boucle_oreille"])
	set_pressure(0);animate(0,0)

func set_pressure(level: int) -> void:
	pressure=clampf(float(level)/3.0,0,1)
	for eye in eyes:
		var mat: StandardMaterial3D=eye.material_override
		mat.emission=Color("63958f").lerp(Color("c46572"),pressure)
		mat.emission_energy_multiplier=lerpf(0.35,1.5,pressure)

func animate(delta: float,speed: float) -> void:
	clock+=delta;gait=move_toward(gait,clampf(speed/1.5,0,1),delta*5)
	phase+=speed*delta*4.0
	var stride:=sin(phase)*0.30*gait
	for i in range(2):
		var side: float=-1 if i==0 else 1
		legs[i].rotation.x=stride*side
		knees[i].rotation.x=-maxf(0,stride*side)*0.75
		arms[i].rotation.x=-0.21-stride*side*0.7
		arms[i].rotation.z=side*(0.10+0.025*sin(clock*1.3+i))
		elbows[i].rotation.x=-0.20+sin(clock*1.7+i)*0.065
	torso.rotation.z=sin(phase)*gait*0.025
	torso.position.y=absf(sin(phase))*0.026*gait
	head.rotation=Vector3(0.01+sin(clock*0.83)*0.025,sin(clock*0.7)*0.045,-0.11-pressure*0.07+sin(clock*1.3)*0.025)
	jaw.rotation.x=sin(clock*2.1)*0.04

