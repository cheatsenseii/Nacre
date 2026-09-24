extends Node3D
## Playable Billy home prologue rebuilt from the supplied 3D house prototype.
## The house stays isolated from NACRE in the same World3D.

var story: Node
var player: CharacterBody3D
var camera: Camera3D
var objective_label: Label
var thought_label: Label
var prompt_label: Label
var fade: ColorRect
var interacted := {}
var enabled := false
var built := false
const HOME_OFFSET := Vector3(0, 0, 2000)

func _ready() -> void:
	story = get_parent().get_node_or_null("BillyPrologue")
	position = HOME_OFFSET
	hide()

func begin() -> void:
	if story == null:
		return
	if not built:
		_build_home()
		_build_ui()
		built = true
	story.begin()
	interacted.clear()
	show()
	enabled = true
	player.position = Vector3(-1.55, 1.30, 1.20)
	player.rotation = Vector3(0, PI, 0)
	camera.rotation = Vector3.ZERO
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_ui()
	_show_thought(story.current_thought)

func make_mat(color: Color, roughness := 0.88, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := make_mat(color, 0.38)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func cube(name_: String, pos: Vector3, size: Vector3, material: Material, solid := true, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation = rotation
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func cylinder(name_: String, pos: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation = rotation
	add_child(node)
	return node

func sphere(name_: String, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add_child(node)
	return node

func add_window(name_: String, pos: Vector3, rotation_y := 0.0) -> void:
	var trim := make_mat(Color("6b4b3a"), 0.75)
	var glass := glow_mat(Color("8bc3cf"), 0.12)
	cube(name_ + "_Frame", pos, Vector3(1.05, 1.08, 0.10), trim, false, Vector3(0, rotation_y, 0))
	var inset := Vector3(0, 0, -0.065).rotated(Vector3.UP, rotation_y)
	cube(name_ + "_Glass", pos + inset, Vector3(0.83, 0.86, 0.035), glass, false, Vector3(0, rotation_y, 0))
	cube(name_ + "_V", pos + inset * 1.12, Vector3(0.06, 0.92, 0.025), trim, false, Vector3(0, rotation_y, 0))
	cube(name_ + "_H", pos + inset * 1.12, Vector3(0.88, 0.06, 0.025), trim, false, Vector3(0, rotation_y, 0))

func add_tree(prefix: String, x: float, z: float, scale_value := 1.0) -> void:
	var trunk := make_mat(Color("6c4931"), 0.95)
	var leaves := make_mat(Color("3f7849"), 0.9)
	cylinder(prefix + "_Trunk", Vector3(x, 0.85 * scale_value, z), 0.18 * scale_value, 1.7 * scale_value, trunk)
	var foliage := MeshInstance3D.new()
	foliage.name = prefix + "_Foliage"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.05 * scale_value
	cone.height = 2.25 * scale_value
	cone.radial_segments = 10
	foliage.mesh = cone
	foliage.position = Vector3(x, 2.1 * scale_value, z)
	foliage.material_override = leaves
	add_child(foliage)
	var foliage_top := MeshInstance3D.new()
	foliage_top.name = prefix + "_FoliageTop"
	var cone_top := CylinderMesh.new()
	cone_top.top_radius = 0.0
	cone_top.bottom_radius = 0.78 * scale_value
	cone_top.height = 1.7 * scale_value
	cone_top.radial_segments = 10
	foliage_top.mesh = cone_top
	foliage_top.position = Vector3(x, 3.18 * scale_value, z)
	foliage_top.material_override = leaves
	add_child(foliage_top)

func add_fence(prefix: String, x: float, z: float, length: int, horizontal := true) -> void:
	var fence_mat := make_mat(Color("d9c092"), 0.85)
	var rotation_y := 0.0 if horizontal else PI / 2.0
	for i in range(length + 1):
		var local := Vector3(float(i) - float(length) * 0.5, 0.56, 0).rotated(Vector3.UP, rotation_y)
		cylinder(prefix + "_Post_%d" % i, Vector3(x, 0, z) + local, 0.06, 1.12, fence_mat)
	cube(prefix + "_RailTop", Vector3(x, 0.82, z), Vector3(float(length), 0.09, 0.09), fence_mat, false, Vector3(0, rotation_y, 0))
	cube(prefix + "_RailLow", Vector3(x, 0.35, z), Vector3(float(length), 0.09, 0.09), fence_mat, false, Vector3(0, rotation_y, 0))

func _build_home() -> void:
	# Palette from the supplied prototype.
	var stone := make_mat(Color("7f8480"), 0.95)
	var wall := make_mat(Color("f2e5c5"), 0.86)
	var trim := make_mat(Color("6b4b3a"), 0.75)
	var door_mat := make_mat(Color("4d3029"), 0.72)
	var wood := make_mat(Color("9c704e"), 0.78)
	var floor_living := make_mat(Color("c99563"), 0.88)
	var floor_kitchen := make_mat(Color("d5c39e"), 0.92)
	var floor_bed := make_mat(Color("b9825e"), 0.90)
	var floor_bath := make_mat(Color("9fc1c5"), 0.76)
	var fabric := make_mat(Color("708a72"), 0.95)
	var linen := make_mat(Color("f6eee1"), 0.96)
	var cabinet := make_mat(Color("78977a"), 0.82)
	var counter := make_mat(Color("e7d5b3"), 0.70)
	var ceramic := make_mat(Color("f5f5ed"), 0.50)
	var rug := make_mat(Color("bf6c4f"), 1.0)
	var dark_metal := make_mat(Color("3d4b43"), 0.65, 0.25)
	var partition := make_mat(Color("eadcc2"), 0.90)

	# Foundation and four readable rooms.
	cube("Foundation", Vector3(0, 0.16, 0), Vector3(6.5, 0.32, 5.35), stone, true)
	cube("LivingFloor", Vector3(-1.48, 0.36, 1.20), Vector3(3.0, 0.08, 2.45), floor_living, false)
	cube("KitchenFloor", Vector3(1.48, 0.36, 1.20), Vector3(3.0, 0.08, 2.45), floor_kitchen, false)
	cube("BedroomFloor", Vector3(-1.48, 0.36, -1.20), Vector3(3.0, 0.08, 2.45), floor_bed, false)
	cube("BathroomFloor", Vector3(1.48, 0.36, -1.20), Vector3(3.0, 0.08, 2.45), floor_bath, false)

	# Exterior shell. The front wall is segmented so the door is a real passage.
	cube("BackWall", Vector3(0, 2.15, -2.46), Vector3(6.2, 4.35, 0.18), wall)
	cube("LeftWall", Vector3(-3.01, 2.15, 0), Vector3(0.18, 4.35, 5.10), wall)
	cube("RightWall", Vector3(3.01, 2.15, 0), Vector3(0.18, 4.35, 5.10), wall)
	cube("FrontWallLeft", Vector3(-1.93, 2.15, 2.46), Vector3(2.34, 4.35, 0.18), wall)
	cube("FrontWallRight", Vector3(1.93, 2.15, 2.46), Vector3(2.34, 4.35, 0.18), wall)
	cube("FrontWallTop", Vector3(0, 3.78, 2.46), Vector3(1.52, 1.10, 0.18), wall)
	cube("Ceiling", Vector3(0, 4.02, 0), Vector3(6.0, 0.14, 4.90), make_mat(Color("fbf3e5"), 0.9), false)

	# Pyramid roof echoing the prototype exterior.
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 4.8
	roof_mesh.height = 2.8
	roof_mesh.radial_segments = 4
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 5.52, 0)
	roof.rotation.y = PI / 4.0
	roof.material_override = make_mat(Color("b94e3c"), 0.78)
	add_child(roof)

	# Internal partitions with broad walkable openings.
	cube("PartitionA", Vector3(0, 1.95, -1.45), Vector3(0.14, 3.15, 1.95), partition)
	cube("PartitionB", Vector3(0, 1.95, 1.65), Vector3(0.14, 3.15, 1.55), partition)
	cube("PartitionC", Vector3(-1.95, 1.95, 0), Vector3(2.05, 3.15, 0.14), partition)
	cube("PartitionD", Vector3(1.95, 1.95, 0), Vector3(2.05, 3.15, 0.14), partition)

	# Door and windows.
	cube("DoorFrame", Vector3(0, 1.48, 2.56), Vector3(1.55, 2.75, 0.14), trim, false)
	cube("FrontDoor", Vector3(0, 1.38, 2.50), Vector3(1.25, 2.45, 0.12), door_mat, true)
	sphere("DoorKnob", Vector3(0.40, 1.48, 2.38), 0.085, make_mat(Color("d7ae52"), 0.3, 0.55))
	add_window("WindowFrontLeft", Vector3(-2.02, 2.65, 2.36), 0)
	add_window("WindowFrontRight", Vector3(2.02, 2.65, 2.36), 0)
	add_window("WindowLeft", Vector3(-2.91, 2.75, -0.80), PI / 2.0)
	add_window("WindowRight", Vector3(2.91, 2.75, -0.80), -PI / 2.0)

	# SALON: rug, sofa, table, lamp and the urbex memory wall.
	cube("LivingRug", Vector3(-1.55, 0.43, 1.25), Vector3(1.72, 0.03, 1.20), rug, false)
	cube("SofaSeat", Vector3(-1.65, 0.79, 1.88), Vector3(1.85, 0.60, 0.68), fabric)
	cube("SofaArmL", Vector3(-2.48, 1.00, 1.88), Vector3(0.20, 0.95, 0.68), fabric)
	cube("SofaArmR", Vector3(-0.82, 1.00, 1.88), Vector3(0.20, 0.95, 0.68), fabric)
	cube("CoffeeTable", Vector3(-1.55, 0.66, 0.98), Vector3(0.95, 0.32, 0.58), wood)
	cube("SideTable", Vector3(-2.45, 0.74, 0.48), Vector3(1.10, 0.60, 0.35), wood)
	cylinder("LampStand", Vector3(-2.35, 1.26, 0.85), 0.06, 1.50, dark_metal)
	var lamp_shade := MeshInstance3D.new()
	lamp_shade.name = "Lamp"
	var lamp_mesh := CylinderMesh.new()
	lamp_mesh.top_radius = 0.14
	lamp_mesh.bottom_radius = 0.28
	lamp_mesh.height = 0.40
	lamp_mesh.radial_segments = 12
	lamp_shade.mesh = lamp_mesh
	lamp_shade.position = Vector3(-2.35, 2.15, 0.85)
	lamp_shade.material_override = glow_mat(Color("f6eee1"), 0.18)
	add_child(lamp_shade)
	cube("Phone", Vector3(-1.55, 0.86, 0.98), Vector3(0.26, 0.045, 0.52), make_mat(Color("1d2326"), 0.45), false)

	# Five framed urbex photographs. PhotoNacre remains the story trigger.
	var frame_mat := make_mat(Color("5a5145"), 0.82)
	var photo_mat := make_mat(Color("667064"), 0.95)
	var frame_positions := [
		Vector3(-2.89, 2.78, 1.75),
		Vector3(-2.89, 2.40, 1.10),
		Vector3(-2.89, 2.82, 0.42),
		Vector3(-2.89, 1.82, 1.55),
		Vector3(-2.89, 1.82, 0.72)
	]
	for i in range(frame_positions.size()):
		var p: Vector3 = frame_positions[i]
		var size := Vector3(0.08, 0.56 if i != 1 else 0.82, 0.78 if i != 1 else 0.92)
		cube("PhotoFrame%d" % i, p, size + Vector3(0.025, 0.12, 0.12), frame_mat, false, Vector3(0, PI / 2.0, 0))
		if i == 1:
			cube("PhotoNacre", p + Vector3(0.055, 0, 0), size, make_mat(Color("31505a"), 0.82), false, Vector3(0, PI / 2.0, 0))
		else:
			cube("OldPhoto%d" % i, p + Vector3(0.055, 0, 0), size, photo_mat, false, Vector3(0, PI / 2.0, 0))

	# CUISINE: cabinets, countertop, island and stools.
	cube("KitchenCabinets", Vector3(1.55, 0.83, 2.00), Vector3(2.45, 0.78, 0.54), cabinet)
	cube("KitchenCounter", Vector3(1.55, 1.26, 2.00), Vector3(2.55, 0.12, 0.65), counter)
	cube("TallCabinet", Vector3(2.48, 0.80, 1.32), Vector3(0.56, 0.72, 1.30), cabinet)
	cube("TallCounter", Vector3(2.48, 1.21, 1.32), Vector3(0.68, 0.10, 1.40), counter)
	cube("KitchenIsland", Vector3(1.35, 0.87, 0.85), Vector3(1.10, 0.85, 0.66), cabinet)
	cube("KitchenIslandTop", Vector3(1.35, 1.31, 0.85), Vector3(1.22, 0.12, 0.78), counter)
	for offset in [-0.38, 0.38]:
		cylinder("StoolLeg_%s" % str(offset), Vector3(1.35 + offset, 0.68, 0.18), 0.15, 0.55, wood)
		cylinder("StoolSeat_%s" % str(offset), Vector3(1.35 + offset, 0.98, 0.18), 0.24, 0.08, wood)
	cube("Keys", Vector3(1.35, 1.42, 0.86), Vector3(0.28, 0.055, 0.14), make_mat(Color("b39f62"), 0.34, 0.48), false)

	# CHAMBRE: bed, bedside table, wardrobe, shoes and Billy's urbex bag.
	cube("BedFrame", Vector3(-1.58, 0.70, -1.15), Vector3(2.00, 0.42, 1.42), wood)
	cube("Mattress", Vector3(-1.58, 1.02, -1.15), Vector3(1.86, 0.26, 1.28), linen)
	cube("PillowL", Vector3(-2.08, 1.22, -1.54), Vector3(0.62, 0.13, 0.38), fabric, false)
	cube("PillowR", Vector3(-1.32, 1.22, -1.54), Vector3(0.62, 0.13, 0.38), fabric, false)
	cube("Headboard", Vector3(-1.58, 1.27, -1.80), Vector3(1.92, 0.88, 0.12), wood)
	cube("Bedside", Vector3(-2.62, 0.78, -0.85), Vector3(0.48, 0.58, 0.45), wood)
	cube("Wardrobe", Vector3(-0.55, 1.35, -1.80), Vector3(0.70, 1.85, 0.52), cabinet)
	cube("Shoes", Vector3(-0.96, 0.54, -2.02), Vector3(0.62, 0.18, 0.42), make_mat(Color("302b28"), 0.88), false)
	cube("UrbexGear", Vector3(-0.62, 0.78, -1.34), Vector3(0.56, 0.76, 0.44), make_mat(Color("26302f"), 0.92), false)

	# SALLE DE BAIN: shower, vanity, basin and WC.
	var glass := make_mat(Color(0.72, 0.87, 0.89, 0.38), 0.15, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cube("ShowerTray", Vector3(2.18, 0.47, -1.42), Vector3(1.22, 0.06, 1.15), ceramic)
	cube("ShowerGlass", Vector3(1.58, 1.40, -1.42), Vector3(0.06, 1.85, 1.20), glass, false)
	cube("Vanity", Vector3(1.35, 0.80, -0.48), Vector3(1.25, 0.70, 0.48), cabinet)
	cylinder("Basin", Vector3(1.35, 1.22, -0.48), 0.30, 0.15, ceramic)
	cube("WCBase", Vector3(2.48, 0.76, -0.42), Vector3(0.55, 0.64, 0.68), ceramic)
	cylinder("WCBowl", Vector3(2.48, 1.14, -0.42), 0.24, 0.16, ceramic)
	cube("BathroomMirror", Vector3(1.35, 2.25, -2.35), Vector3(0.80, 0.56, 0.06), glow_mat(Color("9fc1c5"), 0.06), false)

	# Exterior garden and path keep the same silhouette as the prototype.
	cube("GardenGround", Vector3(0, -0.09, 0), Vector3(17.0, 0.10, 17.0), make_mat(Color("669a63"), 1.0), false)
	cube("FrontPath", Vector3(0, 0.01, 6.15), Vector3(1.80, 0.07, 7.50), make_mat(Color("d4b17c"), 1.0), false, Vector3(0, -0.08, 0))
	add_tree("TreeA", -6.8, -3.6, 1.15)
	add_tree("TreeB", 6.6, -2.4, 0.90)
	add_tree("TreeC", 5.7, 4.8, 0.73)
	add_fence("FenceLeft", -5.2, 4.75, 6, true)
	add_fence("FenceRight", 5.25, 4.75, 6, true)
	add_fence("FenceSide", -8.1, 0.1, 8, false)

	# Warm/cool lighting from the prototype, toned for a playable evening interior.
	var warm := OmniLight3D.new()
	warm.position = Vector3(-1.5, 3.45, 1.1)
	warm.light_energy = 2.15
	warm.omni_range = 8.0
	warm.light_color = Color("ffd99b")
	warm.shadow_enabled = true
	add_child(warm)
	var kitchen_light := OmniLight3D.new()
	kitchen_light.position = Vector3(1.55, 3.35, 1.05)
	kitchen_light.light_energy = 1.45
	kitchen_light.omni_range = 6.5
	kitchen_light.light_color = Color("ffe7b4")
	add_child(kitchen_light)
	var bedroom_light := OmniLight3D.new()
	bedroom_light.position = Vector3(-1.4, 3.10, -1.15)
	bedroom_light.light_energy = 0.82
	bedroom_light.omni_range = 5.4
	bedroom_light.light_color = Color("ffd8ae")
	add_child(bedroom_light)
	var cool := OmniLight3D.new()
	cool.position = Vector3(2.65, 2.5, -0.8)
	cool.light_energy = 0.34
	cool.omni_range = 5.0
	cool.light_color = Color("b8d9ff")
	add_child(cool)

	# Playable first-person Billy.
	player = CharacterBody3D.new()
	player.name = "BillyMaison"
	player.position = Vector3(-1.55, 1.30, 1.20)
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	player.floor_snap_length = 0.25
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.72
	collision.shape = capsule
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.64, 0)
	camera.fov = 76
	player.add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	objective_label = Label.new()
	objective_label.position = Vector2(32, 28)
	objective_label.size = Vector2(700, 55)
	objective_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(objective_label)
	thought_label = Label.new()
	thought_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	thought_label.position = Vector2(-460, -110)
	thought_label.size = Vector2(920, 70)
	thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought_label.add_theme_font_size_override("font_size", 22)
	thought_label.add_theme_color_override("font_outline_color", Color.BLACK)
	thought_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(thought_label)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-220, -175)
	prompt_label.size = Vector2(440, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(prompt_label)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	_refresh_ui()

func _refresh_ui() -> void:
	if story != null:
		objective_label.text = "OBJECTIF  •  " + story.get_objective()

func _show_thought(text: String) -> void:
	if text == "":
		return
	thought_label.text = text
	var tween := create_tween()
	tween.tween_interval(4.2)
	tween.tween_callback(_clear_thought)

func _clear_thought() -> void:
	if is_instance_valid(thought_label):
		thought_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion:
		player.rotate_y(-event.relative.x * 0.0025)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0025, -1.15, 1.15)

func _process(delta: float) -> void:
	if not enabled or player == null:
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := 4.1 if Input.is_action_pressed("sprint") else 3.0
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 12.0 * delta
	player.move_and_slide()
	var target := _target()
	prompt_label.text = "" if target == "" else "[E]  " + _label(target)
	if Input.is_action_just_pressed("interact") and target != "":
		_interact(target)

func _target() -> String:
	var best := ""
	var best_distance := 2.35
	var forward := -camera.global_basis.z
	for id in ["Lamp", "Shoes", "Phone", "PhotoNacre", "Keys", "UrbexGear", "FrontDoor"]:
		var node := get_node_or_null(id)
		if node == null or not node.visible:
			continue
		var offset: Vector3 = node.global_position - camera.global_position
		var distance := offset.length()
		if distance < best_distance and distance > 0.001 and forward.dot(offset.normalized()) > 0.34:
			best_distance = distance
			best = id
	return best

func _label(id: String) -> String:
	match id:
		"Lamp": return "Regarder la lampe"
		"Shoes": return "Regarder les chaussures"
		"Phone": return "Regarder le téléphone"
		"PhotoNacre": return "Examiner la photo de NACRE"
		"Keys": return "Prendre les clés"
		"UrbexGear": return "Prendre le sac d'urbex"
		"FrontDoor": return "Sortir"
	return "Interagir"

func _interact(id: String) -> void:
	var line := ""
	match id:
		"Lamp", "Shoes", "Phone":
			if interacted.has(id):
				return
			interacted[id] = true
			var map := {"Lamp":"urbex_lamp", "Shoes":"old_shoes", "Phone":"phone"}
			line = story.inspect_boredom_object(map[id])
		"PhotoNacre":
			line = story.inspect_nacre_photo()
		"Keys":
			line = story.collect_keys()
			if line != "":
				get_node("Keys").hide()
		"UrbexGear":
			line = story.collect_urbex_gear()
			if line != "":
				get_node("UrbexGear").hide()
		"FrontDoor":
			line = story.leave_home()
			if line != "":
				_leave()
	_show_thought(line)
	_refresh_ui()

func _leave() -> void:
	enabled = false
	prompt_label.text = ""
	objective_label.text = ""
	_show_thought("Allez Billy. Une vraie sortie. Ça changera.")
	await get_tree().create_timer(1.8).timeout
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	await tween.finished
	story.finish_drive()
	thought_label.text = "Quelques kilomètres plus tard…"
	await get_tree().create_timer(1.5).timeout
	story.confirm_arrival()
	thought_label.text = "NACRE. Toujours là."
	await get_tree().create_timer(1.2).timeout
	var game := get_parent()
	if game.front_end != null and game.front_end.has_method("finish_billy_prologue"):
		game.front_end.finish_billy_prologue()
	queue_free()
