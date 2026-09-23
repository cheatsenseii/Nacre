extends Node3D
var game: Node3D
var fired: Dictionary = {}
var enabled := true
var silhouette: Node3D
var apparition_time := 0.0
var footsteps: AudioStreamPlayer3D
var impact: AudioStreamPlayer3D
var caption: Label
var caption_time := 0.0
var maze_shadow: Node3D
var shadow_sound: AudioStreamPlayer3D
var shadow_time := 0.0
var shadow_wait := 6.0
var shadow_probe := 0.0
var shadow_stage := -1
var shadow_follow_clock := 0.0
var shadow_target := Vector3.ZERO
var shadow_eyes: Array[MeshInstance3D] = []
const SHADOW_WARMUP:=1.4
const SHADOW_REACH:=0.85
const SHADOW_SPEEDS: Array[float]=[1.5,1.85,2.25,2.85]
var shadow_age:=0.0
var shadow_safe_time:=0.0
var shadow_nav: RefCounted
var apparition_origin: Vector3
var scare_flash := 0.0
var scare_clock := 0.0
var overlay: ColorRect
var original_energies: Array[float] = []
var polish_node: Node

func _ready() -> void:
	game=get_parent()
	for child in game.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://polish.gd":polish_node=child
	apparition_origin=game.puzzle.origin+Vector3(0,0,-34)
	silhouette=preload("res://shadow_actor.gd").new();silhouette.position=apparition_origin;add_child(silhouette)
	silhouette.build();silhouette.hide()
	build_maze_shadow()
	shadow_nav=preload("res://shadow_navigation.gd").new(); shadow_nav.game=game
	footsteps=AudioStreamPlayer3D.new();footsteps.stream=preload("res://audio/poursuite.wav")
	footsteps.volume_db=-12;footsteps.max_distance=24;footsteps.unit_size=6;add_child(footsteps)
	impact=AudioStreamPlayer3D.new();impact.stream=preload("res://audio/choc_metal.wav")
	impact.volume_db=-12;impact.max_distance=30;impact.unit_size=8;add_child(impact)
	var layer:=CanvasLayer.new();layer.layer=5;add_child(layer)
	caption=Label.new();caption.position=Vector2(26,552);caption.add_theme_font_size_override("font_size",17)
	caption.add_theme_color_override("font_outline_color",Color.BLACK);caption.add_theme_constant_override("outline_size",4);layer.add_child(caption)
	overlay=ColorRect.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.color=Color(0.55,0.03,0.02,0);layer.add_child(overlay)
	if polish_node!=null:
		for lamp in polish_node.spots:original_energies.append(lamp.light_energy)
	var cfg:=ConfigFile.new()
	if cfg.load("user://frissons.cfg")==OK:enabled=bool(cfg.get_value("effects","enabled",true))
	var button:=CheckButton.new();button.text="Événements d'horreur";button.button_pressed=enabled
	game.controls.panel.add_child(button)
	button.toggled.connect(func(value: bool):
		enabled=value
		if not enabled:restore(fired)
		var settings:=ConfigFile.new();settings.set_value("effects","enabled",enabled);settings.save("user://frissons.cfg")
	)

func restore(events: Dictionary) -> void:
	if is_instance_valid(maze_shadow):maze_shadow.hide();shadow_sound.stop()
	shadow_time=0;shadow_wait=6;shadow_probe=0;shadow_stage=-1;shadow_follow_clock=0;shadow_target=Vector3.ZERO
	shadow_age=0;shadow_safe_time=6;shadow_nav.reset()
	fired=events.duplicate();apparition_time=0;silhouette.hide();footsteps.stop();impact.stop();caption_time=0;caption.text="";scare_flash=0;scare_clock=0;overlay.color.a=0

func whisper(text: String) -> void:
	caption.text=text;caption_time=3.5

func startle(text: String) -> void:
	whisper(text);scare_flash=0.38;overlay.color.a=0.2
	if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.82,0.36)
	if game.third_person!=null and game.third_person.has_method("shake"):game.third_person.shake(0.07,0.2)
	impact.pitch_scale=randf_range(0.72,1.08);impact.position=game.player.position+Vector3(0,1,-2);impact.play()
	for lamp in polish_node.spots if polish_node!=null else []:
		if lamp.global_position.distance_to(game.player.global_position)<18:lamp.light_energy*=0.12

func update(delta: float) -> void:
	var frozen: bool=game.paused or game.editor.active
	footsteps.stream_paused=frozen;impact.stream_paused=frozen
	caption.visible=not game.editor.active
	update_maze_shadow(delta,frozen)
	if game.death!=null and game.death.active:return
	if frozen or not enabled:return
	scare_clock+=delta
	if scare_flash>0:
		scare_flash=maxf(0,scare_flash-delta);overlay.color.a=0.2*(scare_flash/0.38)
		if scare_flash<=0:
			overlay.color.a=0
			if polish_node!=null:
				for i in range(mini(polish_node.spots.size(),original_energies.size())):polish_node.spots[i].light_energy=original_energies[i]
	caption_time=maxf(0,caption_time-delta)
	if caption_time<=0:caption.text=""
	# The silence sensor is a readable challenge: random scares never interrupt it.
	if game.silence!=null and game.silence.inside() and game.silence.closed.count(true)==2:
		footsteps.stop(); impact.stop(); silhouette.hide(); apparition_time=0
		return
	var p: Vector3=game.player.position-game.puzzle.origin
	if game.puzzle.solved and p.z< -16 and p.z> -30 and absf(p.x)<10 and not fired.has("silhouette"):
		fired["silhouette"]=true;silhouette.show();apparition_time=7
		whisper("[Une silhouette se tient au fond de la salle.]")
	if apparition_time>0:
		apparition_time-=delta;silhouette.animate(delta,0)
		var direction: Vector3=apparition_origin+Vector3(0,2,0)-game.camera.global_position
		if apparition_time<=0 or direction.length()<5 or (apparition_time<5 and (-game.camera.global_basis.z).dot(direction.normalized())<0.15):
			silhouette.hide();apparition_time=0
	if game.puzzle.solved and p.z< -24 and p.z> -39 and absf(p.x)<10 and not fired.has("pursuit"):
		fired["pursuit"]=true
		footsteps.position=game.player.position+game.player.global_basis.z*5;footsteps.play()
		whisper("[Des pas rapides, juste derrière toi.]")
	if footsteps.playing:
		var direction: Vector3=footsteps.position-game.camera.global_position
		if (-game.camera.global_basis.z).dot(direction.normalized())>0.65:footsteps.stop()
	if game.labyrinth.inside() and not fired.has("pipes"):
		fired["pipes"]=true;impact.position=game.player.position+Vector3(3,2,-3);impact.play()
		whisper("[Trois coups dans les conduites. Puis plus rien.]")
	if game.arrived and not game.puzzle.solved and game.feeding.inside() and p.z < -4 and p.z > -10 and not fired.has("fungus_blink"):
		fired["fungus_blink"]=true;startle("[Le champignon vient de cligner. Il n'avait pas d'yeux.]");game.atmosphere.glow.light_energy=8.0
	if game.puzzle.solved and p.z < -11 and p.z > -23 and not fired.has("galleries_breath") and scare_clock>4:
		fired["galleries_breath"]=true
		var breath:=AudioStreamPlayer3D.new();breath.stream=preload("res://audio/respiration_spores.wav");breath.volume_db=-5;breath.pitch_scale=0.62;breath.unit_size=6;breath.max_distance=18;breath.position=game.player.position+game.camera.global_basis.z*3;add_child(breath);breath.play();whisper("[Une respiration lente colle à ta nuque.]")
	if game.combat.inside() and game.combat.equipped and not fired.has("far_impact") and scare_clock>7:
		fired["far_impact"]=true;impact.position=game.combat.origin+Vector3(0,2,-25);impact.pitch_scale=0.48;impact.play();whisper("[Quelque chose frappe derrière la porte du fond.]")
	if game.combat.inside() and game.combat.equipped and not fired.has("cage"):
		fired["cage"]=true;impact.position=game.combat.origin+Vector3(9,1,-20);impact.pitch_scale=0.7;impact.play()
		whisper("[Une tôle se tord au fond de la fosse.]")

func build_maze_shadow() -> void:
	maze_shadow=preload("res://shadow_actor.gd").new();maze_shadow.name="Ombre_du_labyrinthe";add_child(maze_shadow)
	maze_shadow.build();shadow_eyes.assign(maze_shadow.eyes);maze_shadow.hide()
	shadow_sound=AudioStreamPlayer3D.new()
	var chase: AudioStreamWAV=preload("res://audio/poursuite.wav").duplicate()
	chase.loop_mode=AudioStreamWAV.LOOP_FORWARD;chase.loop_begin=0;chase.loop_end=int(chase.get_length()*chase.mix_rate)
	shadow_sound.stream=chase
	shadow_sound.pitch_scale=0.55;shadow_sound.volume_db=-19;shadow_sound.unit_size=5;shadow_sound.max_distance=20;add_child(shadow_sound)
	style_maze_shadow(0)

func maze_shadow_level() -> int:
	if game == null or game.labyrinth == null:return 0
	return clampi(game.labyrinth.collected.count(true),0,3)

func style_maze_shadow(level: int) -> void:
	# Each awakened node makes the thing physically harder to ignore: taller silhouette,
	# brighter eyes and a pursuit pulse that rises out of the room tone.
	var pressure: float=float(level)/3.0
	maze_shadow.scale=Vector3.ONE*(1.0+pressure*0.08)
	maze_shadow.set_pressure(level)
	shadow_sound.pitch_scale=lerpf(0.55,0.76,pressure)
	shadow_sound.volume_db=lerpf(-19,-8,pressure)

func shadow_follow_target(level: int) -> Vector3:
	# Spawn behind the player, at a safe distance and outside solid objects.
	var pressure: float=float(level)/3.0
	var backward:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
	if backward.length()<0.1:backward=Vector3(game.player.global_basis.z.x,0,game.player.global_basis.z.z).normalized()
	var side:=Vector3(game.camera.global_basis.x.x,0,game.camera.global_basis.x.z).normalized()
	var distance:=lerpf(10.5,5.0,pressure)
	var desired: Vector3=game.player.global_position+backward*distance+side*sin(scare_clock*1.7)*lerpf(1.5,0.45,pressure)
	var best:=Vector3.ZERO
	var score: float=-INF
	for y in range(game.labyrinth.N):
		for x in range(game.labyrinth.N):
			var at: Vector3=game.labyrinth.cell_at(Vector2i(x,y))
			var from_player: Vector3=at-game.player.global_position;from_player.y=0
			var d: float=from_player.length()
			if d<4.0 or d>distance*1.65 or not shadow_nav.free_at(at+Vector3.UP*0.05):continue
			var alignment: float=from_player.normalized().dot((desired-game.player.global_position).normalized())
			var candidate: float=alignment*8.0-absf(d-distance)
			if candidate>score:score=candidate;best=at
	if score==-INF:return Vector3.ZERO
	return best+Vector3(0,0.05,0)

func start_shadow(at: Vector3, level: int) -> bool:
	if shadow_safe_time>0 or not shadow_zone() or at.distance_to(game.player.position)<4.0 or not shadow_nav.free_at(at): return false
	shadow_nav.reset(); shadow_age=0; shadow_target=at
	maze_shadow.global_position=at; maze_shadow.reset_physics_interpolation(); maze_shadow.show()
	shadow_time=18.0+float(level)*4.0; shadow_follow_clock=0
	style_maze_shadow(level)
	shadow_sound.global_position=at+Vector3.UP*2; shadow_sound.stream_paused=false; shadow_sound.play()
	whisper("[L’ombre te chasse. Ne la laisse pas te toucher.]")
	return true

func escalate_maze_shadow(level: int) -> void:
	if level<=shadow_stage:return
	shadow_stage=level; style_maze_shadow(level); shadow_probe=0
	if level==0: return
	if shadow_time>0:
		# A live pursuer accelerates; it never teleports onto the player at a node.
		shadow_time=maxf(shadow_time,18.0+float(level)*4)
	elif shadow_safe_time<=0:
		var spawn:=shadow_follow_target(level)
		if spawn!=Vector3.ZERO: start_shadow(spawn,level)
	if shadow_safe_time<=0:
		whisper("[Le nœud l’a réveillée. Elle accélère.]" if level<3 else "[Les trois nœuds battent. Cours vers la sortie !]")

func shadow_clear(at: Vector3) -> bool:
	var target:=at+Vector3(0,1.7,0)
	for source in [game.interaction_origin(),game.camera.global_position]:
		var query:=PhysicsRayQueryParameters3D.create(source,target,1,[game.player.get_rid()])
		if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():return false
	return true

func try_maze_shadow() -> bool:
	var best:=Vector3.ZERO;var score: float=-INF
	var level:=maze_shadow_level()
	var pressure: float=float(level)/3.0
	for y in range(game.labyrinth.N):
		for x in range(game.labyrinth.N):
			var at: Vector3=game.labyrinth.cell_at(Vector2i(x,y))
			var distance: float=at.distance_to(game.player.global_position)
			var min_distance:=5.0 if level==0 else lerpf(4.7,3.4,pressure)
			var max_distance:=14.0 if level==0 else lerpf(12.0,7.5,pressure)
			if distance<min_distance or distance>max_distance:continue
			var direction: Vector3=(at+Vector3(0,1.7,0)-game.camera.global_position).normalized()
			var facing: float=(-game.camera.global_basis.z).dot(direction)
			if facing<0.6 or not shadow_clear(at):continue
			var candidate: float=facing*10+distance*0.15
			if level>0:
				var behind:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
				candidate+=((at-game.player.global_position).normalized().dot(behind)+1.0)*pressure*2.5
			if candidate>score:score=candidate;best=at
	if score==-INF:return false
	return start_shadow(best,level)

func shadow_zone() -> bool:
	var at: Vector3=game.player.position-game.labyrinth.origin
	return game.arrived and not game.labyrinth.complete and absf(at.x)<17.8 and at.z<0 and at.z> -36 and absf(at.y)<5

func shadow_can_catch() -> bool:
	if game.death==null or game.death.active or not enabled or game.paused or game.editor.active or game.front_end.active or game.finished: return false
	if not shadow_zone() or not maze_shadow.visible or shadow_time<=0 or shadow_safe_time>0 or shadow_age<SHADOW_WARMUP: return false
	var distance: Vector3=game.player.global_position-maze_shadow.global_position
	if Vector2(distance.x,distance.z).length()>SHADOW_REACH or absf(distance.y)>1.2: return false
	# Use the character, not the third-person camera, to check actual contact.
	var ray:=PhysicsRayQueryParameters3D.create(maze_shadow.global_position+Vector3.UP*1.2,game.player.global_position+Vector3.UP*1.2,1,[game.player.get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func update_maze_shadow(delta: float,frozen: bool) -> void:
	shadow_sound.stream_paused=frozen
	var level:=maze_shadow_level()
	if not enabled or not shadow_zone() or game.finished:
		maze_shadow.hide(); shadow_sound.stop(); shadow_time=0; shadow_wait=6; shadow_stage=-1
		shadow_age=0; shadow_safe_time=6; shadow_target=Vector3.ZERO; shadow_nav.reset(); return
	if frozen or game.paused or game.editor.active or game.front_end.active or (game.death!=null and game.death.active):
		maze_shadow.visible=shadow_time>0 and not game.editor.active
		return
	if shadow_safe_time>0:
		shadow_safe_time=maxf(0,shadow_safe_time-delta); shadow_wait=maxf(0,shadow_wait-delta)
		maze_shadow.hide(); shadow_sound.stop(); return
	escalate_maze_shadow(level)
	if shadow_time>0:
		maze_shadow.show(); shadow_time=maxf(0,shadow_time-delta); shadow_age+=delta
		if shadow_can_catch(): game.death.begin(); return
		var direction: Vector3=game.player.global_position-maze_shadow.global_position
		maze_shadow.rotation.y=atan2(direction.x,direction.z)
		maze_shadow.rotation.z=sin(shadow_age*2)*0.045
		var previous: Vector3=maze_shadow.global_position
		if shadow_age>=SHADOW_WARMUP:
			maze_shadow.global_position=shadow_nav.step(maze_shadow.global_position,game.player.global_position,SHADOW_SPEEDS[level],delta)
			shadow_sound.global_position=maze_shadow.global_position+Vector3.UP*2
		maze_shadow.animate(delta,previous.distance_to(maze_shadow.global_position)/maxf(delta,0.001))
		maze_shadow.scale=Vector3.ONE*(1.0+float(level)/3.0*0.08+sin(scare_clock*5)*0.012)
		if shadow_can_catch(): game.death.begin(); return
		if shadow_time<=0:
			maze_shadow.hide(); shadow_sound.stop(); shadow_wait=lerpf(8.0,3.0,float(level)/3.0)
		return
	shadow_wait=maxf(0,shadow_wait-delta)
	if shadow_wait>0:return
	shadow_probe-=delta
	if shadow_probe<=0:
		shadow_probe=0.7
		if not try_maze_shadow():
			var spawn:=shadow_follow_target(level)
			if spawn!=Vector3.ZERO:start_shadow(spawn,level)
