extends Node
var game: Node
var path := "user://progression.cfg"
var stage := 0
var fingerprint := ""
var latest: Dictionary = {}
var status: Label
var countdown := 0.0
var new_button: Button
var confirm_new := false
var confirm_time := 0.0
var retry_time := 0.0

func _ready() -> void:
	game=get_parent()
	var panel: Node=game.controls.panel
	var row:=HBoxContainer.new();panel.add_child(row)
	var resume:=Button.new();resume.text="Recharger le point de reprise";row.add_child(resume)
	resume.pressed.connect(func():
		if not latest.is_empty():
			var inspection=game.get_node_or_null("Inspection")
			if inspection!=null:inspection.active=false
			game.controls.close();apply_save(latest);announce("Point de reprise chargé.")
	)
	new_button=Button.new();new_button.text="Nouvelle partie";row.add_child(new_button)
	new_button.pressed.connect(func():
		if not confirm_new:
			confirm_new=true;confirm_time=5;new_button.text="Confirmer : effacer la progression"
		else:
			var error:=OK
			if FileAccess.file_exists(path):error=DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error!=OK:announce("Impossible d'effacer la progression.");return
			get_tree().reload_current_scene()
	)
	var layer:=CanvasLayer.new();layer.layer=6;add_child(layer)
	status=Label.new();status.position=Vector2(26,585);status.add_theme_font_size_override("font_size",16)
	status.add_theme_color_override("font_outline_color",Color.BLACK);status.add_theme_constant_override("outline_size",4);layer.add_child(status)
	call_deferred("load_progress")

func announce(message: String) -> void:
	status.text=message;countdown=4

func valid(data: Dictionary) -> bool:
	if int(data.get("version",0))!=1:return false
	if not data.get("stage") is int or data.stage<0 or data.stage>7:return false
	if not data.get("nodes") is Array or data.nodes.size()!=3:return false
	for value in data.nodes:
		if not value is bool:return false
	if not data.get("sword") is bool:return false
	if not data.get("events") is Dictionary:return false
	var return_door: Variant=data.get("return_door",data.stage)
	if not return_door is int or return_door<0 or return_door>data.stage:return false
	if not data.get("return_back",false) is bool:return false
	if data.get("return_back",false) and return_door<2:return false
	var valves: Variant=data.get("silence_valves",[data.stage>=3,data.stage>=3])
	if not valves is Array or valves.size()!=2:return false
	for value in valves:
		if not value is bool:return false
	var silence_open: Variant=data.get("silence_open",data.stage>=3)
	if not silence_open is bool:return false
	if silence_open and valves.count(true)!=2:return false
	if data.stage>=3 and not silence_open:return false
	if data.stage<2 and (silence_open or valves.count(true)>0):return false
	if data.stage>=4 and data.nodes.count(true)!=3:return false
	if data.stage>=5 and not data.sword:return false
	if not data.get("simon_done",false) is bool:return false
	if not data.get("torture_captured",false) is bool:return false
	if not data.get("horror_started",false) is bool:return false
	if not data.get("horror_revealed",false) is bool:return false
	if not data.get("horror_completed",false) is bool:return false
	if data.get("horror_revealed",false) and not data.get("horror_started",false):return false
	if data.get("horror_completed",false) and not data.get("horror_revealed",false):return false
	var doses: Variant=data.get("torture_doses",0)
	if not doses is int or doses<0 or doses>3:return false
	if doses>0 and not data.get("torture_captured",false):return false
	if data.stage<6 and (doses>0 or data.get("torture_captured",false)):return false
	if data.stage==6 and not data.get("simon_done",false):return false
	if data.stage<7 and (data.get("horror_started",false) or data.get("horror_revealed",false) or data.get("horror_completed",false)):return false
	if data.stage>=7 and (not data.get("simon_done",false) or not data.get("torture_captured",false) or doses<3):return false
	return true

func load_progress() -> void:
	var config:=ConfigFile.new()
	if config.load(path)!=OK:return
	var data: Variant=config.get_value("progress","data",{})
	if not data is Dictionary or not valid(data):
		announce("Sauvegarde illisible : départ depuis l'entrée.");return
	latest=data.duplicate(true)
	if game.front_end!=null and game.front_end.active:return
	apply_save(data)
	fingerprint=JSON.stringify(snapshot())
	announce("Point de reprise chargé — F1 : menu.")

func snapshot() -> Dictionary:
	var return_door: int=mini(stage,game.death.door.index) if game.death!=null else stage
	var return_back: bool=game.death!=null and game.death.door.backwards and return_door==game.death.door.index
	return {"version":1,"stage":stage,"return_door":return_door,"return_back":return_back,"nodes":game.labyrinth.collected.duplicate(),"sword":game.combat.equipped,"stick":game.feeding.equipped,"spores":game.inventory.has_spores,"events":game.scares.fired.duplicate(),"silence_valves":[true,true] if stage>=3 else game.silence.closed.duplicate(),"silence_open":stage>=3 or game.silence.solved,"simon_done":game.simon.won,"torture_captured":game.torture.captured,"torture_doses":game.torture.doses,"horror_started":game.horrors.started,"horror_revealed":game.horrors.revealed,"horror_completed":game.horrors.completed}

func observe() -> void:
	if game.death!=null and not game.death.active:game.death.door.observe()
	var inspection=game.get_node_or_null("Inspection")
	if inspection!=null and inspection.active:return
	if game.paused or game.editor.active:return
	if game.arrived:stage=maxi(stage,1)
	if game.puzzle.solved:stage=maxi(stage,2)
	if game.puzzle.solved and game.silence.solved and game.labyrinth.inside():stage=maxi(stage,3)
	if game.labyrinth.collected.count(true)==3 and game.combat.inside():stage=maxi(stage,4)
	if game.combat.won:stage=maxi(stage,5)
	if game.simon.won and game.torture.inside():stage=maxi(stage,6)
	if game.horrors.started:stage=maxi(stage,7)
	if stage==0:return
	var data:=snapshot();var key:=JSON.stringify(data)
	# A disk error must never freeze in-memory progress or break the next death.
	latest=data.duplicate(true)
	if retry_time>0:return
	if key==fingerprint:return
	var config:=ConfigFile.new();config.set_value("progress","data",data)
	var error:=config.save(path+".tmp")
	if error==OK:error=DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if error!=OK:
		retry_time=5;announce("Échec de sauvegarde. Vérifie l'accès au dossier utilisateur.");return
	fingerprint=key;latest=data.duplicate(true);announce("Progression sauvegardée.")

func apply_save(data: Dictionary) -> void:
	if not valid(data):return
	if game.death!=null:game.death.cancel()
	game.voice.reset_announcements()
	if game.experience!=null:game.experience.room="";game.experience.announced_quest=""
	stage=data.stage
	game.combat.cancel_charge();game.combat.reset_fight()
	game.actions.reset_stance();game.player.rotation=Vector3.ZERO;game.player.velocity=Vector3.ZERO
	game.camera.rotation=Vector3.ZERO;game.camera.position=Vector3(0,1.62,0);game.camera.fov=78
	game.sliding=false;game.finished=false;game.arrived=stage>=1
	game.puzzle.solved=stage>=2;game.puzzle.step=3 if stage>=2 else 0
	game.puzzle.opened=1 if stage>=2 else 0
	game.puzzle.gate.position.y=game.puzzle.origin.y+2.25+game.puzzle.opened*4.6
	game.puzzle.entered_next=stage>=2
	# Old saves already inside/beyond the labyrinth must never be locked backwards.
	game.silence.restore(data.get("silence_valves",[stage>=3,stage>=3]),bool(data.get("silence_open",stage>=3)))
	game.cycle.clock=0;game.cycle.toxicity=0;game.cycle.sheltered=false;game.cycle.movement_factor=1
	game.labyrinth.collected=data.nodes.duplicate()
	var maze_open: bool=data.nodes.count(true)==3
	game.labyrinth.opened=1 if maze_open else 0
	game.labyrinth.exit_gate.position.y=game.labyrinth.origin.y+2.25+game.labyrinth.opened*5
	game.labyrinth.complete=stage>=4
	for i in range(3):
		game.labyrinth.organs[i].material_override=game.atmosphere.luminous(Color(0.12,0.8,0.55) if data.nodes[i] else Color(1,0.08,0.025),2)
	game.combat.equipped=data.sword;game.combat.pickup.visible=not data.sword
	game.combat.won=stage>=5;game.combat.opened=1 if stage>=5 else 0
	game.combat.exit_gate.position.y=game.combat.origin.y+2+game.combat.opened*4.5
	if stage>=5:
		for body in game.combat.enemies:body.set_meta("hp",0);body.hide();body.collision_layer=0
	game.scares.restore(data.events)
	var runner=game.get_node_or_null("Bouptilop")
	if runner!=null:runner.reset()
	game.simon.restore(stage>=5 and data.get("simon_done",false)==true)
	game.inventory.restore(bool(data.get("spores",stage>=2)))
	game.torture.restore(bool(data.get("torture_captured",false)),int(data.get("torture_doses",3 if stage>=7 else 0)))
	if game.torture.doses>0:game.inventory.restore(false)
	game.horrors.unlocked=stage>=7
	game.horrors.restore(bool(data.get("horror_started",false)),bool(data.get("horror_revealed",false)),bool(data.get("horror_completed",false)))
	game.feeding.restore(stage>=2,bool(data.get("stick",false)))
	match stage:
		0:game.teleport_player(Vector3(0,0.05,1.8))
		1:game.teleport_player(game.puzzle.origin+Vector3(0,0.05,8))
		2:game.teleport_player(game.puzzle.origin+Vector3(0,0.05,-14))
		3:game.teleport_player(game.labyrinth.cell_at(Vector2i(4,0))+Vector3(0,0.05,0))
		4:game.teleport_player(game.combat.origin+Vector3(0,0.05,-2))
		5:game.teleport_player(game.combat.origin+Vector3(0,0.05,-32))
		6:game.teleport_player(game.torture.origin+Vector3(0,0.05,-2))
		7:game.teleport_player(game.horrors.origin+Vector3(0,0.05,-2))
	game.veil.color.a=0
	if game.death!=null:
		if data.has("return_door"):
			game.death.door.restore(data.return_door,bool(data.get("return_back",false)))
			game.teleport_player(game.death.door.destination());game.player.rotation.y=game.death.door.facing()
			game.death.door.last_position=game.player.position
		else:game.death.door.seed_from_position()
	if game.audio_mix!=null:game.audio_mix.reset_transients()

func _process(delta: float) -> void:
	retry_time=maxf(0,retry_time-delta)
	countdown=maxf(0,countdown-delta)
	status.visible=countdown>0 and not game.editor.active
	if confirm_new:
		confirm_time-=delta
		if confirm_time<=0:confirm_new=false;new_button.text="Nouvelle partie"
