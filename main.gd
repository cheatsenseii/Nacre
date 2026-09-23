extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var torch: SpotLight3D
var hud: Label
var prompt: Label
var veil: ColorRect
var finished := false
var paused := false
var sliding := false
var progress := 0.0
var elapsed := 0.0
var ceiling_light: OmniLight3D
const RADIUS := 2.7
var slide_duration := 22.0
var editor: Node
var atmosphere: Node3D
var arrived := false
var puzzle: Node3D
var voice: Node
var actions: Node
var controls: Node
var third_person: Node3D
var experience: Node
var simon: Node3D
var health := 100
var front_end: Node
var inventory: Node
var feeding: Node3D
var checkpoints: Node
var scares: Node3D
var combat: Node3D
var labyrinth: Node3D
var cycle: Node3D
var top_npc: Node
var torture: Node3D
var horrors: Node3D
var audio_mix: Node
var silence: Node3D
var death: Node
var post_fx: ColorRect
var post_material: ShaderMaterial
var post_tension := 0.0
var post_decay := 0.25

func _ready() -> void:
	configure_audio_mix()
	configure_controls()
	build_room()
	atmosphere = preload("res://atmosphere.gd").new()
	add_child(atmosphere)
	build_player()
	build_hud()
	editor = preload("res://editor.gd").new()
	add_child(editor)
	puzzle = preload("res://puzzle.gd").new()
	add_child(puzzle)
	var art = preload("res://art.gd").new()
	add_child(art)
	voice = preload("res://character_voice.gd").new()
	add_child(voice)
	actions = preload("res://player_actions.gd").new()
	add_child(actions)
	controls = preload("res://controls_menu.gd").new()
	add_child(controls)
	cycle = preload("res://spore_cycle.gd").new()
	add_child(cycle)
	var exploration = preload("res://exploration.gd").new()
	add_child(exploration)
	labyrinth = preload("res://labyrinth.gd").new()
	add_child(labyrinth)
	combat = preload("res://combat.gd").new()
	add_child(combat)
	simon=preload("res://simon.gd").new();add_child(simon)
	inventory = preload("res://inventory.gd").new()
	add_child(inventory)
	feeding = preload("res://feeding.gd").new()
	add_child(feeding)
	scares = preload("res://horror_events.gd").new()
	add_child(scares)
	checkpoints = preload("res://checkpoints.gd").new()
	add_child(checkpoints)
	var typography = preload("res://typography.gd").new()
	add_child(typography)
	front_end = preload("res://front_end.gd").new()
	add_child(front_end)
	var polish=preload("res://polish.gd").new()
	add_child(polish)
	third_person=preload("res://third_person.gd").new()
	add_child(third_person)
	var appearance=preload("res://appearance.gd").new();appearance.name="Appearance";add_child(appearance)
	experience=preload("res://experience.gd").new();experience.name="Experience";add_child(experience)
	var foley=preload("res://foley.gd").new();foley.name="Foley";add_child(foley)
	var inspection=preload("res://inspection.gd").new();inspection.name="Inspection";add_child(inspection)
	var realism=preload("res://realism.gd").new();realism.name="Realism";add_child(realism)
	var runner=preload("res://bouptilop.gd").new();runner.name="Bouptilop";add_child(runner)
	top_npc=preload("res://top_npc.gd").new();top_npc.name="Veilleur_du_toboggan";add_child(top_npc)
	torture=preload("res://torture.gd").new();torture.name="Salle_de_torture";add_child(torture)
	horrors=preload("res://horreurs.gd").new();horrors.name="Salle_des_horreurs";add_child(horrors)
	silence=preload("res://silence.gd").new();silence.name="Chambre_du_silence";add_child(silence)
	death=preload("res://player_death.gd").new();death.name="Mort_du_personnage";add_child(death)
	audio_mix=preload("res://audio_mix.gd").new();audio_mix.name="AudioMix";add_child(audio_mix)
	call_deferred("warmup_visuals")

func configure_audio_mix() -> void:
	# Keep simultaneous scares and voice lines clear without clipping the master.
	var master:=AudioServer.get_bus_index("Master")
	if master<0:return
	for i in range(AudioServer.get_bus_effect_count(master)-1,-1,-1):
		if AudioServer.get_bus_effect(master,i) is AudioEffectLimiter:return
	var limiter:=AudioEffectLimiter.new();limiter.ceiling_db=-0.8;limiter.threshold_db=-1.2;limiter.soft_clip_ratio=0.82
	AudioServer.add_bus_effect(master,limiter)

func configure_controls() -> void:
	var bindings := {
		"forward": [KEY_Z, KEY_W, KEY_UP],
		"back": [KEY_S, KEY_DOWN],
		"left": [KEY_Q, KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_CTRL],
		"jump": [KEY_SPACE],
		"crouch": [KEY_SHIFT],
		"torch": [KEY_F],
		"interact": [KEY_E],
		"restart": [KEY_R],
		"music": [KEY_M],
		"voice_toggle": [KEY_V]
	}
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

	if not InputMap.has_action("push"): InputMap.add_action("push")
	InputMap.action_erase_events("push")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("push",mouse)
	if not InputMap.has_action("parry"): InputMap.add_action("parry")
	InputMap.action_erase_events("parry")
	var guard := InputEventMouseButton.new()
	guard.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("parry",guard)

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

func box(at: Vector3, size: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = at
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

# The bend starts immediately: the whole slide and its exit stay hidden.
func slide_center(t: float) -> Vector3:
	return Vector3(18.0 * (1.0 - cos(t * 3.0)), 2.7 - 48.0 * (3.0 * t * t - 2.0 * t * t * t), -4.0 - 80.0 * t)

func slide_frame(t: float) -> Basis:
	var tangent := (slide_center(t + 0.001) - slide_center(t)).normalized()
	var side := tangent.cross(Vector3.UP).normalized()
	var up := side.cross(tangent).normalized()
	return Basis(side, up, -tangent)

func tube() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	const STEPS := 180
	const SIDES := 56
	for i in range(STEPS + 1):
		var t := float(i) / STEPS
		var center := slide_center(t)
		var frame := slide_frame(t)
		for j in range(SIDES + 1):
			var angle := TAU * j / SIDES
			var radial := frame.x * cos(angle) + frame.y * sin(angle)
			vertices.append(center + radial * RADIUS)
			normals.append(-radial)
			var color := Color(0.17, 0.31, 0.29)
			if i % 9 == 0:
				color = Color(0.065, 0.11, 0.105)
			colors.append(color)
	for i in range(STEPS):
		for j in range(SIDES):
			var a := i * (SIDES + 1) + j
			var b := a + SIDES + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var skin := material(Color.WHITE)
	skin.vertex_color_use_as_albedo = true
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.roughness = 0.48
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = skin
	add_child(instance)
	instance.create_trimesh_collision()

func sign_text(text: String, at: Vector3, size: int, color: Color) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = size
	sign.pixel_size = 0.004
	sign.position = at
	sign.modulate = color
	add_child(sign)

func build_room() -> void:
	var world := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color(0.003, 0.007, 0.009)
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color(0.20, 0.30, 0.33)
	atmosphere.ambient_light_energy = 0.045
	world.environment = atmosphere
	add_child(world)
	# Closed departure chamber: no viewpoint reveals the exterior tube.
	box(Vector3(0, -0.2, 0.5), Vector3(12, 0.4, 9), Color(0.22, 0.25, 0.25))
	box(Vector3(0, 7.1, 0.5), Vector3(12, 0.2, 9), Color(0.12, 0.16, 0.17))
	for x in [-6.0, 6.0]:
		box(Vector3(x, 3.5, 0.5), Vector3(0.3, 7, 9), Color(0.20, 0.25, 0.25))
	box(Vector3(0, 3.5, 5), Vector3(12, 7, 0.3), Color(0.17, 0.21, 0.22))
	# Radial concrete panels surround the circular mouth without filling it.
	for i in range(64):
		var angle := TAU * i / 64.0
		var radius := 6.6
		var panel := box(Vector3(cos(angle) * radius, 2.7 + sin(angle) * radius, -4.25), Vector3(8.0, 0.72, 0.5), Color(0.23, 0.28, 0.28))
		panel.rotation.z = angle
	# Thick orange rim, scaled to dwarf a person.
	var lip := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 2.68
	ring.outer_radius = 3.02
	ring.rings = 64
	ring.ring_segments = 16
	lip.mesh = ring
	lip.material_override = material(Color(0.68, 0.31, 0.09))
	lip.rotation.x = PI / 2.0
	lip.position = Vector3(0, 2.7, -3.92)
	add_child(lip)
	# Queue rails and floor markings make the mouth feel gigantic.
	for x in [-3.4, 3.4]:
		for z in [-2.7, -0.7, 1.3, 3.3]:
			box(Vector3(x, 0.55, z), Vector3(0.09, 1.1, 0.09), Color(0.36, 0.40, 0.4))
		box(Vector3(x, 1.08, 0.3), Vector3(0.10, 0.10, 6.1), Color(0.42, 0.45, 0.44))
	for x in [-2.6, 2.6]:
		box(Vector3(x, 0.007, 0.4), Vector3(0.09, 0.012, 7.5), Color(0.64, 0.48, 0.15), false)
	for i in range(12):
		box(Vector3(-2.7 + i * 0.49, 0.012, -2.9), Vector3(0.23, 0.015, 0.35), Color(0.65, 0.46, 0.12), false)
	sign_text("DESCENTE 01", Vector3(0, 6.2, -3.82), 110, Color(0.75, 0.82, 0.77))
	sign_text("UN SEUL DEPART. AUCUNE VISIBILITE.", Vector3(0, 5.7, -3.82), 38, Color(0.72, 0.54, 0.25))
	ceiling_light = OmniLight3D.new()
	ceiling_light.position = Vector3(0, 5.5, -1.4)
	ceiling_light.light_color = Color(0.59, 0.78, 0.79)
	ceiling_light.omni_range = 9.0
	ceiling_light.light_energy = 1.4
	ceiling_light.shadow_enabled = true
	add_child(ceiling_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(0, 2.9, -2.5)
	rim_light.light_color = Color(0.95, 0.47, 0.16)
	rim_light.light_energy = 0.65
	rim_light.omni_range = 4.4
	add_child(rim_light)
	tube()

func build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.05, 1.8)
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	player.floor_snap_length = 0.28
	player.floor_max_angle = deg_to_rad(48.0)
	player.floor_stop_on_slope = true
	player.safe_margin = 0.035
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.current = true
	camera.fov = 78
	camera.rotation.x = 0.07
	player.add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.14, -0.12, -0.1)
	torch.light_color = Color(1, 0.91, 0.75)
	torch.light_energy = 4.0
	torch.spot_range = 12
	torch.spot_angle = 29
	torch.spot_attenuation = 0.65
	torch.shadow_enabled = true
	camera.add_child(torch)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# A very light full-screen pass adds depth and horror atmosphere while keeping
	# the scene readable on the Compatibility renderer.  It is drawn before the
	# fade veil and HUD so menus and scripted fades remain crisp.
	post_fx = ColorRect.new()
	post_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_fx.color = Color.WHITE
	post_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_fx.z_index = -10
	post_material = ShaderMaterial.new()
	post_material.shader = preload("res://post_process.gdshader")
	post_fx.material = post_material
	layer.add_child(post_fx)
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	hud = Label.new()
	hud.position = Vector2(26, 23)
	hud.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(26, 627)
	prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(prompt)

func pulse_post_fx(strength: float, duration: float = 0.22) -> void:
	post_tension = maxf(post_tension, clampf(strength, 0.0, 1.0))
	post_decay = maxf(post_decay, duration)
	if post_material != null:
		post_material.set_shader_parameter("tension", post_tension)

func warmup_visuals() -> void:
	# Let the first frame present the title and controls before refreshing the
	# expensive light budget.  The actual rooms are already available for tests
	# and inspection mode; only optional visual work is staged here.
	await get_tree().process_frame
	var lighting: Node = null
	for child in get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://polish.gd":
			lighting = child
			break
	if lighting != null and lighting.has_method("update_light_budget"):
		lighting.update_light_budget()
	await get_tree().process_frame
	if third_person != null and third_person.has_method("reset_after_teleport"):
		third_person.reset_after_teleport(player.position)

func teleport_player(destination: Vector3, reset_camera: bool = true) -> void:
	if player == null:
		return
	player.position = destination
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	if reset_camera and camera != null:
		camera.reset_physics_interpolation()
		if third_person != null and third_person.has_method("reset_after_teleport"):
			third_person.reset_after_teleport(destination)

func _process(delta: float) -> void:
	if post_material == null:
		return
	if post_tension > 0.0:
		post_tension = move_toward(post_tension, 0.0, delta / maxf(post_decay, 0.001))
	post_material.set_shader_parameter("tension", post_tension)

func near_entrance() -> bool:
	return not arrived and absf(player.position.x) < 2.2 and player.position.z < -1.8

func _unhandled_input(event: InputEvent) -> void:
	if death!=null and death.active:return
	if front_end!=null and front_end.active:return
	if controls != null and controls.is_open: return
	if editor != null and editor.active:
		return
	if event.is_action_pressed("ui_cancel"):
		paused = not paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and not finished:
		var was_paused := paused
		paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if was_paused: return
	if event.is_action_pressed("restart"):
		# Reload from the saved scene; keep unsaved edits during an ordinary restart.
		if editor != null and editor.dirty:
			editor.toggle()
			editor.status.text = "Sauvegarde tes modifications avant de recommencer."
			return
		get_tree().reload_current_scene()
	if paused or finished:
		return
	if event is InputEventMouseMotion:
		if sliding:
			camera.rotation.y = clampf(camera.rotation.y - event.relative.x * 0.0025, -0.8, 0.8)
		else:
			player.rotate_y(-event.relative.x * 0.0025)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0025, -1.2, 1.2)
	if event.is_action_pressed("push"):
		if not feeding.attack() and not combat.begin_charge(): actions.shove()
	if event.is_action_released("push"):
		combat.release_charge()
	if event.is_action_pressed("music"):
		atmosphere.toggle_music()
	if event.is_action_pressed("torch"):
		if horrors!=null and horrors.torch_locked:
			horrors.notify_torch()
		else:
			torch.visible = not torch.visible
	if event.is_action_pressed("interact") and arrived:
		if not silence.interact() and not torture.interact() and not simon.interact() and not feeding.interact() and not combat.interact() and not labyrinth.interact(): puzzle.interact()
	if event.is_action_pressed("interact") and not arrived and not sliding:
		if top_npc!=null and top_npc.near_player():
			if top_npc.interact():return
	if event.is_action_pressed("interact") and near_entrance() and not sliding:
		start_slide()

func start_slide() -> void:
	voice.say("depart")
	sliding = true
	progress = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	camera.position.y = 0.8
	camera.rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if death!=null and death.active:return
	if front_end!=null and front_end.active:return
	if health<=0 and not paused and not editor.active:
		death.begin("danger");return
	if not sliding and not paused and not editor.active:
		var minimum_y: float=atmosphere.mushroom_position.y-8 if arrived else -12
		if player.position.y<minimum_y:
			death.begin("chute");return
	cycle.advance(delta)
	if editor != null and editor.active:
		return
	elapsed += delta
	ceiling_light.light_energy = 1.4 + 0.04 * sin(elapsed * 5.0)
	if not paused and not finished:
		if sliding:
			progress = minf(progress + delta / slide_duration, 1.0)
			var t := progress * progress
			var frame := slide_frame(t)
			player.position = slide_center(t) - frame.y * 1.85
			player.basis = frame
			camera.fov = lerpf(78.0, 91.0, progress)
			if progress >= 1.0:
				land_in_chamber()
		else:
			actions.update_stance(delta)
			var axis := Input.get_vector("left", "right", "forward", "back")
			var direction := player.transform.basis * Vector3(axis.x, 0, axis.y)
			var speed := 1.3 if actions.crouched else (4.6 if Input.is_action_pressed("sprint") else 2.6)
			speed *= cycle.movement_factor
			experience.move_player(delta,direction,speed)
			if not arrived and player.position.z < -4.05:
				start_slide()
	hud.text = "DERNIÈRE PORTE
La descente

Tu ne vois que l'entrée."
	prompt.text = "ZQSD : avancer • Espace : saut • Maj : accroupi • Ctrl : courir • Clic gauche : pousser
F : lampe • Échap : pause • R : point de reprise • F2 : éditeur • M : musique • F1 : touches"
	if finished:
		hud.text = "LA DESCENTE CONTINUE…

		Fin de cet aperçu.
		R pour reprendre au dernier point."
		if torture.completed:hud.text="LE SILENCE DE BOUPTILOP\n\nFin de cet aperçu.\nR pour reprendre au dernier point."
		if horrors!=null and horrors.completed:hud.text="SALLE DES HORREURS\n\nTu as vu ce qui restait des Boptilop.\nR pour reprendre au dernier point."
		prompt.text = ""
	elif paused:
		prompt.text = "PAUSE — Clique pour reprendre."
	elif sliding:
		hud.text = ""
		prompt.text = "F : lampe • Souris : regarder • Échap : pause • R : point de reprise"
	elif top_npc!=null and top_npc.near_player():
		prompt.text=top_npc.prompt_text()
	elif near_entrance():
		prompt.text = "E — S'engager dans le toboggan
Tu ne distingues pas le fond."

	if arrived and not paused:
		hud.text = "CHAMBRE 01\nQuelque chose pousse ici."
		if player.position.distance_to(atmosphere.mushroom_position) < 3.5:
			prompt.text = "Il semble respirer…\nF : lampe • M : musique • F2 : éditeur • R : point de reprise"

	puzzle.update(delta)
	silence.update(delta)
	cycle.decorate()
	labyrinth.update(delta)
	combat.update(delta)
	if death.active:return
	feeding.update(delta)
	if death.active:return
	simon.update(delta)
	horrors.update(delta)
	scares.update(delta)
	checkpoints.observe()
	controls.update_hints()
	if finished:
		hud.text="SALLE DES HORREURS\n\nFin de cet aperçu.\nR pour reprendre au dernier point."
		prompt.text=""

func land_in_chamber() -> void:
	# A scripted landing (inspection, test scene or a resumed run) must always
	# release the title screen before handing control to the player.
	if front_end!=null and front_end.active:
		front_end.launch()
	actions.reset_stance()
	voice.say("arrivee")
	sliding = false
	arrived = true
	var end := slide_center(1.0)
	teleport_player(Vector3(end.x, end.y - RADIUS + 0.05, end.z - 1.2))
	player.rotation = Vector3.ZERO
	camera.position = Vector3(0, 1.62, 0)
	camera.rotation = Vector3.ZERO
	camera.fov = 78
	veil.color.a = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func interaction_origin() -> Vector3:
	return player.to_global(Vector3(0,0.85 if actions.crouched else 1.35,0))
