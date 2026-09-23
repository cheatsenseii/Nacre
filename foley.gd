extends Node
var game: Node
var step: AudioStreamPlayer
var motion: AudioStreamPlayer
var distance := 0.0
var last := Vector3.ZERO
var grounded := false
var last_vertical := 0.0
var variation := 0
var volume := -6.0
var banks := {}
var bags := {}
var previous := {}
var last_surface := "dalle"
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	game=get_parent();process_physics_priority=25;last=game.player.position;rng.randomize()
	step=AudioStreamPlayer.new();step.max_polyphony=2;add_child(step)
	motion=AudioStreamPlayer.new();add_child(motion)
	for surface in ["dalle","eau","organique"]:
		var bank: Array[AudioStream]=[]
		for i in range(6):bank.append(load("res://audio/steps/%s_%02d.wav" % [surface,i+1]))
		banks[surface]=bank
	# Old footstep preferences are migrated by AudioMix into the visible Pas slider.

func surface_at(at: Vector3) -> String:
	if game.labyrinth.inside():return "organique"
	for puddle in get_tree().get_nodes_in_group("nacre_wet_surface"):
		var local: Vector3=puddle.to_local(at)
		if absf(local.y)<0.45 and Vector2(local.x,local.z).length()<1.05:return "eau"
	return "dalle"

func next_step(surface: String) -> AudioStream:
	if not bags.has(surface) or bags[surface].is_empty():
		var order: Array[int]=[0,1,2,3,4,5]
		# Local RNG keeps audio variation independent from puzzle randomness.
		for i in range(5,0,-1):
			var j:=rng.randi_range(0,i);var swap:=order[i];order[i]=order[j];order[j]=swap
		if order[0]==int(previous.get(surface,-1)):
			var swap:=order[0];order[0]=order[1];order[1]=swap
		bags[surface]=order
	var index: int=bags[surface].pop_front()
	previous[surface]=index
	return banks[surface][index]

func play_step(surface: String, speed: float) -> void:
	last_surface=surface;variation+=1
	step.stream=next_step(surface)
	step.pitch_scale=rng.randf_range(0.97,1.03)
	var run_gain:=2.0 if speed>3.2 else 0.0
	step.volume_db=volume+run_gain-(10.0 if game.actions.crouched else 0.0)+rng.randf_range(-0.6,0.4)
	step.play()

func _physics_process(_delta: float) -> void:
	var position: Vector3=game.player.position
	var now: bool=game.player.is_on_floor()
	var offset:=position-last;last=position
	if game.paused or game.editor.active or game.front_end.active or game.finished or game.sliding or offset.length()>3 or volume<=-40:
		step.stop();motion.stop();distance=0;grounded=now;last_vertical=0;return
	var landed:=now and not grounded and last_vertical< -2.5
	if landed:
		motion.stream=preload("res://audio/reception.wav")
		motion.volume_db=volume+clampf((-last_vertical-5.0)*0.6,-3,3)
		motion.pitch_scale=1;motion.play();distance=0
	elif not now and grounded and game.player.velocity.y>1:
		motion.stream=preload("res://audio/saut_tissu.wav");motion.volume_db=volume-1;motion.play()
	if now and not landed:
		var speed:=Vector2(game.player.velocity.x,game.player.velocity.z).length()
		var stride:=0.75 if game.actions.crouched else (1.4 if speed>3.2 else 1.15)
		distance+=Vector2(offset.x,offset.z).length()
		if distance>=stride:
			distance=fmod(distance,stride)
			play_step(surface_at(position),speed)
	grounded=now;last_vertical=game.player.velocity.y
