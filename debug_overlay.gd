extends CanvasLayer
## Overlay de diagnostic et finition visuelle pour le prototype Nacre.
## F3 affiche les informations techniques sans modifier le gameplay.

var game: Node
var debug_panel: Panel
var debug_text: Label
var crosshair: Label
var status_text: Label
var visible_debug := false
var elapsed := 0.0
var last_fps := 0.0

const FONT = preload("res://fonts/Interface.ttf")

func _ready() -> void:
	game = get_parent()
	layer = 120
	_build_cinematic_details()
	_build_debug_panel()
	set_process(true)
	call_deferred("_refresh_debug")

func _build_cinematic_details() -> void:
	# Un viseur très discret améliore la lisibilité des interactions sans casser l'ambiance.
	crosshair = Label.new()
	crosshair.text = "·"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-14, -18)
	crosshair.size = Vector2(28, 36)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_theme_font_override("font", FONT)
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color(0.76, 0.93, 0.88, 0.72))
	crosshair.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.1, 0.9))
	crosshair.add_theme_constant_override("shadow_offset_x", 1)
	crosshair.add_theme_constant_override("shadow_offset_y", 1)
	add_child(crosshair)

	# Barres cinéma : elles donnent une silhouette plus maîtrisée aux écrans larges.
	for anchor in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var bar := ColorRect.new()
		bar.color = Color(0.005, 0.009, 0.012, 0.72)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(anchor)
		bar.custom_minimum_size.y = 18.0
		if anchor == Control.PRESET_BOTTOM_WIDE:
			bar.position.y = -18.0
		add_child(bar)

	status_text = Label.new()
	status_text.position = Vector2(28, 88)
	status_text.add_theme_font_override("font", FONT)
	status_text.add_theme_font_size_override("font_size", 14)
	status_text.add_theme_color_override("font_color", Color(0.48, 0.82, 0.76, 0.82))
	status_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	status_text.add_theme_constant_override("shadow_offset_x", 2)
	status_text.add_theme_constant_override("shadow_offset_y", 2)
	status_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_text.text = "NACRE  /  DERNIÈRE PORTE"
	add_child(status_text)

func _build_debug_panel() -> void:
	debug_panel = Panel.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(24, 118)
	debug_panel.size = Vector2(430, 230)
	debug_panel.visible = false
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.043, 0.93)
	style.border_color = Color(0.24, 0.72, 0.68, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_top = 12
	debug_panel.add_theme_stylebox_override("panel", style)
	add_child(debug_panel)

	debug_text = Label.new()
	debug_text.size = Vector2(398, 204)
	debug_text.add_theme_font_override("font", FONT)
	debug_text.add_theme_font_size_override("font_size", 15)
	debug_text.add_theme_color_override("font_color", Color(0.78, 0.91, 0.88))
	debug_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	debug_text.add_theme_constant_override("shadow_offset_x", 1)
	debug_text.add_theme_constant_override("shadow_offset_y", 1)
	debug_panel.add_child(debug_text)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible_debug = not visible_debug
		debug_panel.visible = visible_debug
		if visible_debug:
			_refresh_debug()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	elapsed += delta
	last_fps = Engine.get_frames_per_second()
	if status_text != null:
		# Respiration lumineuse presque imperceptible, cohérente avec l'ambiance.
		status_text.modulate.a = 0.72 + sin(elapsed * 0.8) * 0.08
	if visible_debug and fmod(elapsed, 0.15) < delta:
		_refresh_debug()

func _refresh_debug() -> void:
	if debug_text == null or game == null:
		return
	var player: Node = game.get("player")
	var position_text := "indisponible"
	if is_instance_valid(player):
		position_text = "(%7.2f, %7.2f, %7.2f)" % [player.position.x, player.position.y, player.position.z]
	var warnings: Array[String] = []
	for required in ["camera", "torch", "atmosphere", "checkpoints", "combat"]:
		if game.get(required) == null:
			warnings.append(required)
	var warning_text := "Aucune anomalie détectée"
	if not warnings.is_empty():
		warning_text = "Références manquantes : " + ", ".join(warnings)
	var scene_state := ""
	if bool(game.get("sliding")):
		scene_state = "DESCENTE"
	elif bool(game.get("arrived")):
		scene_state = "CHAMBRE"
	else:
		scene_state = "ENTRÉE"
	debug_text.text = "DIAGNOSTIC NACRE  [F3 pour fermer]\n\n" + \
		"FPS             %5.1f\n" % last_fps + \
		"ÉTAT            %s\n" % scene_state + \
		"POSITION        %s\n" % position_text + \
		"VIE             %3d / 100\n" % int(game.get("health")) + \
		"SCÈNE            %s\n\n" % str(get_tree().current_scene.name) + \
		"✓ %s" % warning_text
