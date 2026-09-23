extends Node
var game: Node3D
var collider: CollisionShape3D
var crouched := false
var push_time := 0.0
var hands: Node3D
var reticle: Label
var reticle_focus := 0.0
var interaction_flash := 0.0
var last_prompt := ""
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.0

func _ready() -> void:
	game = get_parent()
	collider = game.player.get_child(0)
	var layer := CanvasLayer.new()
	add_child(layer)
	reticle = Label.new()
	reticle.text = "·"
	reticle.position = Vector2(624,344)
	reticle.size = Vector2(32,32)
	reticle.pivot_offset = Vector2(16,16)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size",28)
	reticle.add_theme_color_override("font_color",Color("d8e5e1"))
	reticle.add_theme_color_override("font_outline_color",Color(0.01,0.04,0.05,0.85))
	reticle.add_theme_constant_override("outline_size",3)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(reticle)
	hands = Node3D.new()
	game.camera.add_child(hands)
	# Gloved forearms visible in first person, moved forward during a shove.
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var sleeve := CapsuleMesh.new()
		sleeve.radius = 0.085
		sleeve.height = 0.36
		arm.mesh = sleeve
		arm.material_override = game.material(Color(0.12,0.18,0.17))
		arm.position = Vector3(side*0.32,-0.39,-0.36)
		arm.rotation.x = PI/2
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hands.add_child(arm)
		var glove := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.095
		sphere.height = 0.19
		glove.mesh = sphere
		glove.material_override = game.material(Color(0.28,0.22,0.13))
		glove.position = Vector3(side*0.32,-0.38,-0.58)
		glove.scale = Vector3(0.85,0.72,1.1)
		glove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hands.add_child(glove)

func prompt_is_actionable() -> bool:
	if game.prompt==null:return false
	var text: String=game.prompt.text
	return not text.is_empty() and (text.contains(" — ") or text.contains(" - "))

func update_interaction_feedback(delta: float) -> void:
	if game.prompt==null:return
	var text: String=game.prompt.text
	var actionable:=prompt_is_actionable()
	if text!=last_prompt:
		if actionable:interaction_flash=maxf(interaction_flash,0.55)
		last_prompt=text
	if actionable and Input.is_action_just_pressed("interact"):
		interaction_flash=1.0
	reticle_focus=move_toward(reticle_focus,1.0 if actionable else 0.0,delta*7.5)
	interaction_flash=move_toward(interaction_flash,0.0,delta*4.5)
	var pulse:=0.5+0.5*sin(Time.get_ticks_msec()*0.008)
	var scale_amount:=1.0+reticle_focus*(0.08+0.035*pulse)+interaction_flash*0.12
	reticle.scale=Vector2.ONE*scale_amount
	reticle.text="+" if actionable else "·"
	reticle.add_theme_color_override("font_color",Color("8fe6d5") if actionable else Color("d8e5e1"))
	game.prompt.add_theme_color_override("font_color",Color("dffbf5") if actionable else Color("d5dfdc"))
	game.prompt.add_theme_color_override("font_outline_color",Color(0.01,0.03,0.04,0.92))
	game.prompt.add_theme_constant_override("outline_size",4 if actionable else 3)

func can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.295
	shape.height = STAND_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,game.player.global_position+Vector3(0,STAND_HEIGHT/2+0.025,0))
	query.exclude = [game.player.get_rid()]
	query.margin = 0.005
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func update_stance(delta: float) -> void:
	var wants_low := Input.is_action_pressed("crouch")
	if wants_low:
		crouched = true
	elif crouched and can_stand():
		crouched = false
	var height := CROUCH_HEIGHT if crouched else STAND_HEIGHT
	collider.shape.height = height
	collider.position.y = height/2
	game.camera.position.y = move_toward(game.camera.position.y,0.87 if crouched else 1.62,delta*4)

func reset_stance() -> void:
	crouched = false
	collider.shape.height = STAND_HEIGHT
	collider.position.y = STAND_HEIGHT/2

func shove() -> bool:
	if game.paused or game.editor.active or game.sliding or push_time > 0: return false
	push_time = 0.32
	var from: Vector3 = game.interaction_origin()
	var to: Vector3 = from-game.camera.global_basis.z*2.5
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [game.player.get_rid()]
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is RigidBody3D: return false
	var body: RigidBody3D = hit.collider
	var direction: Vector3 = -game.camera.global_basis.z
	direction.y = 0.12
	body.sleeping = false
	body.apply_central_impulse(direction.normalized()*6.5)
	interaction_flash=0.8
	if game.third_person!=null and game.third_person.has_method("shake"):
		game.third_person.shake(0.035,0.09)
	return true

func _physics_process(delta: float) -> void:
	reticle.visible = not game.editor.active and not game.paused and not game.sliding
	hands.visible = not game.editor.active
	if game.paused or game.editor.active: return
	update_interaction_feedback(delta)
	push_time = maxf(0,push_time-delta)
	var amount := sin((1-push_time/0.32)*PI) if push_time>0 else 0.0
	hands.position = Vector3(0,amount*0.14,-amount*0.27)
