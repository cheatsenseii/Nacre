extends Node3D
const COLORS := [Color("db554c"),Color("5b9fd5"),Color("d9b858"),Color("a470c5")]
const SYMBOLS := ["▲","●","◆","✚"]
var game: Node
var origin: Vector3
var pads: Array[MeshInstance3D]=[]
var tones: Array[AudioStreamWAV]=[]
var speaker: AudioStreamPlayer3D
var eye: MeshInstance3D
var gate: MeshInstance3D
var sequence: Array[int]=[]
var round_size:=2
var cursor:=0
var phase:="idle"
var timer:=0.0
var flash_time:=0.0
var lit:=-1
var won:=false
var opened:=0.0
var message:="Approche des quatre symboles. Observe, puis reproduis l’ordre."

func block(at: Vector3,size: Vector3,color: Color) -> void:
	var node: MeshInstance3D=game.box(origin+at,size,color);node.reparent(self)

func _ready() -> void:
	game=get_parent();origin=game.combat.origin+Vector3(0,0,-36)
	var stone:=Color("15282c")
	block(Vector3(0,-0.25,-12),Vector3(18,0.5,24),stone)
	block(Vector3(0,5.8,-12),Vector3(18,0.4,24),stone)
	for x in [-9,9]:block(Vector3(x,2.8,-12),Vector3(0.4,5.6,24),stone)
	for z in [0,-24]:
		for x in [-5.5,5.5]:block(Vector3(x,2.8,z),Vector3(7,5.6,0.4),stone)
		block(Vector3(0,4.9,z),Vector3(4,1.4,0.4),stone)
	gate=game.box(origin+Vector3(0,2,-24),Vector3(3.9,4,0.4),Color("583244"));gate.reparent(self)
	block(Vector3(0,-0.25,-27),Vector3(8,0.5,6),stone)
	block(Vector3(0,5.8,-27),Vector3(8,0.4,6),stone)
	for x in [-4,4]:block(Vector3(x,2.8,-27),Vector3(0.4,5.6,6),stone)
	# The service corridor now leads directly into the torture room.
	for x in [-3,3]:block(Vector3(x,2.8,-30),Vector3(2,5.6,0.4),stone)
	block(Vector3(0,4.9,-30),Vector3(4,1.4,0.4),stone)
	for i in range(4):
		var at:=origin+Vector3((i-1.5)*2,1.1,-10)
		block(at-origin-Vector3(0,0.6,0),Vector3(1.35,1,1),stone)
		var pad: MeshInstance3D=game.combat.shape(self,at,Vector3(1.2,0.28,0.9),COLORS[i]);pads.append(pad)
		var label:=Label3D.new();label.text=SYMBOLS[i];label.position=at+Vector3(0,0.6,0.2);label.font_size=90;label.pixel_size=0.009;label.modulate=COLORS[i];label.set_meta("simon_symbol",true);add_child(label)
		tones.append(load("res://audio/simon_%d.wav" % (i+1)))
	var face: MeshInstance3D=game.combat.shape(self,origin+Vector3(0,3.3,-13),Vector3(2.4,2.4,0.5),Color("303537"),true)
	eye=game.combat.shape(self,face.position+Vector3(0,0,0.28),Vector3(1.3,0.65,0.2),Color("e2ad72"),true)
	game.combat.shape(self,face.position+Vector3(0,0,0.42),Vector3(0.15,0.57,0.09),Color.BLACK,true)
	for x in [-6,6]:
		var light:=OmniLight3D.new();light.position=origin+Vector3(x,3.6,-10);light.light_color=Color("7a9aab");light.light_energy=1.3;light.omni_range=13;add_child(light)
		light.add_to_group("nacre_dynamic_light");light.set_meta("nacre_light_priority",1)
	speaker=AudioStreamPlayer3D.new();speaker.position=origin+Vector3(0,2,-10);speaker.unit_size=8;speaker.max_distance=28;speaker.volume_db=-10;add_child(speaker)
	game.puzzle.label("CHAMBRE 05 / LA MÉMOIRE DU MAL\nObserve les symboles et écoute les notes.\nVise un symbole et utilise Interagir pour le reproduire.",origin+Vector3(0,4.9,-11),38)

func inside() -> bool:
	var p: Vector3=game.player.position-origin
	return game.arrived and absf(p.x)<9 and p.z<0 and p.z> -30 and absf(p.y)<6

func target_pad() -> int:
	for i in range(4):
		var target:=pads[i].global_position+Vector3(0,0.3,0)
		var from: Vector3=game.interaction_origin()
		var direction:=target-from
		if direction.length()>3 or (-game.camera.global_basis.z).dot(direction.normalized())<0.7:continue
		var query:=PhysicsRayQueryParameters3D.create(from,target,1,[game.player.get_rid()])
		if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():return i
	return -1

func glow(index: int) -> void:
	lit=index;flash_time=0.4;speaker.stream=tones[index];speaker.play()

func replay() -> void:
	cursor=0;phase="show";timer=0.8;message="SIMON : Observe. %d signes. Ne te trompe pas." % round_size

func choose(index: int) -> void:
	if phase!="input" or flash_time>0 or index<0 or index>3:return
	glow(index)
	if index!=sequence[cursor]:
		phase="retry";timer=1.6;message="SIMON : Faux… Regarde encore. Même séquence."
		if game.has_method("pulse_post_fx"):game.pulse_post_fx(0.58,0.26)
		if game.third_person!=null and game.third_person.has_method("shake"):game.third_person.shake(0.045,0.14)
		return
	cursor+=1
	if cursor<round_size:return
	if round_size==5:
		won=true;phase="won";message="SIMON : Tu peux passer… Je retiens ton visage."
	else:
		round_size+=1;phase="next";timer=1.5;message="Bien. Un signe de plus…"

func interact() -> bool:
	if not inside():return false
	if game.paused or game.editor.active:return true
	choose(target_pad());return true

func restore(done: bool) -> void:
	won=done;phase="won" if done else "idle";round_size=2;cursor=0;timer=0;flash_time=0;lit=-1;sequence.clear();speaker.stop();opened=1 if done else 0
	gate.position.y=origin.y+2+opened*4.4
	message="SIMON : Le passage est ouvert." if done else "Approche des quatre symboles. Observe, puis reproduis l’ordre."

func update(delta: float) -> void:
	var active:=inside()
	speaker.stream_paused=game.paused or game.editor.active or not active
	if game.paused or game.editor.active:return
	if not active:
		if phase not in ["idle","won"]:phase="resume";speaker.stop();lit=-1;flash_time=0
		return
	if phase=="resume":replay()
	if phase=="idle" and game.player.position.distance_to(origin+Vector3(0,0,-9))<6:
		var rng:=RandomNumberGenerator.new();rng.randomize()
		for i in range(5):sequence.append(rng.randi_range(0,3))
		replay()
	flash_time=maxf(0,flash_time-delta)
	if flash_time==0:lit=-1
	for i in range(4):
		var mat: StandardMaterial3D=pads[i].material_override
		mat.emission_enabled=true;mat.emission=COLORS[i];mat.emission_energy_multiplier=1.8 if lit==i else 0.08
	timer-=delta
	if phase=="show" and timer<=0:
		if cursor<round_size:glow(sequence[cursor]);cursor+=1;timer=0.85
		else:phase="input";cursor=0;message="À toi. Reproduis les %d signes dans le même ordre." % round_size
	elif phase in ["next","retry"] and timer<=0:replay()
	if won:opened=move_toward(opened,1,delta*0.5);gate.position.y=origin.y+2+opened*4.4
	game.hud.text="LA MÉMOIRE DU MAL — %d / 4 manches" % (round_size-1)
	game.prompt.text=message
	if phase=="input" and target_pad()>=0:game.prompt.text=game.controls.key("interact")+" — "+SYMBOLS[target_pad()]+"   •   Signe %d / %d" % [cursor+1,round_size]
