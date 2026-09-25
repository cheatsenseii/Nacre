extends Node3D
## Purely environmental pass. It reinforces the identity of an abandoned aquatic park
## without changing puzzles, progression or the definitive story.

var game: Node3D
var built := false
var details: Array[Node3D] = []

func _ready() -> void:
	game = get_parent()
	call_deferred("late_build")

func late_build() -> void:
	if built:return
	for _i in range(5):await get_tree().process_frame
	if game == null or game.atmosphere == null:return
	build_departure_identity()
	build_garden_identity()
	build_service_identity()
	build_deep_rooms_identity()
	built = true

func mat(color: Color, metallic := 0.0, roughness := 0.82) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func wet_mat(alpha:=0.32) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=Color(0.18,0.28,0.28,alpha)
	m.metallic=0.08;m.roughness=0.18
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m

func box(at: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new();mesh.size = size
	var node := MeshInstance3D.new();node.mesh = mesh;node.position = at;node.rotation = rotation;node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node);details.append(node);return node

func cylinder(at: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new();mesh.top_radius = radius;mesh.bottom_radius = radius;mesh.height = height;mesh.radial_segments = 12
	var node := MeshInstance3D.new();node.mesh = mesh;node.position = at;node.rotation = rotation;node.material_override = material
	add_child(node);details.append(node);return node

func rod(a: Vector3,b: Vector3,radius: float,material: Material) -> MeshInstance3D:
	var direction:=b-a
	var node:=cylinder((a+b)*0.5,radius,direction.length(),material)
	node.quaternion=Quaternion(Vector3.UP,direction.normalized())
	return node

func sign_text(text: String, at: Vector3, yaw := 0.0, size := 29, color := Color("c5cec7")) -> Label3D:
	var label := Label3D.new();label.text = text;label.position = at;label.rotation.y = yaw
	label.font_size = size;label.pixel_size = 0.0032;label.modulate = color;label.outline_size = 4;label.outline_modulate = Color("081011")
	add_child(label);return label

func wet_patch(at: Vector3,scale_value: Vector2,rotation_y:=0.0) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=0.5;mesh.bottom_radius=0.5;mesh.height=0.012;mesh.radial_segments=18
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at+Vector3.UP*0.012;node.rotation.y=rotation_y
	node.scale=Vector3(scale_value.x,1.0,scale_value.y);node.material_override=wet_mat(0.28)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);details.append(node)

func lifebuoy(at: Vector3, rotation := Vector3.ZERO, scale_value := 1.0) -> void:
	var ring_mesh := TorusMesh.new();ring_mesh.inner_radius = 0.25 * scale_value;ring_mesh.outer_radius = 0.38 * scale_value;ring_mesh.rings = 24;ring_mesh.ring_segments = 10
	var ring := MeshInstance3D.new();ring.mesh = ring_mesh;ring.position = at;ring.rotation = rotation;ring.material_override = mat(Color("a55b34"), 0.0, 0.9)
	add_child(ring);details.append(ring)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var marker := box(at + Vector3(cos(angle), sin(angle), 0) * 0.315 * scale_value, Vector3(0.12, 0.12, 0.08) * scale_value, mat(Color("c8c2ae"), 0.0, 0.95), rotation)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func lane_rope(a: Vector3, b: Vector3) -> void:
	var rope := mat(Color("59645f"), 0.1, 0.8)
	var faded := [Color("8d704b"), Color("5e7677"), Color("a7a08a")]
	var steps := 12
	for i in range(steps + 1):
		var t := float(i) / float(steps);var p := a.lerp(b, t)
		cylinder(p, 0.055, 0.12, mat(faded[i % faded.size()], 0.0, 0.88), Vector3(PI / 2, 0, 0))
	for i in range(steps):
		var p0 := a.lerp(b,float(i)/float(steps));var p1 := a.lerp(b,float(i+1)/float(steps))
		rod(p0,p1,0.018,rope)

func locker_bank(at: Vector3, yaw := 0.0, count := 4) -> void:
	var body := mat(Color("4b5957"), 0.65, 0.62);var inset := mat(Color("242d2d"), 0.25, 0.84)
	for i in range(count):
		var local := Vector3((i - (count - 1) * 0.5) * 0.72, 0, 0).rotated(Vector3.UP, yaw)
		box(at + local + Vector3.UP * 1.0, Vector3(0.64, 1.9, 0.48), body, Vector3(0, yaw, 0))
		box(at + local + Vector3(0, 1.05, -0.247).rotated(Vector3.UP, yaw), Vector3(0.42, 0.07, 0.018), inset, Vector3(0, yaw, 0))

func pump_cluster(at: Vector3,yaw:=0.0) -> void:
	var steel:=mat(Color("4a5753"),0.78,0.5);var rust:=mat(Color("6a4535"),0.42,0.78);var rubber:=mat(Color("202726"),0.08,0.88)
	box(at+Vector3(0,0.22,0),Vector3(2.2,0.22,1.0),steel,Vector3(0,yaw,0))
	for side in [-0.62,0.62]:
		cylinder(at+Vector3(side,0.72,0),0.34,0.86,rust,Vector3.ZERO)
		rod(at+Vector3(side,1.05,0),at+Vector3(side,1.05,-1.35).rotated(Vector3.UP,yaw),0.12,steel)
	box(at+Vector3(0,1.05,0.44),Vector3(0.72,0.52,0.22),rubber,Vector3(0,yaw,0))

func pipe_run(a: Vector3,b: Vector3,height: float) -> void:
	var steel:=mat(Color("45514e"),0.72,0.54);var start:=a+Vector3.UP*height;var end:=b+Vector3.UP*height
	rod(start,end,0.085,steel)
	for t in [0.18,0.5,0.82]:
		var p:=start.lerp(end,t);cylinder(p,0.13,0.05,mat(Color("754a38"),0.5,0.72),Vector3(PI/2,0,0))

func build_departure_identity() -> void:
	lifebuoy(Vector3(-5.72, 2.6, 1.8), Vector3(0, PI / 2, 0), 1.05)
	sign_text("NACRE • DESCENTE 01\nACCÈS BAIGNEURS", Vector3(-5.78, 4.25, -0.2), PI / 2, 32, Color("d1b171"))
	locker_bank(Vector3(4.85, 0, 3.6), PI / 2, 3)
	wet_patch(Vector3(-2.2,0,-0.6),Vector2(1.8,0.9),0.35)
	wet_patch(Vector3(3.4,0,2.4),Vector2(1.1,0.55),-0.4)

func build_garden_identity() -> void:
	var center: Vector3 = game.atmosphere.mushroom_position
	lane_rope(center + Vector3(-8.5, 0.16, 7.5), center + Vector3(8.5, 0.16, 7.5))
	lifebuoy(center + Vector3(12.75, 2.4, 0.5), Vector3(0, PI / 2, 0), 0.9)
	sign_text("ANCIEN BASSIN\nACCÈS PERSONNEL", center + Vector3(12.82, 4.0, -3.4), -PI / 2, 28, Color("8fb6a7"))
	wet_patch(center+Vector3(-5.4,0,2.0),Vector2(2.4,1.3),0.2)
	wet_patch(center+Vector3(6.3,0,-4.2),Vector2(1.6,0.8),-0.6)
	pipe_run(center+Vector3(-11,0,-8),center+Vector3(-11,0,7),4.7)

func build_service_identity() -> void:
	var mushroom: Vector3 = game.atmosphere.mushroom_position
	if game.silence != null:
		var s: Vector3 = game.silence.origin
		lifebuoy(s + Vector3(-10.8, 2.5, 7.5), Vector3(0, PI / 2, 0), 0.82)
		sign_text("FILTRATION BASSINS\nPERSONNEL UNIQUEMENT", s + Vector3(10.75, 3.9, 7.0), -PI / 2, 27, Color("c3aa70"))
		pump_cluster(s+Vector3(-7.8,0,8.4),0.08)
		pipe_run(s+Vector3(-9.6,0,-9),s+Vector3(-9.6,0,9),4.2)
		wet_patch(s+Vector3(4.8,0,-3.2),Vector2(2.0,0.7),0.5)
	if game.labyrinth != null:
		var l: Vector3 = game.labyrinth.origin
		sign_text("GALERIE DE SERVICE\nSOUS LES BASSINS", l + Vector3(17.75, 4.1, -5.0), -PI / 2, 26, Color("8e9c91"))
		lane_rope(mushroom + Vector3(-8.0, 0.10, -34.0), mushroom + Vector3(8.0, 0.10, -34.0))

func build_deep_rooms_identity() -> void:
	if game.combat != null:
		var c: Vector3 = game.combat.origin
		locker_bank(c + Vector3(-10.6, 0, -7.0), PI / 2, 4)
		sign_text("BASSIN DE MAINTENANCE\nFERMÉ AU PUBLIC", c + Vector3(11.7, 4.1, -8.5), -PI / 2, 28, Color("bd765e"))
		pump_cluster(c+Vector3(8.6,0,-23.5),PI/2)
		wet_patch(c+Vector3(-3.8,0,-14.2),Vector2(2.8,1.1),0.18)
		wet_patch(c+Vector3(5.6,0,-22.0),Vector2(1.7,0.7),-0.4)
	if game.simon != null:
		var s: Vector3 = game.simon.origin
		sign_text("ANIMATION AQUATIQUE\nSESSION INTERROMPUE", s + Vector3(0, 4.7, -22.55), 0, 27, Color("80aaa4"))
		wet_patch(s+Vector3(0,0,-9),Vector2(1.8,0.7),0.1)
	if game.torture != null:
		var t: Vector3 = game.torture.origin
		sign_text("LOCAL ÉLECTRIQUE\nACCÈS PERSONNEL", t + Vector3(-10.72, 4.15, -9.0), PI / 2, 28, Color("c4b46f"))
		pipe_run(t+Vector3(9.8,0,-3),t+Vector3(9.8,0,-25),4.4)
		wet_patch(t+Vector3(-5.2,0,-18),Vector2(1.5,0.55),0.3)
	if game.horrors != null:
		var h: Vector3 = game.horrors.origin
		lifebuoy(h + Vector3(10.65, 2.4, -8.5), Vector3(0, -PI / 2, 0), 0.88)
		sign_text("GALERIE 07\nSORTIE DE SECOURS", h + Vector3(-10.72, 4.0, -5.0), PI / 2, 28, Color("aa7767"))
		wet_patch(h+Vector3(4.4,0,-13),Vector2(2.2,0.9),-0.15)
		wet_patch(h+Vector3(-4.8,0,-23),Vector2(1.6,0.7),0.45)

func _process(_delta: float) -> void:
	if not built:return
	var polish := game.get_node_or_null("Polish")
	var quality := 1
	if polish != null:quality = int(polish.get("quality"))
	for node in details:
		if is_instance_valid(node):node.visible = quality > 0
