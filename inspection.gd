extends Node
const ROOMS := ["Entrée du toboggan","Champignon","Chambre du silence","Labyrinthe vivant","Fosse de combat","Simon maléfique","Salle de torture","Salle des horreurs"]
var game: Node
var active:=false
var index:=-1
var original: Dictionary={}
var original_position:=Vector3.ZERO
var from_menu:=false
var selector: OptionButton
var badge: Label

func _ready() -> void:
	game=get_parent()
	var row:=HBoxContainer.new();game.controls.panel.add_child(row)
	var label:=Label.new();label.text="INSPECTION • F3 : salle suivante";row.add_child(label)
	selector=OptionButton.new()
	for room in ROOMS:selector.add_item(room)
	row.add_child(selector)
	var visit:=Button.new();visit.text="Visiter";visit.pressed.connect(func():jump(selector.selected));row.add_child(visit)
	var back:=Button.new();back.text="Reprendre ma partie";back.pressed.connect(leave);game.controls.panel.add_child(back)
	var layer:=CanvasLayer.new();layer.layer=12;add_child(layer)
	badge=Label.new();badge.position=Vector2(340,680);badge.add_theme_font_size_override("font_size",15);badge.add_theme_color_override("font_color",Color("e8bd76"));badge.add_theme_constant_override("outline_size",5);layer.add_child(badge)

func jump(room: int) -> void:
	if game.editor.active:return
	if not active:
		original=game.checkpoints.snapshot().duplicate(true);original_position=game.player.position
		from_menu=game.front_end.active
		if from_menu and not game.checkpoints.latest.is_empty():original=game.checkpoints.latest.duplicate(true)
	active=true;index=clampi(room,0,ROOMS.size()-1);selector.select(index)
	if game.controls.is_open:game.controls.close()
	var stage:=index
	var data:={"version":1,"stage":stage,"nodes":[stage>=4,stage>=4,stage>=4],"sword":stage>=4,"stick":stage>=1,"spores":stage>=2 and stage<7,"events":{},"simon_done":stage>=6,"torture_captured":stage>=7,"torture_doses":3 if stage>=7 else 0,"horror_started":false,"horror_revealed":false,"horror_completed":false}
	game.checkpoints.apply_save(data)
	if index==5:game.teleport_player(game.simon.origin+Vector3(0,0.05,-3))
	if index==7:game.teleport_player(game.horrors.origin+Vector3(0,0.05,-2))
	game.front_end.launch()
	game.voice.stop_all()

func leave() -> void:
	if not active:return
	if game.editor.active:return
	if game.controls.is_open:game.controls.close()
	game.checkpoints.apply_save(original)
	if not from_menu:game.teleport_player(original_position)
	active=false;game.front_end.launch()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
		if not game.editor.active and not game.get_node("Appearance").active and game.controls.waiting.is_empty():
			if not active:
				index=7 if game.horrors.inside() else (6 if game.torture.inside() else (5 if game.simon.inside() else (4 if game.combat.inside() else (3 if game.labyrinth.inside() else (2 if game.puzzle.solved else (1 if game.arrived else 0))))))
			jump((index+1)%ROOMS.size())
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	badge.visible=active and not game.paused and not game.editor.active
	badge.text="INSPECTION — "+ROOMS[maxi(0,index)]+" • F3 : suivante • F1 : retour • progression suspendue"
