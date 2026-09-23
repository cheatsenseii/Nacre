extends Node
const PATH := "user://touches.cfg"
const TITLES := {"forward":"Avancer", "back":"Reculer", "left":"Aller à gauche", "right":"Aller à droite", "jump":"Sauter", "crouch":"S'accroupir (maintenir)", "sprint":"Courir (maintenir)", "push":"Pousser / armes", "parry":"Parer (maintenir)", "interact":"Interagir", "torch":"Lampe torche", "music":"Musique", "voice_toggle":"Voix du personnage", "restart":"Point de reprise"}
var game: Node
var is_open := false
var waiting := ""
var previous_pause := false
var defaults := {}
var buttons := {}
var layer: CanvasLayer
var status: Label
var panel: VBoxContainer
var resume_button: Button

func _ready() -> void:
	game=get_parent()
	# Capture factory bindings, not bindings left over from the previous scene.
	for action in TITLES: defaults[action]=InputMap.action_get_events(action).duplicate()
	load_bindings()
	build_ui()

func build_ui() -> void:
	layer=CanvasLayer.new()
	layer.layer=60
	add_child(layer)
	var shade:=ColorRect.new()
	shade.color=Color(0.015,0.025,0.025,0.95)
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu_scroll:=ScrollContainer.new()
	menu_scroll.position=Vector2(260,30)
	menu_scroll.size=Vector2(760,650)
	layer.add_child(menu_scroll)
	panel=VBoxContainer.new()
	panel.custom_minimum_size=Vector2(720,0)
	panel.add_theme_constant_override("separation",10)
	menu_scroll.add_child(panel)
	var heading:=Label.new()
	heading.text="NACRE  /  TOUCHES"
	heading.add_theme_font_size_override("font_size",30)
	panel.add_child(heading)
	var help:=Label.new()
	help.text="Clique une commande, puis presse une touche ou un bouton de souris.\nÉchap annule la saisie. F1, F2 et Échap restent réservées aux menus."
	panel.add_child(help)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(720,320)
	panel.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",25)
	grid.add_theme_constant_override("v_separation",5)
	scroll.add_child(grid)
	for action in TITLES:
		var label:=Label.new()
		label.text=TITLES[action]
		label.custom_minimum_size=Vector2(330,30)
		grid.add_child(label)
		var button:=Button.new()
		button.custom_minimum_size=Vector2(320,30)
		button.pressed.connect(func():
			waiting=action
			status.text="Nouvelle touche pour « "+TITLES[action]+" »…"
			refresh()
		)
		buttons[action]=button
		grid.add_child(button)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size=Vector2(700,45)
	status.text="Sauvegarde automatique. Un changement remplace les touches alternatives de cette commande."
	panel.add_child(status)
	var row:=HBoxContainer.new()
	panel.add_child(row)
	var reset:=Button.new()
	reset.text="Rétablir les touches par défaut"
	reset.pressed.connect(reset_defaults)
	row.add_child(reset)
	var resume:=Button.new()
	resume_button=resume
	resume.text="Reprendre le jeu"
	resume.pressed.connect(close)
	row.add_child(resume)
	refresh()
	layer.hide()

func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var name := OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		return {"Space":"Espace", "Shift":"Maj", "Control":"Ctrl", "Up":"Flèche haut", "Down":"Flèche bas", "Left":"Flèche gauche", "Right":"Flèche droite"}.get(name,name)
	if event is InputEventMouseButton:
		var names={1:"Clic gauche",2:"Clic droit",3:"Clic molette",8:"Souris 4",9:"Souris 5"}
		return names.get(event.button_index,"Souris "+str(event.button_index))
	return "?"

func key(action: String) -> String:
	var events:=InputMap.action_get_events(action)
	return event_label(events[0]) if not events.is_empty() else "?"

func refresh() -> void:
	for action in buttons:
		var labels: PackedStringArray=[]
		for event in InputMap.action_get_events(action):labels.append(event_label(event))
		buttons[action].text="Appuie sur une touche…" if waiting==action else " / ".join(labels)

func open() -> void:
	if game.editor.active:return
	resume_button.text="Retour à l'accueil" if game.front_end!=null and game.front_end.active else "Reprendre le jeu"
	game.combat.cancel_charge()
	previous_pause=game.paused
	game.paused=true
	is_open=true
	waiting=""
	layer.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	refresh()

func close() -> void:
	waiting=""
	is_open=false
	layer.hide()
	game.paused=previous_pause
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if previous_pause else Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	var appearance=game.get_node_or_null("Appearance")
	if appearance!=null and appearance.active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_F1]:appearance.close();get_viewport().set_input_as_handled()
		return
	if game.editor.active:return
	if not waiting.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:
				waiting=""
				status.text="Modification annulée."
				refresh()
			else: assign(waiting,event)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			assign(waiting,event)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1,KEY_ESCAPE]:
		if is_open:close()
		else:open()
		get_viewport().set_input_as_handled()

func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:return {"type":"key","code":event.physical_keycode if event.physical_keycode else event.keycode}
	return {"type":"mouse","code":event.button_index}

func decode(data: Variant) -> InputEvent:
	if not data is Dictionary:return null
	if not data.get("code") is int:return null
	if data.get("type")=="key":
		if data.code<=0 or data.code in [KEY_ESCAPE,KEY_F1,KEY_F2,KEY_F3]:return null
		var event:=InputEventKey.new()
		event.physical_keycode=data.code
		return event
	if data.get("type")=="mouse" and data.code in [1,2,3,8,9]:
		var event:=InputEventMouseButton.new()
		event.button_index=data.code
		return event
	return null

func assign(action: String, raw: InputEvent) -> bool:
	var event:=decode(encode(raw))
	if event==null:
		status.text="Touche réservée ou molette non prise en charge. Choisis une autre touche."
		return false
	for other in TITLES:
		if other==action:continue
		for bound in InputMap.action_get_events(other):
			if encode(bound)==encode(event):
				status.text="Déjà utilisée pour « "+TITLES[other]+" ». Choisis une autre touche."
				return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action,event)
	waiting=""
	refresh()
	save_bindings()
	return true

func save_bindings() -> void:
	var config:=ConfigFile.new()
	for action in TITLES:
		var encoded:=[]
		for event in InputMap.action_get_events(action):encoded.append(encode(event))
		config.set_value("touches",action,encoded)
	var result:=config.save(PATH)
	status.text="Touches sauvegardées automatiquement." if result==OK else "Touches appliquées, mais sauvegarde impossible."

func load_bindings() -> void:
	var config:=ConfigFile.new()
	if config.load(PATH)!=OK:return
	var proposed:={}
	var seen:=[]
	for action in TITLES:
		if action=="parry" and not config.has_section_key("touches","parry"):continue
		var data=config.get_value("touches",action,[])
		if not data is Array or data.is_empty() or data.size()>5:return
		var events:=[]
		for entry in data:
			var event:=decode(entry)
			if event==null or encode(event) in seen:return
			seen.append(encode(event))
			events.append(event)
		proposed[action]=events
	if not proposed.has("parry"):
		var candidates: Array[InputEvent]=[]
		var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_RIGHT;candidates.append(mouse)
		for code in [KEY_G,KEY_B,KEY_T,KEY_P,KEY_H]:
			var key_event:=InputEventKey.new();key_event.physical_keycode=code;candidates.append(key_event)
		for event in candidates:
			if not encode(event) in seen:
				proposed["parry"]=[event];break
		if not proposed.has("parry"):return
	for action in proposed:
		InputMap.action_erase_events(action)
		for event in proposed[action]:InputMap.action_add_event(action,event)

func reset_defaults() -> void:
	waiting=""
	for action in defaults:
		InputMap.action_erase_events(action)
		for event in defaults[action]:InputMap.action_add_event(action,event)
	refresh()
	save_bindings()

func update_hints() -> void:
	var replacements={"ZQSD":key("forward")+key("left")+key("back")+key("right"), "Espace : saut":key("jump")+" : saut", "Maj : accroupi":key("crouch")+" : accroupi", "Ctrl : courir":key("sprint")+" : courir", "Clic gauche : pousser":key("push")+" : pousser", "E —":key("interact")+" —", "E près":key("interact")+" près", "E pour":key("interact")+" pour", "E :":key("interact")+" :", "F : lampe":key("torch")+" : lampe", "M : musique":key("music")+" : musique", "R :":key("restart")+" :", "R pour":key("restart")+" pour"}
	for old in replacements:
		game.prompt.text=game.prompt.text.replace(old,replacements[old])
		game.hud.text=game.hud.text.replace(old,replacements[old])
