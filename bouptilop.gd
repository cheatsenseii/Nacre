extends Node3D
# A brief, harmless physical encounter. Never a full-screen overlay or teleport chase.
var game: Node
var body: CharacterBody3D
var model: Node3D
var cap: Node3D
var legs: Array[Node3D]=[]
var arms: Array[Node3D]=[]
var voice: AudioStreamPlayer3D
var steps: AudioStreamPlayer3D
var caption: Label
var collider:=CapsuleShape3D.new()
var rng:=RandomNumberGenerator.new()
var active:=false
var cooldown:=12.0
var elapsed:=0.0
var step_wait:=0.0
var target:=Vector3.ZERO
var last_position:=Vector3.ZERO
var last_room:=-1
var spawn_room:=-1
var turns:=0
var repeated:=false

func _ready() -> void:
	game=get_parent();rng.randomize()
	body=CharacterBody3D.new();body.name="PetitChampignon";body.collision_layer=0;body.collision_mask=1
	add_child(body);collider.radius=0.38;collider.height=1.16
	var collision:=CollisionShape3D.new();collision.shape=collider;collision.position.y=0.60;body.add_child(collision)
	model=Node3D.new();body.add_child(model)
	var cream:=Color("d1c59a");var dark:=Color("261e26")
	game.combat.shape(model,Vector3(0,0.53,0),Vector3(0.35,0.59,0.34),cream,true)
	cap=Node3D.new();cap.name="Cap";cap.position=Vector3(0,0.85,0);model.add_child(cap)
	var hat: MeshInstance3D=game.combat.shape(cap,Vector3.ZERO,Vector3(0.96,0.36,0.84),Color("ba462f"),true)
	hat.material_override.roughness=0.46
	game.combat.shape(cap,Vector3(0,-0.09,0),Vector3(0.85,0.05,0.73),Color("dbc798"),true)
	for i in range(9):
		var a:=i*2.39996;var radius:=0.12+0.21*sqrt(float(i)/9)
		game.combat.shape(cap,Vector3(cos(a)*radius,0.17-radius*0.13,sin(a)*radius*0.8),Vector3(0.10,0.035,0.08),Color("e3d8a8"),true)
	for i in range(2):
		var side: float=-1 if i==0 else 1
		var eye: MeshInstance3D=game.combat.shape(model,Vector3(side*0.105,0.66+i*0.035,-0.163),Vector3(0.13,0.16,0.085),Color("fff2c5"),true)
		eye.material_override=game.atmosphere.luminous(Color("fff2c5"),0.35)
		game.combat.shape(model,Vector3(side*0.096,0.663+i*0.035,-0.207),Vector3(0.048,0.075,0.025),dark,true)
		var leg:=Node3D.new();leg.name="Leg_%d" % i;leg.position=Vector3(side*0.1,0.29,0);model.add_child(leg);legs.append(leg)
		game.combat.shape(leg,Vector3(0,-0.1,0),Vector3(0.075,0.24,0.08),cream,true)
		game.combat.shape(leg,Vector3(0,-0.235,-0.055),Vector3(0.16,0.09,0.23),dark,true)
		var arm:=Node3D.new();arm.name="Arm_%d" % i;arm.position=Vector3(side*0.19,0.56,0);model.add_child(arm);arms.append(arm)
		game.combat.shape(arm,Vector3(side*0.095,-0.06,0),Vector3(0.23,0.065,0.07),cream,true)
		game.combat.shape(arm,Vector3(side*0.2,-0.06,0),Vector3(0.1,0.09,0.08),cream,true)
	game.combat.shape(model,Vector3(0,0.47,-0.168),Vector3(0.19,0.22,0.065),dark,true)
	game.combat.shape(model,Vector3(0,0.415,-0.204),Vector3(0.10,0.065,0.025),Color("d87985"),true)
	voice=AudioStreamPlayer3D.new();voice.stream=preload("res://audio/bouptilop.wav")
	voice.volume_db=-4;voice.unit_size=5;voice.max_distance=22;voice.position.y=0.65;body.add_child(voice)
	steps=AudioStreamPlayer3D.new();steps.stream=preload("res://audio/pas.wav");steps.pitch_scale=1.85
	steps.volume_db=-24;steps.unit_size=3;steps.max_distance=12;body.add_child(steps)
	var layer:=CanvasLayer.new();layer.layer=6;add_child(layer)
	caption=Label.new();caption.position=Vector2(120,485);caption.size=Vector2(1040,35)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.text="« BOUPTILOP LA POULIIIIII ! »"
	caption.add_theme_font_override("font",preload("res://fonts/Signaletique.ttf"));caption.add_theme_font_size_override("font_size",23)
	caption.add_theme_color_override("font_color",Color("efe0a1"));caption.add_theme_color_override("font_outline_color",Color("172127"));caption.add_theme_constant_override("outline_size",6)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(caption)
	body.hide();caption.hide();last_position=game.player.position

func room() -> int:
	if not game.arrived:return 0
	if game.simon.inside():return 5
	if game.combat.inside():return 4
	if game.labyrinth.inside():return 3
	if game.feeding.inside():return 1
	return 2

func allowed_at(at: Vector3) -> bool:
	# Keep the entire encounter inside one of the two authorised rooms.
	var p: Vector3=at-game.feeding.center
	if room()==1:return absf(p.x)<12.7 and p.z> -10.2 and p.z<10.2 and absf(p.y)<2
	p=at-game.simon.origin
	return room()==5 and absf(p.x)<8.2 and p.z< -0.8 and p.z> -23.0 and absf(p.y)<2

func reset() -> void:
	stop();cooldown=12;last_room=-1;last_position=game.player.position

func stop() -> void:
	active=false;body.hide();voice.stop();steps.stop();caption.hide();body.velocity=Vector3.ZERO
	cooldown=rng.randf_range(45,75)

func ground(at: Vector3) -> Variant:
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.4,at-Vector3.UP*1.2,1,[game.player.get_rid(),body.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<0.85:return null
	if absf(hit.position.y-game.player.position.y)>0.5:return null
	var feet: Vector3=hit.position+Vector3.UP*0.04
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=collider;query.collision_mask=1
	query.exclude=[game.player.get_rid(),body.get_rid()];query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*0.60)
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return null
	return feet

func clear_path(a: Vector3,b: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=collider;query.collision_mask=1
	query.exclude=[game.player.get_rid(),body.get_rid()];query.transform=Transform3D(Basis.IDENTITY,a+Vector3.UP*0.60)
	query.motion=b-a
	var result:=get_world_3d().direct_space_state.cast_motion(query)
	return result.size()==2 and result[0]>=0.99

func try_spawn() -> bool:
	if room() not in [1,5] or not game.scares.enabled:return false
	if game.voice.busy():return false
	var forward: Vector3=-game.camera.global_basis.z;forward.y=0;forward=forward.normalized()
	var right:=forward.cross(Vector3.UP)
	var first_side: float=-1 if rng.randf()<0.5 else 1
	for side in [first_side,-first_side]:
		for offset in [Vector2(2.5,2.6),Vector2(3.5,2.6),Vector2(4.5,2.6),Vector2(3.5,1.0),Vector2(4.5,1.0)]:
			var a: Variant=ground(game.player.position+forward*offset.x+right*side*offset.y)
			var b: Variant=ground(game.player.position+forward*offset.x-right*side*offset.y)
			if a==null or b==null:continue
			if not allowed_at(a) or not allowed_at(b) or not clear_path(a,b):continue
			var sight:=PhysicsRayQueryParameters3D.create(game.camera.global_position,a+Vector3.UP*0.7,1,[game.player.get_rid(),body.get_rid()])
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
			body.position=a;target=b;body.velocity=Vector3.ZERO
			active=true;elapsed=0;turns=0;repeated=false;step_wait=0;spawn_room=room()
			model.scale=Vector3.ONE;body.show();voice.stream_paused=false;voice.play();caption.show()
			return true
	return false

func next_target() -> bool:
	for i in range(12):
		var angle:=rng.randf_range(0,TAU)
		var candidate: Variant=ground(game.player.position+Vector3(cos(angle),0,sin(angle))*rng.randf_range(2.5,6.0))
		if candidate==null or not allowed_at(candidate) or body.position.distance_to(candidate)<2:continue
		if clear_path(body.position+Vector3.UP*0.02,candidate):target=candidate;turns+=1;return true
	return false

func _physics_process(delta: float) -> void:
	var frozen: bool=game.paused or game.editor.active or game.front_end.active
	voice.stream_paused=frozen;steps.stream_paused=frozen
	caption.visible=active and voice.playing and not frozen
	body.visible=active and not game.editor.active and not game.front_end.active
	if room() not in [1,5] or not game.scares.enabled or game.sliding or game.health<=0:
		if active:stop()
		return
	if game.player.position.distance_to(last_position)>5:
		reset()
	last_position=game.player.position
	if frozen:return
	if active:
		if room()!=spawn_room or not allowed_at(body.position):stop();return
		elapsed+=delta
		if elapsed>=7.5:stop();return
		var direction:=target-body.position;direction.y=0
		if direction.length()<0.5 or body.is_on_wall():
			if not next_target():stop();return
			direction=target-body.position;direction.y=0
		direction=direction.normalized();body.velocity.x=direction.x*5.8;body.velocity.z=direction.z*5.8
		body.velocity.y-=18*delta;body.move_and_slide()
		body.rotation.y=lerp_angle(body.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*18))
		model.position.y=absf(sin(elapsed*19))*0.065
		cap.rotation.z=sin(elapsed*15)*0.12
		for i in range(2):
			legs[i].rotation.x=sin(elapsed*22+i*PI)*0.85
			arms[i].rotation.z=sin(elapsed*17+i*PI)*0.75
		if elapsed>3.3 and not repeated:
			repeated=true
			if not game.voice.busy():voice.play()
		if elapsed>6.9:model.scale=Vector3.ONE*maxf(0.01,(7.5-elapsed)/0.6)
		step_wait-=delta
		if step_wait<=0:steps.play();step_wait=0.13
		return
	var current:=room()
	if current!=last_room:last_room=current;cooldown=minf(cooldown,rng.randf_range(10,17))
	cooldown=maxf(0,cooldown-delta)
	if cooldown>0:return
	# Do not shout over a mission, the feeding scene, or Simon's memory sequence.
	if game.voice.busy():return
	if game.feeding.inside() and game.feeding.feeding_time>=0 and not game.puzzle.solved:return
	if game.simon.inside() and not game.simon.won:return
	if not try_spawn():cooldown=2.5
