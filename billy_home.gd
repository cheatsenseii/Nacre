extends Node3D
## Playable Billy home prologue.
## The house lives far away from NACRE in the same World3D so both spaces never overlap.

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
	player.position = Vector3(0, 0.9, 1.8)
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_ui()
	_show_thought(story.current_thought)

func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.88
	return m

func glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func cube(name_: String, pos: Vector3, size: Vector3, c: Color, solid := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name_
	var bm := BoxMesh.new()
	bm.size = size
	n.mesh = bm
	n.material_override = mat(c)
	n.position = pos
	add_child(n)
	if solid:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		b.add_child(cs)
		n.add_child(b)
	return n

func _build_home() -> void:
	# A warm but tired living room. It should feel safe enough that NACRE hurts by contrast.
	cube("Floor", Vector3(0, -0.15, 0), Vector3(12, 0.3, 10), Color("3a332e"))
	cube("BackWall", Vector3(0, 2.4, -5), Vector3(12, 5, 0.25), Color("aaa294"))
	cube("LeftWall", Vector3(-6, 2.4, 0), Vector3(0.25, 5, 10), Color("9b9488"))
	cube("RightWall", Vector3(6, 2.4, 0), Vector3(0.25, 5, 10), Color("9b9488"))
	cube("Ceiling", Vector3(0, 4.9, 0), Vector3(12, 0.2, 10), Color("77736c"), false)
	cube("Rug", Vector3(-0.5, 0.02, -1.4), Vector3(4.6, 0.035, 2.8), Color("56483f"), false)
	cube("Sofa", Vector3(-2, 0.65, -3.8), Vector3(3.8, 1.3, 1.2), Color("465351"))
	cube("Table", Vector3(0, 0.45, -1.4), Vector3(2.2, 0.2, 1.2), Color("67472f"))
	cube("TV", Vector3(3, 1.35, -4.72), Vector3(2.5, 1.45, 0.18), Color("151719"), false)
	cube("TVStand", Vector3(3, 0.42, -4.55), Vector3(3.0, 0.6, 0.7), Color("3c3028"))
	# Urbex memories sit together rather than looking like random quest props.
	cube("PhotoFrame", Vector3(-0.2, 1.45, -4.76), Vector3(1.62, 1.10, 0.10), Color("241f1b"), false)
	cube("PhotoNacre", Vector3(-0.2, 1.45, -4.82), Vector3(1.4, 0.9, 0.08), Color("31505a"), false)
	for i in range(3):
		cube("OldPhoto%d" % i, Vector3(-2.0 + i * 0.65, 1.75 + (i % 2) * 0.22, -4.83), Vector3(0.5, 0.34, 0.05), Color("746a5a"), false)
	cube("Keys", Vector3(2.1, 0.68, -1.4), Vector3(0.28, 0.06, 0.14), Color("b39f62"), false)
	cube("UrbexGear", Vector3(-4, 0.55, -3.9), Vector3(0.75, 1.05, 0.55), Color("26302f"), false)
	cube("Lamp", Vector3(-4.5, 0.7, -1.2), Vector3(0.18, 0.55, 0.18), Color("bcae7f"), false)
	cube("Shoes", Vector3(4.4, 0.18, 2.8), Vector3(0.8, 0.3, 0.65), Color("302b28"), false)
	cube("Phone", Vector3(0.65, 0.62, -1.4), Vector3(0.32, 0.05, 0.62), Color("1d2326"), false)
	cube("FrontDoor", Vector3(0, 1.25, 4.88), Vector3(1.8, 2.5, 0.16), Color("49372b"), false)
	# A cold window edge and warm ceiling lamp give the room a believable evening split.
	var window := cube("WindowGlow", Vector3(5.84, 2.35, -1.2), Vector3(0.03, 2.3, 2.8), Color("60747a"), false)
	window.material_override = glow_mat(Color("60747a"), 0.18)
	var warm := OmniLight3D.new()
	warm.position = Vector3(-0.6, 3.7, -0.4)
	warm.light_energy = 1.7
	warm.omni_range = 9
	warm.light_color = Color("e6bd8d")
	warm.shadow_enabled = true
	add_child(warm)
	var cool := OmniLight3D.new()
	cool.position = Vector3(4.7, 2.6, -1.2)
	cool.light_energy = 0.42
	cool.omni_range = 5.5
	cool.light_color = Color("7897a0")
	add_child(cool)
	player = CharacterBody3D.new()
	player.name = "BillyMaison"
	player.position = Vector3(0, 0.9, 1.8)
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	player.floor_snap_length = 0.25
	add_child(player)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	player.add_child(col)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.65, 0)
	camera.fov = 76
	player.add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	objective_label = Label.new()
	objective_label.position = Vector2(32, 28)
	objective_label.size = Vector2(650, 55)
	objective_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(objective_label)
	thought_label = Label.new()
	thought_label.position = Vector2(180, 610)
	thought_label.size = Vector2(920, 70)
	thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought_label.add_theme_font_size_override("font_size", 22)
	thought_label.add_theme_color_override("font_outline_color", Color.BLACK)
	thought_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(thought_label)
	prompt_label = Label.new()
	prompt_label.position = Vector2(450, 535)
	prompt_label.size = Vector2(380, 42)
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

func _show_thought(t: String) -> void:
	if t == "":
		return
	thought_label.text = t
	var tw := create_tween()
	tw.tween_interval(4.2)
	tw.tween_callback(_clear_thought)

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
	var dir := (player.transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := 4.1 if Input.is_action_pressed("sprint") else 3.0
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 12.0 * delta
	player.move_and_slide()
	var target := _target()
	prompt_label.text = "" if target == "" else "[E]  " + _label(target)
	if Input.is_action_just_pressed("interact") and target != "":
		_interact(target)

func _target() -> String:
	var best := ""
	var best_distance := 2.25
	var forward := -camera.global_basis.z
	for id in ["Lamp", "Shoes", "Phone", "PhotoNacre", "Keys", "UrbexGear", "FrontDoor"]:
		var n := get_node_or_null(id)
		if n == null or not n.visible:
			continue
		var offset: Vector3 = n.global_position - camera.global_position
		var d := offset.length()
		if d < best_distance and d > 0.001 and forward.dot(offset.normalized()) > 0.38:
			best_distance = d
			best = id
	return best

func _label(id: String) -> String:
	match id:
		"Lamp": return "Regarder la vieille lampe"
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
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	await tw.finished
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
