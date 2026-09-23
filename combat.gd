extends Node3D
var game: Node3D
var origin: Vector3
var sword: Node3D
var pickup: Node3D
var enemies: Array[CharacterBody3D] = []
var charging := false
var charge := 0.0
var guard_time := 0.0
var guarding := false
var stamina := 100.0
var health: int:
	get: return game.health if game!=null else 100
	set(value):
		if game!=null:game.health=clampi(value,0,100)
var equipped := false
var won := false
var clock := 0.0
var wake_time := 0.0
var navigation: AStarGrid2D
var navigation_ready := false
var cell_cache: Dictionary = {}
var route_searches := 0
var cooldown := 0.0
var immunity := 0.0
var notice := ""
var notice_time := 0.0
var exit_gate: MeshInstance3D
var opened := 0.0
var slash_audio: AudioStreamPlayer
var hurt_overlay: ColorRect

func block(at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var node: MeshInstance3D=game.box(at,size,color)
	node.reparent(self)
	return node

func shape(parent: Node3D,at: Vector3,size: Vector3,color: Color,orb: bool=false) -> MeshInstance3D:
	var mesh: Mesh
	if orb:
		var sphere:=SphereMesh.new();sphere.radius=0.5;sphere.height=1;mesh=sphere
	else:mesh=BoxMesh.new()
	return game.atmosphere.form(parent,mesh,at,size,game.material(color))

func make_sword(parent: Node3D) -> Node3D:
	var model:=Node3D.new();parent.add_child(model)
	shape(model,Vector3(0,0.7,0),Vector3(0.12,1.35,0.035),Color(0.7,0.82,0.84))
	shape(model,Vector3.ZERO,Vector3(0.55,0.07,0.09),Color(0.55,0.32,0.12))
	shape(model,Vector3(0,-0.18,0),Vector3(0.085,0.32,0.085),Color(0.13,0.065,0.04))
	return model

func _ready() -> void:
	game=get_parent()
	origin=game.labyrinth.origin+Vector3(0,0,-44)
	var stone:=Color(0.1,0.14,0.16)
	block(origin+Vector3(0,-0.25,-14),Vector3(24,0.5,28),stone)
	block(origin+Vector3(0,6,-14),Vector3(24,0.4,28),stone)
	for x in [-12,12]:block(origin+Vector3(x,3,-14),Vector3(0.4,6,28),stone)
	for z in [0,-28]:
		for x in [-7,7]:block(origin+Vector3(x,3,z),Vector3(10,6,0.4),stone)
		block(origin+Vector3(0,5,z),Vector3(4,2,0.4),stone)
	exit_gate=block(origin+Vector3(0,2,-28),Vector3(3.95,4,0.35),Color(0.35,0.12,0.09))
	block(origin+Vector3(0,-0.25,-32),Vector3(8,0.5,8),stone)
	block(origin+Vector3(0,6,-32),Vector3(8,0.4,8),stone)
	for x in [-4,4]:block(origin+Vector3(x,3,-32),Vector3(0.4,6,8),stone)
	for x in [-3,3]:block(origin+Vector3(x,3,-36),Vector3(2,6,0.4),stone)
	block(origin+Vector3(0,5,-36),Vector3(4,2,0.4),stone)
	# Side screen conceals the blade from the doorway; accessible around both ends.
	block(origin+Vector3(-8.5,1.4,-5),Vector3(0.35,2.8,4.5),Color(0.21,0.12,0.1))
	pickup=make_sword(self);pickup.position=origin+Vector3(-10,0.7,-5)
	pickup.rotation.z=-0.3
	game.puzzle.label("LE FER DORT DERRIÈRE LES TÔLES.\nNE LES RÉVEILLE PAS LES MAINS VIDES.",origin+Vector3(-6,2.8,-0.4),44)
	game.puzzle.label("CHAMBRE 04 / LA FOSSE DES RATÉS",origin+Vector3(0,4.5,-1),48)
	game.puzzle.label("SCEAU DES TROIS BÊTES",origin+Vector3(0,4.5,-27.7),54)
	game.puzzle.label("CHAMBRE 05 — LA MÉMOIRE DU MAL",origin+Vector3(0,4.8,-35.7),38)
	for x in [-10,10]:
		for z in [-10,-19,-25]:
			block(origin+Vector3(x,0.55,z),Vector3(1,1.1,1.8),Color(0.19,0.22,0.2))
	for at in [Vector3(-10,3,-5),Vector3(0,5,-12),Vector3(7,4,-23),Vector3(0,4,-32)]:
		var light:=OmniLight3D.new();light.position=origin+at
		light.light_color=Color(0.35,0.75,0.72) if at.x<0 else Color(1,0.3,0.13)
		light.light_energy=2;light.omni_range=14;add_child(light)
		light.add_to_group("nacre_dynamic_light");light.set_meta("nacre_light_priority",1)
	for i in range(3):spawn_enemy(i)
	sword=make_sword(game.camera);sword.position=Vector3(0.4,-0.48,-0.72)
	sword.rotation=Vector3(-0.3,0,-0.2);sword.scale=Vector3.ONE*0.6;sword.hide()
	slash_audio=AudioStreamPlayer.new();slash_audio.stream=preload("res://audio/epee.wav");slash_audio.volume_db=-12;add_child(slash_audio)
	var layer:=CanvasLayer.new();layer.layer=4;add_child(layer)
	hurt_overlay=ColorRect.new();layer.add_child(hurt_overlay)
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;hurt_overlay.color=Color(0.6,0.02,0.01,0)

func spawn_enemy(i: int) -> void:
	var body:=CharacterBody3D.new();add_child(body);enemies.append(body)
	body.position=origin+Vector3((i-1)*6,0.02,-17-abs(i-1)*4)
	body.collision_layer=2;body.collision_mask=1
	var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=0.55;capsule.height=2.8;collider.shape=capsule;collider.position.y=1.4;body.add_child(collider)
	body.set_meta("spawn",body.position);body.set_meta("hp",3);body.set_meta("windup",0.0);body.set_meta("rest",0.0)
	var model=preload("res://spore_creature.gd").new()
	body.add_child(model);model.name="Creature";model.build(game,0.92)

func inside() -> bool:
	var p: Vector3=game.player.position-origin
	return game.arrived and p.z<0 and p.z> -36 and absf(p.x)<12 and absf(p.y)<6

func can_take_sword() -> bool:
	var target: Vector3=pickup.position+Vector3(0,0.5,0)
	if game.interaction_origin().distance_to(target)>=2.5:return false
	var ray:=PhysicsRayQueryParameters3D.create(game.interaction_origin(),target,1)
	ray.exclude=[game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func interact() -> bool:
	if not inside() or game.paused or game.editor.active:return false
	if not equipped and can_take_sword():
		equipped=true;pickup.hide();notice="Le fer chante. Défends-toi !";notice_time=4
	return true

func unobstructed(target: Vector3,enemy: CharacterBody3D) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(game.interaction_origin(),target,1)
	query.exclude=[game.player.get_rid(),enemy.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func cancel_charge() -> void:
	charging=false;charge=0;guarding=false;guard_time=0

func begin_charge() -> bool:
	if not inside() or not equipped:return false
	if game.paused or game.editor.active or cooldown>0 or guarding:return true
	charging=true;charge=0
	return true

func release_charge() -> void:
	if not charging:return
	var heavy:=charge>=0.75
	charging=false;charge=0
	attack(heavy)

func receive_strike(body: CharacterBody3D) -> void:
	if game.paused or game.editor.active or (game.death!=null and game.death.active):return
	var toward: Vector3=body.position-game.player.position;toward.y=0
	var facing: Vector3=-game.player.global_basis.z;facing.y=0
	if guarding and stamina>=25 and facing.normalized().dot(toward.normalized())>0.4:
		stamina-=25
		var perfect:=guard_time<=0.3
		body.set_meta("rest",1.8 if perfect else 0.8)
		notice="PARADE PARFAITE — contre-attaque !" if perfect else "Coup bloqué."
		notice_time=1.2;immunity=0.35
		if game.audio_mix!=null:game.audio_mix.play_at("parry" if perfect else "block",game.interaction_origin())
		return
	health-=18;immunity=0.8;hurt_overlay.color.a=0.22
	if game.audio_mix!=null:game.audio_mix.play_at("hurt",game.interaction_origin())
	if game.third_person!=null and game.third_person.has_method("shake"):game.third_person.shake(0.14,0.2)
	if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.72,0.28)
	notice="La créature te frappe : −18 PV !";notice_time=1.2
	if health<=0:game.death.begin("combat")

func attack(heavy: bool=false) -> bool:
	if not inside() or not equipped:return false
	if game.paused or game.editor.active or cooldown>0 or guarding:return true
	cooldown=0.8 if heavy else 0.55;slash_audio.stream=preload("res://audio/epee.wav")
	slash_audio.pitch_scale=0.87 if heavy else randf_range(0.97,1.03)
	slash_audio.volume_db=-7 if heavy else -9;slash_audio.play()
	var candidate: CharacterBody3D=null;var nearest:=3.0
	for body in enemies:
		if int(body.get_meta("hp"))<=0:continue
		var aim: Vector3=body.position+Vector3(0,1.5,0)-game.interaction_origin()
		if aim.length()<nearest and (-game.camera.global_basis.z).dot(aim.normalized())>0.45 and unobstructed(body.position+Vector3(0,1.5,0),body):
			candidate=body;nearest=aim.length()
	if candidate!=null:
		var hp:=maxi(0,int(candidate.get_meta("hp"))-(2 if heavy else 1));candidate.set_meta("hp",hp)
		game.experience.hit(hp<=0)
		if game.audio_mix!=null:
			game.audio_mix.play_at("hit",candidate.position+Vector3.UP,2.0 if heavy else 0.0)
			if hp<=0:game.audio_mix.play_at("death",candidate.position+Vector3.UP*0.3)
		candidate.set_meta("rest",1.1 if heavy else 0.7);candidate.set_meta("windup",0.0)
		var away: Vector3=candidate.position-game.player.position;away.y=0
		candidate.velocity=away.normalized()*(3.5 if heavy else 1.8)
		candidate.move_and_slide()
		candidate.get_node("Creature").rotation.x=0.45
		candidate.get_node("Creature").scale.x=0.8
		notice="COUP CHARGÉ — 2 dégâts" if heavy else "Touché !";notice_time=0.6
		if hp<=0:
			candidate.hide();candidate.collision_layer=0
	return true

func reset_fight() -> void:
	wake_time=0
	cancel_charge();stamina=100;health=100;immunity=2;cooldown=0
	if game.has_method("teleport_player"):game.teleport_player(origin+Vector3(0,0.05,-2))
	else:
		game.player.position=origin+Vector3(0,0.05,-2);game.player.velocity=Vector3.ZERO
	for body in enemies:
		body.position=body.get_meta("spawn");body.velocity=Vector3.ZERO
		body.set_meta("hp",3);body.set_meta("windup",0.0);body.set_meta("rest",1.0);body.show();body.collision_layer=2
	notice="Tu reprends ton souffle à l'entrée. Épée conservée, combat réinitialisé.";notice_time=4

func update(delta: float) -> void:
	var active:=inside()
	sword.visible=active and equipped and not game.editor.active
	if game.paused or game.editor.active:
		cancel_charge();return
	var was_guarding:=guarding
	guarding=active and equipped and not charging and cooldown<=0 and Input.is_action_pressed("parry") and stamina>=25
	guard_time=guard_time+delta if guarding and was_guarding else 0.0
	if not guarding:stamina=minf(100,stamina+delta*22)
	if charging:
		if not active:cancel_charge()
		else:
			charge=minf(1.2,charge+delta)
			if not Input.is_action_pressed("push"):release_charge()
	clock+=delta;cooldown=maxf(0,cooldown-delta);immunity=maxf(0,immunity-delta);notice_time=maxf(0,notice_time-delta)
	hurt_overlay.color.a=maxf(0,hurt_overlay.color.a-delta*0.8)
	sword.rotation.z=-0.2+sin((1-cooldown/0.55)*PI)*1.8 if cooldown>0 else -0.2
	if guarding:sword.rotation.z=1.2
	elif charging:sword.rotation.z=-0.2-minf(1,charge)*0.9
	if not active:return
	if not navigation_ready:build_navigation()
	wake_time+=delta
	var alive:=0
	for i in range(enemies.size()):
		var body:=enemies[i]
		if int(body.get_meta("hp"))<=0:continue
		alive+=1
		var model: Node3D=body.get_node("Creature")
		model.scale.x=lerpf(model.scale.x,1,minf(1,delta*7))
		model.rotation.z=sin(clock*3+i)*0.1;model.scale.y=1+0.05*sin(clock*4+i)
		if not equipped and wake_time<4:continue
		var offset: Vector3=game.player.position-body.position;offset.y=0
		var distance:=offset.length()
		if distance>0.1:body.rotation.y=atan2(-offset.x,-offset.z)
		model.rotation.x=lerpf(model.rotation.x,0.0,minf(1,delta*8))
		var rest:=maxf(0,float(body.get_meta("rest"))-delta);body.set_meta("rest",rest)
		var windup:=float(body.get_meta("windup"))
		if windup>0:
			windup=maxf(0,windup-delta);body.set_meta("windup",windup)
			model.rotation.x=-0.35*sin(windup/0.5*PI)
			model.right_arm.rotation.x=-0.8*sin(windup/0.5*PI)
			if windup==0:
				body.set_meta("rest",1.2)
				if distance<2.15 and immunity<=0 and unobstructed(body.position+Vector3(0,1.5,0),body):
					receive_strike(body)
					if game.death.active:return
					if immunity>=2:return
		elif rest<=0 and distance<1.85:
			body.set_meta("windup",0.5)
			if game.audio_mix!=null:game.audio_mix.play_at("warning",body.position+Vector3.UP*1.3)
		else:
			model.right_arm.rotation.x=lerpf(model.right_arm.rotation.x,0,minf(1,delta*8))
			body.velocity=chase_direction(body,delta)*(2.0+i*0.12) if rest<=0 and distance>1.6 else Vector3.ZERO
			body.velocity.y=-3;body.move_and_slide()
			body.position.x=clampf(body.position.x,origin.x-11,origin.x+11)
			body.position.z=clampf(body.position.z,origin.z-26,origin.z-1)
	if alive==0:
		if not won:won=true;game.voice.say("victoire")
		opened=minf(1,opened+delta/2);exit_gate.position.y=origin.y+2+opened*4.5
	game.hud.text="CHAMBRE 04 — LA FOSSE DES RATÉS\nGarde : %d / 100 • Créatures : %d / 3" % [int(stamina),alive]
	game.prompt.text="Les créatures arrivent ! Trouve l'épée derrière la tôle éclairée à gauche."
	if not equipped and can_take_sword():game.prompt.text=game.controls.key("interact")+" — Prendre l'épée"
	if equipped:game.prompt.text=game.controls.key("push")+" : relâcher pour frapper / maintenir pour charger • "+game.controls.key("parry")+" : parade"
	if charging:game.prompt.text="CHARGE : %d %% — relâche pour frapper" % mini(100,int(charge/0.75*100))
	if won:game.prompt.text="Les trois bêtes sont tombées. La porte du fond est ouverte."
	if notice_time>0:game.prompt.text=notice

func build_navigation() -> void:
	cell_cache.clear()
	for enemy in enemies:enemy.set_meta("route",PackedVector2Array())
	navigation=AStarGrid2D.new()
	navigation.region=Rect2i(0,0,23,27)
	navigation.cell_size=Vector2.ONE
	navigation.offset=Vector2(origin.x-11,origin.z-27)
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	var shape:=BoxShape3D.new();shape.size=Vector3(1.1,1.7,1.1)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.exclude=[game.player.get_rid()]
	for y in range(27):
		for x in range(23):
			var at:=navigation.get_point_position(Vector2i(x,y))
			query.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,origin.y+1.2,at.y))
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():navigation.set_point_solid(Vector2i(x,y))
	navigation_ready=true

func walkable_cell(at: Vector3) -> Vector2i:
	var approximate:=Vector2i(roundi(at.x-navigation.offset.x),roundi(at.z-navigation.offset.y))
	approximate.x=clampi(approximate.x,0,22);approximate.y=clampi(approximate.y,0,26)
	if not navigation.is_point_solid(approximate):return approximate
	if cell_cache.has(approximate):return cell_cache[approximate]
	var best:=approximate;var distance:=INF
	for y in range(27):
		for x in range(23):
			var cell:=Vector2i(x,y)
			if navigation.is_point_solid(cell):continue
			var d:=Vector2(cell).distance_squared_to(Vector2(approximate))
			if d<distance:distance=d;best=cell
	cell_cache[approximate]=best
	return best

func chase_direction(body: CharacterBody3D,delta: float) -> Vector3:
	var delay:=float(body.get_meta("route_delay",0.0))-delta
	var route: PackedVector2Array=body.get_meta("route",PackedVector2Array())
	var target:=walkable_cell(game.player.position)
	var last: Vector3=body.get_meta("last_route_position",body.position)
	var stuck:=float(body.get_meta("stuck",0.0))+delta if last.distance_to(body.position)<0.008 else 0.0
	body.set_meta("last_route_position",body.position);body.set_meta("stuck",stuck)
	if route.is_empty() or (delay<=0 and (target!=body.get_meta("route_target",Vector2i(-1,-1)) or stuck>0.8)):
		route=navigation.get_point_path(walkable_cell(body.position),target)
		route_searches+=1
		if route.size()>1:route.remove_at(0)
		body.set_meta("route_delay",0.35);body.set_meta("route_target",target);body.set_meta("stuck",0.0)
	else:body.set_meta("route_delay",delay)
	while route.size()>1 and Vector2(body.position.x,body.position.z).distance_to(route[0])<0.35:route.remove_at(0)
	body.set_meta("route",route)
	if route.is_empty():return Vector3.ZERO
	var goal:=Vector3(route[0].x,body.position.y,route[0].y)
	var heading: Vector3=(goal-body.position).normalized()
	# Separate neighbours gently without steering outside the corridor.
	var separation:=Vector3.ZERO
	for other in enemies:
		if other==body or int(other.get_meta("hp"))<=0:continue
		var apart: Vector3=body.position-other.position;apart.y=0
		if apart.length()>0.01 and apart.length()<1.1:separation+=apart.normalized()*(1.1-apart.length())
	return (heading+separation*0.45).normalized()
