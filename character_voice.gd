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
var text_only_time:=0.0
var captions := {
	"depart": "Bon… c'est parti.",
	"bienvenue": "Bienvenue à NACRE…",
	"prologue": "En 1998, le parc a fermé après un accident. Les bassins n'ont jamais été vidés.",
	"arrivee": "Non… ce truc respire vraiment.",
	"erreur": "Non… ce n'est pas ça.",
	"victoire": "Ça a marché.",
	"mission": "Le toboggan descend sous le parc. Évidemment.",
	"mushroom_quest": "Un bâton, une créature… et ce champignon qui attend.",
	"galleries_quest": "Les vannes alimentent encore quelque chose.",
	"labyrinth_quest": "Ces nœuds réagissent à moi. Et cette ombre aussi.",
	"combat_quest": "Un bassin vide, des bestioles… et une épée. Parfait.",
	"torture_quest": "Il faut remettre le courant. J'ai pas envie de savoir pourquoi.",
	"horror_quest": "Non… qu'est-ce qui s'est passé ici ?"
}
# These lines used to be literal quest instructions recorded as voice clips. Billy now
# keeps them as sparse internal reactions, which avoids the GPS effect without requiring
# regenerated audio assets. Existing NPC/spatial voices remain fully voiced.
var text_only := {
	"arrivee": true,
	"victoire": true,
	"mission": true,
	"mushroom_quest": true,
	"galleries_quest": true,
	"labyrinth_quest": true,
	"combat_quest": true,
	"torture_quest": true,
	"horror_quest": true
}

func _ready() -> void:
	game = get_parent()
	for key in captions:
		if not text_only.has(key):
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
	if key==current:
		if current_source!=null:
			current_source.stop();finish_line(current_source)
		else:
			current="";text_only_time=0;subtitle.hide();speech_gap=SPEECH_GAP
	used.erase(key)

func other_voice_playing() -> bool:
	if game.audio_mix==null:return false
	for source in game.audio_mix.voice_sources:
		if source==current_source or not is_instance_valid(source) or not source.playing or source.stream_paused:continue
		if source is AudioStreamPlayer3D and source.global_position.distance_to(game.camera.global_position)>source.max_distance:continue
		return true
	return false

func busy() -> bool:
	return not pending.is_empty() or current!="" or current_source!=null or speaker.playing or speech_gap>0 or other_voice_playing()

func stop_all() -> void:
	pending.clear();speaker.stop();current="";current_source=null;speech_gap=0;text_only_time=0;subtitle.hide()
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
		pending.push_front(key)
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
	if text_only_time>0:
		text_only_time=maxf(0,text_only_time-delta)
		if text_only_time<=0:
			current="";subtitle.hide();speech_gap=SPEECH_GAP
	if enabled and current_source==null and current=="" and speech_gap<=0 and not other_voice_playing() and not pending.is_empty():
		current = pending.pop_front()
		if text_only.has(current):
			subtitle.text="« " + captions[current] + " »"
			subtitle.show()
			text_only_time=clampf(1.9+float(captions[current].length())*0.035,2.4,4.4)
		elif spatial_lines.has(current):
			current_source=spatial_lines[current].source
			current_source.stream_paused=false;current_source.play()
		else:
			current_source=speaker;speaker.stream=clips[current]
			current_source.stream_paused=false;current_source.play()
	if current_source!=null:
		if spatial_lines.has(current):
			var label: Label=spatial_lines[current].label
			label.text=captions[current];label.visible=enabled
		else:subtitle.text="« " + captions[current] + " »"
	subtitle.visible = enabled and ((current_source==speaker and speaker.playing) or text_only_time>0)
