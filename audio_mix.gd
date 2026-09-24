extends Node
## A small offline mixer: clear dialogue, room ambience, bounded one-shot pools.
const SETTINGS := "user://audio_mix.cfg"
const CONTROL_BUSES := ["Master", "Musique", "Ambiances", "Bruitages", "Voix", "Pas"]
const TITLES := ["Volume général", "Musique", "Ambiances", "Effets et combats", "Voix", "Pas du personnage"]
const DEFAULTS := [100.0, 85.0, 75.0, 95.0, 100.0, 85.0]
const CUES := {
	"hit": [preload("res://audio/impact_chair_1.wav"), preload("res://audio/impact_chair_2.wav"), preload("res://audio/impact_chair_3.wav")],
	"parry": [preload("res://audio/parade.wav")], "block": [preload("res://audio/garde.wav")],
	"hurt": [preload("res://audio/joueur_blesse.wav")], "death": [preload("res://audio/creature_chute.wav")],
	"warning": [preload("res://audio/creature_alerte_1.wav"), preload("res://audio/creature_alerte_2.wav"), preload("res://audio/creature_alerte_3.wav")],
	"drip": [preload("res://audio/goutte_1.wav"), preload("res://audio/goutte_2.wav"), preload("res://audio/goutte_3.wav")],
	"pipe": [preload("res://audio/choc_metal.wav")]
}
const GAINS := {"hit": -5.0, "parry": -5.0, "block": -7.0, "hurt": -4.0, "death": -8.0, "warning": -7.0, "drip": -15.0, "pipe": -22.0}
var game: Node
var levels := {}
var quiet_mode := false
var reverb: AudioEffectReverb
var night_index := -1
var pool: Array[AudioStreamPlayer3D] = []
var ambience: Array[AudioStreamPlayer] = []
var voice_sources: Array[Node] = []
var routed: Array[Node] = []
var ui_focus: AudioStreamPlayer
var ui_accept: AudioStreamPlayer
var music_duck := 0.0
var ambience_duck := 0.0
var ambient_wait := 8.0
var occlusion_wait := 0.0
var cooldowns := {}
var choices := {}
var paused_sources := {}
var last_position := Vector3.ZERO
var rng := RandomNumberGenerator.new()

func ensure_bus(bus_name: String, send: String = "Master") -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	if bus_name != "Master": AudioServer.set_bus_send(index, send)
	return index

func effect_index(bus: int, effect_name: String) -> int:
	for i in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus,i).resource_name == effect_name: return i
	return -1

func install_buses() -> void:
	for bus in ["Musique", "Ambiances", "Bruitages", "Voix", "Interface"]: ensure_bus(bus)
	ensure_bus("Decor", "Bruitages")
	ensure_bus("Pas", "Bruitages")
	ensure_bus("Apparitions", "Bruitages")
	var effects := ensure_bus("Decor", "Bruitages")
	var found := effect_index(effects,"NacreRoom")
	if found < 0:
		reverb = AudioEffectReverb.new()
		reverb.resource_name = "NacreRoom"
		reverb.dry = 1.0; reverb.wet = 0.13; reverb.room_size = 0.68
		reverb.damping = 0.72; reverb.predelay_msec = 19; reverb.hipass = 0.35
		AudioServer.add_bus_effect(effects,reverb)
	else: reverb = AudioServer.get_bus_effect(effects,found)
	var voices := ensure_bus("Voix")
	if effect_index(voices,"NacreVoiceFilter") < 0:
		var filter := AudioEffectHighPassFilter.new()
		filter.resource_name = "NacreVoiceFilter"; filter.cutoff_hz = 85
		AudioServer.add_bus_effect(voices,filter)
		var compression := AudioEffectCompressor.new()
		compression.resource_name = "NacreVoiceLevel"
		compression.threshold = -22; compression.ratio = 2.2; compression.gain = 1.0
		compression.attack_us = 7000; compression.release_ms = 135
		AudioServer.add_bus_effect(voices,compression)
	var master := AudioServer.get_bus_index("Master")
	night_index = effect_index(master,"NacreNight")
	if night_index < 0:
		var compression := AudioEffectCompressor.new()
		compression.resource_name = "NacreNight"
		compression.threshold = -24; compression.ratio = 3.0; compression.gain = 2
		compression.attack_us = 2000; compression.release_ms = 180
		AudioServer.add_bus_effect(master,compression,0)
		night_index = 0

func _ready() -> void:
	game = get_parent(); process_priority = 100; rng.randomize()
	last_position = game.player.position
	install_buses()
	load_settings()
	build_players()
	route_tree(game)
	get_tree().node_added.connect(on_node_added)
	build_controls()
	apply_levels()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var existing := cfg.load(SETTINGS) == OK
	for i in range(CONTROL_BUSES.size()):
		var value: Variant = cfg.get_value("volumes",CONTROL_BUSES[i],DEFAULTS[i])
		levels[CONTROL_BUSES[i]] = clampf(float(value),0,100) if value is float or value is int else DEFAULTS[i]
	quiet_mode = cfg.get_value("mix","night",false) == true
	if not existing:
		var legacy := ConfigFile.new()
		if legacy.load("user://bruitages.cfg") == OK:
			var old_gain: Variant = legacy.get_value("sound","volume",-6.0)
			if old_gain is float or old_gain is int:
				levels["Pas"] = 0.0 if float(old_gain)<=-40 else clampf(85.0*db_to_linear(float(old_gain)+6.0),0,100)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in CONTROL_BUSES: cfg.set_value("volumes",bus,levels[bus])
	cfg.set_value("mix","night",quiet_mode)
	cfg.save(SETTINGS)

func apply_levels() -> void:
	for bus in CONTROL_BUSES:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.001,float(levels[bus])/100.0)))
		AudioServer.set_bus_mute(index,float(levels[bus]) <= 0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Interface"),-4)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Apparitions"),-6 if quiet_mode else 0)
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Master"),night_index,quiet_mode)

func build_controls() -> void:
	var heading := Label.new(); heading.text = "SON / MIXAGE"
	heading.add_theme_font_size_override("font_size",22); game.controls.panel.add_child(heading)
	var shortcut := Button.new(); shortcut.name="AudioShortcut"; shortcut.text="Son et mixage ↓"
	game.controls.panel.add_child(shortcut); game.controls.panel.move_child(shortcut,2)
	shortcut.pressed.connect(func(): game.controls.panel.get_parent().scroll_vertical=maxi(0,int(heading.position.y)-12))
	for i in range(CONTROL_BUSES.size()):
		var bus: String = CONTROL_BUSES[i]
		var row := HBoxContainer.new(); game.controls.panel.add_child(row)
		var caption := Label.new(); caption.text = TITLES[i]; caption.custom_minimum_size.x = 240; row.add_child(caption)
		var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 100; slider.step = 1
		slider.name = "Volume"+bus
		slider.value = levels[bus]; slider.custom_minimum_size = Vector2(260,26)
		slider.tooltip_text = "0 % : muet"; row.add_child(slider)
		var value := Label.new(); value.text = "%d %%" % int(slider.value); row.add_child(value)
		slider.value_changed.connect(func(amount: float): levels[bus]=amount; value.text="%d %%" % int(amount); apply_levels())
		slider.drag_ended.connect(func(_changed: bool): save_settings())
		slider.focus_exited.connect(save_settings)
	var night := CheckButton.new(); night.text = "Mode nuit : sursauts moins forts, volumes plus réguliers"
	night.button_pressed = quiet_mode; game.controls.panel.add_child(night)
	night.toggled.connect(func(value: bool): quiet_mode=value; apply_levels(); save_settings())
	var reset := Button.new(); reset.text = "Rétablir le mixage conseillé"
	game.controls.panel.add_child(reset)
	reset.pressed.connect(func():
		for i in range(CONTROL_BUSES.size()): levels[CONTROL_BUSES[i]]=DEFAULTS[i]
		quiet_mode=false; apply_levels(); save_settings()
		var rows: Array[Node] = game.controls.panel.get_children()
		var start := heading.get_index()+1
		for i in range(CONTROL_BUSES.size()): rows[start+i].get_child(1).value=DEFAULTS[i]
		night.button_pressed=false
	)

func build_players() -> void:
	for i in range(8):
		var player := AudioStreamPlayer3D.new(); player.bus = "Decor"
		player.unit_size = 4.0; player.max_distance = 22
		player.max_db = -2; player.attenuation_filter_cutoff_hz = 9000
		add_child(player); pool.append(player)
	for path in ["res://audio/ambiance_eau.ogg", "res://audio/ambiance_organique.ogg", "res://audio/ambiance_machines.ogg"]:
		var bed := AudioStreamPlayer.new(); bed.bus = "Ambiances"
		var stream: AudioStreamOggVorbis = load(path).duplicate(); stream.loop = true
		bed.stream = stream; bed.volume_db = -60; add_child(bed); ambience.append(bed)
	ui_focus = AudioStreamPlayer.new(); ui_focus.bus = "Interface"
	ui_focus.stream = preload("res://audio/ui_focus.wav"); ui_focus.volume_db = -4; add_child(ui_focus)
	ui_accept = AudioStreamPlayer.new(); ui_accept.bus = "Interface"
	ui_accept.stream = preload("res://audio/ui_valider.wav"); ui_accept.volume_db = -2; add_child(ui_accept)

func on_node_added(node: Node) -> void:
	if not is_ancestor_of(node): call_deferred("route_node",node)

func route_tree(node: Node) -> void:
	route_node(node)
	for child in node.get_children():
		if child != self: route_tree(child)

func route_node(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is Button and not node.has_meta("nacre_ui_sound"):
		node.set_meta("nacre_ui_sound",true)
		node.mouse_entered.connect(func(): if is_instance_valid(node) and not node.disabled and node.is_visible_in_tree(): ui_tick())
		node.focus_entered.connect(ui_tick)
		node.pressed.connect(func(): if not node.disabled: ui_accept.play())
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer3D): return
	if routed.has(node): return
	routed.append(node)
	var runner: Node = game.get_node("Bouptilop")
	if node == game.atmosphere.music: node.bus = "Musique"
	elif node in [game.voice.speaker,game.feeding.thanks,game.feeding.cry,runner.voice,game.torture.voice,game.top_npc.voice]:
		node.bus = "Voix"; voice_sources.append(node)
	elif node.has_meta("nacre_ambience") or node in [game.labyrinth.heartbeat,game.top_npc.ambience,game.horrors.hum]: node.bus = "Ambiances"
	elif node in [game.get_node("Foley").step,game.get_node("Foley").motion]: node.bus = "Pas"
	elif node.has_meta("nacre_death_sound") or node in [game.horrors.shadow_sound,game.horrors.flash_sound,game.scares.impact]: node.bus = "Apparitions"
	elif node == game.simon.speaker: node.bus = "Bruitages"
	else: node.bus = "Decor"

func ui_tick() -> void:
	if not ui_focus.playing: ui_focus.play()

func voice_active() -> bool:
	if float(levels.get("Voix",100)) <= 0: return false
	for player in voice_sources:
		if not is_instance_valid(player) or not player.playing or player.stream_paused: continue
		if player is AudioStreamPlayer3D and player.global_position.distance_to(game.camera.global_position) > player.max_distance: continue
		return true
	return false

func play_at(key: String, at: Vector3, gain: float = 0.0) -> AudioStreamPlayer3D:
	if not CUES.has(key) or game.paused or game.editor.active or game.front_end.active or game.finished: return null
	if float(cooldowns.get(key,0)) > 0: return null
	var player: AudioStreamPlayer3D = null
	for free in pool:
		if not free.playing: player=free; break
	if player == null and key not in ["drip","pipe"]:
		for candidate in pool:
			if candidate.get_meta("cue","") in ["drip","pipe"]: player=candidate; break
	if player == null: return null
	var bank: Array = CUES[key]
	var choice := rng.randi_range(0,bank.size()-1)
	if bank.size()>1 and choice==int(choices.get(key,-1)): choice=(choice+1)%bank.size()
	choices[key]=choice
	player.stop(); player.stream=bank[choice]; player.global_position=at
	player.pitch_scale=rng.randf_range(0.97,1.03)
	player.volume_db=float(GAINS[key])+clampf(gain,-8,3)
	player.set_meta("dry_gain",player.volume_db); player.set_meta("cue",key)
	player.stream_paused=false; player.play()
	cooldowns[key]=0.3 if key=="warning" else 0.07
	return player

func update_occlusion() -> void:
	for player in pool:
		if not player.playing: continue
		var ray := PhysicsRayQueryParameters3D.create(game.camera.global_position,player.global_position,1,[game.player.get_rid()])
		var blocked: bool = not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		player.volume_db=float(player.get_meta("dry_gain",-12))-(8.0 if blocked else 0.0)
		player.attenuation_filter_cutoff_hz=1900 if blocked else 9000

func reset_transients() -> void:
	for player in pool: player.stop()
	for bed in ambience: bed.stop(); bed.volume_db=-60
	cooldowns.clear(); ambient_wait=8.0; music_duck=0; ambience_duck=0
	last_position=game.player.position

func current_zone() -> String:
	if game.horrors!=null and game.horrors.inside():return "horrors"
	if game.torture!=null and game.torture.inside():return "torture"
	if game.simon!=null and game.simon.inside():return "simon"
	if game.combat!=null and game.combat.inside():return "combat"
	if game.labyrinth!=null and game.labyrinth.inside():return "labyrinth"
	if game.silence!=null and game.silence.inside():return "silence"
	if game.feeding!=null and game.feeding.inside():return "feeding"
	if game.sliding:return "slide"
	return "park"

func zone_weights(zone: String) -> Vector3:
	match zone:
		"feeding": return Vector3(0.42,0.76,0.08)
		"silence": return Vector3(0.10,0.04,0.92)
		"labyrinth": return Vector3(0.05,0.92,0.10)
		"combat": return Vector3(0.08,0.16,0.86)
		"simon": return Vector3(0.18,0.08,0.55)
		"torture": return Vector3(0.04,0.12,1.0)
		"horrors": return Vector3(0.05,0.68,0.16)
		"slide": return Vector3(0.42,0.05,0.72)
		_: return Vector3(0.88,0.06,0.14)

func update_mix(delta: float) -> void:
	var frozen: bool = game.paused or game.editor.active or game.front_end.active or game.finished
	var speaking := voice_active() and not frozen
	var intense: bool = game.horrors.intense()
	var simon_busy: bool = game.simon.inside() and game.simon.phase in ["show","input"]
	var silence_ready: bool=game.silence!=null and game.silence.quiet_phase()
	var zone:=current_zone()
	var zone_music: float=0.0
	match zone:
		"feeding": zone_music=-5.0
		"silence": zone_music=-12.0
		"labyrinth": zone_music=-10.0
		"combat": zone_music=-5.0
		"simon": zone_music=-7.0
		"torture": zone_music=-6.0
		"horrors": zone_music=-18.0
		"slide": zone_music=-8.0
	var music_target := -24.0 if intense else minf(zone_music,-11.0 if speaking else (-7.0 if simon_busy else (-4.0 if game.front_end.active else 0.0)))
	if silence_ready: music_target=minf(music_target,-28.0)
	if game.death!=null and game.death.active: music_target=minf(music_target,-24.0)
	music_duck = move_toward(music_duck,music_target,delta*(45 if music_target<music_duck else 5))
	game.atmosphere.music.volume_db=-7.0+music_duck
	var ambient_target := -15.0 if intense else (-8.0 if speaking or simon_busy else 0.0)
	ambience_duck=move_toward(ambience_duck,ambient_target,delta*(35 if ambient_target<ambience_duck else 5))
	var weights:=zone_weights(zone)
	if silence_ready: weights=Vector3.ZERO
	for i in range(ambience.size()):
		var target := -60.0 if frozen or intense or weights[i]<0.05 else -16.0+linear_to_db(weights[i])+ambience_duck
		ambience[i].volume_db=move_toward(ambience[i].volume_db,target,delta*18)
		ambience[i].stream_paused=frozen
		if target > -60 and not ambience[i].playing: ambience[i].play()
		elif target <= -60 and ambience[i].volume_db <= -59.9: ambience[i].stop()
	var wet_target:=0.13
	var room_target:=0.68
	match zone:
		"feeding": wet_target=0.16;room_target=0.72
		"silence": wet_target=0.20;room_target=0.82
		"labyrinth": wet_target=0.08;room_target=0.44
		"combat": wet_target=0.18;room_target=0.78
		"simon": wet_target=0.12;room_target=0.64
		"torture": wet_target=0.19;room_target=0.82
		"horrors": wet_target=0.24;room_target=0.90
		"slide": wet_target=0.22;room_target=0.88
	reverb.wet=move_toward(reverb.wet,wet_target,delta*0.08)
	reverb.room_size=move_toward(reverb.room_size,room_target,delta*0.2)

func _process(delta: float) -> void:
	var frozen: bool=game.paused or game.editor.active or game.front_end.active or game.finished
	for player in routed:
		if not is_instance_valid(player) or player==game.atmosphere.music: continue
		if player.has_meta("nacre_death_sound") and game.death.active:
			player.stream_paused=game.controls.is_open or game.editor.active or game.get_node("Appearance").active
			continue
		if frozen:
			if not paused_sources.has(player): paused_sources[player]=player.stream_paused
			player.stream_paused=true
		elif paused_sources.has(player):
			player.stream_paused=paused_sources[player]; paused_sources.erase(player)
	for player in pool: player.stream_paused=frozen
	update_mix(delta)
	if frozen: return
	if last_position.distance_to(game.player.position)>12: reset_transients()
	last_position=game.player.position
	for key in cooldowns: cooldowns[key]=maxf(0,float(cooldowns[key])-delta)
	occlusion_wait-=delta
	if occlusion_wait<=0: update_occlusion(); occlusion_wait=0.18
	ambient_wait-=delta
	if ambient_wait<=0 and not game.sliding and not game.horrors.intense() and not game.simon.inside() and not game.silence.quiet_phase() and not voice_active():
		var zone:=current_zone()
		var mechanical:=zone in ["silence","combat","torture"]
		if mechanical and rng.randf()<0.34:
			var pipe_offset:=Vector3(rng.randf_range(-7,7),rng.randf_range(0.8,3.2),rng.randf_range(-8,5))
			play_at("pipe",game.player.global_position+pipe_offset,-2)
			ambient_wait=rng.randf_range(10.0,18.0)
		else:
			var offset:=Vector3(rng.randf_range(-4,4),rng.randf_range(0.4,2.4),rng.randf_range(-6,4))
			play_at("drip",game.player.global_position+offset,-1 if zone in ["feeding","horrors"] else 0)
			ambient_wait=rng.randf_range(5.5,10.0) if zone in ["feeding","horrors"] else rng.randf_range(8.0,15.0)
