extends Node
## Opening narrative shown only when starting a new game.
## It pauses gameplay and lets the player control the reading pace.
var game: Node
var active := false
var armed_new_game := false
var layer: CanvasLayer
var objective_layer: CanvasLayer
var backdrop: ColorRect
var title: Label
var body: Label
var chapter: Label
var hint: Label
var objective: Label
var index := 0
var reveal := 0.0
var full_text := ""
const TEXT_SPEED := 42.0
const PANELS := [
	{
		"title":"48 HEURES PLUS TÔT",
		"body":"Nathan, ton petit frère, est entré dans NACRE pour filmer une exploration nocturne. Le parc aquatique est fermé depuis 1998. Officiellement, il n’y a plus rien ici. Plus de courant. Plus d’eau. Plus personne."
	},
	{
		"title":"22 H 17 — DERNIER MESSAGE",
		"body":"Ton téléphone a vibré une seule fois : « Je suis sous le grand toboggan. J’ai trouvé une porte qui n’existe pas sur les plans. Si je ne réponds plus… ne viens pas ici. » Tu n’as jamais reçu d’autre message."
	},
	{
		"title":"TU N’AS PAS ATTENDU",
		"body":"La police parle de fugue et refuse de fouiller un bâtiment condamné. Toi, tu sais que Nathan ne serait pas parti sans son sac, son appareil et ses médicaments. Alors cette nuit, tu as franchi la clôture de NACRE avec la dernière position envoyée par son téléphone."
	},
	{
		"title":"À L’INTÉRIEUR",
		"body":"Tu as retrouvé son sac près des anciens vestiaires. Trempé. Les bassins sont pourtant vides depuis des années. Puis les rideaux de sécurité se sont refermés derrière toi. Les commandes d’urgence ne répondent plus et ton téléphone n’a plus de réseau."
	},
	{
		"title":"IL RESTE UNE ISSUE",
		"body":"Sur un ancien plan d’évacuation, toutes les sorties de surface sont barrées. Une seule ligne descend sous le parc : SORTIE TECHNIQUE — DERNIÈRE PORTE. Pour l’atteindre, il faut passer par les niveaux de maintenance, sous les toboggans."
	},
	{
		"title":"TON OBJECTIF",
		"body":"Retrouve Nathan s’il est encore vivant. Découvre ce qui lui est arrivé s’il ne l’est plus. Et surtout, sors de NACRE. Depuis que tu es entré, quelque chose remet le parc en marche… et tu as déjà entendu des pas dans des zones où personne ne devrait pouvoir marcher."
	}
]

func _ready() -> void:
	game=get_parent()
	build_ui()
	layer.hide();objective_layer.hide()
	call_deferred("bind_front_end")

func bind_front_end() -> void:
	# FrontEnd is created dynamically by main.gd after this scene child becomes ready.
	for _i in range(16):
		await get_tree().process_frame
		if game.front_end!=null and game.front_end.new_button!=null:break
	if game.front_end==null or game.front_end.new_button==null:return
	game.front_end.new_button.pressed.connect(func():armed_new_game=true)
	game.front_end.continue_button.pressed.connect(func():armed_new_game=false)
	if game.front_end.confirmation!=null:
		game.front_end.confirmation.canceled.connect(func():armed_new_game=false)

func font() -> Font:
	return preload("res://fonts/Interface.ttf")

func build_ui() -> void:
	layer=CanvasLayer.new();layer.layer=109;add_child(layer)
	backdrop=ColorRect.new();backdrop.color=Color(0.008,0.016,0.019,0.985)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)
	var top_rule:=ColorRect.new();top_rule.position=Vector2(96,112);top_rule.size=Vector2(1088,2);top_rule.color=Color("2d7079");backdrop.add_child(top_rule)
	chapter=Label.new();chapter.position=Vector2(98,72);chapter.size=Vector2(1080,30)
	chapter.text="NACRE // PROLOGUE";chapter.add_theme_font_override("font",font());chapter.add_theme_font_size_override("font_size",17)
	chapter.add_theme_color_override("font_color",Color("75aeb4"));backdrop.add_child(chapter)
	title=Label.new();title.position=Vector2(98,145);title.size=Vector2(1080,64)
	title.add_theme_font_override("font",font());title.add_theme_font_size_override("font_size",34)
	title.add_theme_color_override("font_color",Color("e9f0ec"));backdrop.add_child(title)
	body=Label.new();body.position=Vector2(102,245);body.size=Vector2(1030,270)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	body.add_theme_font_override("font",font());body.add_theme_font_size_override("font_size",25)
	body.add_theme_color_override("font_color",Color("cbd5d0"));body.add_theme_color_override("font_outline_color",Color("020708"));body.add_theme_constant_override("outline_size",3)
	backdrop.add_child(body)
	hint=Label.new();hint.position=Vector2(102,605);hint.size=Vector2(1030,42)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;hint.add_theme_font_override("font",font());hint.add_theme_font_size_override("font_size",17)
	hint.add_theme_color_override("font_color",Color("6f8f92"));backdrop.add_child(hint)
	var bottom_rule:=ColorRect.new();bottom_rule.position=Vector2(96,660);bottom_rule.size=Vector2(1088,2);bottom_rule.color=Color("193d42");backdrop.add_child(bottom_rule)
	# Small reminder shown only during the opening area after the cinematic text.
	objective_layer=CanvasLayer.new();objective_layer.layer=8;add_child(objective_layer)
	var panel:=Panel.new();panel.position=Vector2(835,28);panel.size=Vector2(410,86);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.015,0.065,0.075,0.91);style.border_color=Color("285961");style.set_border_width_all(1);style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel",style);objective_layer.add_child(panel)
	objective=Label.new();objective.position=Vector2(15,10);objective.size=Vector2(380,66)
	objective.text="OBJECTIF\nRetrouver Nathan • Atteindre la Dernière Porte"
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objective.add_theme_font_override("font",font());objective.add_theme_font_size_override("font_size",16)
	objective.add_theme_color_override("font_color",Color("cce6df"));panel.add_child(objective)

func begin() -> void:
	if active:return
	active=true;index=0;game.paused=true;objective_layer.hide()
	if game.voice!=null:
		game.voice.stop_all();game.voice.welcome_played=true
	layer.show();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	show_panel()

func show_panel() -> void:
	var data: Dictionary=PANELS[index]
	title.text=String(data["title"])
	full_text=String(data["body"])
	body.text=full_text;body.visible_characters=0;reveal=0
	chapter.text="NACRE // PROLOGUE                                      %02d / %02d" % [index+1,PANELS.size()]
	hint.text="Espace / E — continuer     Échap — passer le prologue"

func text_complete() -> bool:
	return body.visible_characters>=full_text.length()

func advance() -> void:
	if not text_complete():
		body.visible_characters=-1;reveal=float(full_text.length());return
	index+=1
	if index>=PANELS.size():finish()
	else:show_panel()

func finish() -> void:
	active=false;layer.hide();objective_layer.show();game.paused=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.16,0.35)
	if game.voice!=null:game.voice.say("mission")

func _input(event: InputEvent) -> void:
	if not active:return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		finish();get_viewport().set_input_as_handled();return
	if (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")) and not event.is_echo():
		advance();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		if armed_new_game and game.front_end!=null and not game.front_end.active:
			armed_new_game=false;begin();return
		if objective_layer.visible and game.arrived:objective_layer.hide()
		return
	# Keep gameplay frozen even if another UI system briefly toggles the flag.
	game.paused=true
	if not text_complete():
		reveal=minf(float(full_text.length()),reveal+delta*TEXT_SPEED)
		body.visible_characters=int(reveal)
