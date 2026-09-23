extends Node3D
# A scripted quest actor, separate from Bouptilop's optional surprise encounters.
const ROUTE := [Vector3(5,0,-5),Vector3(6,0,-11),Vector3(5,0,-22),Vector3(-5,0,-22),Vector3(-6,0,-11),Vector3(-5,0,-5)]
const PULSE_DURATION := 1.8
var game: Node
var origin: Vector3
var actor: CharacterBody3D
var model: Node3D
var cap: Node3D
var restraints: Node3D
var console_position: Vector3
var seat_position: Vector3
var specimen_position: Vector3
var specimen: Node3D
var gate: MeshInstance3D
var bulbs: Array[MeshInstance3D]=[]
var spore_cloud: CPUParticles3D
var spore_light: OmniLight3D
var voice: AudioStreamPlayer3D
var hiss: AudioStreamPlayer3D
var latch: AudioStreamPlayer3D
var chase_steps: AudioStreamPlayer3D
var captured := false
var doses := 0
var completed := false
var pulse_left := 0.0
var capture_left := 0.0
var capture_from := Vector3.ZERO
var opened := 0.0
var clock := 0.0
var chase_clock := 0.0
var route_index := 1
var voice_wait := 1.5
var step_wait := 0.0
var was_inside := false
var message := ""
var message_time := 0.0
var neon: SpotLight3D
var lighting_settings: Node

func block(at: Vector3,size: Vector3,color: Color,solid: bool = true) -> MeshInstance3D:
	var node: MeshInstance3D=game.box(origin+at,size,color,solid)
	node.reparent(self)
	return node

func form(at: Vector3,size: Vector3,color: Color,orb: bool = false) -> MeshInstance3D:
	return game.combat.shape(self,origin+at,size,color,orb)

func _ready() -> void:
	game=get_parent();origin=game.simon.origin+Vector3(0,0,-30)
	for child in game.get_children():
		if child.get_script()==preload("res://exploration.gd"):lighting_settings=child
	console_position=origin+Vector3(0,1.25,-13.4)
	seat_position=origin+Vector3(0,0.9,-17)
	specimen_position=origin+Vector3(-6.9,1.1,-3.6)
	build_room()
	build_apparatus()
	build_actor()
	build_effects()
	restore(false,0)

func build_room() -> void:
	var stone:=Color("253636")
	var details: Node=game.get_node("Realism")
	var floor_mesh:=block(Vector3(0,-0.25,-14),Vector3(22,0.5,28),stone)
	floor_mesh.material_override=details.art.surface(Color("53615c"),origin.y,true)
	block(Vector3(0,5.8,-14),Vector3(22,0.4,28),Color("1c2728"))
	for side in [-1,1]:
		var wall:=block(Vector3(side*11,2.8,-14),Vector3(0.4,5.6,28),stone)
		wall.material_override=details.art.surface(Color("4f655f"),origin.y,true)
	for z in [0,-28]:
		for x in [-6.5,6.5]:block(Vector3(x,2.8,z),Vector3(9,5.6,0.4),stone)
		block(Vector3(0,4.9,z),Vector3(4,1.4,0.4),stone)
	gate=block(Vector3(0,2,-28),Vector3(3.9,4,0.35),Color("4d6056"));gate.name="Sortie_scellee"
	block(Vector3(0,-0.25,-31),Vector3(8,0.5,6),stone)
	block(Vector3(0,5.8,-31),Vector3(8,0.4,6),stone)
	for x in [-4,4]:block(Vector3(x,2.8,-31),Vector3(0.4,5.6,6),stone)
	# The old end wall is removed: the service corridor now opens directly
	# into Chambre 07, so the horror room feels like the consequence of this one.
	# One entrance sign; objectives stay in the existing HUD.
	game.puzzle.label("CHAMBRE 06 / SALLE DE TORTURE",origin+Vector3(0,4.7,-0.35),40)
	# Empty holding cages, kept away from the chase route.
	for side in [-1,1]:
		block(Vector3(side*9.25,0.2,-21),Vector3(2.8,0.4,4),Color("25302d"))
		block(Vector3(side*9.25,3.4,-21),Vector3(2.8,0.15,4),Color("46564f"))
		for i in range(9):
			form(Vector3(side*7.9,1.85,-22.9+i*0.47),Vector3(0.055,3.1,0.055),Color("59645a"))
		# Bolted trolleys and sealed tanks along the wall.
		block(Vector3(side*9.5,0.8,-8),Vector3(1.6,1.6,2.3),Color("304b49"))
		for j in range(3):
			form(Vector3(side*9.5,1.95,-8.7+j*0.65),Vector3(0.45,0.75,0.45),Color("7d8d6a"),true)
	details.architecture(origin,10.65,-27.4,-0.6,5.4,5)
	details.flush_batches()
	details.polish.practical(origin+Vector3(-4,5.15,-6),Color("70b8ad"),2.0,15)
	details.polish.practical(origin+Vector3(1,5.15,-17),Color("d4bf81"),2.8,14)
	details.polish.practical(origin+Vector3(4,5.15,-25),Color("bc685b"),1.5,10)
	neon=details.polish.spots[-3]
	details.polish.configure_lights(details.polish)
	details.polish.apply_settings()

func build_apparatus() -> void:
	var steel:=Color("61766b");var dark:=Color("25322e")
	# The treatment seat and its overhead organic delivery pipes.
	block(Vector3(0,0.25,-17),Vector3(2.3,0.5,2.5),dark)
	block(Vector3(0,0.7,-17),Vector3(1.2,0.4,1.25),steel)
	block(Vector3(0,1.45,-17.62),Vector3(1.35,1.7,0.22),Color("524132"))
	for x in [-0.83,0.83]:
		block(Vector3(x,1,-17),Vector3(0.2,1.7,0.2),steel)
		form(Vector3(x,1.65,-16.95),Vector3(0.5,0.12,1.1),dark)
		block(Vector3(x*1.7,2.2,-17.6),Vector3(0.15,4.4,0.15),steel)
	form(Vector3(0,4.36,-17.6),Vector3(3.1,0.2,0.2),steel)
	for i in range(3):
		var x: float=(i-1)*0.48
		form(Vector3(x,3.9,-17.15),Vector3(0.085,0.95,0.085),Color("97734c"))
		form(Vector3(x,3.38,-17.15),Vector3(0.2,0.17,0.2),dark,true)
	# Console with three physical indicators, instead of another text panel.
	block(Vector3(0,0.7,-13.4),Vector3(1.8,1.4,0.85),dark)
	form(Vector3(0,1.44,-13.4),Vector3(1.95,0.12,1.0),steel)
	for i in range(3):
		bulbs.append(form(Vector3((i-1)*0.45,1.56,-13.4),Vector3(0.19,0.1,0.19),Color("658666"),true))
	# A translucent culture tank, with an emissive living core.
	var tank:=form(Vector3(3,1.7,-17.8),Vector3(1.4,3.2,1.4),Color(0.28,0.5,0.37,0.24),true)
	tank.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	form(Vector3(3,0.3,-17.8),Vector3(1.8,0.6,1.8),dark)
	var core:=form(Vector3(3,1.7,-17.8),Vector3(0.65,2.3,0.65),Color("9daa4d"),true)
	core.material_override=game.atmosphere.luminous(Color("789244"),0.5)
	for i in range(10):
		var a:=float(i)*TAU/10
		form(Vector3(3+cos(a)*0.61,0.35,-17.8+sin(a)*0.61),Vector3(0.06,0.13,0.06),steel,true)
	restraints=Node3D.new();restraints.position=seat_position;add_child(restraints)
	for y in [0.24,0.61]:
		game.combat.shape(restraints,Vector3(0,y,0.04),Vector3(1.05,0.085,0.5),dark)
	# A supply graft prevents an old save without the reward from blocking the quest.
	block(Vector3(-6.9,0.5,-3.6),Vector3(1.25,1,1.05),Color("364b42"))
	specimen=Node3D.new();specimen.position=specimen_position;add_child(specimen)
	for i in range(5):
		var at:=Vector3(sin(i*2.4)*0.3,0.15+0.1*(i%2),cos(i*2.4)*0.3)
		game.combat.shape(specimen,at-Vector3.UP*0.15,Vector3(0.05,0.35,0.05),Color("8e9661"))
		var spore: MeshInstance3D=game.combat.shape(specimen,at,Vector3(0.21,0.15,0.21),Color("b4cc68"),true)
		spore.material_override=game.atmosphere.luminous(Color("a8be59"),0.6)

func build_actor() -> void:
	actor=CharacterBody3D.new();actor.name="Bouptilop_a_capturer";actor.collision_layer=0;actor.collision_mask=1;add_child(actor)
	var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new()
	shape.radius=0.38;shape.height=1.16;collision.shape=shape;collision.position.y=0.6;actor.add_child(collision)
	model=game.get_node("Bouptilop").model.duplicate();actor.add_child(model)
	cap=model.get_node("Cap")
	voice=AudioStreamPlayer3D.new();voice.stream=preload("res://audio/bouptilop.wav")
	voice.volume_db=-10;voice.unit_size=4;voice.max_distance=25;actor.add_child(voice)
	chase_steps=AudioStreamPlayer3D.new();chase_steps.stream=preload("res://audio/pas.wav")
	chase_steps.volume_db=-24;chase_steps.pitch_scale=1.8;chase_steps.unit_size=3;chase_steps.max_distance=14;actor.add_child(chase_steps)

func build_effects() -> void:
	spore_cloud=CPUParticles3D.new();spore_cloud.position=seat_position+Vector3.UP*1.1
	spore_cloud.amount=44;spore_cloud.lifetime=0.9;spore_cloud.emitting=false
	spore_cloud.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;spore_cloud.emission_sphere_radius=0.5
	spore_cloud.direction=Vector3.DOWN;spore_cloud.spread=60;spore_cloud.gravity=Vector3(0,-0.25,0)
	spore_cloud.initial_velocity_min=0.4;spore_cloud.initial_velocity_max=1.1
	spore_cloud.scale_amount_min=0.025;spore_cloud.scale_amount_max=0.07
	var mote:=SphereMesh.new();mote.radius=0.5;mote.height=1;mote.radial_segments=6;mote.rings=3
	mote.material=game.atmosphere.luminous(Color("b2c954"),1.3);spore_cloud.mesh=mote
	spore_cloud.visibility_aabb=AABB(Vector3(-2,-3,-2),Vector3(4,5,4));add_child(spore_cloud)
	spore_light=OmniLight3D.new();spore_light.position=seat_position+Vector3.UP
	spore_light.light_color=Color("adc95f");spore_light.light_energy=0.2;spore_light.omni_range=7;add_child(spore_light)
	spore_light.add_to_group("nacre_dynamic_light");spore_light.set_meta("nacre_light_priority",2)
	hiss=AudioStreamPlayer3D.new();hiss.stream=preload("res://audio/respiration_spores.wav")
	hiss.position=seat_position;hiss.volume_db=-9;hiss.unit_size=5;hiss.max_distance=25;add_child(hiss)
	latch=AudioStreamPlayer3D.new();latch.stream=preload("res://audio/choc_metal.wav")
	latch.position=seat_position;latch.volume_db=-14;latch.unit_size=5;latch.max_distance=24;add_child(latch)

func inside() -> bool:
	var p: Vector3=game.player.position-origin
	return game.arrived and absf(p.x)<11 and p.z<=0 and p.z> -34 and absf(p.y)<6

func can_reach(at: Vector3,reach: float = 2.5) -> bool:
	var source: Vector3=game.interaction_origin()
	var direction:=at-source
	if direction.length()>reach:return false
	if (-game.camera.global_basis.z).dot(direction.normalized())<0.35:return false
	var ray:=PhysicsRayQueryParameters3D.create(source,at,1,[game.player.get_rid(),actor.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func tell(text: String) -> void:
	message=text;message_time=4

func goal() -> String:
	if completed:return "La cuve s’est tue. Traverse la porte du fond."
	if not captured:return "Attrape Bouptilop quand il reprend son souffle."
	if not game.inventory.has_spores and doses==0:return "Récupère des spores sur la greffe près de l’entrée."
	return "Active la cuve avec les spores : %d / 3 décharges." % doses

func interact() -> bool:
	if not inside():return false
	if game.paused or game.editor.active or game.front_end.active or game.finished:return true
	if not game.inventory.has_spores and doses==0 and can_reach(specimen_position+Vector3.UP*0.3):
		game.inventory.grant_spores();specimen.hide();tell("Spores du grand champignon récupérées.");return true
	if not captured:
		if can_reach(actor.global_position+Vector3.UP*0.7):
			captured=true;capture_left=0.8;capture_from=actor.position;actor.velocity=Vector3.ZERO
			voice.stop();chase_steps.stop();latch.play()
			tell("Bouptilop capturé. Rejoins la commande devant le fauteuil.")
		return true
	if completed or capture_left>0 or pulse_left>0:return true
	if not can_reach(console_position+Vector3.UP*0.4):return true
	if doses==0 and not game.inventory.consume_spores():
		tell("Il faut les spores du grand champignon. La greffe près de l’entrée en contient.");return true
	doses+=1;pulse_left=PULSE_DURATION
	if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.42+float(doses)*0.1,0.2)
	if game.third_person!=null and game.third_person.has_method("shake"):game.third_person.shake(0.035+float(doses)*0.01,0.12)
	hiss.pitch_scale=0.9+doses*0.1;hiss.play()
	voice.pitch_scale=0.74+doses*0.12;voice.volume_db=-11;voice.play()
	tell("Décharge de spores %d / 3 — Bouptilop se tord dans les sangles." % doses)
	return true

func restore(was_captured: bool,count: int) -> void:
	doses=clampi(count,0,3);captured=was_captured or doses>0;completed=doses==3
	pulse_left=0;capture_left=0;opened=1.0 if completed else 0.0;chase_clock=0;clock=0
	route_index=1;voice_wait=1.5;step_wait=0;was_inside=false;message_time=0
	actor.position=seat_position if captured else origin+Vector3(3,0.05,-6)
	actor.velocity=Vector3.ZERO;actor.rotation=Vector3.ZERO;model.position=Vector3.ZERO;model.scale=Vector3.ONE
	cap.rotation=Vector3.ZERO
	for i in range(2):
		model.get_node("Leg_%d" % i).rotation=Vector3.ZERO
		model.get_node("Arm_%d" % i).rotation=Vector3.ZERO
	gate.position.y=origin.y+2+opened*4.4
	actor.hide();restraints.visible=captured;spore_cloud.emitting=false;spore_cloud.hide();spore_light.light_energy=0.2
	for sound in [voice,hiss,latch,chase_steps]:sound.stop()
	refresh_indicators()

func refresh_indicators() -> void:
	for i in range(3):
		bulbs[i].material_override=game.atmosphere.luminous(Color("b4d36a") if i<doses else Color("374d42"),1.0 if i<doses else 0.1)

func chase(delta: float) -> void:
	chase_clock+=delta
	var tired:=fmod(chase_clock,8.0)>5.0
	var target: Vector3=origin+ROUTE[route_index]
	var direction:=target-actor.position;direction.y=0
	if direction.length()<0.6 or actor.is_on_wall():
		route_index=(route_index+1)%ROUTE.size();direction=origin+ROUTE[route_index]-actor.position;direction.y=0
	var speed:=0.9 if tired else 3.6
	direction=direction.normalized();actor.velocity.x=direction.x*speed;actor.velocity.z=direction.z*speed
	actor.velocity.y-=18*delta;actor.move_and_slide()
	actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*12))
	actor.position.x=clampf(actor.position.x,origin.x-9.8,origin.x+9.8)
	actor.position.z=clampf(actor.position.z,origin.z-26,origin.z-2)
	model.position.y=absf(sin(chase_clock*16))*0.045
	cap.rotation.z=sin(chase_clock*13)*0.09
	for i in range(2):
		model.get_node("Leg_%d" % i).rotation.x=sin(chase_clock*(9 if tired else 19)+i*PI)*0.8
		model.get_node("Arm_%d" % i).rotation.z=sin(chase_clock*12+i*PI)*0.6
	step_wait-=delta
	if step_wait<=0:chase_steps.play();step_wait=0.4 if tired else 0.17
	voice_wait-=delta
	if voice_wait<=0 and not game.voice.speaker.playing:
		voice.pitch_scale=1.0;voice.volume_db=-10;voice.play();voice_wait=11

func _physics_process(delta: float) -> void:
	update(delta)

func update(delta: float) -> void:
	var active:=inside()
	var frozen: bool=game.paused or game.editor.active or game.front_end.active or not active or game.finished
	actor.visible=active and not game.front_end.active and not game.editor.active
	specimen.visible=not game.inventory.has_spores and doses==0
	for sound in [voice,hiss,latch,chase_steps]:sound.stream_paused=frozen
	spore_cloud.speed_scale=0.0 if frozen else 1.0
	spore_cloud.visible=active and not game.editor.active
	if not active:
		if was_inside:
			for sound in [voice,hiss,latch,chase_steps]:sound.stop()
		was_inside=false;return
	if frozen:return
	was_inside=true;clock+=delta;message_time=maxf(0,message_time-delta)
	var stable: bool=lighting_settings==null or lighting_settings.stable_lighting
	neon.light_energy=2.0 if stable else (0.75 if fmod(clock,6.5)>6.15 else 1.9+sin(clock*4.3)*0.08)
	if not captured:chase(delta)
	elif capture_left>0:
		capture_left=maxf(0,capture_left-delta)
		actor.position=capture_from.lerp(seat_position,1.0-capture_left/0.8)
		actor.rotation.y=lerp_angle(actor.rotation.y,PI,minf(1,delta*10))
		model.position=Vector3.ZERO;restraints.visible=capture_left==0
	elif pulse_left>0:
		pulse_left=maxf(0,pulse_left-delta)
		model.position=Vector3(sin(clock*43)*0.035,absf(sin(clock*29))*0.04,0)
		model.scale=Vector3(1.0+sin(clock*24)*0.07,0.91+sin(clock*31)*0.08,1.0)
		cap.rotation.z=sin(clock*26)*0.22
		spore_light.light_energy=1.8 if stable else 1.8+0.3*sin(clock*19)
		if pulse_left==0:
			voice.stop();hiss.stop();model.position=Vector3.ZERO;model.scale=Vector3.ONE;cap.rotation=Vector3.ZERO
			refresh_indicators()
			if doses==3:
				completed=true;latch.play();tell("La cuve se tait. Le verrou de la sortie vient de céder.")
	else:
		actor.rotation.y=PI;model.position.y=sin(clock*2.2)*0.01
		spore_light.light_energy=0.2
	spore_cloud.emitting=pulse_left>0
	if completed:
		opened=move_toward(opened,1,delta*0.55);gate.position.y=origin.y+2+opened*4.4
		if game.player.position.z<origin.z-31.5:
			if game.horrors!=null:
				game.horrors.unlock()
			else:
				game.finished=true;game.hud.text="LE SILENCE DE BOUPTILOP\n\nFin de cet aperçu.\nR pour reprendre au dernier point.";game.prompt.text=""
	if not game.finished:
		game.hud.text="SALLE DE TORTURE"
		game.prompt.text=message if message_time>0 else goal()
		var key: String=game.controls.key("interact")
		if not captured and can_reach(actor.position+Vector3.UP*0.7):game.prompt.text=key+" — Attraper Bouptilop"
		elif captured and not completed and capture_left<=0 and pulse_left<=0 and can_reach(console_position+Vector3.UP*0.4):game.prompt.text=key+" — Charger les spores et activer la cuve" if doses==0 else key+" — Décharge suivante (%d / 3)" % doses
		elif specimen.visible and can_reach(specimen_position+Vector3.UP*0.3):game.prompt.text=key+" — Récupérer les spores du grand champignon"
