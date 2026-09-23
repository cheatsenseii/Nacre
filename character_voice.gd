extends Node
var game: Node
var speaker: AudioStreamPlayer
var subtitle: Label
var enabled := true
var used := {}
var pending: Array[String] = []
var failure_cooldown := 0.0
var victory_cooldown := 0.0
var welcome_played := false
var current := ""
const SPEECH_GAP:=0.35
var speech_gap:=0.0
var current_source: Node
var spatial_lines: Dictionary={}
var clips := {}
var captions := {
	"depart": "Bon… c'est parti.",
	"bienvenue": "Bienvenue à NACRE…",
	"prologue": "En 1998, le parc a fermé après un accident. Les bassins n'ont jamais été vidés.",
	"arrivee": "WOW ALORS ÇA C'EST DU CHAMPIGNON !!!",
	"erreur": "Non… ce n'est pas ça.",
	"victoire": "Oh yes !",
	"mission": "Mission : atteindre la dernière porte. Commence par l'entrée du toboggan.",
	"mushroom_quest": "Quête : prends le bâton, bats le monstre et nourris le champignon.",
	"galleries_quest": "Ferme les deux vannes bruyantes. Puis reste immobile trois secondes dans le cercle pour ouvrir le labyrinthe.",
	"labyrinth_quest": "Réveille les trois nœuds vitaux. Fuis l'ombre : si elle te touche, tu meurs.",
	"combat_quest": "Quête : trouve l'épée, élimine les créatures et rejoins la porte du fond.",
	"torture_quest": "Attrape Bouptilop. Puis charge les spores du grand champignon dans la cuve et active trois décharges.",
	"horror_quest": "Non… Qu'est-ce qui leur est arrivé ?"
}

func _ready() -> void:
	game = get_parent()
	for key in captions:
		clips[key] = load("res://audio/voix_"+key+".wav")
	speaker = AudioStreamPlayer.new()
	speaker.volume_db = -3
	add_child(speaker)
	speaker.finished.connect(finish_line.bind(speaker))
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	subtitle = Label.new()
	subtitle.position = Vector2(140, 565)
	subtitle.size = Vector2(1000, 70)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size",24)
	subtitle.add_theme_color_override("font_color",Color(0.93,0.93,0.81))
	subtitle.add_theme_color_override("font_outline_color",Color.BLACK)
	subtitle.add_theme_constant_override("outline_size",7)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(subtitle)
	subtitle.hide()

func register_spatial(key: String, source: AudioStreamPlayer3D, caption: String, label: Label) -> void:
	captions[key]=caption
	spatial_lines[key]={"source":source,"label":label}
	source.finished.connect(finish_line.bind(source))

func finish_line(source: Node) -> void:
	if source!=current_source:return
	if spatial_lines.has(current):
		spatial_lines[current].label.text=""; spatial_lines[current].label.hide()
	current="";current_source=null;subtitle.hide();speech_gap=SPEECH_GAP

func cancel_line(key: String) -> void:
	pending.erase(key)
	if key==current and current_source!=null:
		current_source.stop();finish_line(current_source)
	used.erase(key)

func other_voice_playing() -> bool:
	if game.audio_mix==null:return false
	for source in game.audio_mix.voice_sources:
		if source==current_source or not is_instance_valid(source) or not source.playing or source.stream_paused:continue
		if source is AudioStreamPlayer3D and source.global_position.distance_to(game.camera.global_position)>source.max_distance:continue
		return true
	return false

func busy() -> bool:
	return not pending.is_empty() or current_source!=null or speaker.playing or speech_gap>0 or other_voice_playing()

func stop_all() -> void:
	pending.clear();speaker.stop();current="";current_source=null;speech_gap=0;subtitle.hide()
	for line in spatial_lines.values():
		line.source.stop();line.label.text="";line.label.hide()

func say(key: String) -> void:
	if not captions.has(key) or not enabled: return
	if key==current or pending.has(key):return
	if key=="victoire":
		if victory_cooldown>0:return
		victory_cooldown=2
	if key == "erreur":
		if failure_cooldown > 0: return
		failure_cooldown = 8
	elif key!="victoire":
		if used.has(key): return
	if key == "victoire":
		# Celebrate at the next free turn, without cutting a rule or NPC mid-sentence.
		pending.push_front(key)
	# Keep the short welcome/prologue stack and the first room objective together;
	# otherwise the mission can be silently discarded on a fresh launch.
	elif pending.size() < 32:
		pending.append(key)
		used[key]=true

func reset_announcements() -> void:
	stop_all();used.clear();welcome_played=false
	failure_cooldown=0;victory_cooldown=0

func _input(event: InputEvent) -> void:
	if game.editor.active or game.paused: return
	if event.is_action_pressed("voice_toggle") and not event.is_echo():
		enabled = not enabled
		if not enabled:
			stop_all()
		else:
			game.experience.room="";game.experience.announced_quest=""

func _process(delta: float) -> void:
	var frozen: bool = game.paused or game.editor.active or game.front_end.active
	speaker.stream_paused = frozen
	for line in spatial_lines.values():line.source.stream_paused=frozen
	if frozen:
		subtitle.hide()
		for line in spatial_lines.values():line.label.hide()
		return
	failure_cooldown = maxf(0,failure_cooldown-delta)
	victory_cooldown=maxf(0,victory_cooldown-delta)
	speech_gap=maxf(0,speech_gap-delta)
	# A paused 3D source can report playing=false. Only finished (or an explicit
	# cancellation) releases its turn, so resuming never skips the end of a line.
	if enabled and current_source==null and speech_gap<=0 and not other_voice_playing() and not pending.is_empty():
		current = pending.pop_front()
		if spatial_lines.has(current):current_source=spatial_lines[current].source
		else:
			current_source=speaker;speaker.stream=clips[current]
		current_source.stream_paused=false;current_source.play()
	if current_source!=null:
		if spatial_lines.has(current):
			var label: Label=spatial_lines[current].label
			label.text=captions[current];label.visible=enabled
		else:subtitle.text="« " + captions[current] + " »"
	subtitle.visible = enabled and current_source==speaker and speaker.playing
	# AudioMix ducks music for all audible voices, including nearby NPCs.
