extends Node3D

# Mascotte NACRE installée à l'entrée : elle remplace le veilleur triste,
# avec le même modèle que les apparitions de Bouptilop pour garder une vraie
# identité visuelle dans tout le parc.
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
	# Décalée vers la rambarde pour être lisible sans bloquer la ligne du toboggan.
	position = Vector3(2.85, 0.05, 1.75)
	rotation.y = PI
	build_mascot()
	build_stage()
	build_dialogue()
	voice = AudioStreamPlayer3D.new()
	voice.stream = preload("res://audio/bouptilop.wav")
	voice.volume_db = -10
	voice.unit_size = 5
	voice.max_distance = 16
	add_child(voice)
	ambience = AudioStreamPlayer3D.new()
	ambience.stream = preload("res://audio/respiration_spores.wav")
	ambience.volume_db = -25
	ambience.unit_size = 3.5
	ambience.max_distance = 8
	add_child(ambience)

func build_mascot() -> void:
	var source: Node = game.get_node_or_null("Bouptilop")
	if source != null and source.get("model") != null:
		mascot = source.model.duplicate()
	else:
		# Secours uniquement pour les scènes de test qui instancient ce script seul.
		mascot = Node3D.new()
		var fallback := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		fallback.mesh = sphere
		fallback.position = Vector3(0, 0.55, 0)
		fallback.scale = Vector3(0.45, 0.6, 0.42)
		fallback.material_override = game.material(Color("d1c59a"))
		mascot.add_child(fallback)
	add_child(mascot)
	mascot.name = "Mascotte_NACRE"
	mascot.scale = Vector3.ONE * 1.30
	cap = mascot.get_node_or_null("Cap") as Node3D
	for i in range(2):
		var arm := mascot.get_node_or_null("Arm_%d" % i) as Node3D
		var leg := mascot.get_node_or_null("Leg_%d" % i) as Node3D
		if arm != null:
			arms.append(arm)
		if leg != null:
			legs.append(leg)
	# Une petite plaque cousue rend la mascotte identifiable de dos comme de face.
	var badge := mesh_part(mascot, BoxMesh.new(), Vector3(0, 0.47, 0.2), Vector3(0.34, 0.16, 0.025), game.atmosphere.luminous(Color("63cfc2"), 0.55))
	badge.name = "Ecusson_NACRE"
	var badge_text := Label3D.new()
	badge_text.name = "Marque_NACRE"
	badge_text.text = "NACRE"
	badge_text.font_size = 22
	badge_text.pixel_size = 0.0026
	badge_text.position = Vector3(0, 0.47, 0.222)
	badge_text.modulate = Color("e6f4dd")
	mascot.add_child(badge_text)

func build_stage() -> void:
	# Socle humide, halo et éclairage en trois couleurs : la mascotte ressort
	# sans transformer l'entrée en sapin de Noël sous acide.
	var base := CylinderMesh.new()
	base.top_radius = 0.88
	base.bottom_radius = 0.98
	base.height = 0.10
	base.radial_segments = 40
	mesh_part(self, base, Vector3(0, 0.03, 0), Vector3(1, 1, 0.78), game.material(Color("1b3032")))
	var base_ring := TorusMesh.new()
	base_ring.inner_radius = 0.79
	base_ring.outer_radius = 0.84
	base_ring.rings = 40
	base_ring.ring_segments = 8
	halo = mesh_part(self, base_ring, Vector3(0, 0.095, 0), Vector3(1, 1, 0.78), game.atmosphere.luminous(Color("65ccc7"), 1.35))
	var crown := TorusMesh.new()
	crown.inner_radius = 0.59
	crown.outer_radius = 0.615
	crown.rings = 32
	crown.ring_segments = 8
	var crown_mesh := mesh_part(self, crown, Vector3(0, 2.33, 0), Vector3(1, 0.68, 1), game.atmosphere.luminous(Color("e1a85f"), 0.8))
	crown_mesh.rotation.x = PI / 2.0
	spotlight = SpotLight3D.new()
	spotlight.position = Vector3(0, 3.1, 0.15)
	spotlight.rotation_degrees = Vector3(-90, 0, 0)
	spotlight.light_color = Color("79d8d0")
	spotlight.light_energy = 1.7
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
	dialogue.add_theme_color_override("font_color", Color("e6f1d2"))
	dialogue.add_theme_color_override("font_outline_color", Color("050708"))
	dialogue.add_theme_constant_override("outline_size", 7)
	dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue.hide()
	layer.add_child(dialogue)

func near_player() -> bool:
	return game != null and not game.arrived and not game.sliding and global_position.distance_to(game.player.global_position) < 3.5

func prompt_text() -> String:
	return game.controls.key("interact") + " — Parler à la mascotte"

func interact() -> bool:
	if not near_player() or game.paused or game.editor.active:
		return false
	if dialogue_time > 0:
		return true
	talked = true
	dialogue.text = "LA MASCOTTE NACRE : « J'ai attendu la fermeture… puis le retour de quelqu'un.\nPersonne n'est jamais remonté de ce toboggan. »"
	dialogue_time = 8.0
	if voice != null:
		voice.play()
	return true

func _process(delta: float) -> void:
	if game == null or mascot == null:
		return
	var menu_active: bool = game.front_end != null and game.front_end.active
	visible = not menu_active and not game.arrived and not game.sliding
	if ambience != null:
		ambience.stream_paused = game.paused or game.editor.active
	if visible and not game.paused and not game.editor.active:
		clock += delta
		mascot.position.y = 0.035 + sin(clock * 2.2) * 0.025
		mascot.rotation.z = sin(clock * 1.1) * 0.018
		if cap != null:
			cap.rotation.z = sin(clock * 1.7) * 0.035
		for i in range(arms.size()):
			arms[i].rotation.z = sin(clock * 1.8 + i * PI) * 0.12
		for i in range(legs.size()):
			legs[i].rotation.x = sin(clock * 1.8 + i * PI) * 0.08
		halo.rotation.y = fmod(clock * 0.35, TAU)
	else:
		if ambience != null:
			ambience.stop()
	if dialogue_time > 0 and not game.paused and not game.editor.active:
		dialogue_time = maxf(0.0, dialogue_time - delta)
	dialogue.visible = visible and dialogue_time > 0 and not game.paused and not game.editor.active
