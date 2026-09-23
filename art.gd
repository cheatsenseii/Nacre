extends Node3D
# NACRE: mineral pool architecture gradually reclaimed by bioluminescent growth.
var game: Node3D
var rng := RandomNumberGenerator.new()
var screen: ColorRect
var foot: AudioStreamPlayer
var drip: AudioStreamPlayer3D
var step_clock := 0.0
var drip_clock := 4.0
var materials := {}

func _ready() -> void:
	game = get_parent()
	rng.seed = 1987
	retouch_surfaces()
	departure()
	garden()
	second_room()
	finish_ui()
	foot = AudioStreamPlayer.new()
	foot.stream = load("res://audio/pas.wav")
	foot.volume_db = -15
	add_child(foot)
	drip = AudioStreamPlayer3D.new()
	drip.stream = load("res://audio/goutte.wav")
	drip.position = game.atmosphere.mushroom_position + Vector3(5, 3, -3)
	drip.volume_db = -12
	drip.unit_size = 8
	add_child(drip)

func surface(color: Color, level: float, tiled: bool = true, metal: bool = false) -> ShaderMaterial:
	var key := str(color)+str(level)+str(tiled)+str(metal)
	if materials.has(key): return materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://surface.gdshader")
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("floor_level",level)
	mat.set_shader_parameter("tiles",tiled)
	mat.set_shader_parameter("metal",metal)
	materials[key]=mat
	return mat

func retouch_surfaces() -> void:
	# Keep existing editable object identities and transforms.
	for child in game.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var size: Vector3 = child.mesh.size
			var level := -48.0 if child.position.y < -20 else 0.0
			if size.x > 8 or size.z > 8 or size.y > 5:
				child.material_override = surface(Color(0.38,0.48,0.44) if level==0 else Color(0.28,0.36,0.34),level)
			elif child.position.y > level+0.08:
				child.material_override = surface(Color(0.36,0.39,0.33),level,false,true)
	for child in game.puzzle.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			child.material_override=surface(Color(0.28,0.36,0.34),-48,child != game.puzzle.gate,child == game.puzzle.gate)
	for child in game.atmosphere.get_children():
		if child is OmniLight3D and child.position.distance_to(game.atmosphere.mushroom_position+Vector3(0,1.8,1)) < 0.1:
			child.light_energy = 0.65
	for child in game.atmosphere.mushroom.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh and child.mesh.radius > 1.5 and child.name!="Chapeau":
			var skin := ShaderMaterial.new()
			skin.shader=preload("res://fungus.gdshader")
			child.material_override=skin
	for child in game.get_children():
		if child is Label3D:
			if child.text=="DESCENTE 01": child.text="N A C R E"
			elif child.text.begins_with("UN SEUL"): child.text="CENTRE AQUATIQUE • BASSIN 01"
			elif child.text=="CHAMBRE 01": child.text="LA SERRE AVEUGLE"

func box(at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var node: MeshInstance3D = game.box(at,size,Color.WHITE,solid)
	node.reparent(self)
	node.material_override=mat
	return node

func rod(a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=a.distance_to(b)
	mesh.radial_segments=8
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=mat
	node.position=(a+b)*0.5
	var direction: Vector3=(b-a).normalized()
	var reference:=Vector3.FORWARD if absf(direction.dot(Vector3.UP))>0.95 else Vector3.UP
	var x:=direction.cross(reference).normalized()
	node.basis=Basis(x,direction,x.cross(direction).normalized())
	add_child(node)

func text_sign(words: String, at: Vector3, size: int = 45, yaw: float = 0.0, color: Color = Color(0.78,0.83,0.66)) -> void:
	var sign:=Label3D.new()
	sign.text=words
	sign.font_size=size
	sign.pixel_size=0.004
	sign.position=at
	sign.rotation.y=yaw
	sign.modulate=color
	add_child(sign)

func lamp(at: Vector3,color: Color,energy: float,reach: float) -> void:
	var light:=OmniLight3D.new()
	light.position=at
	light.light_color=color
	light.light_energy=energy
	light.omni_range=reach
	add_child(light)

func departure() -> void:
	var rust:=surface(Color(0.32,0.42,0.37),0,false,true)
	var dark:=surface(Color(0.08,0.13,0.14),0,false)
	var gold: Material=game.atmosphere.luminous(Color(0.84,0.52,0.18),0.45)
	# Service pipework above the queue, out of the walking path.
	for x in [-4.8,4.8]:
		rod(Vector3(x,5.9,4),Vector3(x,5.9,-3.5),0.10,rust)
		rod(Vector3(x,0.3,3.9),Vector3(x,5.9,3.9),0.10,rust)
		for z in [-2.0,0.5,3.0]:
			box(Vector3(x,5.9,z),Vector3(0.3,0.32,0.14),rust)
	# Dented lockers against the side walls.
	for i in range(4):
		var z: float=2.8-i*1.2
		box(Vector3(-5.35,1.15,z),Vector3(0.7,2.3,1.03),rust,true)
		for j in range(3):
			box(Vector3(-4.985,1.9-j*0.09,z),Vector3(0.014,0.025,0.58),dark)
		box(Vector3(-4.97,1.13,z+0.3),Vector3(0.06,0.15,0.04),gold)
	# Typography and a closed ticket window tell the setting without a cutscene.
	box(Vector3(5.79,2.6,1.4),Vector3(0.15,2.9,3.5),dark)
	text_sign("ACCUEIL\n\nFERMÉ DEPUIS 1998",Vector3(5.69,2.8,1.4),55,-PI/2)
	for i in range(12):
		box(Vector3(5.67,1.4+i*0.2,1.4),Vector3(0.03,0.025,3.3),rust)
	# Warm practicals frame the portal against the cool ceiling light.
	for x in [-3.6,3.6]:
		box(Vector3(x,3.5,-3.6),Vector3(0.12,1.6,0.12),gold)
		lamp(Vector3(x,3.4,-3),Color(1,0.55,0.2),0.9,4)
	for i in range(8):
		box(Vector3(0,0.015,3.8-i*0.8),Vector3(0.075,0.013,0.32),gold)

func root_growth(center: Vector3,count: int,spread: float) -> void:
	var bark:=surface(Color(0.23,0.22,0.13),center.y,false)
	var bright: Material=game.atmosphere.luminous(Color(0.20,0.57,0.32),0.4)
	for i in range(count):
		var angle:=TAU*i/count
		var last:=center+Vector3(cos(angle)*0.5,0.055,sin(angle)*0.5)
		for j in range(1,7):
			var r: float=float(j)/6*spread
			var a:=angle+sin(j*0.9+i)*0.14
			var next:=center+Vector3(cos(a)*r,0.045+0.035*sin(j),sin(a)*r)
			rod(last,next,0.055*(1.1-float(j)/8),bark)
			if i%3==0: rod(last+Vector3(0,0.035,0),next+Vector3(0,0.035,0),0.009,bright)
			last=next

func small_fungus(at: Vector3,size: float) -> void:
	var stem:=CylinderMesh.new()
	stem.height=size
	stem.top_radius=size*0.08
	stem.bottom_radius=size*0.13
	stem.radial_segments=8
	game.atmosphere.form(self,stem,at+Vector3(0,size*0.5,0),Vector3.ONE,game.material(Color(0.39,0.48,0.34)))
	var cap:=SphereMesh.new()
	cap.radius=size*0.48
	cap.height=size*0.96
	cap.radial_segments=12
	cap.rings=6
	game.atmosphere.form(self,cap,at+Vector3(0,size,0),Vector3(1,0.37,1),game.atmosphere.luminous(Color(0.17,0.42,0.33),0.35))

func garden() -> void:
	var center: Vector3=game.atmosphere.mushroom_position
	root_growth(center,4,5.8)
	var iron:=surface(Color(0.20,0.28,0.26),center.y,false,true)
	# A broken research apparatus hangs above the living specimen.
	var ring:=TorusMesh.new()
	ring.inner_radius=2.35
	ring.outer_radius=2.45
	ring.rings=48
	ring.ring_segments=8
	game.atmosphere.form(self,ring,center+Vector3(0,5.9,0),Vector3.ONE,iron)
	for i in range(6):
		var a:=TAU*i/6
		var anchor:=center+Vector3(cos(a)*2.4,5.9,sin(a)*2.4)
		rod(anchor,anchor+Vector3(0,1.8,0),0.025,iron)
		rod(anchor,anchor+Vector3(0,-0.65,0),0.035,game.atmosphere.luminous(Color(0.44,0.75,0.64),0.6))
	for i in range(6):
		var side: float=-1 if i%2==0 else 1
		var at:=center+Vector3(side*rng.randf_range(6.4,7.7),0,rng.randf_range(-8.5,8.0))
		small_fungus(at,rng.randf_range(0.2,0.75))
	# Wall conduits frame the route, leaving puzzle pedestals clear.
	for x in [-8.15,8.15]:
		rod(center+Vector3(x,1.1,-10),center+Vector3(x,1.1,10),0.065,iron)
		rod(center+Vector3(x,5.8,-10),center+Vector3(x,5.8,10),0.09,iron)
	# Pools are thin glossy shapes, not extra collision surfaces.
	var wet:=StandardMaterial3D.new()
	wet.albedo_color=Color(0.035,0.09,0.07,0.7)
	wet.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness=0.12
	for i in range(7):
		var sphere:=SphereMesh.new()
		sphere.radius=1
		sphere.height=2
		var at:=center+Vector3(rng.randf_range(-6,6),0.012,rng.randf_range(-8,7))
		game.atmosphere.form(self,sphere,at,Vector3(rng.randf_range(0.5,1.4),0.008,rng.randf_range(0.4,0.9)),wet)
	lamp(center+Vector3(-5,4,3),Color(0.47,0.72,0.66),1.2,9)
	text_sign("NACRE / LABORATOIRE 04\nLE BASSIN N'A JAMAIS ÉTÉ VIDÉ.",center+Vector3(-13.25,3,2),46,PI/2)
	text_sign("CULTURE MÈRE\nELLE A FAIM",center+Vector3(13.25,3,-3),50,-PI/2,Color(0.8,0.48,0.24))

func second_room() -> void:
	var center: Vector3=game.atmosphere.mushroom_position+Vector3(0,0,-26)
	var metal:=surface(Color(0.32,0.39,0.37),center.y,false,true)
	var amber: Material=game.atmosphere.luminous(Color(0.82,0.34,0.12),0.6)
	for x in [-10.4,10.4]:
		for i in range(5):
			var z: float=-6+i*2.6
			box(center+Vector3(x,1.4,z),Vector3(1.1,2.8,1.6),metal,true)
			box(center+Vector3(x-signf(x)*0.57,2.15,z),Vector3(0.03,0.08,0.9),amber)
			for j in range(4):
				box(center+Vector3(x-signf(x)*0.57,1.7-j*0.22,z),Vector3(0.04,0.04,1),game.material(Color(0.035,0.06,0.065)))
	for i in range(10):
		box(center+Vector3(-1.4,0.015,-7+i*1.5),Vector3(0.06,0.012,0.7),amber)
	text_sign("ARCHIVES HYDRAULIQUES\nILS ONT FERMÉ LES PORTES.\nPAS LES VANNES.",center+Vector3(6.75,2.5,-14.65),53)

func finish_ui() -> void:
	game.hud.add_theme_font_size_override("font_size",18)
	game.prompt.add_theme_font_size_override("font_size",17)
	for label in [game.hud,game.prompt]:
		label.add_theme_color_override("font_color",Color(0.82,0.89,0.84))
		label.add_theme_color_override("font_outline_color",Color(0.015,0.02,0.018,0.95))
		label.add_theme_constant_override("outline_size",5)
	var layer:=CanvasLayer.new()
	layer.layer=2
	add_child(layer)
	screen=ColorRect.new()
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; void fragment(){vec2 d=UV-vec2(0.5);float v=smoothstep(0.25,0.7,length(d));COLOR=vec4(0.005,0.013,0.012,v*0.37);}"
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	screen.material=mat
	screen.hide()

func _process(delta: float) -> void:
	# The central post pass owns the vignette and follows the graphics setting.
	screen.hide()
	if game.paused or game.editor.active: return
	drip_clock-=delta
	if drip_clock<=0:
		drip_clock=rng.randf_range(5,11)
		if game.arrived: drip.play()
	if game.has_node("Foley"):
		foot.stop();return
	if not game.sliding and game.player.is_on_floor() and Vector2(game.player.velocity.x,game.player.velocity.z).length()>0.5:
		step_clock-=delta
		if step_clock<=0:
			step_clock=0.32 if Input.is_action_pressed("sprint") else 0.5
			foot.pitch_scale=rng.randf_range(0.92,1.08)
			foot.play()
	else: step_clock=0
