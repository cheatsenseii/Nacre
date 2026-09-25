extends Node3D
## Playable Billy home prologue.
## Built as a compact believable house with optional interactions and a clear path
## through the existing prologue. It never changes NACRE progression or save data.

var story: Node
var player: CharacterBody3D
var camera: Camera3D
var objective_label: Label
var thought_label: Label
var prompt_label: Label
var fade: ColorRect
var crosshair: Label
var enabled := false
var built := false
var interacted := {}
var thought_time := 0.0
var interaction_lock := 0.0
var lamp_light: OmniLight3D
var lamp_shade: MeshInstance3D
var tv_screen: MeshInstance3D
var tv_on := false
var lamp_on := true
var computer_screen: MeshInstance3D
var computer_on := true

const HOME_OFFSET := Vector3(0, 0, 2000)
const INTERACTABLES := [
	"Lamp", "Phone", "TV", "Computer", "Fridge", "Sink", "Camera",
	"Shoes", "PhotoNacre", "Keys", "UrbexGear", "FrontDoor"
]

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
	thought_time = 0.0
	interaction_lock = 0.0
	show()
	enabled = true
	player.position = Vector3(-1.75, 1.25, 1.55)
	player.rotation = Vector3(0, 0, 0)
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
	var material := make_mat(color, 0.36)
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

func cylinder(name_: String, pos: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO, solid := false) -> MeshInstance3D:
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
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
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
	var trim := make_mat(Color("665044"), 0.78)
	var glass := glow_mat(Color("789aa0"), 0.08)
	cube(name_ + "Frame", pos, Vector3(1.18, 1.30, 0.10), trim, false, Vector3(0, rotation_y, 0))
	var inset := Vector3(0, 0, -0.065).rotated(Vector3.UP, rotation_y)
	cube(name_ + "Glass", pos + inset, Vector3(0.96, 1.08, 0.035), glass, false, Vector3(0, rotation_y, 0))
	cube(name_ + "Vertical", pos + inset * 1.12, Vector3(0.05, 1.12, 0.025), trim, false, Vector3(0, rotation_y, 0))
	cube(name_ + "Horizontal", pos + inset * 1.12, Vector3(1.02, 0.05, 0.025), trim, false, Vector3(0, rotation_y, 0))

func add_book(prefix: String, pos: Vector3, color: Color, rotation_y := 0.0) -> void:
	cube(prefix, pos, Vector3(0.16, 0.28, 0.42), make_mat(color, 0.92), false, Vector3(0, rotation_y, 0))

func add_picture(prefix: String, pos: Vector3, size: Vector2, picture_color: Color, rotation_y := 0.0) -> MeshInstance3D:
	var frame := make_mat(Color("413b34"), 0.82)
	var matting := make_mat(Color("c9c0af"), 0.94)
	cube(prefix + "Frame", pos, Vector3(size.x + 0.12, size.y + 0.12, 0.07), frame, false, Vector3(0, rotation_y, 0))
	var inset := Vector3(0, 0, -0.045).rotated(Vector3.UP, rotation_y)
	cube(prefix + "Mat", pos + inset, Vector3(size.x + 0.035, size.y + 0.035, 0.035), matting, false, Vector3(0, rotation_y, 0))
	return cube(prefix, pos + inset * 1.65, Vector3(size.x, size.y, 0.024), make_mat(picture_color, 0.95), false, Vector3(0, rotation_y, 0))

func _build_home() -> void:
	var foundation_mat := make_mat(Color("535552"), 0.96)
	var wall := make_mat(Color("d9d0bf"), 0.90)
	var wall_dark := make_mat(Color("c8beab"), 0.93)
	var trim := make_mat(Color("5b4639"), 0.78)
	var wood := make_mat(Color("75533d"), 0.80)
	var dark_wood := make_mat(Color("49362e"), 0.84)
	var fabric := make_mat(Color("4d6158"), 0.96)
	var fabric_dark := make_mat(Color("303d39"), 0.97)
	var linen := make_mat(Color("d9d1c2"), 0.98)
	var cabinet := make_mat(Color("5c7068"), 0.84)
	var counter := make_mat(Color("b9aa91"), 0.72)
	var ceramic := make_mat(Color("d8dcda"), 0.48)
	var metal := make_mat(Color("353b3b"), 0.46, 0.42)
	var black := make_mat(Color("15191a"), 0.62)
	var rug := make_mat(Color("7f4d3e"), 1.0)

	# Foundation and room floors.
	cube("Foundation", Vector3(0, 0.14, 0), Vector3(7.6, 0.28, 6.4), foundation_mat, true)
	cube("LivingFloor", Vector3(-1.85, 0.30, 1.55), Vector3(3.65, 0.05, 3.0), make_mat(Color("9a704f"), 0.91), false)
	cube("KitchenFloor", Vector3(1.85, 0.30, 1.55), Vector3(3.65, 0.05, 3.0), make_mat(Color("aaa187"), 0.95), false)
	cube("BedroomFloor", Vector3(-1.85, 0.30, -1.55), Vector3(3.65, 0.05, 3.0), make_mat(Color("855f4d"), 0.94), false)
	cube("BathroomFloor", Vector3(1.85, 0.30, -1.55), Vector3(3.65, 0.05, 3.0), make_mat(Color("738c8d"), 0.80), false)

	# Exterior shell. The door opening is intentionally real rather than a fake wall.
	cube("BackWall", Vector3(0, 2.30, -3.10), Vector3(7.6, 4.55, 0.18), wall)
	cube("LeftWall", Vector3(-3.70, 2.30, 0), Vector3(0.18, 4.55, 6.2), wall)
	cube("RightWall", Vector3(3.70, 2.30, 0), Vector3(0.18, 4.55, 6.2), wall)
	cube("FrontWallLeft", Vector3(-2.25, 2.30, 3.10), Vector3(2.90, 4.55, 0.18), wall)
	cube("FrontWallRight", Vector3(2.25, 2.30, 3.10), Vector3(2.90, 4.55, 0.18), wall)
	cube("FrontWallTop", Vector3(0, 3.93, 3.10), Vector3(1.62, 1.30, 0.18), wall)
	cube("Ceiling", Vector3(0, 4.50, 0), Vector3(7.35, 0.14, 6.0), make_mat(Color("e5ddcf"), 0.94), false)

	# Cross-shaped circulation keeps all four rooms readable and prevents collision traps.
	cube("CenterWallNorth", Vector3(0, 2.25, -1.92), Vector3(0.14, 4.10, 2.30), wall_dark)
	cube("CenterWallSouth", Vector3(0, 2.25, 1.92), Vector3(0.14, 4.10, 2.30), wall_dark)
	cube("CenterWallWest", Vector3(-2.30, 2.25, 0), Vector3(2.65, 4.10, 0.14), wall_dark)
	cube("CenterWallEast", Vector3(2.30, 2.25, 0), Vector3(2.65, 4.10, 0.14), wall_dark)
	cube("NorthDoorLintel", Vector3(0, 3.82, -0.73), Vector3(0.14, 0.95, 0.95), trim, false)
	cube("SouthDoorLintel", Vector3(0, 3.82, 0.73), Vector3(0.14, 0.95, 0.95), trim, false)
	cube("WestDoorLintel", Vector3(-0.72, 3.82, 0), Vector3(0.95, 0.95, 0.14), trim, false)
	cube("EastDoorLintel", Vector3(0.72, 3.82, 0), Vector3(0.95, 0.95, 0.14), trim, false)

	# Front door. It stays closed physically because leaving starts the travel transition.
	cube("DoorFrameTop", Vector3(0, 2.82, 3.02), Vector3(1.55, 0.16, 0.18), trim, false)
	cube("DoorFrameLeft", Vector3(-0.70, 1.55, 3.02), Vector3(0.15, 2.65, 0.18), trim, false)
	cube("DoorFrameRight", Vector3(0.70, 1.55, 3.02), Vector3(0.15, 2.65, 0.18), trim, false)
	cube("FrontDoor", Vector3(0, 1.52, 3.00), Vector3(1.25, 2.50, 0.14), dark_wood, true)
	sphere("DoorKnob", Vector3(0.42, 1.55, 2.90), 0.075, make_mat(Color("a88b55"), 0.34, 0.50))

	add_window("LivingWindow", Vector3(-3.58, 2.50, 1.35), PI / 2.0)
	add_window("KitchenWindow", Vector3(3.58, 2.50, 1.10), -PI / 2.0)
	add_window("BedroomWindow", Vector3(-2.05, 2.50, -2.98), PI)
	add_window("BathroomWindow", Vector3(2.05, 2.50, -2.98), PI)

	# SALON: a lived-in room instead of a set of quest boxes.
	cube("LivingRug", Vector3(-1.85, 0.34, 1.55), Vector3(2.30, 0.03, 1.65), rug, false)
	cube("SofaBase", Vector3(-2.55, 0.72, 2.18), Vector3(1.75, 0.52, 0.72), fabric, true)
	cube("SofaBack", Vector3(-2.55, 1.10, 2.47), Vector3(1.75, 0.78, 0.20), fabric_dark, true)
	cube("SofaCushionL", Vector3(-2.92, 0.98, 2.05), Vector3(0.62, 0.18, 0.48), make_mat(Color("65766c"), 0.98), false, Vector3(0, 0, 0.05))
	cube("SofaCushionR", Vector3(-2.18, 0.98, 2.05), Vector3(0.62, 0.18, 0.48), make_mat(Color("5a6b64"), 0.98), false, Vector3(0, 0, -0.05))
	cube("CoffeeTable", Vector3(-1.55, 0.61, 1.38), Vector3(1.15, 0.18, 0.72), wood, true)
	cube("CoffeeTableShelf", Vector3(-1.55, 0.43, 1.38), Vector3(0.95, 0.07, 0.58), dark_wood, false)
	cube("Phone", Vector3(-1.66, 0.73, 1.30), Vector3(0.25, 0.045, 0.48), black, false, Vector3(0, 0.10, 0))
	cube("Mug", Vector3(-1.30, 0.76, 1.47), Vector3(0.18, 0.22, 0.18), make_mat(Color("8a785f"), 0.74), false)
	add_book("BookLivingA", Vector3(-1.68, 0.50, 1.38), Color("5b6d6b"), 0.08)
	add_book("BookLivingB", Vector3(-1.52, 0.50, 1.38), Color("704d43"), -0.06)

	# TV wall with a console, speakers and cables.
	cube("TVUnit", Vector3(-3.35, 0.68, 0.48), Vector3(0.45, 0.70, 1.45), dark_wood, true)
	tv_screen = cube("TV", Vector3(-3.50, 1.62, 0.48), Vector3(0.10, 1.25, 1.85), glow_mat(Color("243337"), 0.02), false)
	cube("SpeakerA", Vector3(-3.40, 0.95, -0.38), Vector3(0.28, 0.62, 0.32), black, false)
	cube("SpeakerB", Vector3(-3.40, 0.95, 1.34), Vector3(0.28, 0.62, 0.32), black, false)
	cube("GameConsole", Vector3(-3.18, 0.94, 0.48), Vector3(0.12, 0.16, 0.58), black, false)

	# Reading corner and lamp. Lamp is actually toggleable.
	cube("SideTable", Vector3(-0.72, 0.58, 2.20), Vector3(0.56, 0.46, 0.56), wood, true)
	cylinder("LampStand", Vector3(-0.72, 1.16, 2.20), 0.045, 0.88, metal)
	var lamp_mesh := CylinderMesh.new()
	lamp_mesh.top_radius = 0.15
	lamp_mesh.bottom_radius = 0.32
	lamp_mesh.height = 0.38
	lamp_mesh.radial_segments = 16
	lamp_shade = MeshInstance3D.new()
	lamp_shade.name = "Lamp"
	lamp_shade.mesh = lamp_mesh
	lamp_shade.position = Vector3(-0.72, 1.75, 2.20)
	lamp_shade.material_override = glow_mat(Color("d8caa8"), 0.45)
	add_child(lamp_shade)
	lamp_light = OmniLight3D.new()
	lamp_light.position = Vector3(-0.72, 1.62, 2.12)
	lamp_light.light_color = Color("e2c28f")
	lamp_light.light_energy = 1.15
	lamp_light.omni_range = 4.2
	lamp_light.shadow_enabled = true
	add_child(lamp_light)

	# Urbex photo wall. PhotoNacre is visually distinct but not glowing like a quest marker.
	add_picture("OldPhotoA", Vector3(-3.57, 2.70, 2.18), Vector2(0.58, 0.42), Color("696c64"), PI / 2.0)
	add_picture("OldPhotoB", Vector3(-3.57, 2.08, 2.25), Vector2(0.48, 0.64), Color("6d675c"), PI / 2.0)
	add_picture("OldPhotoC", Vector3(-3.57, 2.72, 1.48), Vector2(0.68, 0.46), Color("626b67"), PI / 2.0)
	add_picture("PhotoNacre", Vector3(-3.57, 1.92, 1.40), Vector2(0.82, 0.58), Color("435d61"), PI / 2.0)
	cube("PhotoShelf", Vector3(-3.43, 1.35, 1.70), Vector3(0.20, 0.08, 1.65), dark_wood, false)

	# Small plant and clutter.
	cylinder("PlantPot", Vector3(-0.55, 0.62, 0.65), 0.20, 0.38, make_mat(Color("664c3d"), 0.90))
	for offset in [Vector3(-0.10, 0.50, 0), Vector3(0.08, 0.56, 0.06), Vector3(0.02, 0.62, -0.07)]:
		cube("PlantLeaf_%s" % str(offset), Vector3(-0.55, 0.62, 0.65) + offset, Vector3(0.10, 0.55, 0.15), make_mat(Color("3f5b45"), 0.96), false, Vector3(0.18, 0, offset.x * 2.0))

	# CUISINE: counters leave a clear route to the central cross.
	cube("KitchenBase", Vector3(2.42, 0.78, 2.42), Vector3(2.15, 0.82, 0.62), cabinet, true)
	cube("KitchenCounter", Vector3(2.42, 1.22, 2.42), Vector3(2.25, 0.10, 0.72), counter, false)
	cube("KitchenSideBase", Vector3(3.15, 0.78, 1.45), Vector3(0.62, 0.82, 1.20), cabinet, true)
	cube("KitchenSideCounter", Vector3(3.15, 1.22, 1.45), Vector3(0.72, 0.10, 1.28), counter, false)
	cube("Fridge", Vector3(3.12, 1.45, 2.44), Vector3(0.82, 2.30, 0.72), make_mat(Color("b7bbb7"), 0.42, 0.18), true)
	cube("FridgeHandle", Vector3(2.69, 1.45, 2.18), Vector3(0.04, 0.70, 0.06), metal, false)
	cube("SinkBasin", Vector3(2.28, 1.29, 2.40), Vector3(0.66, 0.08, 0.42), metal, false)
	cylinder("Faucet", Vector3(2.28, 1.47, 2.59), 0.045, 0.34, metal)
	cube("CuttingBoard", Vector3(1.67, 1.31, 2.39), Vector3(0.48, 0.04, 0.34), wood, false)
	cube("Bread", Vector3(1.65, 1.38, 2.39), Vector3(0.34, 0.12, 0.24), make_mat(Color("b58b5d"), 0.96), false)
	cube("Keys", Vector3(1.58, 1.34, 2.10), Vector3(0.26, 0.045, 0.13), make_mat(Color("a98a4c"), 0.35, 0.46), false, Vector3(0, 0.24, 0))
	cube("Kettle", Vector3(2.88, 1.42, 1.22), Vector3(0.32, 0.42, 0.28), metal, false)
	cube("DishRack", Vector3(2.68, 1.36, 2.38), Vector3(0.44, 0.12, 0.28), make_mat(Color("777e79"), 0.68, 0.18), false)
	cube("KitchenIsland", Vector3(1.32, 0.86, 1.22), Vector3(1.25, 0.92, 0.72), cabinet, true)
	cube("KitchenIslandTop", Vector3(1.32, 1.35, 1.22), Vector3(1.38, 0.10, 0.82), counter, false)
	for x in [0.98, 1.66]:
		cylinder("KitchenStool_%s" % str(x), Vector3(x, 0.62, 0.42), 0.18, 0.54, wood)
		cylinder("KitchenStoolSeat_%s" % str(x), Vector3(x, 0.92, 0.42), 0.26, 0.08, wood)

	# BEDROOM: Billy's urbex gear lives here, surrounded by normal clutter.
	cube("BedBase", Vector3(-2.38, 0.64, -2.05), Vector3(2.05, 0.38, 1.45), dark_wood, true)
	cube("Mattress", Vector3(-2.38, 0.92, -2.05), Vector3(1.92, 0.25, 1.34), linen, false)
	cube("PillowA", Vector3(-2.82, 1.13, -2.38), Vector3(0.62, 0.16, 0.38), make_mat(Color("d1c8b8"), 0.98), false, Vector3(0, 0.08, 0))
	cube("PillowB", Vector3(-2.05, 1.13, -2.38), Vector3(0.62, 0.16, 0.38), make_mat(Color("c8c0b2"), 0.98), false, Vector3(0, -0.05, 0))
	cube("Blanket", Vector3(-2.38, 1.09, -1.74), Vector3(1.84, 0.08, 0.70), make_mat(Color("46595a"), 0.99), false)
	cube("Wardrobe", Vector3(-3.18, 1.45, -0.72), Vector3(0.82, 2.30, 0.76), cabinet, true)
	cube("WardrobeHandleA", Vector3(-2.75, 1.45, -0.84), Vector3(0.035, 0.48, 0.035), metal, false)
	cube("Desk", Vector3(-0.86, 0.82, -2.45), Vector3(1.38, 0.12, 0.72), wood, true)
	cube("DeskLegA", Vector3(-1.42, 0.54, -2.45), Vector3(0.12, 0.64, 0.58), dark_wood, true)
	cube("DeskLegB", Vector3(-0.30, 0.54, -2.45), Vector3(0.12, 0.64, 0.58), dark_wood, true)
	computer_screen = cube("Computer", Vector3(-0.86, 1.48, -2.78), Vector3(1.02, 0.62, 0.08), glow_mat(Color("32454a"), 0.22), false)
	cube("Keyboard", Vector3(-0.86, 0.93, -2.35), Vector3(0.72, 0.045, 0.26), black, false)
	cube("Mouse", Vector3(-0.36, 0.94, -2.32), Vector3(0.12, 0.05, 0.16), black, false)
	cube("Camera", Vector3(-1.36, 1.02, -2.30), Vector3(0.28, 0.22, 0.22), black, false)
	cylinder("CameraLens", Vector3(-1.36, 1.02, -2.16), 0.08, 0.10, make_mat(Color("202829"), 0.22, 0.30), Vector3(PI / 2.0, 0, 0))
	cube("UrbexGear", Vector3(-2.95, 0.75, -0.82), Vector3(0.72, 0.90, 0.52), make_mat(Color("273330"), 0.95), false, Vector3(0, -0.18, 0))
	cube("BagPocket", Vector3(-2.92, 0.69, -0.53), Vector3(0.48, 0.42, 0.10), make_mat(Color("1f2927"), 0.96), false, Vector3(0, -0.18, 0))
	cube("Shoes", Vector3(-2.18, 0.43, -0.73), Vector3(0.72, 0.24, 0.52), make_mat(Color("282827"), 0.96), false, Vector3(0, 0.22, 0))
	cube("Jacket", Vector3(-3.50, 2.25, -1.10), Vector3(0.12, 1.10, 0.66), make_mat(Color("343b39"), 0.98), false)
	add_book("BookBedroomA", Vector3(-0.62, 0.96, -2.46), Color("5b5148"), 0.25)
	add_book("BookBedroomB", Vector3(-0.45, 0.96, -2.46), Color("4c6060"), 0.18)

	# BATHROOM: enough detail to feel like a room, but no unnecessary collision maze.
	cube("ShowerTray", Vector3(2.75, 0.36, -2.25), Vector3(1.30, 0.08, 1.42), ceramic, false)
	var glass := make_mat(Color(0.55, 0.72, 0.74, 0.34), 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cube("ShowerGlass", Vector3(2.10, 1.34, -2.25), Vector3(0.04, 1.90, 1.40), glass, false)
	cube("Vanity", Vector3(1.12, 0.76, -2.48), Vector3(1.05, 0.70, 0.48), cabinet, true)
	cube("Sink", Vector3(1.12, 1.15, -2.48), Vector3(0.68, 0.16, 0.42), ceramic, false)
	cylinder("SinkTap", Vector3(1.12, 1.34, -2.69), 0.035, 0.28, metal)
	cube("Mirror", Vector3(1.12, 2.18, -2.96), Vector3(0.92, 0.88, 0.035), glow_mat(Color("778486"), 0.03), false)
	cube("ToiletBase", Vector3(2.80, 0.63, -0.68), Vector3(0.55, 0.58, 0.72), ceramic, true)
	cube("ToiletSeat", Vector3(2.80, 0.96, -0.60), Vector3(0.54, 0.12, 0.58), ceramic, false)
	cube("Towel", Vector3(3.52, 1.70, -1.28), Vector3(0.06, 0.72, 0.52), make_mat(Color("9a8c76"), 0.99), false)
	cube("LaundryBasket", Vector3(1.05, 0.61, -0.75), Vector3(0.58, 0.70, 0.58), make_mat(Color("8a765e"), 0.92), false)

	# Lighting deliberately separates the four rooms while staying domestic.
	var living_light := OmniLight3D.new()
	living_light.position = Vector3(-1.85, 3.55, 1.55)
	living_light.light_color = Color("e3c59a")
	living_light.light_energy = 1.35
	living_light.omni_range = 6.0
	living_light.shadow_enabled = true
	add_child(living_light)
	var kitchen_light := OmniLight3D.new()
	kitchen_light.position = Vector3(1.85, 3.55, 1.55)
	kitchen_light.light_color = Color("ddd3b9")
	kitchen_light.light_energy = 1.15
	kitchen_light.omni_range = 5.5
	add_child(kitchen_light)
	var bedroom_light := OmniLight3D.new()
	bedroom_light.position = Vector3(-1.85, 3.35, -1.55)
	bedroom_light.light_color = Color("c99f82")
	bedroom_light.light_energy = 0.72
	bedroom_light.omni_range = 5.0
	add_child(bedroom_light)
	var bathroom_light := OmniLight3D.new()
	bathroom_light.position = Vector3(1.85, 3.35, -1.55)
	bathroom_light.light_color = Color("b9ced0")
	bathroom_light.light_energy = 0.92
	bathroom_light.omni_range = 4.8
	add_child(bathroom_light)

	# Billy's dedicated first-person controller for the home sequence.
	player = CharacterBody3D.new()
	player.name = "BillyMaison"
	player.position = Vector3(-1.75, 1.25, 1.55)
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	player.floor_snap_length = 0.25
	player.floor_max_angle = deg_to_rad(48.0)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.72
	collision.shape = capsule
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.64, 0)
	camera.fov = 76
	camera.near = 0.05
	player.add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var objective_panel := Panel.new()
	objective_panel.position = Vector2(24, 22)
	objective_panel.size = Vector2(535, 58)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var objective_style := StyleBoxFlat.new()
	objective_style.bg_color = Color(0.025, 0.035, 0.035, 0.78)
	objective_style.border_color = Color(0.45, 0.52, 0.48, 0.34)
	objective_style.set_border_width_all(1)
	objective_style.set_corner_radius_all(5)
	objective_panel.add_theme_stylebox_override("panel", objective_style)
	root.add_child(objective_panel)
	objective_label = Label.new()
	objective_label.position = Vector2(15, 9)
	objective_label.size = Vector2(505, 40)
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color("d9e0da"))
	objective_panel.add_child(objective_label)

	thought_label = Label.new()
	thought_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	thought_label.offset_left = 150
	thought_label.offset_right = -150
	thought_label.offset_top = 570
	thought_label.offset_bottom = -36
	thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought_label.add_theme_font_size_override("font_size", 22)
	thought_label.add_theme_color_override("font_color", Color("ece8da"))
	thought_label.add_theme_color_override("font_outline_color", Color.BLACK)
	thought_label.add_theme_constant_override("outline_size", 6)
	root.add_child(thought_label)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-240, 165)
	prompt_label.size = Vector2(480, 46)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("e2e0d4"))
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 5)
	root.add_child(prompt_label)

	crosshair = Label.new()
	crosshair.text = "·"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12, -17)
	crosshair.size = Vector2(24, 34)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 27)
	crosshair.add_theme_color_override("font_color", Color(0.87, 0.88, 0.83, 0.68))
	root.add_child(crosshair)

	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	_refresh_ui()

func _refresh_ui() -> void:
	if story != null and is_instance_valid(objective_label):
		objective_label.text = "OBJECTIF  •  " + story.get_objective()

func _show_thought(text: String, duration := 4.2) -> void:
	if text == "" or not is_instance_valid(thought_label):
		return
	thought_label.text = text
	thought_time = duration

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or player == null or camera == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.00235)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.00235, -1.18, 1.18)

func _process(delta: float) -> void:
	if thought_time > 0:
		thought_time = maxf(0.0, thought_time - delta)
		if thought_time <= 0 and is_instance_valid(thought_label):
			thought_label.text = ""
	interaction_lock = maxf(0.0, interaction_lock - delta)
	if not enabled or player == null or camera == null:
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := 4.15 if Input.is_action_pressed("sprint") else 2.85
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if player.is_on_floor():
		player.velocity.y = -0.25
	else:
		player.velocity.y -= 12.5 * delta
	player.move_and_slide()
	var target := _target()
	prompt_label.text = "" if target == "" else "[E]  " + _label(target)
	if target != "" and Input.is_action_just_pressed("interact") and interaction_lock <= 0:
		interaction_lock = 0.18
		_interact(target)

func _target() -> String:
	var best := ""
	var best_score := INF
	var forward := -camera.global_basis.z
	for id in INTERACTABLES:
		var node := get_node_or_null(id)
		if node == null or not node.visible:
			continue
		var offset: Vector3 = node.global_position - camera.global_position
		var distance := offset.length()
		if distance < 0.08 or distance > 2.65:
			continue
		var facing := forward.dot(offset.normalized())
		if facing < 0.28:
			continue
		var score := distance - facing * 0.65
		if score < best_score:
			best_score = score
			best = id
	return best

func _label(id: String) -> String:
	match id:
		"Lamp": return "Allumer / éteindre la lampe"
		"Phone": return "Regarder le téléphone"
		"TV": return "Allumer / éteindre la télé"
		"Computer": return "Regarder l'ordinateur"
		"Fridge": return "Ouvrir le frigo"
		"Sink": return "Regarder le lavabo"
		"Camera": return "Regarder l'appareil photo"
		"Shoes": return "Regarder les chaussures"
		"PhotoNacre": return "Examiner la photo de NACRE"
		"Keys": return "Prendre les clés"
		"UrbexGear": return "Prendre le sac d'urbex"
		"FrontDoor": return "Sortir"
	return "Interagir"

func _story_boredom(id: String, story_id: String) -> String:
	if interacted.has(id):
		return _repeat_line(id)
	interacted[id] = true
	var line := story.inspect_boredom_object(story_id)
	if line == "":
		return _repeat_line(id)
	return line

func _repeat_line(id: String) -> String:
	match id:
		"Lamp": return "La lumière est au moins plus motivée que moi."
		"Phone": return "Toujours rien d'intéressant."
		"TV": return "Non. Ça ne va pas sauver ma soirée."
		"Computer": return "J'ai déjà fait le tour du web trois fois."
		"Fridge": return "Toujours aussi vide."
		"Sink": return "Rien de passionnant dans un lavabo."
		"Camera": return "Elle prend la poussière. Quel gâchis."
		"Shoes": return "Elles sont prêtes. Moi, moins."
	return ""

func _interact(id: String) -> void:
	var line := ""
	match id:
		"Lamp":
			lamp_on = not lamp_on
			if lamp_light != null:
				lamp_light.visible = lamp_on
			if lamp_shade != null and lamp_shade.material_override is StandardMaterial3D:
				lamp_shade.material_override.emission_energy_multiplier = 0.45 if lamp_on else 0.015
			line = _story_boredom(id, "urbex_lamp")
		"Phone":
			line = _story_boredom(id, "phone")
		"TV":
			tv_on = not tv_on
			if tv_screen != null and tv_screen.material_override is StandardMaterial3D:
				var tv_material: StandardMaterial3D = tv_screen.material_override
				tv_material.albedo_color = Color("405b62") if tv_on else Color("101617")
				tv_material.emission = Color("405b62") if tv_on else Color("101617")
				tv_material.emission_energy_multiplier = 0.48 if tv_on else 0.01
			line = _story_boredom(id, "tv")
		"Computer":
			computer_on = not computer_on
			if computer_screen != null and computer_screen.material_override is StandardMaterial3D:
				computer_screen.material_override.emission_energy_multiplier = 0.22 if computer_on else 0.01
			line = _story_boredom(id, "computer")
		"Fridge":
			line = _story_boredom(id, "fridge")
		"Shoes":
			line = _story_boredom(id, "old_shoes")
		"Sink":
			line = _repeat_line(id)
		"Camera":
			line = _repeat_line(id)
		"PhotoNacre":
			line = story.inspect_nacre_photo()
			if line == "":
				line = "Je connais cette photo par cœur maintenant."
		"Keys":
			line = story.collect_keys()
			if line != "":
				var keys := get_node_or_null("Keys")
				if keys != null: keys.hide()
			else:
				line = "Les clés peuvent attendre. Je ne sais même pas encore où aller."
		"UrbexGear":
			line = story.collect_urbex_gear()
			if line != "":
				var bag := get_node_or_null("UrbexGear")
				var pocket := get_node_or_null("BagPocket")
				if bag != null: bag.hide()
				if pocket != null: pocket.hide()
			else:
				line = "Le sac est prêt depuis longtemps. Pas moi."
		"FrontDoor":
			line = story.leave_home()
			if line != "":
				_leave()
				return
			line = "Sortir pour tourner sans but ? Non. Il me faut une vraie raison."
	_show_thought(line)
	_refresh_ui()

func _leave() -> void:
	enabled = false
	if is_instance_valid(prompt_label): prompt_label.text = ""
	if is_instance_valid(objective_label): objective_label.text = ""
	_show_thought("Allez Billy. Une vraie sortie. Ça changera.", 8.0)
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree(): return
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.9)
	await tween.finished
	if not is_inside_tree(): return
	story.finish_drive()
	thought_label.text = "Quelques kilomètres plus tard…"
	await get_tree().create_timer(1.35).timeout
	if not is_inside_tree(): return
	story.confirm_arrival()
	thought_label.text = "NACRE. Toujours là."
	await get_tree().create_timer(1.05).timeout
	if not is_inside_tree(): return
	var game := get_parent()
	if game != null and game.front_end != null and game.front_end.has_method("finish_billy_prologue"):
		game.front_end.finish_billy_prologue()
	queue_free()
