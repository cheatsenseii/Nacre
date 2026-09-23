extends Node3D
# Low-frequency cinematic horror events. Cosmetic only: no damage, locks or progression changes.
var game: Node3D
var rng:=RandomNumberGenerator.new()
var ready:=false
var clock:=0.0
var tension:=0.0
var event_wait:=20.0
var glimpse_time:=0.0
var sound_time:=0.0
var door_time:=0.0
var light_time:=0.0
var shadow: Node3D
var breath: AudioStreamPlayer3D
var steps: AudioStreamPlayer3D
var knock: AudioStreamPlayer3D
var event_light: OmniLight3D
var door_records: Array[Dictionary]=[]
var active_door: Dictionary={}

func _ready() -> void:
	game=get_parent();rng.randomize()
	call_deferred("late_ready")

func late_ready() -> void:
	# The root creates most gameplay systems in its own _ready(), after child _ready calls.
	for i in range(8):
		await get_tree().process_frame
		if game.player!=null and game.scares!=null and game.horrors!=null:break
	if game.player==null:return
	build_shadow()
	build_audio()
	build_event_light()
	build_door_reactions()
	ready=true

func build_shadow() -> void:
	shadow=preload("res://shadow_actor.gd").new();shadow.name="Ombre_furtive_cinematique";add_child(shadow)
	shadow.build();shadow.hide()

func apparition_player(stream: AudioStream,volume: float,pitch: float) -> AudioStreamPlayer3D:
	var player:=AudioStreamPlayer3D.new();player.stream=stream;player.volume_db=volume
	player.pitch_scale=pitch;player.unit_size=4;player.max_distance=24;player.bus="Apparitions"
	add_child(player);return player

func build_audio() -> void:
	breath=apparition_player(preload("res://audio/respiration_spores.wav"),-12,0.56)
	steps=apparition_player(preload("res://audio/poursuite.wav"),-18,0.72)
	knock=apparition_player(preload("res://audio/choc_metal.wav"),-17,0.62)

func build_event_light() -> void:
	event_light=OmniLight3D.new();event_light.light_color=Color("9ebbb2")
	event_light.light_energy=0;event_light.omni_range=6;event_light.shadow_enabled=false
	event_light.add_to_group("nacre_dynamic_light");event_light.set_meta("nacre_light_priority",0);add_child(event_light)

func visual_box(parent: Node3D,at: Vector3,size: Vector3,color: Color,glow: float=0.0) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at
	node.material_override=game.atmosphere.luminous(color,glow) if glow>0 else game.material(color)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node

func decorate_gate(gate: Variant,label: String,color: Color) -> void:
	if gate==null or not (gate is Node3D):return
	var root:=Node3D.new();root.name="Reaction_%s" % label;gate.add_child(root)
	visual_box(root,Vector3(-1.72,0,0.22),Vector3(0.09,3.45,0.055),Color("202a29"))
	visual_box(root,Vector3(1.72,0,0.22),Vector3(0.09,3.45,0.055),Color("202a29"))
	visual_box(root,Vector3(0,1.72,0.22),Vector3(3.5,0.10,0.055),Color("303936"))
	visual_box(root,Vector3(0,1.72,0.26),Vector3(0.42,0.08,0.035),color,0.75)
	var lamp:=OmniLight3D.new();lamp.position=Vector3(0,1.65,0.42);lamp.light_color=color
	lamp.light_energy=0.08;lamp.omni_range=2.8;lamp.shadow_enabled=false;root.add_child(lamp)
	door_records.append({"gate":gate,"root":root,"lamp":lamp})

func build_door_reactions() -> void:
	decorate_gate(game.silence.gate if game.silence!=null else null,"silence",Color("d8a34f"))
	decorate_gate(game.labyrinth.exit_gate if game.labyrinth!=null else null,"labyrinthe",Color("9a302b"))
	decorate_gate(game.combat.exit_gate if game.combat!=null else null,"combat",Color("b44932"))
	decorate_gate(game.torture.gate if game.torture!=null else null,"torture",Color("8aaa63"))
	decorate_gate(game.horrors.gate if game.horrors!=null else null,"horreurs",Color("9b4a42"))

func progression_tension() -> float:
	var value:=0.08
	if game.puzzle!=null and game.puzzle.solved:value+=0.10
	if game.labyrinth!=null:value+=0.055*game.labyrinth.collected.count(true)
	if game.labyrinth!=null and game.labyrinth.complete:value+=0.08
	if game.combat!=null and game.combat.equipped:value+=0.06
	if game.combat!=null and game.combat.won:value+=0.08
	if game.simon!=null and game.simon.won:value+=0.07
	if game.torture!=null and game.torture.completed:value+=0.12
	if game.horrors!=null:value+=0.18*clampf(game.horrors.fear_weight,0,1)
	return clampf(value,0.08,0.78)

func blocked_by_scripted_horror() -> bool:
	if not game.arrived or game.paused or game.editor.active or game.front_end.active or game.finished:return true
	if game.health<=0 or (game.death!=null and game.death.active):return true
	if game.scares==null or not game.scares.enabled:return true
	if game.silence!=null and game.silence.quiet_phase():return true
	if game.labyrinth!=null and game.labyrinth.inside() and game.scares.shadow_time>0:return true
	if game.horrors!=null and game.horrors.inside():return true
	return false

func horizontal(vector: Vector3) -> Vector3:
	var result:=Vector3(vector.x,0,vector.z)
	return result.normalized() if result.length()>0.01 else Vector3.FORWARD

func ground_candidate(candidate: Vector3) -> Variant:
	var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*3.0,candidate-Vector3.UP*4.0,1,[game.player.get_rid()])
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<0.65:return null
	var at: Vector3=hit.position+Vector3.UP*0.04
	var sight:=PhysicsRayQueryParameters3D.create(game.camera.global_position,at+Vector3.UP*1.55,1,[game.player.get_rid()])
	if not game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():return null
	return at

func try_shadow_glimpse() -> bool:
	# Never competes with the maze pursuer or the scripted horror-room apparition.
	if game.labyrinth!=null and game.labyrinth.inside():return false
	var forward:=horizontal(-game.camera.global_basis.z);var right:=horizontal(game.camera.global_basis.x)
	var first_side: float=-1.0 if rng.randf()<0.5 else 1.0
	for side in [first_side,-first_side]:
		for distance in [7.5,6.0,5.0]:
			var candidate:=game.player.global_position+forward*distance+right*side*rng.randf_range(2.4,4.4)
			var grounded: Variant=ground_candidate(candidate)
			if grounded==null:continue
			shadow.global_position=grounded;shadow.look_at(Vector3(game.player.global_position.x,shadow.global_position.y+1.2,game.player.global_position.z),Vector3.UP)
			shadow.reset_physics_interpolation();shadow.show();glimpse_time=rng.randf_range(0.65,1.15)
			breath.global_position=shadow.global_position+Vector3.UP*1.4;breath.pitch_scale=rng.randf_range(0.48,0.62);breath.play()
			if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.10+0.10*tension,0.16)
			return true
	return false

func sound_position(behind: bool=true) -> Vector3:
	var forward:=horizontal(-game.camera.global_basis.z);var right:=horizontal(game.camera.global_basis.x)
	var direction:=-forward if behind else forward
	return game.player.global_position+direction*rng.randf_range(3.0,6.0)+right*rng.randf_range(-3.0,3.0)+Vector3.UP*rng.randf_range(0.4,1.8)

func play_directional_sound() -> void:
	if rng.randf()<0.55:
		steps.global_position=sound_position(true);steps.pitch_scale=rng.randf_range(0.62,0.82);steps.play();sound_time=1.6
	else:
		breath.global_position=sound_position(true);breath.pitch_scale=rng.randf_range(0.48,0.68);breath.play();sound_time=1.8

func nearest_door(max_distance: float=13.0) -> Dictionary:
	var best: Dictionary={};var distance:=max_distance
	for record in door_records:
		var gate: Node3D=record.gate
		if not is_instance_valid(gate):continue
		var current:=gate.global_position.distance_to(game.player.global_position)
		if current<distance:distance=current;best=record
	return best

func react_door() -> bool:
	var record:=nearest_door()
	if record.is_empty():return false
	active_door=record;door_time=0.75
	var gate: Node3D=record.gate
	knock.volume_db=-17;knock.global_position=gate.global_position+Vector3.UP*0.6
	knock.pitch_scale=rng.randf_range(0.48,0.72);knock.play()
	return true

func light_stutter() -> void:
	event_light.global_position=game.player.global_position+Vector3.UP*3.5
	event_light.light_color=Color("8faeaa") if rng.randf()<0.65 else Color("bd735c")
	light_time=0.55
	knock.volume_db=-22;knock.global_position=sound_position(false)
	knock.pitch_scale=rng.randf_range(0.42,0.58);knock.play()

func schedule_next() -> void:
	var pressure:=clampf(tension,0,1)
	event_wait=rng.randf_range(lerpf(22.0,11.0,pressure),lerpf(36.0,20.0,pressure))

func trigger_event() -> void:
	var roll:=rng.randf()
	var done:=false
	if roll<0.28:done=try_shadow_glimpse()
	elif roll<0.58:play_directional_sound();done=true
	elif roll<0.82:done=react_door()
	else:light_stutter();done=true
	if not done:play_directional_sound()
	schedule_next()

func update_transients(delta: float) -> void:
	if glimpse_time>0:
		glimpse_time=maxf(0,glimpse_time-delta);shadow.animate(delta,clampi(int(tension*3.0),0,2))
		shadow.scale=Vector3.ONE*(1.0+0.035*sin(clock*7.0))
		if glimpse_time<=0:shadow.hide()
	if sound_time>0:
		sound_time=maxf(0,sound_time-delta)
		if sound_time<=0:steps.stop()
	if door_time>0 and not active_door.is_empty():
		door_time=maxf(0,door_time-delta)
		var root: Node3D=active_door.root;var lamp: OmniLight3D=active_door.lamp
		if is_instance_valid(root):
			var amount:=door_time/0.75
			root.position.x=sin(clock*47.0)*0.025*amount
			root.rotation.z=sin(clock*39.0)*0.012*amount
		if is_instance_valid(lamp):lamp.light_energy=0.08+0.5*amount*absf(sin(clock*31.0))
		if door_time<=0:
			if is_instance_valid(root):root.position=Vector3.ZERO;root.rotation=Vector3.ZERO
			if is_instance_valid(lamp):lamp.light_energy=0.08
			active_door={}
	if light_time>0:
		light_time=maxf(0,light_time-delta)
		event_light.light_energy=(0.12+0.55*tension)*absf(sin(clock*54.0))
	else:event_light.light_energy=0

func _process(delta: float) -> void:
	if not ready:return
	clock+=delta;tension=lerpf(tension,progression_tension(),1.0-exp(-delta*0.8))
	var frozen:=blocked_by_scripted_horror()
	for player in [breath,steps,knock]:player.stream_paused=game.paused or game.editor.active
	if frozen:
		shadow.hide();event_light.light_energy=0
		return
	update_transients(delta)
	event_wait=maxf(0,event_wait-delta)
	if event_wait<=0 and glimpse_time<=0 and door_time<=0 and light_time<=0:trigger_event()
