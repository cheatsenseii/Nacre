extends "res://billy_home.gd"
## Stability layer for the polished Billy house.
## Keeps the decorated base scene while hardening replay, interactions and transition flow.

const SAFE_START := Vector3(-0.72, 1.25, 1.10)

func begin() -> void:
	if story == null:
		push_warning("[NACRE] Maison Billy: BillyPrologue introuvable")
		return
	if not built:
		_build_home()
		_build_ui()
		built = true
		_validate_home()
	if player == null or camera == null:
		push_warning("[NACRE] Maison Billy: contrôleur ou caméra manquant")
		return
	_reset_home_state()
	story.begin()
	interacted.clear()
	thought_time = 0.0
	interaction_lock = 0.0
	show()
	_set_canvas_visible(true)
	enabled = true
	player.position = SAFE_START
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_ui()
	_show_thought(story.current_thought)

func _reset_home_state() -> void:
	for id in ["Keys", "UrbexGear", "BagPocket"]:
		var node := get_node_or_null(id)
		if node != null:
			node.show()
	lamp_on = true
	tv_on = false
	computer_on = true
	if lamp_light != null:
		lamp_light.visible = true
	if lamp_shade != null and lamp_shade.material_override is StandardMaterial3D:
		var lamp_material := lamp_shade.material_override as StandardMaterial3D
		lamp_material.emission_energy_multiplier = 0.45
	if tv_screen != null and tv_screen.material_override is StandardMaterial3D:
		var tv_material := tv_screen.material_override as StandardMaterial3D
		tv_material.albedo_color = Color("101617")
		tv_material.emission = Color("101617")
		tv_material.emission_energy_multiplier = 0.01
	if computer_screen != null and computer_screen.material_override is StandardMaterial3D:
		var pc_material := computer_screen.material_override as StandardMaterial3D
		pc_material.emission_energy_multiplier = 0.22
	if fade != null:
		fade.color.a = 0.0
	if thought_label != null:
		thought_label.text = ""
	if prompt_label != null:
		prompt_label.text = ""

func _set_canvas_visible(value: bool) -> void:
	for child in get_children():
		if child is CanvasLayer:
			child.visible = value

func _validate_home() -> void:
	var missing: Array[String] = []
	for id in INTERACTABLES:
		if get_node_or_null(id) == null:
			missing.append(id)
	if get_node_or_null("BagPocket") == null:
		missing.append("BagPocket")
	if missing.is_empty():
		print("[NACRE] Maison Billy validée: interactions et objets présents")
	else:
		push_warning("[NACRE] Maison Billy: objets manquants: " + ", ".join(missing))

func _target() -> String:
	if camera == null:
		return ""
	var best := ""
	var best_score := 1000000.0
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

func _interact(id: String) -> void:
	# These two interactions need explicit material casts to stay safe on strict Godot builds.
	if id == "Lamp":
		lamp_on = not lamp_on
		if lamp_light != null:
			lamp_light.visible = lamp_on
		if lamp_shade != null and lamp_shade.material_override is StandardMaterial3D:
			var lamp_material := lamp_shade.material_override as StandardMaterial3D
			lamp_material.emission_energy_multiplier = 0.45 if lamp_on else 0.015
		_show_thought(_story_boredom(id, "urbex_lamp"))
		_refresh_ui()
		return
	if id == "Computer":
		computer_on = not computer_on
		if computer_screen != null and computer_screen.material_override is StandardMaterial3D:
			var pc_material := computer_screen.material_override as StandardMaterial3D
			pc_material.emission_energy_multiplier = 0.22 if computer_on else 0.01
		_show_thought(_story_boredom(id, "computer"))
		_refresh_ui()
		return
	super._interact(id)

func _leave() -> void:
	# Keep the house alive but dormant instead of queue_free(). This lets a second
	# New Game in the same session replay the prologue correctly.
	enabled = false
	if is_instance_valid(prompt_label):
		prompt_label.text = ""
	if is_instance_valid(objective_label):
		objective_label.text = ""
	_show_thought("Allez Billy. Une vraie sortie. Ça changera.", 8.0)
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.9)
	await tween.finished
	if not is_inside_tree():
		return
	story.finish_drive()
	thought_label.text = "Quelques kilomètres plus tard…"
	await get_tree().create_timer(1.35).timeout
	if not is_inside_tree():
		return
	story.confirm_arrival()
	thought_label.text = "NACRE. Toujours là."
	await get_tree().create_timer(1.05).timeout
	if not is_inside_tree():
		return
	var game := get_parent()
	if game != null and game.front_end != null and game.front_end.has_method("finish_billy_prologue"):
		game.front_end.finish_billy_prologue()
	hide()
	_set_canvas_visible(false)
