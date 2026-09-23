extends Node
## Vérifications runtime légères : évite les recherches coûteuses répétées et
## expose un diagnostic clair dans la console Godot.

var game: Node
var scan_timer := 0.0
var last_state := ""

func _ready() -> void:
	game = get_parent()
	process_priority = 100
	call_deferred("_validate_runtime")

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	scan_timer += delta
	if scan_timer < 1.0:
		return
	scan_timer = 0.0
	_validate_runtime()

func _validate_runtime() -> void:
	if game == null:
		return
	var missing: Array[String] = []
	for property_name in ["player", "camera", "torch", "atmosphere", "front_end", "checkpoints"]:
		if game.get(property_name) == null:
			missing.append(property_name)
	var state := "OK" if missing.is_empty() else "MISSING:" + ",".join(missing)
	if state != last_state:
		last_state = state
		if state == "OK":
			print("[NACRE] Runtime validé — scène prête")
		else:
			push_warning("[NACRE] Références manquantes : " + ", ".join(missing))
