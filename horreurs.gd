extends Node3D
## Five seconds of darkness, one reveal, then a half-second apparition.
## Timers advance only in update(); presentation also runs while menus are open.
const BLACKOUT_DURATION := 5.0
const FLICKER_DURATION := 4.2
const SHADOW_DURATION := 0.5
const ROOM_DEPTH := 30.0

var game: Node3D
var origin: Vector3
var unlocked := false
var started := false
var revealed := false
var completed := false
var shadow_spawned := false
var torch_locked := false
var phase := "locked"
var timer := 0.0
var flicker_clock := 0.0
var explore_clock := 0.0
var shadow_time := 0.0
var fear_time := 0.0
var fear_weight := 0.0
var message := ""
var message_time := 0.0
var was_inside := false
var old_torch_visible := true
var old_torch_energy := 3.5
var torch_click_wait := 0.0
var gate: MeshInstance3D
var lamps: Array[Light3D] = []
var lamp_glass: Array[StandardMaterial3D] = []
var lamp_energy: Array[float] = []
var bodies: Array[Node3D] = []
var shadow: Node3D
var shadow_eyes: Array[MeshInstance3D] = []
var shadow_view: SubViewport
var shadow_camera: Camera3D
var shadow_layer: CanvasLayer
var dark_overlay: ColorRect
var flash_overlay: ColorRect
var overlay_layer: CanvasLayer
var hum: AudioStreamPlayer
var flash_sound: AudioStreamPlayer
var shadow_sound: AudioStreamPlayer
var torch_click: AudioStreamPlayer

func block(at: Vector3, size: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var node: MeshInstance3D = game.box(origin + at, size, color, solid)
	node.reparent(self)
	return node

func _ready() -> void:
	game = get_parent()
	process_priority = 30
	origin = game.torture.origin + Vector3(0, 0, -34)
	build_room()
	build_lamps()
	build_bodies()
	build_shadow()
	build_audio()
	build_overlay()
	restore(false, false, false)

func build_room() -> void:
	var stone := Color("273c39")
	var details: Node = game.get_node("Realism")
	var floor := block(Vector3(0, -0.25, -15), Vector3(22, 0.5, ROOM_DEPTH), stone)
	floor.material_override = details.art.surface(Color("465b53"), origin.y, true)
	block(Vector3(0, 5.8, -15), Vector3(22, 0.4, ROOM_DEPTH), Color("152422"))
	for side in [-1, 1]:
		var wall := block(Vector3(side * 11, 2.8, -15), Vector3(0.4, 5.6, ROOM_DEPTH), stone)
		wall.material_override = details.art.surface(Color("405b51"), origin.y, true)
		block(Vector3(side * 10.74, 1.25, -15), Vector3(0.08, 0.2, 29), Color("805640"), false)
		block(Vector3(side * 7.0, 2.8, 0), Vector3(8, 5.6, 0.4), stone)
		block(Vector3(side * 7.0, 2.8, -30), Vector3(8, 5.6, 0.4), stone)
		# A continuous, enclosed exit passage prevents falls after the gate opens.
		block(Vector3(side * 3.0, 2.0, -33.5), Vector3(0.3, 4, 7), stone)
	block(Vector3(0, 5, -30), Vector3(6, 2, 0.4), stone)
	block(Vector3(0, -0.25, -33.5), Vector3(6, 0.5, 7), stone)
	block(Vector3(0, 4, -33.5), Vector3(6, 0.3, 7), stone)
	block(Vector3(0, 2, -37), Vector3(6, 4, 0.4), stone)
	gate = block(Vector3(0, 2, -30), Vector3(5.8, 4, 0.35), Color("394844"))
	gate.name = "Porte_finale_des_horreurs"
	game.puzzle.label("07 / SALLE DES HORREURS", origin + Vector3(0, 4.9, -0.35), 36)
	# Drainage, supports and pipework keep the abandoned-pool identity.
	for x in [-8.6, 8.6]:
		block(Vector3(x, 0.015, -15), Vector3(0.35, 0.025, 28), Color("14201e"), false)
		for z in range(1, 30):
			block(Vector3(x, 0.031, -z), Vector3(0.4, 0.012, 0.045), Color("4e5e52"), false)
	for z in [-4.0, -12.0, -20.0, -28.0]:
		block(Vector3(0, 5.35, z), Vector3(21.6, 0.32, 0.28), Color("4e4739"), false)
	details.architecture(origin, 10.65, -28.4, -0.6, 5.4, 4)
	details.flush_batches()

func build_lamps() -> void:
	for i in range(4):
		var spot := SpotLight3D.new()
		spot.position = origin + Vector3(-2.8 if i % 2 == 0 else 2.8, 5.0, -4.0 - i * 7.3)
		spot.rotation.x = -PI / 2
		spot.light_color = Color("bdcfb6") if i % 2 == 0 else Color("e0b294")
		spot.light_energy = 4.0
		spot.spot_range = 15
		spot.spot_angle = 66
		spot.spot_attenuation = 0.45
		spot.shadow_bias = 0.04
		# Scripted fixtures are excluded from the general distance-light budget.
		spot.set_meta("horror_light", true)
		add_child(spot)
		lamps.append(spot)
		lamp_energy.append(spot.light_energy)
		block(spot.position - origin + Vector3(0, 0.09, 0), Vector3(1.4, 0.18, 0.4), Color("253733"), false)
		var glass := block(spot.position - origin, Vector3(1.18, 0.04, 0.28), Color("a6bca5"), false)
		var material: StandardMaterial3D = game.atmosphere.luminous(spot.light_color, 1.8)
		glass.material_override = material
		lamp_glass.append(material)
	var exit_light := OmniLight3D.new()
	exit_light.position = origin + Vector3(0, 2.8, -33)
	exit_light.light_color = Color("ae5949")
	exit_light.light_energy = 1.4
	exit_light.omni_range = 7
	exit_light.set_meta("horror_light", true)
	add_child(exit_light)
	lamps.append(exit_light)
	lamp_energy.append(exit_light.light_energy)

func append_remains(node: Node3D, transform: Transform3D, surface: SurfaceTool, pose: int) -> void:
	# Bake the existing mascot into four shared, low-cost static poses. Preserve
	# cap/skin/eye colour contrast, remove emission, and leave navigation clear.
	for child in node.get_children():
		if not child is Node3D:
			continue
		var local: Transform3D = child.transform
		if String(child.name).begins_with("Arm_"):
			local.basis = Basis.from_euler(Vector3(0.3 * pose, 0, -0.7 if String(child.name).ends_with("0") else 0.85))
		elif String(child.name).begins_with("Leg_"):
			local.basis = Basis.from_euler(Vector3(0.12 * pose, 0, -0.28 if String(child.name).ends_with("0") else 0.4))
		var at := transform * local
		if child is MeshInstance3D and child.mesh != null:
			var mesh: Mesh = child.mesh
			if mesh is SphereMesh:
				mesh = mesh.duplicate()
				mesh.radial_segments = 16
				mesh.rings = 8
			var color := Color("bbb597")
			if child.material_override is StandardMaterial3D:
				color = child.material_override.albedo_color
			var gray := (color.r + color.g + color.b) / 3.0
			color = color.lerp(Color(gray, gray * 1.02, gray * 0.95), 0.35)
			color = Color(color.r * 0.77, color.g * 0.78, color.b * 0.75, 1)
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var normal_basis := at.basis.inverse().transposed()
			for index in indices:
				surface.set_color(color)
				surface.set_normal((normal_basis * normals[index]).normalized())
				surface.add_vertex(at * vertices[index])
		append_remains(child, at, surface, pose)

func build_bodies() -> void:
	var poses: Array[ArrayMesh] = []
	var dead := StandardMaterial3D.new()
	dead.vertex_color_use_as_albedo = true
	dead.roughness = 0.88
	for pose in range(4):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rotation := Vector3(PI * 0.5, 0, 0.25 * pose - 0.3)
		if pose == 3:
			rotation = Vector3(0.45, 0, -1.45)
		append_remains(game.get_node("Bouptilop").model, Transform3D(Basis.from_euler(rotation), Vector3.ZERO), surface, pose)
		surface.index()
		poses.append(surface.commit())
	var positions := [Vector2(-2.0,-4.6), Vector2(3.2,-5.3), Vector2(-6.8,-6.4), Vector2(7.0,-8.5), Vector2(-3.1,-9.3), Vector2(1.4,-11.2), Vector2(-7.3,-12.6), Vector2(5.0,-14.4), Vector2(-4.6,-16.2), Vector2(7.2,-18.3), Vector2(-1.8,-18.8), Vector2(-7.0,-21.4), Vector2(3.4,-23.0), Vector2(-2.5,-25.2), Vector2(7.4,-27.0)]
	for i in range(positions.size()):
		var corpse := Node3D.new()
		corpse.name = "Goptilop_mort_%02d" % (i + 1)
		corpse.position = origin + Vector3(positions[i].x, 0.025, positions[i].y)
		corpse.rotation.y = i * 1.73
		add_child(corpse)
		var visual := MeshInstance3D.new()
		visual.mesh = poses[i % 4]
		visual.material_override = dead
		var size := 1.3 + float(i % 3) * 0.1
		visual.scale = Vector3.ONE * size
		visual.position.y = -visual.mesh.get_aabb().position.y * size
		corpse.add_child(visual)
		var pool := CylinderMesh.new()
		pool.top_radius = 0.72
		pool.bottom_radius = 0.72
		pool.height = 0.008
		pool.radial_segments = 20
		game.atmosphere.form(corpse, pool, Vector3.ZERO, Vector3(1.3, 1, 0.65), game.material(Color("221a19")))
		bodies.append(corpse)

func build_shadow() -> void:
	# A small isolated 3D pass keeps proper depth/lighting within the face while
	# allowing the half-second apparition to remain visible beside a room wall.
	shadow_view=SubViewport.new();shadow_view.own_world_3d=true;shadow_view.transparent_bg=true
	shadow_view.size=Vector2i(1280,720);shadow_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(shadow_view)
	shadow_camera=Camera3D.new();shadow_camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	shadow_view.add_child(shadow_camera);shadow_camera.current=true
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("a3b4bf");environment.ambient_light_energy=0.4
	shadow_camera.environment=environment
	for spec in [[Vector3(-1.5,1.5,0),Color("e0cebd"),2.2],[Vector3(1.5,1,-3),Color("719eaa"),2.7]]:
		var lamp:=OmniLight3D.new();lamp.position=spec[0];lamp.light_color=spec[1];lamp.light_energy=spec[2];lamp.omni_range=7
		shadow_camera.add_child(lamp)
	shadow = preload("res://shadow_actor.gd").new()
	shadow.name = "Ombre_sursaut_des_horreurs"
	shadow_view.add_child(shadow)
	shadow.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	shadow.build();shadow_eyes.assign(shadow.eyes)
	shadow_layer=CanvasLayer.new();shadow_layer.layer=17;add_child(shadow_layer)
	var display:=TextureRect.new();display.texture=shadow_view.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shadow_layer.add_child(display);shadow_layer.hide()
	shadow.hide()

func sound(stream: AudioStream, volume: float, pitch: float = 1.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	add_child(player)
	return player

func build_audio() -> void:
	hum = sound(preload("res://audio/respiration_spores.wav"), -26, 0.55)
	flash_sound = sound(preload("res://audio/choc_metal.wav"), -16, 0.7)
	shadow_sound = sound(preload("res://audio/horreurs_sursaut.wav"), -8)
	torch_click = sound(preload("res://audio/horreurs_interrupteur.wav"), -16)

func build_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 18
	add_child(overlay_layer)
	for i in range(2):
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = Color(0, 0, 0, 0) if i == 0 else Color(0.91, 0.97, 0.9, 0)
		overlay_layer.add_child(rect)
		if i == 0: dark_overlay = rect
		else: flash_overlay = rect

func inside() -> bool:
	var p: Vector3 = game.player.position - origin
	var in_room := p.z <= 0.0 and p.z >= -ROOM_DEPTH and absf(p.x) < 10.85
	var in_exit := p.z < -ROOM_DEPTH and p.z > -37.0 and absf(p.x) < 2.9
	return game.arrived and absf(p.y) < 5.8 and (in_room or in_exit)

func frozen() -> bool:
	return game.paused or game.editor.active or game.front_end.active or game.finished

func intense() -> bool:
	return started and inside() and not frozen() and phase in ["blackout", "flicker"]

func unlock() -> void:
	unlocked = true

func tell(text: String, duration: float = 3.0) -> void:
	message = text
	message_time = duration

func goal() -> String:
	if not unlocked: return "La porte de la torture est encore verrouillée."
	if phase == "blackout": return "La lampe ne répond plus…"
	if phase == "flicker": return "…"
	if completed: return "Passe la porte du fond."
	return "Rejoins la porte du fond." if revealed else "Entre dans la salle."

func lock_torch() -> void:
	if not torch_locked:
		old_torch_visible = game.torch.visible
		old_torch_energy = game.torch.light_energy
		torch_locked = true
	game.torch.visible = false
	game.torch.light_energy = 0

func unlock_torch() -> void:
	if not torch_locked: return
	torch_locked = false
	game.torch.visible = old_torch_visible
	game.torch.light_energy = old_torch_energy

func notify_torch() -> void:
	if torch_locked and torch_click_wait <= 0:
		torch_click.play()
		torch_click_wait = 0.35

func set_lamps(on: bool, strength: float = 1.0) -> void:
	var quality: int = game.get_node("Realism").polish.quality
	for i in range(lamps.size()):
		lamps[i].visible = on
		lamps[i].light_energy = lamp_energy[i] * strength if on else 0.0
		lamps[i].shadow_enabled = on and quality > 0 and i < mini(quality, 2)
	for glass in lamp_glass:
		glass.emission_energy_multiplier = 1.8 * strength if on else 0

func show_bodies(value: bool) -> void:
	for body in bodies: body.visible = value

func begin_sequence() -> void:
	started = true
	phase = "blackout"
	timer = BLACKOUT_DURATION
	flicker_clock = 0
	shadow_spawned = false
	shadow_time = 0
	fear_time = 0
	# Stop queued quest narration so nothing announces the reveal in advance.
	game.voice.stop_all()
	game.voice.subtitle.hide()
	hum.play()
	torch_click.play()
	sync_presentation()

func reveal_scene() -> void:
	if revealed: return
	revealed = true
	flash_sound.play()
	spawn_shadow()

func spawn_shadow() -> void:
	if shadow_spawned: return
	shadow_spawned = true
	shadow_time = SHADOW_DURATION
	fear_time = 2.2
	shadow_sound.play()
	game.third_person.shake(0.10, 0.25)
	game.pulse_post_fx(0.7, 0.28)

func end_sequence() -> void:
	phase = "explore"
	shadow_time = 0
	hum.stop()
	tell("Non… Qu'est-ce qui leur est arrivé ?", 3.0)
	game.voice.say("horror_quest")
	sync_presentation()

func lamps_on() -> bool:
	if game.torture.lighting_settings.stable_lighting: return true
	# The first flash lasts long enough to see the full half-second apparition.
	# Irregular, separated outages then suggest faulty relays, not a steady strobe.
	var t := flicker_clock
	return t < 0.6 or (t >= 0.9 and t < 1.1) or (t >= 1.7 and t < 2.25) or (t >= 3.1 and t < 3.35) or t >= 3.8

func sync_presentation() -> void:
	if dark_overlay == null: return
	var active := inside()
	var playing := active and not frozen()
	var inspecting: bool = game.editor.active and active and not game.front_end.active
	dark_overlay.color.a = 0
	flash_overlay.color.a = 0
	shadow.visible = playing and shadow_time > 0
	shadow_layer.visible=shadow.visible
	shadow_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if shadow.visible else SubViewport.UPDATE_DISABLED
	if shadow.visible:
		var viewport_size:=get_viewport().get_visible_rect().size
		shadow_view.size=Vector2i(roundi(720.0*viewport_size.x/maxf(viewport_size.y,1)),720)
		shadow_view.msaa_3d=get_viewport().msaa_3d
		shadow_camera.global_transform=game.camera.global_transform;shadow_camera.fov=game.camera.fov
		shadow.global_transform=game.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0.08,-2.22,-1.65))
	fear_weight = clampf(fear_time / 2.2, 0, 1) if playing else 0.0
	show_bodies(revealed or inspecting)
	for player in [hum, flash_sound, shadow_sound, torch_click]: player.stream_paused = not playing
	if intense(): lock_torch()
	else: unlock_torch()
	if inspecting:
		set_lamps(true, 0.8)
	elif not playing:
		set_lamps(false)
	elif phase == "blackout":
		set_lamps(false)
		dark_overlay.color.a = 1
	elif phase == "flicker":
		var on := lamps_on()
		set_lamps(on, 1.2)
		dark_overlay.color.a = 0.0 if on else 0.97
		var stable: bool = game.torture.lighting_settings.stable_lighting
		flash_overlay.color.a = 0.0 if stable else maxf(0, 0.18 * (1.0 - flicker_clock / 0.12))
	elif phase == "explore":
		var strength := 0.72 if game.torture.lighting_settings.stable_lighting else 0.72 + sin(explore_clock * 0.7) * 0.035
		set_lamps(true, strength)
	else:
		set_lamps(false)

func update(delta: float) -> void:
	if inside() and game.torture.completed: unlock()
	if not inside() or frozen() or not unlocked:
		sync_presentation()
		return
	was_inside = true
	if not started: begin_sequence()
	message_time = maxf(0, message_time - delta)
	torch_click_wait = maxf(0, torch_click_wait - delta)
	fear_time = maxf(0, fear_time - delta)
	if phase == "blackout":
		timer -= delta
		if timer <= 0:
			phase = "flicker"
			flicker_clock = -timer
			timer = 0
			reveal_scene()
	elif phase == "flicker":
		flicker_clock += delta
	if phase == "flicker":
		shadow_time = maxf(0, SHADOW_DURATION - flicker_clock)
		if shadow_time>0:shadow.animate(delta,0)
		if flicker_clock >= FLICKER_DURATION: end_sequence()
	elif phase == "explore":
		explore_clock += delta
		if game.player.position.z < origin.z - 27.5 and not completed:
			completed = true
			flash_sound.play()
			tell("Le verrou a cédé. Sors d'ici.", 4)
	if completed:
		gate.position.y = move_toward(gate.position.y, origin.y + 6.4, delta * 3.0)
		if game.player.position.z < origin.z - 33.0:
			game.finished = true
	game.hud.text = "CHAMBRE 07 — SALLE DES HORREURS"
	game.prompt.text = message if message_time > 0 else goal()
	sync_presentation()

func _process(_delta: float) -> void:
	# Main physics skips the editor and title screen. Always clear their blackout.
	sync_presentation()

func restore(was_started: bool, was_revealed: bool, was_completed: bool) -> void:
	unlock_torch()
	started = was_started or was_revealed or was_completed
	revealed = was_revealed or was_completed
	completed = was_completed
	shadow_spawned = revealed
	phase = "explore" if revealed else ("blackout" if started else "locked")
	timer = BLACKOUT_DURATION if started and not revealed else 0.0
	flicker_clock = 0
	explore_clock = 0
	shadow_time = 0
	fear_time = 0
	fear_weight = 0
	was_inside = false
	message = ""
	message_time = 0
	torch_click_wait = 0
	shadow.hide()
	dark_overlay.color.a = 0
	flash_overlay.color.a = 0
	gate.position.y = origin.y + (6.4 if completed else 2.0)
	show_bodies(revealed)
	set_lamps(false)
	for player in [hum, flash_sound, shadow_sound, torch_click]: player.stop()
