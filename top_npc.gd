extends Node3D

# Mascotte NACRE installée à l'entrée : même famille visuelle que Bouptilop,
# mais présence plus calme et ambiguë. Elle ne livre jamais une vérité définitive sur le parc.
var game: Node3D
var mascot: Node3D
var cap: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var dialogue: Label
var dialogue_time := 0.0
var clock := 0.0
var talked := false
var voice: AudioStreamPlayer3D
var ambience: AudioStreamPlayer3D
var halo: MeshInstance3D
var spotlight: SpotLight3D

func mesh_part(parent: Node3D, mesh: Mesh, at: Vector3, scale_value: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = scale_value
	node.rotation = rot
	node.material_override = mat
	parent.add_child(node)
	return node

func _ready() -> void:
	game = get_parent()
	position = Vector3(2.85, 0.05, 1.75)
	rotation.y = PI
	build_mascot()
	build_stage()
	build_dialogue()
	voice = AudioStreamPlayer3D.new()
	voice.stream = preload("res://audio/bouptilop.wav")
	voice.volume_db = -12
	voice.unit_size = 4
	voice.max_distance = 13
	add_child(voice)
	ambience = AudioStreamPlayer3D.new()
	var water: AudioStreamOggVorbis = preload("res://audio/ambiance_eau.ogg").duplicate()
	water.loop = true
	ambience.stream = water
	ambience.volume_db = -31
	ambience.unit_size = 5.5
	ambience.max_distance = 10
	ambience.set_meta("nacre_ambience",true)
	add_child(ambience)

func build_mascot() -> void:
	var source: Node = game.get_node_or_null("Bouptilop")
	if source != null and source.get("model") != null:
		mascot = source.model.duplicate()
	else:
		mascot = Node3D.new()
		var fallback := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		fallback.mesh = sphere
		fallback.position = Vector3(0, 0.55, 0)
		fallback.scale = Vector3(0.45, 0.6, 0.42)
		fallback.material_override = game.material(Color("b9aa82"))
		mascot.add_child(fallback)
	add_child(mascot)
	mascot.name = "Mascotte_NACRE"
	mascot.scale = Vector3.ONE * 1.30
	cap = mascot.get_node_or_null("Cap") as Node3D
	for i in range(2):
		var arm := mascot.get_node_or_null("Arm_%d" % i) as Node3D
		var leg := mascot.get_node_or_null("Leg_%d" % i) as Node3D
		if arm != null: arms.append(arm)
		if leg != null: legs.append(leg)
	var badge := mesh_part(mascot, BoxMesh.new(), Vector3(0, 0.47, 0.2), Vector3(0.34, 0.16, 0.025), game.atmosphere.luminous(Color("4b8f8a"), 0.28))
	badge.name = "Ecusson_NACRE"
	var badge_text := Label3D.new()
	badge_text.name = "Marque_NACRE"
	badge_text.text = "NACRE"
	badge_text.font_size = 22
	badge_text.pixel_size = 0.0026
	badge_text.position = Vector3(0, 0.47, 0.222)
	badge_text.modulate = Color("d3ddcc")
	mascot.add_child(badge_text)

func build_stage() -> void:
	var base := CylinderMesh.new()
	base.top_radius = 0.88
	base.bottom_radius = 0.98
	base.height = 0.10
	base.radial_segments = 40
	mesh_part(self, base, Vector3(0, 0.03, 0), Vector3(1, 1, 0.78), game.material(Color("182829")))
	var base_ring := TorusMesh.new()
	base_ring.inner_radius = 0.79
	base_ring.outer_radius = 0.84
	base_ring.rings = 40
	base_ring.ring_segments = 8
	halo = mesh_part(self, base_ring, Vector3(0, 0.095, 0), Vector3(1, 1, 0.78), game.atmosphere.luminous(Color("4c8c88"), 0.68))
	var crown := TorusMesh.new()
	crown.inner_radius = 0.59
	crown.outer_radius = 0.615
	crown.rings = 32
	crown.ring_segments = 8
	var crown_mesh := mesh_part(self, crown, Vector3(0, 2.33, 0), Vector3(1, 0.68, 1), game.atmosphere.luminous(Color("a77d4c"), 0.38))
	crown_mesh.rotation.x = PI / 2.0
	spotlight = SpotLight3D.new()
	spotlight.position = Vector3(0, 3.1, 0.15)
	spotlight.rotation_degrees = Vector3(-90, 0, 0)
	spotlight.light_color = Color("779d98")
	spotlight.light_energy = 1.15
	spotlight.spot_range = 5.5
	spotlight.spot_angle = 48
	spotlight.shadow_enabled = true
	add_child(spotlight)
	spotlight.add_to_group("nacre_dynamic_light")
	spotlight.set_meta("nacre_light_priority", 2)

func build_dialogue() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	dialogue = Label.new()
	dialogue.position = Vector2(120, 500)
	dialogue.size = Vector2(1040, 110)
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_override("font", preload("res://fonts/Signaletique.ttf"))
	dialogue.add_theme_font_size_override("font_size", 21)
	dialogue.add_theme_color_override("font_color", Color("e0e7cd"))
	dialogue.add_theme_color_override("font_outline_color", Color("050708"))
	dialogue.add_theme_constant_override("outline_size", 7)
	dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue.hide()
	layer.add_child(dialogue)

func near_player() -> bool:
	return game != null and not game.arrived and not game.sliding and global_position.distance_to(game.player.global_position) < 3.5

func prompt_text() -> String:
	return game.controls.key("interact") + " — Observer la mascotte"

func interact() -> bool:
	if not near_player() or game.paused or game.editor.active:return false
	if dialogue_time > 0:return true
	if not talked:
		dialogue.text = "LA MASCOTTE NACRE : « Tu es revenu… Enfin, je crois.\nLe toboggan est toujours ouvert. Lui aussi, il attend. »"
		talked = true
	else:
		dialogue.text = "LA MASCOTTE NACRE : « Écoute bien.\nIci, le silence fait parfois plus de bruit que l'eau. »"
	dialogue_time = 7.0
	if voice != null and not voice.playing:voice.play()
	return true

func _process(delta: float) -> void:
	if game == null or mascot == null:return
	var menu_active: bool = game.front_end != null and game.front_end.active
	visible = not menu_active and not game.arrived and not game.sliding
	if ambience != null:
		ambience.stream_paused = game.paused or game.editor.active
		if visible and not ambience.playing:ambience.play()
	if visible and not game.paused and not game.editor.active:
		clock += delta
		mascot.position.y = 0.035 + sin(clock * 2.0) * 0.018
		mascot.rotation.z = sin(clock * 0.9) * 0.012
		if cap != null:cap.rotation.z = sin(clock * 1.4) * 0.026
		for i in range(arms.size()):arms[i].rotation.z = sin(clock * 1.5 + i * PI) * 0.08
		for i in range(legs.size()):legs[i].rotation.x = sin(clock * 1.5 + i * PI) * 0.05
		halo.rotation.y = fmod(clock * 0.22, TAU)
	else:
		if ambience != null:ambience.stop()
	if dialogue_time > 0 and not game.paused and not game.editor.active:
		dialogue_time = maxf(0.0, dialogue_time - delta)
	dialogue.visible = visible and dialogue_time > 0 and not game.paused and not game.editor.active
