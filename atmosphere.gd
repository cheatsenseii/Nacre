extends Node3D
var game: Node3D
var chamber_back: MeshInstance3D
var music: AudioStreamPlayer
var mushroom: Node3D
var glow: OmniLight3D
var spores: Array[MeshInstance3D] = []
var clock := 0.0
var mushroom_position: Vector3
var hood_skin: ShaderMaterial

func _ready() -> void:
	game = get_parent()
	build_neons()
	build_chamber()
	music = AudioStreamPlayer.new()
	var track := load("res://audio/chambre_des_spores.wav") as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = int(track.get_length() * track.mix_rate)
	music.stream = track
	music.volume_db = -7
	add_child(music)
	music.play()

func luminous(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.4
	return mat

func build_neons() -> void:
	for i in range(1, 22):
		var t := float(i) / 22.0
		var frame: Basis = game.slide_frame(t)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 2.53
		mesh.outer_radius = 2.61
		mesh.rings = 48
		mesh.ring_segments = 8
		ring.mesh = mesh
		var color := Color("65ccc7") if i % 4 != 0 else Color("7b2f55")
		ring.material_override = luminous(color, 1.9)
		ring.position = game.slide_center(t)
		ring.basis = frame * Basis(Vector3.RIGHT, PI / 2)
		add_child(ring)
		var light := OmniLight3D.new()
		light.position = ring.position
		light.omni_range = 5.2
		light.omni_attenuation = 1.7
		light.light_color = color
		light.light_energy = 1.15
		add_child(light)
		light.add_to_group("nacre_dynamic_light");light.set_meta("nacre_light_priority",0)

func form(parent: Node3D, mesh: Mesh, at: Vector3, scale_value: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = scale_value
	node.material_override = mat
	parent.add_child(node)
	return node

func build_chamber() -> void:
	var end: Vector3 = game.slide_center(1.0)
	var floor_y: float = end.y - game.RADIUS
	var middle := Vector3(end.x, floor_y, end.z - 10)
	mushroom_position = middle
	var stone := Color(0.16, 0.18, 0.21)
	game.box(middle + Vector3(0, -0.25, 0), Vector3(27, 0.5, 22), stone)
	game.box(middle + Vector3(0, 8.2, 0), Vector3(27, 0.4, 22), stone)
	for x in [-13.5, 13.5]:
		game.box(middle + Vector3(x, 4, 0), Vector3(0.4, 8, 22), stone)
	chamber_back = game.box(middle + Vector3(0, 4, -11), Vector3(27, 8, 0.4), stone)
	# Back wall: the circular exit remains open.
	for x in [-8.55, 8.55]:
		game.box(middle + Vector3(x, 4, 11), Vector3(9.9, 8, 0.4), stone)
	game.box(middle + Vector3(0, 6.85, 11), Vector3(7.2, 2.3, 0.4), stone)
	# Ceiling ribs and stone pillars provide depth around the central specimen.
	for z in [-7.5, 0.0, 7.5]:
		for x in [-7.7, 7.7]:
			game.box(middle + Vector3(x, 3.8, z), Vector3(0.5, 7.6, 0.65), Color(0.24, 0.23, 0.26))
		game.box(middle + Vector3(0, 7.65, z), Vector3(26, 0.4, 0.6), Color(0.24, 0.23, 0.26))
	mushroom = Node3D.new()
	mushroom.position = middle
	add_child(mushroom)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.85
	stem.bottom_radius = 0.78
	stem.height = 2.8
	stem.radial_segments = 28
	var stalk := form(mushroom, stem, Vector3(0, 1.4, 0), Vector3.ONE, game.material(Color(0.57, 0.57, 0.41)))
	stalk.rotation.z = -0.025
	var cap := SphereMesh.new()
	cap.radius = 1.85
	cap.height = 3.7
	cap.radial_segments = 48
	cap.rings = 24
	var hood := form(mushroom, cap, Vector3(0.17, 2.85, 0), Vector3(1, 0.38, 0.93), game.material(Color(0.31, 0.05, 0.4)))
	hood.rotation.z = -0.1
	hood.name = "Chapeau"
	hood_skin = ShaderMaterial.new()
	hood_skin.shader = preload("res://mushroom_skin.gdshader")
	hood.material_override = hood_skin
	# Luminous gills beneath the cap.
	for i in range(22):
		var a := TAU * i / 22
		var rib := BoxMesh.new()
		rib.size = Vector3(1.35, 0.035, 0.035)
		var node := form(mushroom, rib, Vector3(cos(a)*0.9, 2.55, sin(a)*0.9), Vector3.ONE, luminous(Color(0.15, 0.7, 0.55)))
		node.rotation.y = -a
		node.reparent(hood)
	# Irregular glowing warts, with a deterministic pattern.
	for i in range(19):
		var a := i * 2.39996
		var r := 0.35 + 1.2 * sqrt(float(i) / 19)
		var wart := SphereMesh.new()
		wart.radius = 0.11 + 0.025 * (i % 3)
		wart.height = wart.radius * 2
		var y := 2.85 + 0.70 * sqrt(maxf(0, 1-r*r/3.42))
		var spot := form(mushroom, wart, Vector3(0.17+cos(a)*r, y, sin(a)*r*0.93), Vector3(1, 0.35, 1), luminous(Color(0.64, 0.76, 0.49), 0.35))
		spot.reparent(hood)
	for i in range(10):
		var a := i*TAU/10
		var root_mesh := SphereMesh.new()
		root_mesh.radius=0.5;root_mesh.height=1
		var root := form(mushroom,root_mesh,Vector3(cos(a)*0.68,0.15,sin(a)*0.68),Vector3(0.34,0.28,1.25),game.material(Color("777b51")))
		root.rotation.y=PI/2-a
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.87
	shape.height = 3.5
	collision.shape = shape
	collision.position.y = 1.75
	body.add_child(collision)
	mushroom.add_child(body)
	glow = OmniLight3D.new()
	glow.position = middle + Vector3(0, 3.7, 0)
	glow.light_color = Color(0.56, 0.18, 0.88)
	glow.light_energy = 3.0
	glow.omni_range = 11
	add_child(glow)
	glow.add_to_group("nacre_dynamic_light");glow.set_meta("nacre_light_priority",3)
	var under := OmniLight3D.new()
	under.position = middle + Vector3(0, 1.8, 1)
	under.light_color = Color(0.18, 0.9, 0.52)
	under.light_energy = 1.6
	under.omni_range = 5.5
	add_child(under)
	under.add_to_group("nacre_dynamic_light");under.set_meta("nacre_light_priority",2)
	for i in range(6):
		var particle := SphereMesh.new()
		particle.radius = 0.025
		particle.height = 0.05
		particle.radial_segments = 8
		particle.rings = 4
		spores.append(form(mushroom, particle, Vector3.ZERO, Vector3.ONE, luminous(Color(0.49, 0.9, 0.6))))
	game.sign_text("CHAMBRE 01", middle + Vector3(0, 5.8, -10.75), 100, Color(0.47, 0.55, 0.56))

func _process(delta: float) -> void:
	if game.paused: return
	clock += delta
	glow.light_energy = 2.7 + 0.4 * sin(clock * 1.1)
	if hood_skin != null:
		hood_skin.set_shader_parameter("breath",clock*1.15)
	for i in range(spores.size()):
		var a := i * 2.4 + clock * 0.12
		spores[i].position = Vector3(cos(a) * (1.1 + i % 4 * 0.3), 0.3 + fmod(clock * 0.19 + i * 0.37, 4.6), sin(a) * 1.7)

func toggle_music() -> void:
	music.stream_paused = not music.stream_paused
