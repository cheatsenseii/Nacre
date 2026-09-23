extends Node3D
## Salle 08 : retrouver une piste humaine parmi de fausses traces.
## Les Ombres et les Bouptilop ne portent pas de vêtements : les bons indices
## sont donc des objets portés par un humain.
const ROOM_DEPTH := 26.0
const SAVE_PATH := "user://investigation.cfg"

var game: Node3D
var origin := Vector3.ZERO
var built := false
var found: Array[bool] = [false, false, false]
var completed := false
var ending := false
var was_inside := false
var message := ""
var message_time := 0.0
var evidence: Array[Node3D] = []
var exit_gate: MeshInstance3D
var ui_layer: CanvasLayer
var objective: Label
var hint: Label
var end_layer: CanvasLayer

func _ready() -> void:
	game = get_parent()
	process_priority = 80
	call_deferred("setup_room")

func setup_room() -> void:
	for _i in range(24):
		await get_tree().process_frame
		if game.horrors != null and game.puzzle != null and game.front_end != null:
			break
	if game.horrors == null:
		return
	origin = game.horrors.origin + Vector3(0, 0, -37.0)
	open_old_end_wall()
	build_room()
	build_evidence()
	build_ui()
	bind_new_game_reset()
	if not FileAccess.file_exists(game.checkpoints.path):
		reset_progress()
	else:
		load_progress()
	apply_state()
	built = true

func block(at: Vector3, size: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var node: MeshInstance3D = game.box(origin + at, size, color, solid)
	node.reparent(self)
	return node

func open_old_end_wall() -> void:
	# La salle 07 se terminait volontairement sur ce mur. On le retire maintenant
	# que la suite existe, sans toucher à la porte scénarisée de la salle d'horreurs.
	var target: Vector3 = game.horrors.origin + Vector3(0, 2, -37)
	for child in game.horrors.get_children():
		if child is MeshInstance3D and child.global_position.distance_to(target) < 0.45:
			var mesh := child.mesh
			if mesh is BoxMesh and mesh.size.x > 5.5 and mesh.size.z < 0.8:
				child.queue_free()
				return

func build_room() -> void:
	var wall := Color("283533")
	var floor_color := Color("3b4743")
	var metal := Color("394542")
	block(Vector3(0, -0.25, -ROOM_DEPTH * 0.5), Vector3(18, 0.5, ROOM_DEPTH), floor_color)
	block(Vector3(0, 5.8, -ROOM_DEPTH * 0.5), Vector3(18, 0.35, ROOM_DEPTH), Color("111b1b"))
	for side in [-1, 1]:
		block(Vector3(side * 9, 2.8, -ROOM_DEPTH * 0.5), Vector3(0.35, 5.6, ROOM_DEPTH), wall)
		block(Vector3(side * 6, 2.8, 0), Vector3(6, 5.6, 0.35), wall)
		block(Vector3(side * 6, 2.8, -ROOM_DEPTH), Vector3(6, 5.6, 0.35), wall)
	# Encadrement de la sortie et petit couloir final.
	block(Vector3(0, 5.0, -ROOM_DEPTH), Vector3(6, 1.6, 0.35), wall)
	exit_gate = block(Vector3(0, 2, -ROOM_DEPTH), Vector3(5.7, 4, 0.3), metal)
	exit_gate.name = "Porte_sortie_enquete"
	for side in [-1, 1]:
		block(Vector3(side * 3, 2.0, -29.5), Vector3(0.3, 4, 7), wall)
	block(Vector3(0, -0.25, -29.5), Vector3(6, 0.5, 7), floor_color)
	block(Vector3(0, 4.0, -29.5), Vector3(6, 0.3, 7), Color("14201f"))
	block(Vector3(0, 2.0, -33.0), Vector3(6, 4, 0.35), wall)
	game.puzzle.label("08 / SALLE D’ENQUÊTE", origin + Vector3(0, 4.9, -0.3), 34)
	game.puzzle.label("RECONSTITUE LA PISTE HUMAINE", origin + Vector3(0, 4.3, -0.31), 18)
	# Tables et casiers d'un ancien local de sécurité.
	for x in [-6.7, 6.7]:
		for z in [-5.0, -11.0, -17.0, -22.0]:
			block(Vector3(x, 1.0, z), Vector3(2.5, 0.12, 0.85), Color("313a38"), false)
			block(Vector3(x - 1.0, 0.5, z), Vector3(0.09, 1.0, 0.09), Color("232a29"), false)
			block(Vector3(x + 1.0, 0.5, z), Vector3(0.09, 1.0, 0.09), Color("232a29"), false)
	for z in [-4.0, -10.5, -17.0, -23.0]:
		var lamp := OmniLight3D.new()
		lamp.position = origin + Vector3(0, 4.7, z)
		lamp.light_color = Color("c4d5cb")
		lamp.light_energy = 1.45
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		add_child(lamp)

func child_box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = game.material(color)
	visual.position = at
	parent.add_child(visual)
	return visual

func add_label(parent: Node3D, text: String, at: Vector3, size: int = 20) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.0035
	label.modulate = Color("dbe7df")
	label.outline_modulate = Color("06100f")
	label.outline_size = 6
	parent.add_child(label)
	return label

func evidence_root(at: Vector3, title: String, response: String, correct_index: int, kind: String) -> Node3D:
	var root := Node3D.new()
	root.position = origin + at
	root.set_meta("title", title)
	root.set_meta("response", response)
	root.set_meta("correct_index", correct_index)
	root.set_meta("checked", false)
	root.set_meta("kind", kind)
	add_child(root)
	evidence.append(root)
	return root

func build_evidence() -> void:
	# 1. Bon indice : tissu humain.
	var cloth := evidence_root(Vector3(-4.2, 0.055, -5.2), "morceau de sweat bleu", "Du tissu. Déchiré récemment. L'Ombre et les Bouptilop n'en portent pas.", 0, "cloth")
	var cloth_mesh := child_box(cloth, Vector3.ZERO, Vector3(1.05, 0.025, 0.48), Color("263e59"))
	cloth_mesh.rotation.y = -0.42
	child_box(cloth, Vector3(0.26, 0.018, 0.02), Vector3(0.42, 0.012, 0.025), Color("d7d7cf"))
	# Faux : spores noires.
	var spores := evidence_root(Vector3(4.8, 0.05, -6.8), "résidu noir", "Des spores et de la matière organique. Ça peut venir d'un Bouptilop. Pas une piste humaine.", -1, "spores")
	for p in [Vector3(-0.25,0,0), Vector3(0.12,0,0.14), Vector3(0.34,0,-0.1)]:
		var blob := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius=0.22; sphere.height=0.3
		blob.mesh=sphere; blob.material_override=game.material(Color("171918")); blob.position=p; spores.add_child(blob)
	# 2. Bon indice : lacet humain.
	var lace := evidence_root(Vector3(5.1, 0.055, -13.2), "lacet orange", "Un lacet de chaussure. Aucun des monstres de NACRE ne porte de chaussures. La piste continue.", 1, "lace")
	for spec in [[Vector3(-0.25,0,0),0.35],[Vector3(0.1,0,0.12),-0.6],[Vector3(0.35,0,-0.05),0.15]]:
		var seg := child_box(lace, spec[0], Vector3(0.6,0.025,0.045), Color("c76b32")); seg.rotation.y=spec[1]
	# Faux : morceau de carapace/champignon.
	var shell := evidence_root(Vector3(-5.4, 0.07, -14.9), "fragment pâle", "Ce n'est pas du tissu. C'est une excroissance sèche, probablement arrachée à une créature.", -1, "shell")
	var shell_mesh := child_box(shell, Vector3.ZERO, Vector3(0.7,0.12,0.5), Color("afa98a")); shell_mesh.rotation.y=0.7
	# Faux : éclat métallique du décor.
	var scrap := evidence_root(Vector3(2.0, 0.08, -19.0), "éclat métallique", "Rouille, peinture technique, aucune fibre. Ça vient du parc, pas d'un vêtement.", -1, "scrap")
	var scrap_mesh := child_box(scrap, Vector3.ZERO, Vector3(0.7,0.08,0.28), Color("725342")); scrap_mesh.rotation.y=-0.25
	# 3. Bon indice : tirette de fermeture marquée N.
	var zipper := evidence_root(Vector3(-3.0, 0.07, -21.5), "tirette de fermeture", "Une fermeture de vêtement. Il y a un N gravé dessus… Nathan est passé par ici.", 2, "zipper")
	child_box(zipper, Vector3.ZERO, Vector3(0.34,0.045,0.18), Color("909995"))
	child_box(zipper, Vector3(0.25,0,0), Vector3(0.24,0.035,0.05), Color("909995"))
	add_label(zipper, "N", Vector3(0,0.055,0), 18)

func build_ui() -> void:
	ui_layer = CanvasLayer.new(); ui_layer.layer = 12; add_child(ui_layer)
	var panel := Panel.new(); panel.position=Vector2(805,24); panel.size=Vector2(450,112); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.012,0.055,0.06,0.93); style.border_color=Color("456f6a"); style.set_border_width_all(1); style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel",style); ui_layer.add_child(panel)
	objective=Label.new(); objective.position=Vector2(14,10); objective.size=Vector2(420,90); objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_override("font",preload("res://fonts/Interface.ttf")); objective.add_theme_font_size_override("font_size",16); objective.add_theme_color_override("font_color",Color("d8e8df")); panel.add_child(objective)
	hint=Label.new(); hint.position=Vector2(150,592); hint.size=Vector2(980,72); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font",preload("res://fonts/Interface.ttf")); hint.add_theme_font_size_override("font_size",19); hint.add_theme_color_override("font_color",Color("e6ece5")); hint.add_theme_color_override("font_outline_color",Color.BLACK); hint.add_theme_constant_override("outline_size",6); ui_layer.add_child(hint)
	ui_layer.hide()
	end_layer=CanvasLayer.new();end_layer.layer=75;add_child(end_layer)
	var shade:=ColorRect.new();shade.color=Color(0.006,0.015,0.016,0.96);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);end_layer.add_child(shade)
	var ending_text:=Label.new();ending_text.position=Vector2(180,210);ending_text.size=Vector2(920,300);ending_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ending_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	ending_text.text="LA PISTE CONTINUE\n\nLes trois indices sont humains.\nNathan est descendu plus bas dans NACRE.\n\nR — reprendre au dernier point"
	ending_text.add_theme_font_override("font",preload("res://fonts/Signaletique.ttf"));ending_text.add_theme_font_size_override("font_size",30);ending_text.add_theme_color_override("font_color",Color("e3ebe5"));shade.add_child(ending_text)
	end_layer.hide()

func bind_new_game_reset() -> void:
	if game.front_end == null:return
	game.front_end.new_button.pressed.connect(func():
		if game.checkpoints.latest.is_empty():reset_progress()
	)
	if game.front_end.confirmation!=null:
		game.front_end.confirmation.confirmed.connect(reset_progress)

func inside() -> bool:
	if not built:return false
	var p:=game.player.position-origin
	var room:=p.z<=0.8 and p.z>=-ROOM_DEPTH and absf(p.x)<8.9
	var exit:=p.z<-ROOM_DEPTH and p.z>-33.2 and absf(p.x)<2.9
	return absf(p.y)<5.8 and (room or exit)

func nearest_evidence() -> Node3D:
	var best: Node3D=null
	var best_distance:=2.0
	for item in evidence:
		if bool(item.get_meta("checked",false)):continue
		var distance:=game.player.global_position.distance_to(item.global_position)
		if distance<best_distance:
			best=item;best_distance=distance
	return best

func found_count() -> int:
	return found.count(true)

func inspect(item: Node3D) -> void:
	item.set_meta("checked",true)
	var correct_index:=int(item.get_meta("correct_index",-1))
	message=String(item.get_meta("response",""));message_time=5.0
	if correct_index>=0 and correct_index<found.size() and not found[correct_index]:
		found[correct_index]=true
		if found_count()==3:
			completed=true
			message="Trois objets portés par un humain. Et ce N… Nathan est passé ici. La porte vient de se déverrouiller."
			message_time=7.0
			if game.third_person!=null:game.third_person.shake(0.035,0.16)
	save_progress()
	apply_state()

func interact() -> bool:
	if not inside() or not game.horrors.completed or ending:return false
	var item:=nearest_evidence()
	if item==null:return false
	inspect(item);return true

func _unhandled_input(event: InputEvent) -> void:
	if not built or ending or game.paused or game.editor.active or game.front_end.active:return
	if event.is_action_pressed("interact") and not event.is_echo():
		if interact():get_viewport().set_input_as_handled()

func apply_state() -> void:
	for item in evidence:
		var idx:=int(item.get_meta("correct_index",-1))
		item.set_meta("checked",idx>=0 and idx<found.size() and found[idx])
	if exit_gate!=null:
		exit_gate.position.y=origin.y+(6.2 if completed else 2.0)

func save_progress() -> void:
	var config:=ConfigFile.new();config.set_value("enquete","found",found.duplicate());config.set_value("enquete","completed",completed);config.save(SAVE_PATH)

func load_progress() -> void:
	var config:=ConfigFile.new()
	if config.load(SAVE_PATH)!=OK:return
	var saved:Variant=config.get_value("enquete","found",[false,false,false])
	if saved is Array and saved.size()==3:
		for i in range(3):found[i]=bool(saved[i])
	completed=bool(config.get_value("enquete","completed",found_count()==3)) and found_count()==3

func reset_progress() -> void:
	found=[false,false,false];completed=false;ending=false;was_inside=false;message="";message_time=0
	if FileAccess.file_exists(SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if built:apply_state()

func finish_preview() -> void:
	if ending:return
	ending=true;game.finished=true;game.player.velocity=Vector3.ZERO;end_layer.show();ui_layer.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func update_ui() -> void:
	if not inside() or ending:
		ui_layer.hide();return
	ui_layer.show()
	objective.text="SALLE 08 — ENQUÊTE\nLes Ombres et les Bouptilop ne portent pas de vêtements.\nIndices humains : %d / 3" % found_count()
	if message_time>0:
		hint.text=message;return
	if completed:
		hint.text="La piste est reconstituée. Passe la porte du fond."
		return
	var item:=nearest_evidence()
	if item!=null:
		hint.text="E — examiner : "+String(item.get_meta("title","indice"))
	else:
		hint.text="Cherche les objets qui ne peuvent appartenir qu'à un humain."

func _process(delta: float) -> void:
	if not built:return
	message_time=maxf(0,message_time-delta)
	# La salle 07 utilisait ce couloir comme fin de prototype. Tant que la salle
	# d'enquête n'est pas terminée, on neutralise cette ancienne fin.
	if game.horrors.completed and not ending and game.player.position.z<game.horrors.origin.z-32.7:
		game.finished=false
	var now_inside:=inside()
	if now_inside and not was_inside:
		message="Les Bouptilop et l'Ombre ne portent rien. Si tu trouves du tissu ou un objet porté, il vient d'un humain."
		message_time=6.5
	was_inside=now_inside
	if completed and exit_gate!=null:
		exit_gate.position.y=move_toward(exit_gate.position.y,origin.y+6.2,delta*3.2)
	if completed and game.player.position.z<origin.z-30.8:
		finish_preview()
	update_ui()
