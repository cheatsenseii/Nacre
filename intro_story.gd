extends Node
## Legacy intro controller kept temporarily for compatibility.
## The old Nathan/brother storyline has been removed.
## The playable Billy prologue is now handled by billy_prologue.gd.

var game: Node
var active := false
var armed_new_game := false

func _ready() -> void:
	game = get_parent()
	call_deferred("bind_front_end")

func bind_front_end() -> void:
	for _i in range(16):
		await get_tree().process_frame
		if game.front_end != null and game.front_end.new_button != null:
			break
	if game.front_end == null or game.front_end.new_button == null:
		return
	game.front_end.new_button.pressed.connect(func(): armed_new_game = true)
	game.front_end.continue_button.pressed.connect(func(): armed_new_game = false)
	if game.front_end.confirmation != null:
		game.front_end.confirmation.canceled.connect(func(): armed_new_game = false)

func begin() -> void:
	# No text-card prologue anymore. Billy's playable home sequence owns the opening.
	active = false
	armed_new_game = false

func _process(_delta: float) -> void:
	if armed_new_game and game.front_end != null and not game.front_end.active:
		armed_new_game = false
		begin()
