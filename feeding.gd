extends Node3D
var game: Node3D
var center: Vector3
var stick: Node3D
var pickup: Node3D
var monster: CharacterBody3D
var model: Node3D
var mouth: MeshInstance3D
var eyes: Node3D
var tendril: MeshInstance3D
var cap: MeshInstance3D
var thanks: AudioStreamPlayer3D
var equipped := false
var hp := 3
var health: int:
	get: return game.health if game!=null else 100
	set(value):
		if game!=null:game.health=clampi(value,0,100)
var cooldown := 0.0
var rest := 1.5
var windup := 0.0
var immunity := 0.0
var feeding_time := -1.0
var corpse_start: Vector3
var said_thanks := false
var gift_started := false
var gift_time := 0.0
var cry: AudioStreamPlayer3D
var gift: Node3D
var clock := 0.0
var subtitle: Label
var subtitle_time := 0.0

func make_stick(parent: Node3D) -> Node3D:
	var node:=Node3D.new();parent.add_child(node)
	game.combat.shape(node,Vector3(0,0.45,0),Vector3(0.085,1.3,0.1),Color(0.32,0.19,0.08))
	for y in [-0.08,0.0,0.08]:game.combat.shape(node,Vector3(0,y,0),Vector3(0.105,0.05,0.12),Color(0.54,0.43,0.28))
	return node

func _ready() -> void:
	game=get_parent();center=game.atmosphere.mushroom_position
	pickup=make_stick(self);pickup.position=center+Vector3(-2.6,0.4,7.7);pickup.rotation.z=0.6
	game.puzzle.label("UN BÂTON\nPrends-le pour te défendre.",center+Vector3(-2.6,2,7.7),42)
	var light:=OmniLight3D.new();light.position=pickup.position+Vector3(0,2,0)
	light.light_color=Color(0.85,0.78,0.45);light.light_energy=1.4;light.omni_range=6;add_child(light)
	light.add_to_group("nacre_dynamic_light");light.set_meta("nacre_light_priority",2)
	stick=make_stick(game.camera);stick.position=Vector3(0.4,-0.4,-0.65);stick.rotation.z=-0.2;stick.hide()
	monster=CharacterBody3D.new();add_child(monster);monster.position=center+Vector3(4,0.05,3)
	monster.collision_layer=2;monster.collision_mask=1
	var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.45;capsule.height=1.5
	collider.shape=capsule;collider.position.y=0.75;monster.add_child(collider)
	model=preload("res://spore_creature.gd").new()
	monster.add_child(model);model.build(game,0.5)
	cap=game.atmosphere.mushroom.get_node("Chapeau")
	# The elder fungus belongs to the same damp ecosystem as the infected, but reads as ancient and intelligent.
	if cap is MeshInstance3D:
		var elder_mat:=StandardMaterial3D.new();elder_mat.albedo_color=Color("4b352d");elder_mat.roughness=0.92
		preload("res://material_detail.gd").apply(elder_mat,false);cap.material_override=elder_mat
	mouth=game.combat.shape(self,center+Vector3(0,1.65,0.81),Vector3(1.05,0.65,0.18),Color("090807"),true);mouth.hide()
	eyes=Node3D.new();add_child(eyes);eyes.hide()
	for x in [-0.36,0.36]:
		game.combat.shape(eyes,center+Vector3(x,2.2,0.74),Vector3(0.38,0.27,0.15),Color("4a4435"),true)
		var eye: MeshInstance3D=game.combat.shape(eyes,center+Vector3(x,2.2,0.82),Vector3(0.18,0.13,0.06),Color("c9c2a4"),true)
		eye.material_override=game.atmosphere.luminous(Color("b7aa78"),0.28)
		game.combat.shape(eyes,center+Vector3(x,2.2,0.856),Vector3(0.045,0.1,0.025),Color("11100d"),true)
	tendril=game.combat.shape(self,Vector3.ZERO,Vector3.ONE,Color("3d4632"),true);tendril.hide()
	thanks=AudioStreamPlayer3D.new();thanks.position=center+Vector3(0,2,0)
	thanks.stream=preload("res://audio/champignon_merci.wav");thanks.pitch_scale=0.82;thanks.unit_size=10;thanks.max_distance=35;add_child(thanks)
	# La récompense n'est plus un cri incompréhensible : le grand champignon
	# savoure son repas et révèle enfin ce que sont les petits Bouptilop.
	cry=AudioStreamPlayer3D.new();cry.name="Voix_delice";cry.stream=preload("res://audio/voix_delice.wav")
	cry.position=center+Vector3(0,2,0);cry.unit_size=12;cry.max_distance=40;cry.volume_db=-3;add_child(cry)
	gift=Node3D.new();add_child(gift);gift.hide()
	for i in range(7):
		var seed: MeshInstance3D=game.combat.shape(gift,Vector3(sin(i*2.4)*0.22,cos(i*1.7)*0.18,sin(i)*0.15),Vector3.ONE*0.12,Color("8d9562"),true)
		seed.material_override=game.atmosphere.luminous(Color("8d9562"),0.65)
	var layer:=CanvasLayer.new();layer.layer=7;add_child(layer)
	subtitle=Label.new();subtitle.position=Vector2(80,550);subtitle.size=Vector2(1120,72)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_font_size_override("font_size",22)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_color_override("font_outline_color",Color.BLACK);subtitle.add_theme_constant_override("outline_size",6)
	layer.add_child(subtitle)
	game.voice.register_spatial("mushroom_thanks",thanks,"LE CHAMPIGNON : « Merci de m'avoir nourri… Tu peux passer. »",subtitle)
	game.voice.register_spatial("mushroom_delice",cry,"LE GRAND CHAMPIGNON : « Quel délice ! Cela faisait si longtemps que je n'avais mangé d'autre que mes enfants… »",subtitle)

func say(key: String) -> void:
	if game.voice.enabled:game.voice.say(key)
	else:
		# Keep the story readable when character voices are disabled.
		subtitle.text=game.voice.captions[key];subtitle_time=8

func inside() -> bool:
	var p: Vector3=game.player.position-center
	return game.arrived and absf(p.x)<13.5 and p.z> -11 and p.z<11 and absf(p.y)<6

func interact() -> bool:
	if not inside() or game.paused or game.editor.active:return false
	if not equipped and not game.puzzle.solved and game.interaction_origin().distance_to(pickup.position+Vector3(0,0.45,0))<2.7:
		equipped=true;pickup.hide();rest=2
	return true

func attack() -> bool:
	if not inside() or not equipped or game.puzzle.solved:return false
	if game.paused or game.editor.active or cooldown>0 or hp<=0:return true
	cooldown=0.45;game.combat.slash_audio.stream=preload("res://audio/baton_souffle.wav")
	game.combat.slash_audio.pitch_scale=randf_range(0.95,1.04);game.combat.slash_audio.volume_db=-8;game.combat.slash_audio.play()
	var aim: Vector3=monster.position+Vector3(0,0.85,0)-game.interaction_origin()
	if aim.length()<3 and (-game.camera.global_basis.z).dot(aim.normalized())>0.15 and game.combat.unobstructed(monster.position+Vector3(0,0.85,0),monster):
		hp-=1;windup=0;rest=1.1;model.rotation.x=0.4
		if game.audio_mix!=null:
			game.audio_mix.play_at("hit",monster.position+Vector3.UP*0.7,-2)
			if hp<=0:game.audio_mix.play_at("death",monster.position+Vector3.UP*0.3)
		game.experience.hit(hp<=0)
		if hp==0:
			monster.collision_layer=0;monster.velocity=Vector3.ZERO;corpse_start=monster.position
			model.rotation.z=PI/2;feeding_time=0
	return true

func restore(done: bool,has_stick: bool) -> void:
	game.voice.cancel_line("mushroom_thanks");game.voice.cancel_line("mushroom_delice")
	equipped=has_stick;health=100;hp=0 if done else 3;feeding_time=-1;said_thanks=done
	# Consuming the spores later must never replay the original gift on load.
	gift_started=done;gift_time=4 if gift_started else 0;gift.hide();cry.stop()
	windup=0;rest=2;cooldown=0;immunity=0;subtitle_time=0;subtitle.text="";thanks.stop()
	monster.velocity=Vector3.ZERO;model.scale=Vector3.ONE;monster.rotation=Vector3.ZERO
	monster.position=center+Vector3(4,0.05,3);monster.scale=Vector3.ONE;model.rotation=Vector3.ZERO
	monster.visible=not done;monster.collision_layer=0 if done else 2
	pickup.visible=not equipped and not done;mouth.hide();mouth.scale=Vector3(1.05,0.65,0.18);tendril.hide();eyes.visible=done;cap.rotation=Vector3(0,0,-0.1)

func update(delta: float) -> void:
	var active:=inside()
	stick.visible=active and equipped and not game.puzzle.solved and not game.editor.active
	thanks.stream_paused=game.paused or game.editor.active
	cry.stream_paused=game.paused or game.editor.active
	subtitle.visible=not game.editor.active and not game.paused and active
	if game.paused or game.editor.active:return
	clock+=delta;cooldown=maxf(0,cooldown-delta);immunity=maxf(0,immunity-delta)
	subtitle_time=maxf(0,subtitle_time-delta)
	if subtitle_time==0 and game.voice.current not in ["mushroom_thanks","mushroom_delice"]:subtitle.text=""
	stick.rotation.z=-0.2+sin(cooldown/0.45*PI)*1.5
	if feeding_time>=0 and not game.puzzle.solved:
		feeding_time+=delta;mouth.show();eyes.show();tendril.show()
		cap.rotation.z=-0.1+sin(feeding_time*3)*0.045
		var target:=mouth.position
		monster.position=corpse_start.lerp(target,smoothstep(0,4,feeding_time))
		monster.scale=Vector3.ONE*maxf(0.01,1-smoothstep(3.5,5.5,feeding_time))
		var vector: Vector3=monster.position-mouth.position
		tendril.position=(monster.position+mouth.position)/2
		tendril.scale=Vector3(0.18,0.18,maxf(0.05,vector.length()))
		if vector.length()>0.05:tendril.look_at(monster.position,Vector3.UP)
		mouth.scale.y=0.7+0.25*sin(feeding_time*7)
		if feeding_time>=6 and not said_thanks:
			monster.hide();mouth.hide();tendril.hide();cap.rotation.z=-0.1
			said_thanks=true
			say("mushroom_thanks")
		if said_thanks:
			mouth.hide();tendril.hide();monster.hide();cap.rotation.z=-0.1
		if feeding_time>=10:game.puzzle.solved=true;game.puzzle.step=3
	if game.puzzle.solved and game.puzzle.opened>=0.95 and not gift_started:
		gift_started=true;gift_time=0
		say("mushroom_delice")
		game.inventory.grant_spores()
	if gift_started and gift_time<4:
		gift_time+=delta
		mouth.visible=gift_time<2.8
		mouth.scale.y=0.6+absf(sin(gift_time*17))*0.7
		cap.rotation.z=-0.1+(sin(gift_time*8)*0.035 if gift_time<2.8 else 0.0)
		gift.visible=gift_time<1.3
		gift.position=(center+Vector3(0,2.1,1.8)).lerp(game.camera.global_position-game.camera.global_basis.z*0.4,clampf(gift_time/1.3,0,1))
		gift.rotation.y=gift_time*4
	if said_thanks:
		var speaking: bool=(thanks.playing or cry.playing) and not game.paused
		mouth.visible=speaking
		if speaking:
			mouth.scale.y=0.5+absf(sin(clock*12))*0.55
			cap.rotation.z=-0.1+sin(clock*5)*0.025
	if active and equipped and hp>0 and not game.puzzle.solved:
		model.rotation.x=lerpf(model.rotation.x,0.0,minf(1,delta*6))
		model.scale.y=1+sin(clock*3)*0.06
		var offset: Vector3=game.player.position-monster.position;offset.y=0
		if offset.length()>0.1:monster.rotation.y=atan2(-offset.x,-offset.z)
		rest=maxf(0,rest-delta)
		if windup>0:
			windup=maxf(0,windup-delta);model.rotation.x=-0.3
			if windup==0:
				rest=2.5
				if offset.length()<1.8 and immunity<=0 and game.combat.unobstructed(monster.position+Vector3(0,0.85,0),monster):
					health-=8;immunity=1
					if game.audio_mix!=null:game.audio_mix.play_at("hurt",game.interaction_origin(),-2)
					if game.third_person!=null and game.third_person.has_method("shake"):game.third_person.shake(0.08,0.16)
					if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.45,0.2)
					if health<=0:
						game.death.begin("creature");return
		elif rest<=0 and offset.length()<1.6:windup=0.9
		else:
			monster.velocity=offset.normalized()*0.8 if rest<=0 else Vector3.ZERO
			monster.velocity.y=-3;monster.move_and_slide()
	if not active:return
	game.hud.text="CHAMBRE 01 — LE REPAS\nPrends le temps de regarder autour de toi."
	game.prompt.text="Approche du bâton éclairé, près de l'arrivée."
	if not equipped and not game.puzzle.solved and game.interaction_origin().distance_to(pickup.position+Vector3(0,0.45,0))<2.7:game.prompt.text=game.controls.key("interact")+" — Prendre le bâton"
	if equipped:
		game.hud.text="LE REPAS • Monstre : %d / 3" % hp
		game.prompt.text=game.controls.key("push")+" — Frapper au bâton. Trois coups suffisent."
	if feeding_time>=0 and not game.puzzle.solved:game.prompt.text="Le champignon se réveille… Regarde ce qu'il fait du monstre."
	if game.puzzle.solved:
		game.hud.text="LE CHAMPIGNON EST RASSASIÉ"
		game.prompt.text="Il t'ouvre le passage. Rejoins la porte au fond."
