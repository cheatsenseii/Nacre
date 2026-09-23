extends Node3D
# Fixed puzzle structure is separate from the editable decoration.
var game: Node3D
var stations: Array[Vector3] = []
var lamps: Array[OmniLight3D] = []
var names := ["TRIANGLE — ROUGE", "LUNE — BLEUE", "SOLEIL — JAUNE"]
var order := [2, 1, 0]
var step := 0
var solved := false
var entered_next := false
var message := ""
var message_time := 0.0
var cooldown := 0.0
var gate: MeshInstance3D
var origin: Vector3
var door_z := 0.0
var opened := 0.0

func block(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = game.box(at, size, color)
	mesh.reparent(self)
	return mesh

func label(text: String, at: Vector3, font_size: int = 55) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = font_size
	node.pixel_size = 0.004
	node.position = at
	node.modulate = Color(0.8, 0.88, 0.74)
	add_child(node)

func _ready() -> void:
	game = get_parent()
	origin = game.atmosphere.mushroom_position
	door_z = origin.z - 11
	disable_old_wall()
	var stone := Color(0.17, 0.19, 0.21)
	for x in [-8.25, 8.25]:
		block(Vector3(origin.x+x, origin.y+4, door_z), Vector3(12.5, 8, 0.5), stone)
	block(Vector3(origin.x, origin.y+6.25, door_z), Vector3(4, 3.5, 0.5), stone)
	gate = block(Vector3(origin.x, origin.y+2.25, door_z), Vector3(3.95, 4.5, 0.35), Color(0.25, 0.31, 0.28))
	label("PASSAGE SCELLÉ", Vector3(origin.x, origin.y+4.9, door_z+0.31), 64)
	# An actual second room, with continuous floor and bounded walls.
	var next := Vector3(origin.x, origin.y, door_z-15)
	block(next+Vector3(0, -0.25, 0), Vector3(23, 0.5, 30), Color(0.21, 0.23, 0.24))
	block(next+Vector3(0, 6.2, 0), Vector3(23, 0.4, 30), stone)
	for x in [-11.5, 11.5]:
		block(next+Vector3(x, 3, 0), Vector3(0.4, 6, 30), stone)
	for x in [-6.75, 6.75]:
		block(next+Vector3(x, 3, -15), Vector3(9.5, 6, 0.4), stone)
	block(next+Vector3(0, 5.3, -15), Vector3(4, 1.4, 0.4), stone)
	label("CHAMBRE 02\nLE SILENCE", next+Vector3(-6.75, 3.4, -14.7), 95)
	for z in [-4.0, 3.0]:
		var light := OmniLight3D.new()
		light.position = next+Vector3(0, 4.5, z)
		light.light_color = Color(0.44, 0.64, 0.8)
		light.light_energy = 2
		light.omni_range = 10
		add_child(light)
		block(next+Vector3(0, 5.8, z), Vector3(3, 0.12, 0.3), Color(0.65, 0.75, 0.8))

func disable_old_wall() -> void:
	# Preserve old decor IDs/saves while replacing this one structural wall.
	var wall: MeshInstance3D = game.atmosphere.chamber_back
	wall.hide()
	for child in wall.get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
			child.collision_mask = 0

func interact() -> void:
	pass

func update(delta: float) -> void:
	disable_old_wall()
	if game.paused or game.editor.active:return
	if solved:
		opened=minf(opened+delta/2,1)
		gate.position.y=origin.y+2.25+opened*4.6
		if game.player.position.z<door_z-2 and absf(game.player.position.x-origin.x)<10:
			if not entered_next:game.voice.say("victoire")
			entered_next=true
