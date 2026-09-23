extends Node3D
## Two permanent valve closures, then three seconds of stillness on the sensor.
## Uses gameplay input/physics, never the microphone or the audio volume.
const HOLD_SECONDS := 3.0
const FONT = preload("res://fonts/Signaletique.ttf")
var game: Node3D
var origin: Vector3
var pad_position: Vector3
var closed := [false, false]
var solved := false
var opened := 0.0
var quiet_time := 0.0
var settle_time := 0.0
var movement_cooldown := 0.0
var last_position := Vector3.ZERO
var notice := ""
var notice_time := 0.0
var gate: MeshInstance3D
var wheels: Array[Node3D] = []
var valve_labels: Array[Label3D] = []
var indicators: Array[MeshInstance3D] = []
var pumps: Array[AudioStreamPlayer3D] = []
var wheel_angles := [0.0, 0.0]
var pad_ring: MeshInstance3D
var progress_lights: Array[MeshInstance3D] = []
var door_label: Label3D
var mechanism: AudioStreamPlayer3D
var amber: StandardMaterial3D
var green: StandardMaterial3D
var dark: StandardMaterial3D
var metal: StandardMaterial3D
var clock := 0.0

func box_mesh(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size=size
	return game.atmosphere.form(parent,mesh,at,Vector3.ONE,mat)

func solid_box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D=game.box(at,size,Color.WHITE)
	node.reparent(self); node.material_override=mat
	return node

func label(parent: Node3D, words: String, at: Vector3, size: int=42) -> Label3D:
	var sign:=Label3D.new(); sign.text=words; sign.font=FONT; sign.font_size=size
	sign.pixel_size=0.0038; sign.position=at; sign.modulate=Color("dfede5")
	sign.outline_size=4; sign.outline_modulate=Color("09191b"); sign.shaded=false
	parent.add_child(sign)
	return sign

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh:=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius
	mesh.height=height; mesh.radial_segments=24
	return game.atmosphere.form(parent,mesh,at,Vector3.ONE,mat)

func ring(parent: Node3D, at: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var mesh:=TorusMesh.new(); mesh.inner_radius=inner; mesh.outer_radius=outer
	mesh.rings=32; mesh.ring_segments=8
	return game.atmosphere.form(parent,mesh,at,Vector3.ONE,mat)

func _ready() -> void:
	game=get_parent(); origin=game.puzzle.origin+Vector3(0,0,-26)
	last_position=game.player.position; pad_position=origin+Vector3(0,0.025,-10.6)
	amber=game.atmosphere.luminous(Color("e8a456"),1.1)
	green=game.atmosphere.luminous(Color("6cd9bd"),1.2)
	dark=game.material(Color("152527")); metal=game.material(Color("526862"))
	metal.metallic=0.65; metal.roughness=0.48
	build_valve(origin+Vector3(-8.6,0,4),0)
	build_valve(origin+Vector3(8.6,0,-6),1)
	build_door()
	mechanism=AudioStreamPlayer3D.new(); mechanism.unit_size=6; mechanism.max_distance=18
	mechanism.volume_db=-11; add_child(mechanism)
	restore([false,false],false)

func build_valve(at: Vector3, index: int) -> void:
	var root:=Node3D.new(); root.position=at; root.name="Vanne_%d" % (index+1); add_child(root)
	solid_box(at+Vector3(0,0.85,0),Vector3(1.7,1.7,1.05),metal)
	box_mesh(root,Vector3(0,0.16,0),Vector3(2,0.3,1.4),dark)
	box_mesh(root,Vector3(0,1.15,0.56),Vector3(1.45,1.0,0.06),dark)
	for x in [-0.48,0.48]:
		cylinder(root,Vector3(x,2.3,-0.25),0.13,2.8,metal)
		for y in [1.4,2.6,3.5]: ring(root,Vector3(x,y,-0.25),0.14,0.19,dark)
	var bridge:=cylinder(root,Vector3(0,3.7,-0.25),0.13,1.2,metal); bridge.rotation.z=PI/2
	var wheel:=Node3D.new(); wheel.position=Vector3(0,1.32,0.73); root.add_child(wheel); wheels.append(wheel)
	var rim:=ring(wheel,Vector3.ZERO,0.32,0.40,amber); rim.rotation.x=PI/2
	for i in range(3):
		var spoke:=box_mesh(wheel,Vector3.ZERO,Vector3(0.68,0.06,0.065),metal); spoke.rotation.z=i*PI/3
	var hub:=cylinder(wheel,Vector3.ZERO,0.10,0.17,metal); hub.rotation.x=PI/2
	box_mesh(root,Vector3(0,2.17,0.42),Vector3(1.85,0.67,0.10),dark)
	valve_labels.append(label(root,"VANNE %02d\nEN PRESSION" % (index+1),Vector3(0,2.2,0.49),35))
	indicators.append(box_mesh(root,Vector3(0,1.79,0.58),Vector3(0.60,0.06,0.055),amber))
	# Floor markers lead into the side aisles without adding floating HUD icons.
	for z in [1.25,1.65,2.05]: box_mesh(root,Vector3(0,0.018,z),Vector3(0.72,0.012,0.08),amber)
	var lamp:=OmniLight3D.new(); lamp.position=Vector3(0,2.5,1.2); lamp.light_color=Color("cdd6bc")
	lamp.light_energy=1.1; lamp.omni_range=4; lamp.distance_fade_enabled=true; lamp.distance_fade_begin=20
	lamp.add_to_group("nacre_dynamic_light"); lamp.set_meta("nacre_light_priority",2); root.add_child(lamp)
	var pump:=AudioStreamPlayer3D.new(); pump.position=Vector3(0,1.4,0)
	var stream: AudioStreamOggVorbis=preload("res://audio/ambiance_machines.ogg").duplicate(); stream.loop=true
	pump.stream=stream; pump.unit_size=5; pump.max_distance=20; pump.volume_db=-60
	pump.pitch_scale=0.84 if index==0 else 1.12; pump.set_meta("nacre_ambience",true)
	root.add_child(pump); pumps.append(pump)

func build_door() -> void:
	gate=solid_box(origin+Vector3(0,2.25,-14.78),Vector3(4.02,4.5,0.38),metal)
	gate.name="Porte_du_labyrinthe"
	for y in [-1.8,-1.2,-0.6,0,0.6,1.2,1.8]:
		box_mesh(gate,Vector3(0,y,0.205),Vector3(3.82,0.045,0.035),dark)
	for x in [-1.85,1.85]: box_mesh(gate,Vector3(x,0,0.21),Vector3(0.08,4.32,0.04),amber)
	box_mesh(self,origin+Vector3(0,3.05,-14.48),Vector3(3.3,1.02,0.13),dark)
	door_label=label(self,"",origin+Vector3(0,3.26,-14.39),37)
	for i in range(3):
		progress_lights.append(box_mesh(self,origin+Vector3((i-1)*0.8,2.77,-14.39),Vector3(0.69,0.095,0.035),dark))
	cylinder(self,pad_position,1.25,0.018,dark)
	pad_ring=ring(self,pad_position+Vector3(0,0.018,0),1.10,1.17,amber)
	for z in [0.9,1.35,1.8]: box_mesh(self,pad_position+Vector3(0,0.014,z),Vector3(0.10,0.012,0.28),amber)
	label(self,"DEUX VANNES À FERMER\nPUIS 3 SECONDES IMMOBILE\nDANS LE CERCLE",origin+Vector3(3.75,1.9,-14.45),37)
	box_mesh(self,origin+Vector3(3.75,1.9,-14.50),Vector3(2.95,0.85,0.055),dark)

func inside() -> bool:
	var at: Vector3=game.player.position-origin
	return game.arrived and absf(at.x)<11.4 and at.z<15.0 and at.z> -15.1 and absf(at.y)<5.8

func frozen() -> bool:
	return game.paused or game.editor.active or game.finished or (game.front_end!=null and game.front_end.active)

func quiet_phase() -> bool:
	return inside() and closed.count(true)==2 and not solved

func on_pad() -> bool:
	var at: Vector3=game.player.position-pad_position
	return Vector2(at.x,at.z).length()<1.04 and absf(at.y)<0.25 and game.player.is_on_floor()

func valve_in_reach() -> int:
	var from: Vector3=game.interaction_origin()
	for i in range(wheels.size()):
		if closed[i]: continue
		var target: Vector3=wheels[i].global_position+Vector3(0,0,0.14)
		var offset:=target-from
		if offset.length()>2.35 or (-game.camera.global_basis.z).dot(offset.normalized())<0.30: continue
		var ray:=PhysicsRayQueryParameters3D.create(from,target,1,[game.player.get_rid()])
		if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return i
	return -1

func interact() -> bool:
	if not inside() or frozen(): return false
	var index:=valve_in_reach()
	if index>=0:
		closed[index]=true; settle_time=1.0; quiet_time=0
		mechanism.global_position=wheels[index].global_position
		mechanism.stream=preload("res://audio/garde.wav"); mechanism.pitch_scale=0.62; mechanism.play()
		notice="Vanne %02d fermée. Il en reste une." % (index+1) if closed.count(true)==1 else "Les conduites se taisent. Rejoins le cercle devant la porte."
		notice_time=3
		refresh_visuals()
	return true

func restore(valves: Array, done: bool) -> void:
	closed=valves.duplicate(); solved=done; opened=1.0 if done else 0.0
	quiet_time=0; settle_time=0; movement_cooldown=0; notice_time=0; notice=""
	last_position=game.player.position
	for i in range(pumps.size()):
		pumps[i].stop(); pumps[i].volume_db=-60
		wheel_angles[i]=-PI*1.5 if closed[i] else 0.0
		wheels[i].rotation.z=wheel_angles[i]
	mechanism.stop(); refresh_visuals()

func refresh_visuals() -> void:
	gate.position.y=origin.y+2.25+opened*4.8
	for i in range(2):
		valve_labels[i].text="VANNE %02d\n%s" % [i+1,"FERMÉE" if closed[i] else "EN PRESSION"]
		indicators[i].material_override=green if closed[i] else amber
	pad_ring.material_override=green if closed.count(true)==2 else amber
	if solved: door_label.text="SILENCE ACCEPTÉ\nPASSAGE OUVERT"
	elif closed.count(true)<2: door_label.text="VERROU ACOUSTIQUE\nVANNES : %d / 2" % closed.count(true)
	elif settle_time>0: door_label.text="DÉPRESSURISATION…"
	else: door_label.text="IMMOBILE DANS LE CERCLE\n%.1f / 3 SECONDES" % quiet_time
	for i in range(progress_lights.size()):
		progress_lights[i].material_override=green if solved or quiet_time>=float(i+1) else dark

func goal() -> String:
	if solved: return "La porte est ouverte. Entre dans le labyrinthe."
	if closed.count(true)<2: return "Ferme les deux vannes bruyantes dans les alcôves : %d / 2." % closed.count(true)
	if not on_pad(): return "Rejoins le cercle lumineux devant la porte."
	if settle_time>0: return "Les conduites se vident…"
	return "Reste immobile : %.1f / 3 s. Bouger relance le décompte." % quiet_time

func update(delta: float) -> void:
	var active:=inside()
	var halted:=frozen()
	mechanism.stream_paused=halted
	for i in range(pumps.size()):
		pumps[i].stream_paused=halted
		if halted: continue
		var target: float=-10.0 if active and not closed[i] else -60.0
		pumps[i].volume_db=move_toward(pumps[i].volume_db,target,delta*60)
		if target> -60 and not pumps[i].playing: pumps[i].play()
		elif target<=-60 and pumps[i].volume_db<=-59.9: pumps[i].stop()
	if halted: return
	clock+=delta; notice_time=maxf(0,notice_time-delta); settle_time=maxf(0,settle_time-delta)
	for i in range(wheels.size()):
		wheel_angles[i]=move_toward(wheel_angles[i],-PI*1.5 if closed[i] else 0.0,delta*5)
		wheels[i].rotation.z=wheel_angles[i]
	if solved: opened=move_toward(opened,1.0,delta/2.2)
	var displacement: Vector3=game.player.position-last_position; last_position=game.player.position
	if not active: quiet_time=0; movement_cooldown=0; refresh_visuals(); return
	var input_move:=Input.get_vector("left","right","forward","back").length()>0.05
	var velocity: Vector3=game.player.velocity
	var moved:=Vector2(displacement.x,displacement.z).length()>0.003 or Vector2(velocity.x,velocity.z).length()>0.12
	var noisy: bool=input_move or moved or absf(velocity.y)>0.2 or Input.is_action_pressed("jump") or Input.is_action_pressed("push") or game.actions.push_time>0
	if noisy: movement_cooldown=0.4
	else: movement_cooldown=maxf(0,movement_cooldown-delta)
	if not solved:
		if closed.count(true)==2 and settle_time<=0 and on_pad() and not noisy and movement_cooldown<=0:
			quiet_time=minf(HOLD_SECONDS,quiet_time+delta)
			if quiet_time>=HOLD_SECONDS:
				solved=true; notice="Le verrou cède. Le labyrinthe t'attend."; notice_time=4
				mechanism.global_position=gate.position; mechanism.stream=preload("res://audio/choc_metal.wav")
				mechanism.pitch_scale=0.68; mechanism.play(); game.voice.say("victoire")
		else: quiet_time=0
	refresh_visuals()
	game.hud.text="CHAMBRE 02 — LE SILENCE\nVannes fermées : %d / 2" % closed.count(true)
	game.prompt.text=goal()
	var target:=valve_in_reach()
	if target>=0: game.prompt.text=game.controls.key("interact")+" — Fermer la vanne %02d" % (target+1)
	elif notice_time>0: game.prompt.text=notice
