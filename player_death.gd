extends Node
## Short, interruptible death sequence. Saving/inspection keep their own identity.
const DURATION:=2.4
var game: Node
var active:=false
var elapsed:=0.0
var resume_data: Dictionary={}
var previous_pause:=false
var layer: CanvasLayer
var shade: ColorRect
var title: Label
var eyebrow: Label
var subtitle: Label
var sound: AudioStreamPlayer
var door: RefCounted

func _ready() -> void:
	game=get_parent(); process_priority=90
	door=preload("res://door_return.gd").new();door.setup(game)
	layer=CanvasLayer.new(); layer.layer=55; add_child(layer)
	shade=ColorRect.new(); shade.color=Color(0.012,0.008,0.012,0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(shade)
	var frame:=CenterContainer.new(); frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(frame)
	var stack:=VBoxContainer.new(); stack.add_theme_constant_override("separation",18); stack.mouse_filter=Control.MOUSE_FILTER_IGNORE; frame.add_child(stack)
	eyebrow=Label.new(); eyebrow.text="N A C R E"
	eyebrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; eyebrow.add_theme_font_size_override("font_size",16)
	eyebrow.add_theme_color_override("font_color",Color("c59682")); stack.add_child(eyebrow)
	title=Label.new(); title.text="L’OMBRE T’A PRIS"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_override("font",preload("res://fonts/Signaletique.ttf"))
	title.add_theme_font_size_override("font_size",49); title.add_theme_color_override("font_color",Color("f3d6cd")); stack.add_child(title)
	subtitle=Label.new(); subtitle.text="Retour à la dernière porte franchie…"
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; subtitle.add_theme_font_size_override("font_size",19)
	subtitle.add_theme_color_override("font_color",Color("ccdcd6")); stack.add_child(subtitle)
	sound=AudioStreamPlayer.new(); sound.stream=preload("res://audio/horreurs_sursaut.wav"); sound.volume_db=-10
	sound.set_meta("nacre_death_sound",true); add_child(sound); layer.hide()

func begin(cause: String="shadow") -> bool:
	if active or game.paused or game.editor.active or game.front_end.active or game.finished: return false
	# Save the node just activated in this physics tick before freezing the world.
	game.checkpoints.observe()
	resume_data=game.checkpoints.snapshot().duplicate(true)
	if not game.checkpoints.valid(resume_data): return false
	title.text="L’OMBRE T’A PRIS" if cause=="shadow" else "TU ES MORT"
	eyebrow.text="N A C R E  /  "+door.NAMES[door.index]
	previous_pause=game.paused; active=true; elapsed=0
	game.health=0; game.player.velocity=Vector3.ZERO; game.combat.cancel_charge(); game.actions.push_time=0
	game.voice.stop_all()
	game.paused=true; layer.show(); shade.color.a=0; sound.stream_paused=false; sound.play()
	if game.third_person!=null: game.third_person.shake(0.13,0.25)
	return true

func cancel() -> void:
	if active:
		game.paused=previous_pause
		game.third_person.avatar.rotation=Vector3.ZERO
		game.third_person.avatar.position.y=0
	active=false; elapsed=0; resume_data.clear(); sound.stop(); layer.hide(); shade.color.a=0

func update(delta: float) -> void:
	if not active: return
	var suspended: bool=game.controls.is_open or game.editor.active or game.front_end.active or game.get_node("Appearance").active
	layer.visible=not suspended; sound.stream_paused=suspended
	if suspended: return
	elapsed+=delta
	shade.color.a=lerpf(0.12,0.96,smoothstep(0.0,1.0,elapsed))
	game.third_person.avatar.rotation.z=-smoothstep(0.0,0.65,elapsed)*0.7
	game.third_person.avatar.position.y=-smoothstep(0.0,0.65,elapsed)*0.35
	if elapsed>=DURATION:
		var data:=resume_data.duplicate(true)
		game.checkpoints.apply_save(data)
		game.feeding.immunity=2;game.combat.immunity=2
		game.checkpoints.announce("Retour à la dernière porte — armes et progression conservées.")
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	update(delta)
