extends Node
# In-game scene editor. Base geometry IDs follow deterministic creation order.
const SAVE_PATH := "user://decor_editeur.json"
var game: Node3D
var active := false
var fly := false
var view: Camera3D
var layer: CanvasLayer
var panel: PanelContainer
var items := {}
var selected := ""
var next_id := 0
var list: ItemList
var fields: Array[SpinBox] = []
var status: Label
var refreshing := false
var history: Array = []
var dirty := false
var saved_paused := false
var selector: MeshInstance3D
var duration: SpinBox

func _ready() -> void:
	game = get_parent()
	var index := 0
	for child in game.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var id := "base_%03d" % index
			var center: Vector3 = game.atmosphere.mushroom_position
			var offset: float = child.position.x-center.x
			if child.position.y < -20 and (is_equal_approx(absf(offset),13.5) or is_equal_approx(absf(offset),8.55)):
				var old: Vector3 = child.position
				old.x = center.x + signf(offset)*(8.5 if absf(offset)>10 else 6.05)
				child.set_meta("legacy_position",old)
				child.set_meta("expanded_position",child.position)
			child.set_meta("editor_id", id)
			items[id] = {"node": child, "kind": "base", "deleted": false}
			index += 1
	view = Camera3D.new()
	view.fov = 78
	game.add_child(view)
	var light := OmniLight3D.new()
	light.omni_range = 28
	light.light_energy = 2.5
	view.add_child(light)
	light.visible = false
	selector = MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	selector.mesh = cube
	var tint := StandardMaterial3D.new()
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(0.2, 0.85, 1, 0.22)
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selector.material_override = tint
	selector.visible = false
	game.add_child(selector)
	build_ui()
	if FileAccess.file_exists(SAVE_PATH):
		load_scene(false)

func button(parent: Node, title: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = title
	b.pressed.connect(callback)
	parent.add_child(b)

func build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(944, 10)
	panel.size = Vector2(326, 700)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(326, 700)
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 300
	scroll.add_child(col)
	var title := Label.new()
	title.text = "ÉDITEUR — F2 pour jouer"
	title.add_theme_font_size_override("font_size", 21)
	col.add_child(title)
	var help := Label.new()
	help.text = "Clic : sélectionner un objet\nClic droit maintenu : regarder + voler\nZQSD : voler • E / C : haut / bas\nMaj : accélérer • Suppr : supprimer"
	col.add_child(help)
	var row := HBoxContainer.new()
	col.add_child(row)
	button(row, "+ Cube", func(): add_object("cube"))
	button(row, "+ Mur", func(): add_object("wall"))
	button(row, "+ Lumière", func(): add_object("light"))
	list = ItemList.new()
	list.custom_minimum_size = Vector2(295, 110)
	list.item_selected.connect(func(i: int): select_item(str(list.get_item_metadata(i))))
	col.add_child(list)
	var labels := ["Position X", "Position Y", "Position Z", "Rotation X °", "Rotation Y °", "Rotation Z °", "Taille X", "Taille Y", "Taille Z"]
	for i in range(9):
		var line := HBoxContainer.new()
		col.add_child(line)
		var label := Label.new()
		label.text = labels[i]
		label.custom_minimum_size.x = 125
		line.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0.05 if i >= 6 else -1000.0
		spin.max_value = 100.0 if i >= 6 else 1000.0
		spin.step = 0.1 if i < 3 or i >= 6 else 5.0
		spin.custom_minimum_size.x = 150
		spin.value_changed.connect(func(_v: float): change_transform())
		line.add_child(spin)
		fields.append(spin)
	row = HBoxContainer.new()
	col.add_child(row)
	button(row, "Dupliquer", duplicate_item)
	button(row, "Supprimer", delete_item)
	button(row, "Annuler", undo)
	var duration_label := Label.new()
	duration_label.text = "Durée de la descente (secondes)"
	col.add_child(duration_label)
	duration = SpinBox.new()
	duration.min_value = 5
	duration.max_value = 120
	duration.value = game.slide_duration
	duration.value_changed.connect(func(value: float):
		if not refreshing:
			remember()
			game.slide_duration = value
			dirty = true
	)
	col.add_child(duration)
	row = HBoxContainer.new()
	col.add_child(row)
	button(row, "Sauvegarder", save_scene)
	button(row, "Recharger", func(): load_scene(true))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 295
	status.text = "Décor et lumières modifiables.\nLe tracé du toboggan reste fixe."
	col.add_child(status)
	button(col, "Retour au jeu (F2)", toggle)
	panel.hide()
	refresh_list()

func toggle() -> void:
	active = not active
	panel.visible = active
	fly = false
	if active:
		saved_paused = game.paused
		game.paused = true
		view.global_transform = game.camera.global_transform
		view.make_current()
		view.get_child(0).visible = true
		game.veil.hide()
		game.hud.hide()
		game.prompt.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		game.camera.make_current()
		view.get_child(0).visible = false
		game.paused = saved_paused
		game.veil.show()
		game.hud.show()
		game.prompt.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.paused or game.finished else Input.MOUSE_MODE_CAPTURED
	selector.visible = active and not selected.is_empty()

func _input(event: InputEvent) -> void:
	if game.front_end!=null and game.front_end.active:return
	if game.controls != null and game.controls.is_open: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		fly = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if fly else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and fly:
		view.rotation.y -= event.relative.x * 0.0025
		view.rotation.x = clampf(view.rotation.x - event.relative.y * 0.0025, -1.5, 1.5)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if game.front_end!=null and game.front_end.active:return
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var origin := view.project_ray_origin(event.position)
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + view.project_ray_normal(event.position) * 250)
		var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			var node: Node = hit.collider
			while node != null and not node.has_meta("editor_id"):
				node = node.get_parent()
			if node != null:
				select_item(str(node.get_meta("editor_id")))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			delete_item()
		elif event.ctrl_pressed and event.keycode == KEY_S:
			save_scene()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	if fly:
		var axis := Input.get_vector("left", "right", "forward", "back")
		var move := view.basis * Vector3(axis.x, 0, axis.y)
		# Space and C also avoid ambiguity on AZERTY/QWERTY keyboards.
		move.y += float(Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE))
		move.y -= float(Input.is_physical_key_pressed(KEY_C))
		view.position += move.normalized() * delta * (18.0 if Input.is_key_pressed(KEY_SHIFT) else 6.0)
	if not selected.is_empty() and items.has(selected):
		var node: Node3D = items[selected].node
		selector.global_transform = node.global_transform
		if node is MeshInstance3D:
			var bounds: AABB = node.mesh.get_aabb()
			selector.scale *= bounds.size + Vector3.ONE * 0.06
		else:
			selector.scale = Vector3.ONE * 0.4

func refresh_list() -> void:
	list.clear()
	for id in items:
		if items[id].deleted:
			continue
		list.add_item(str(id) + " — " + str(items[id].kind))
		list.set_item_metadata(list.item_count - 1, id)
		if id == selected:
			list.select(list.item_count - 1)

func select_item(id: String) -> void:
	selected = id
	selector.visible = active and not id.is_empty()
	if id.is_empty():
		return
	var node: Node3D = items[id].node
	refreshing = true
	for i in range(3):
		fields[i].value = node.position[i]
		fields[i + 3].value = node.rotation_degrees[i]
		fields[i + 6].value = node.scale[i]
	refreshing = false
	refresh_list()

func change_transform() -> void:
	if refreshing or selected.is_empty():
		return
	remember()
	var node: Node3D = items[selected].node
	node.position = Vector3(fields[0].value, fields[1].value, fields[2].value)
	node.rotation_degrees = Vector3(fields[3].value, fields[4].value, fields[5].value)
	node.scale = Vector3(fields[6].value, fields[7].value, fields[8].value)
	dirty = true
	status.text = "Modification appliquée — pense à sauvegarder."

func spawn(id: String, kind: String) -> Node3D:
	var node: Node3D
	if kind == "light":
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1, 0.65, 0.3)
		lamp.light_energy = 2.0
		lamp.omni_range = 8
		game.add_child(lamp)
		node = lamp
	else:
		var size := Vector3(3, 2.5, 0.3) if kind == "wall" else Vector3.ONE
		node = game.box(Vector3.ZERO, size, Color(0.42, 0.32, 0.22))
	node.set_meta("editor_id", id)
	items[id] = {"node": node, "kind": kind, "deleted": false}
	return node

func add_object(kind: String) -> void:
	if items.size() >= 950:
		status.text = "Limite de 950 objets atteinte."
		return
	remember()
	var id := "objet_%04d" % next_id
	next_id += 1
	var node := spawn(id, kind)
	node.position = view.position - view.basis.z * 4.0
	dirty = true
	select_item(id)

func duplicate_item() -> void:
	if selected.is_empty() or items.size() >= 950: return
	remember()
	var original: Node3D = items[selected].node
	var kind: String = items[selected].kind
	var id := "objet_%04d" % next_id
	next_id += 1
	# Base boxes are converted to unit cubes preserving their actual dimensions.
	var copy := spawn(id, "cube" if kind == "base" else kind)
	copy.transform = original.transform
	if kind == "base":
		copy.scale *= original.mesh.size
		copy.scale = copy.scale.clamp(Vector3.ONE * 0.05, Vector3.ONE * 100.0)
	copy.position.x += 1.0
	dirty = true
	select_item(id)

func set_deleted(id: String, value: bool) -> void:
	items[id].deleted = value
	var node: Node3D = items[id].node
	node.visible = not value
	for child in node.get_children():
		if child is StaticBody3D:
			child.collision_layer = 0 if value else 1
			child.collision_mask = 0 if value else 1

func delete_item() -> void:
	if selected.is_empty(): return
	remember()
	set_deleted(selected, true)
	selected = ""
	selector.hide()
	dirty = true
	refresh_list()

func v_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func snapshot() -> Dictionary:
	var rows := []
	for id in items:
		var obj: Node3D = items[id].node
		rows.append({"id": id, "kind": items[id].kind, "deleted": items[id].deleted, "position": v_array(obj.position), "rotation": v_array(obj.rotation_degrees), "scale": v_array(obj.scale)})
	return {"version": 1, "next_id": next_id, "duration": game.slide_duration, "objects": rows}

func remember() -> void:
	history.append(snapshot())
	if history.size() > 40: history.pop_front()

func valid_data(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("version") != 1 or not data.get("objects") is Array: return false
	if data.objects.size() > 1000: return false
	if not (data.get("duration") is float or data.get("duration") is int): return false
	if not is_finite(float(data.duration)) or float(data.duration) < 5 or float(data.duration) > 120: return false
	var ids := {}
	for row in data.objects:
		if not row is Dictionary: return false
		if not row.get("id") is String or not row.get("deleted") is bool: return false
		if ids.has(row.id): return false
		ids[row.id] = true
		if not row.get("kind") in ["base", "cube", "wall", "light"]: return false
		if row.kind == "base" and (not items.has(row.id) or items[row.id].kind != "base"): return false
		if row.kind != "base" and not row.id.begins_with("objet_"): return false
		for key in ["position", "rotation", "scale"]:
			if not row.get(key) is Array or row[key].size() != 3: return false
			for v in row[key]:
				if not (v is float or v is int): return false
				if not is_finite(float(v)) or absf(float(v)) > 1000: return false
				if key == "scale" and (float(v) < 0.05 or float(v) > 100): return false
	return true

func apply_snapshot(data: Dictionary) -> void:
	# Clear additions, then recreate them. Existing base objects retain identity.
	for id in items.keys():
		if items[id].kind != "base":
			var node: Node = items[id].node
			node.get_parent().remove_child(node)
			node.queue_free()
			items.erase(id)
	next_id = 0
	for row in data.objects:
		if row.kind != "base":
			spawn(row.id, row.kind)
			next_id = maxi(next_id, int(str(row.id).trim_prefix("objet_")) + 1)
		var node: Node3D = items[row.id].node
		node.position = Vector3(row.position[0], row.position[1], row.position[2])
		if node.has_meta("legacy_position") and node.position.is_equal_approx(node.get_meta("legacy_position")):
			node.position = node.get_meta("expanded_position")
		node.rotation_degrees = Vector3(row.rotation[0], row.rotation[1], row.rotation[2])
		node.scale = Vector3(row.scale[0], row.scale[1], row.scale[2])
		set_deleted(row.id, row.deleted)
	game.slide_duration = float(data.duration)
	refreshing = true
	duration.value = game.slide_duration
	refreshing = false
	selected = ""
	selector.hide()
	refresh_list()

func undo() -> void:
	if history.is_empty(): return
	apply_snapshot(history.pop_back())
	dirty = true
	status.text = "Dernière modification annulée."

func save_scene() -> void:
	var temp := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		status.text = "Échec de la sauvegarde : écriture impossible."
		return
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		status.text = "Échec de la sauvegarde : données non écrites."
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	var renamed := DirAccess.rename_absolute(temp, SAVE_PATH)
	if renamed != OK:
		status.text = "Échec de la sauvegarde : remplacement impossible."
		return
	dirty = false
	status.text = "Décor sauvegardé ! Il sera chargé au prochain lancement."

func load_scene(with_undo: bool) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		status.text = "Aucune sauvegarde pour le moment."
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 2000000:
		status.text = "Sauvegarde illisible. Décor actuel conservé."
		return
	var data = JSON.parse_string(file.get_as_text())
	if not valid_data(data):
		status.text = "Sauvegarde invalide. Décor actuel conservé."
		return
	if with_undo: remember()
	apply_snapshot(data)
	dirty = false
	status.text = "Décor rechargé."
