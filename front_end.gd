extends Node
var game: Node
var active := true
var prologue_mode := false
var layer: CanvasLayer
var continue_button: Button
var new_button: Button
var note: Label
var confirming := false
var health_layer: CanvasLayer
var health_bar: ProgressBar
var trail: ProgressBar
var health_text: Label
var bar_style: StyleBoxFlat
var displayed := 100.0
var menu_actions: VBoxContainer
var menu_camera: Camera3D
var confirmation: ConfirmationDialog
var menu_clock:=0.0
var reference_frame: Control
var credits: AcceptDialog
const REFERENCE_SIZE := Vector2(1672,941)

func label(parent: Node,text: String,at: Vector2,font_size: int,color: Color) -> Label:
	var node:=Label.new();node.text=text;node.position=at
	node.add_theme_font_override("font",preload("res://fonts/Interface.ttf"))
	node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
	parent.add_child(node);return node

func style(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color
	box.corner_radius_top_left=5;box.corner_radius_top_right=5;box.corner_radius_bottom_left=5;box.corner_radius_bottom_right=5
	return box

func button(text: String,y: float,callback: Callable) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size=Vector2(363,49)
	node.set_meta("menu_order",y)
	node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_override("font",preload("res://fonts/Interface.ttf"))
	node.add_theme_font_size_override("font_size",26)
	var base:=style(Color("09191e"));base.content_margin_left=33;base.content_margin_right=16
	base.set_border_width_all(1);base.border_color=Color("2a464b")
	base.set_corner_radius_all(0)
	node.add_theme_stylebox_override("normal",base)
	var hover:=base.duplicate();hover.bg_color=Color("095664");hover.border_color=Color("61dbef")
	node.add_theme_stylebox_override("hover",hover)
	var pressed:=hover.duplicate();pressed.bg_color=Color("07353e")
	node.add_theme_stylebox_override("pressed",pressed)
	var disabled:=base.duplicate();disabled.bg_color=Color("10171b")
	node.add_theme_stylebox_override("disabled",disabled)
	node.add_theme_color_override("font_color",Color("e0e9e7"))
	node.add_theme_color_override("font_hover_color",Color.WHITE)
	node.add_theme_color_override("font_disabled_color",Color("627078"))
	var focus:=style(Color(0,0,0,0));focus.set_border_width_all(2)
	focus.border_color=Color("45e0f4");focus.set_corner_radius_all(0)
	node.add_theme_stylebox_override("focus",focus)
	node.pressed.connect(callback);menu_actions.add_child(node)
	var ordered:=menu_actions.get_children()
	ordered.sort_custom(func(a: Node,b: Node):return a.get_meta("menu_order")<b.get_meta("menu_order"))
	for i in range(ordered.size()):menu_actions.move_child(ordered[i],i)
	return node

func layout_reference() -> void:
	if reference_frame==null:return
	var available:=get_viewport().get_visible_rect().size
	var factor:=minf(available.x/REFERENCE_SIZE.x,available.y/REFERENCE_SIZE.y)
	reference_frame.size=REFERENCE_SIZE
	reference_frame.scale=Vector2.ONE*factor
	reference_frame.position=(available-REFERENCE_SIZE*factor)*0.5

func _ready() -> void:
	game=get_parent();game.paused=true
	game.hud.get_parent().hide()
	layer=CanvasLayer.new();layer.layer=90;add_child(layer)
	menu_camera=Camera3D.new();menu_camera.name="CameraAccueil";menu_camera.fov=61
	menu_camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.add_child(menu_camera);menu_camera.position=Vector3(3.8,2.5,4.0)
	menu_camera.look_at(Vector3(-1.9,3.1,-4));menu_camera.make_current()
	var background:=ColorRect.new();background.color=Color("04090c")
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reference_frame=Control.new();reference_frame.name="AccueilLayout"
	reference_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(reference_frame)
	var picture:=TextureRect.new();picture.name="VisuelNACRE"
	picture.texture=preload("res://branding/accueil_nacre.png")
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_SCALE
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;reference_frame.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_actions=VBoxContainer.new();menu_actions.position=Vector2(64,366)
	menu_actions.size.x=363;menu_actions.add_theme_constant_override("separation",7)
	reference_frame.add_child(menu_actions)
	new_button=button("NOUVELLE PARTIE",0,new_game)
	continue_button=button("CONTINUER",1,continue_game)
	continue_button.tooltip_text="Reprendre le dernier point de sauvegarde."
	button("PARAMÈTRES",2,func():game.controls.open())
	button("CRÉDITS",3,func():credits.popup_centered(Vector2i(580,300)))
	button("QUITTER",4,func():get_tree().quit())
	note=label(reference_frame,"",Vector2(65,728),18,Color("d2dcd6"))
	note.size=Vector2(355,75);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_outline_color",Color("031014"));note.add_theme_constant_override("outline_size",5)
	credits=AcceptDialog.new();credits.title="NACRE / Dernière Porte"
	credits.dialog_text="Un jeu d’horreur et d’exploration solo.\n\nUnivers et direction : Hugo.\nMoteur : Godot Engine 4.4.1.\nÉcran d’accueil : illustration fournie par Hugo.\nVoix : synthèse Flite. Bruitages procéduraux.\n\nLicences complètes dans LICENCES.txt et Sources/fonts."
	credits.ok_button_text="Retour";add_child(credits)
	confirmation=ConfirmationDialog.new();confirmation.title="Recommencer le parcours ?"
	confirmation.dialog_text="Ta progression actuelle sera remplacée.\nTon apparence et tes réglages seront conservés."
	confirmation.ok_button_text="Recommencer";confirmation.cancel_button_text="Annuler"
	confirmation.confirmed.connect(new_game)
	confirmation.canceled.connect(func():confirming=false;new_button.grab_focus())
	add_child(confirmation)
	get_viewport().size_changed.connect(layout_reference)
	layout_reference()
	build_health()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	call_deferred("refresh")

func refresh() -> void:
	continue_button.disabled=game.checkpoints.latest.is_empty()
	continue_button.visible=true
	note.text="Commence avec Billy, avant son retour à NACRE." if continue_button.disabled else "Reprends ton exploration au dernier point sauvegardé."
	if continue_button.disabled:new_button.grab_focus()
	else:continue_button.grab_focus()

func launch() -> void:
	prologue_mode=false
	confirmation.hide();credits.hide();confirming=false;game.camera.make_current()
	game.hud.get_parent().show()
	active=false;game.paused=false;layer.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	game.checkpoints.countdown=0;displayed=game.health

func begin_billy_prologue() -> void:
	confirmation.hide();credits.hide();confirming=false
	var home:=game.get_node_or_null("MaisonBilly")
	if home==null or not home.has_method("begin"):
		# Fallback keeps a broken optional prologue from blocking the actual game.
		launch()
		return
	prologue_mode=true
	active=true
	game.paused=true
	game.hud.get_parent().hide()
	health_layer.hide()
	layer.hide()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	home.begin()

func finish_billy_prologue() -> void:
	prologue_mode=false
	active=false
	game.paused=false
	game.camera.make_current()
	game.hud.get_parent().show()
	layer.hide()
	game.checkpoints.countdown=0
	displayed=game.health
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# The park greets Billy only after the playable home sequence, not from a text dump.
	if not game.voice.welcome_played:
		game.voice.welcome_played=true
		game.voice.say("bienvenue")

func continue_game() -> void:
	if game.checkpoints.latest.is_empty():return
	game.checkpoints.apply_save(game.checkpoints.latest)
	launch()

func new_game() -> void:
	if not game.checkpoints.latest.is_empty() and not confirming:
		confirming=true;confirmation.popup_centered(Vector2i(490,190));return
	if FileAccess.file_exists(game.checkpoints.path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(game.checkpoints.path))!=OK:
			note.text="Impossible de remplacer la sauvegarde.";return
	game.checkpoints.latest={};game.checkpoints.fingerprint=""
	var inspection=game.get_node_or_null("Inspection")
	if inspection!=null:inspection.active=false
	game.checkpoints.apply_save({"version":1,"stage":0,"nodes":[false,false,false],"sword":false,"stick":false,"spores":false,"events":{}})
	begin_billy_prologue()

func build_health() -> void:
	health_layer=CanvasLayer.new();health_layer.layer=9;add_child(health_layer)
	var panel:=Panel.new();panel.position=Vector2(26,465);panel.size=Vector2(292,72)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame:=style(Color(0.025,0.095,0.12,0.93));frame.set_border_width_all(1);frame.border_color=Color("32616a");panel.add_theme_stylebox_override("panel",frame);health_layer.add_child(panel)
	health_text=label(panel,"VITALITÉ                         100 / 100",Vector2(15,8),14,Color("e0efeb"))
	trail=ProgressBar.new();trail.position=Vector2(15,38);trail.size=Vector2(262,14);trail.show_percentage=false;trail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	trail.add_theme_stylebox_override("background",style(Color("081b22")));trail.add_theme_stylebox_override("fill",style(Color("d6a56d")));panel.add_child(trail)
	health_bar=ProgressBar.new();health_bar.position=trail.position;health_bar.size=trail.size;health_bar.show_percentage=false;health_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background",StyleBoxEmpty.new());bar_style=style(Color("61d6bc"));health_bar.add_theme_stylebox_override("fill",bar_style);panel.add_child(health_bar)

func _process(delta: float) -> void:
	layer.visible=active and not prologue_mode and not game.controls.is_open
	health_layer.visible=not active and not prologue_mode and not game.editor.active and not game.paused
	var hp: int=clampi(game.health,0,100)
	health_bar.value=hp
	displayed=move_toward(displayed,hp,delta*28);trail.value=maxf(hp,displayed)
	bar_style.bg_color=Color("e0695b") if hp<=25 else (Color("e8b467") if hp<=50 else Color("61d6bc"))
	health_text.text=("VITALITÉ CRITIQUE" if hp<=25 else "VITALITÉ")+"         %d / 100" % hp
	if active and not prologue_mode:
		menu_clock+=delta
		menu_camera.position=Vector3(3.8+sin(menu_clock*0.08)*0.10,2.5,4.0)
		menu_camera.look_at(Vector3(-1.9,3.1,-4))
