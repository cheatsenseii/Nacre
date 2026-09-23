extends Node3D

# Pass additif: donne de la vie au décor sans changer les règles, checkpoints ou sauvegardes.
var game: Node3D
var polish: Node
var third_person: Node
var face: Node3D
var runner: Node
var runner_cap: Node3D
var pushables: Array[RigidBody3D] = []
var steam_fields: Array[CPUParticles3D] = []
var hanging_cables: Array[Node3D] = []
var cable_phases: Array[float] = []
var clock := 0.0
var face_phase := 0.0
var ready_for_life := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("setup")

func setup() -> void:
	await get_tree().process_frame
	game = get_parent()
	if game == null or game.get("player") == null or game.get("atmosphere") == null:
		return
	polish = find_script_child("res://polish.gd")
	third_person = game.get("third_person")
	if third_person != null:
		var avatar: Node3D = third_person.get("avatar")
		if avatar != null:
			face = avatar.get_node_or_null("Visage")
	runner = game.get_node_or_null("Bouptilop")
	if runner != null:
		runner_cap = runner.get("cap")
	build_pushable_props()
	build_steam_leaks()
	build_hanging_cables()
	ready_for_life = true

func find_script_child(path: String) -> Node:
	var wanted: Script = load(path)
	for child in game.get_children():
		if child.get_script() == wanted:
			return child
	return null

func metal_material(color: Color, metallic := 0.45, roughness := 0.56) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func add_box_part(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func make_crate(at: Vector3, size: Vector3, tint: Color, mass_value := 6.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Objet_mobile_%d" % pushables.size()
	body.position = at
	body.mass = mass_value
	body.linear_damp = 1.8
	body.angular_damp = 2.4
	body.continuous_cd = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.sleeping = true
	var material := metal_material(tint, 0.35, 0.62)
	add_box_part(body, Vector3.ZERO, size, material)
	var frame := metal_material(Color("252d30"), 0.72, 0.42)
	for side in [-1.0, 1.0]:
		add_box_part(body, Vector3(side * size.x * 0.44, 0, -size.z * 0.505), Vector3(0.055, size.y * 0.9, 0.035), frame)
		add_box_part(body, Vector3(0, side * size.y * 0.44, -size.z * 0.505), Vector3(size.x * 0.9, 0.055, 0.035), frame)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	pushables.append(body)
	return body

func make_canister(at: Vector3, tint: Color) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Bidon_mobile_%d" % pushables.size()
	body.position = at
	body.mass = 3.5
	body.linear_damp = 1.25
	body.angular_damp = 1.7
	body.continuous_cd = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.sleeping = true
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.23
	cylinder.bottom_radius = 0.23
	cylinder.height = 0.62
	cylinder.radial_segments = 18
	var visual := MeshInstance3D.new()
	visual.mesh = cylinder
	visual.material_override = metal_material(tint, 0.56, 0.48)
	body.add_child(visual)
	for y in [-0.22, 0.22]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.205
		ring.outer_radius = 0.235
		ring.rings = 18
		ring.ring_segments = 8
		var band := MeshInstance3D.new()
		band.mesh = ring
		band.position.y = y
		band.material_override = metal_material(Color("242b2e"), 0.8, 0.38)
		body.add_child(band)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.23
	shape.height = 0.62
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	pushables.append(body)
	return body

func build_pushable_props() -> void:
	var mushroom_center: Vector3 = game.atmosphere.mushroom_position
	make_crate(Vector3(-4.9, 0.34, 2.8), Vector3(0.72, 0.68, 0.72), Color("5d716d"), 7.0)
	make_canister(Vector3(5.0, 0.32, 2.65), Color("755c45"))
	make_crate(mushroom_center + Vector3(-10.9, 0.32, 7.2), Vector3(0.62, 0.62, 0.82), Color("50645f"), 6.0)
	make_canister(mushroom_center + Vector3(10.7, 0.32, -6.8), Color("6c5141"))
	if game.get("combat") != null:
		var origin: Vector3 = game.combat.origin
		make_crate(origin + Vector3(-9.6, 0.34, -4.2), Vector3(0.76, 0.68, 0.68), Color("4c5f5c"), 8.0)
		make_canister(origin + Vector3(9.5, 0.32, -18.5), Color("67523e"))

func steam_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.69, 0.78, 0.76, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return mat

func add_steam(at: Vector3, direction: Vector3, spread := 18.0) -> void:
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.amount = 14
	particles.lifetime = 3.6
	particles.randomness = 0.65
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.08
	particles.direction = direction.normalized()
	particles.spread = spread
	particles.gravity = Vector3(0, 0.08, 0)
	particles.initial_velocity_min = 0.22
	particles.initial_velocity_max = 0.46
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = steam_material()
	particles.mesh = quad
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 5, 4))
	add_child(particles)
	steam_fields.append(particles)

func build_steam_leaks() -> void:
	var center: Vector3 = game.atmosphere.mushroom_position
	add_steam(Vector3(-5.25, 4.65, 2.1), Vector3(0.25, -0.15, 1.0))
	add_steam(center + Vector3(10.7, 4.2, 4.8), Vector3(-1.0, 0.1, 0.2))
	add_steam(center + Vector3(-10.9, 4.45, -19.5), Vector3(1.0, 0.08, -0.15))
	if game.get("combat") != null:
		add_steam(game.combat.origin + Vector3(-10.4, 4.1, -13.0), Vector3(1.0, 0.12, 0.0))

func cable_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("171d20")
	mat.metallic = 0.15
	mat.roughness = 0.78
	return mat

func add_hanging_cable(at: Vector3, length: float, phase: float) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	var cable := CylinderMesh.new()
	cable.top_radius = 0.025
	cable.bottom_radius = 0.03
	cable.height = length
	cable.radial_segments = 10
	var cable_node := MeshInstance3D.new()
	cable_node.mesh = cable
	cable_node.position.y = -length * 0.5
	cable_node.material_override = cable_material()
	pivot.add_child(cable_node)
	var end_piece := MeshInstance3D.new()
	var end_mesh := SphereMesh.new()
	end_mesh.radius = 0.07
	end_mesh.height = 0.14
	end_piece.mesh = end_mesh
	end_piece.position.y = -length
	end_piece.material_override = metal_material(Color("5b6a68"), 0.45, 0.55)
	pivot.add_child(end_piece)
	add_child(pivot)
	hanging_cables.append(pivot)
	cable_phases.append(phase)

func build_hanging_cables() -> void:
	var center: Vector3 = game.atmosphere.mushroom_position
	add_hanging_cable(Vector3(-4.3, 5.65, -1.8), 1.25, 0.0)
	add_hanging_cable(center + Vector3(9.8, 5.15, -7.0), 1.55, 1.7)
	add_hanging_cable(center + Vector3(-10.2, 5.2, -24.0), 1.35, 3.1)
	if game.get("combat") != null:
		add_hanging_cable(game.combat.origin + Vector3(9.5, 5.0, -9.0), 1.6, 4.4)

func graphics_quality() -> int:
	if polish == null:
		return 1
	return int(polish.get("quality"))

func update_player_life(delta: float) -> void:
	if face == null or not is_instance_valid(face):
		return
	var moving_speed := Vector2(game.player.velocity.x, game.player.velocity.z).length()
	var fear := 0.0
	if game.get("horrors") != null:
		fear = clampf(float(game.horrors.fear_weight), 0.0, 1.0)
	face_phase += delta * (1.8 + moving_speed * 0.12)
	var breathe := sin(face_phase) * (0.008 + fear * 0.006)
	var look := sin(clock * 0.37) * 0.018 if moving_speed < 0.15 else 0.0
	face.rotation.x = breathe - fear * 0.025
	face.rotation.y = look + sin(clock * 17.0) * fear * 0.004

func update_runner_life() -> void:
	if runner_cap == null or not is_instance_valid(runner_cap) or runner == null:
		return
	var active := bool(runner.get("active"))
	if not active:
		runner_cap.scale = Vector3.ONE
		return
	var pulse := sin(clock * 8.2) * 0.035
	runner_cap.scale = Vector3(1.0 + pulse, 1.0 - pulse * 0.35, 1.0 + pulse * 0.7)
	runner_cap.rotation.x = sin(clock * 5.3) * 0.025

func update_world_motion(delta: float) -> void:
	var fear := 0.0
	if game.get("horrors") != null:
		fear = clampf(float(game.horrors.fear_weight), 0.0, 1.0)
	for i in range(hanging_cables.size()):
		var cable := hanging_cables[i]
		if not is_instance_valid(cable):
			continue
		var phase := cable_phases[i]
		var amp := 0.018 + fear * 0.025
		cable.rotation.z = sin(clock * 0.78 + phase) * amp
		cable.rotation.x = cos(clock * 0.61 + phase * 1.3) * amp * 0.55
	var quality := graphics_quality()
	for particles in steam_fields:
		if not is_instance_valid(particles):
			continue
		var near := particles.global_position.distance_squared_to(game.player.global_position) < 900.0
		particles.visible = quality > 0 and near
		particles.emitting = particles.visible and not game.paused and not game.editor.active

func _process(delta: float) -> void:
	if not ready_for_life or game == null:
		return
	if game.front_end.active or game.editor.active or game.paused:
		return
	clock += delta
	update_player_life(delta)
	update_runner_life()
	update_world_motion(delta)
