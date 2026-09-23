extends Node3D
# Permanent spanning tree guarantees a route even when every living shortcut shuts.
const N := 9
const CELL := 4.0
var game: Node3D
var origin: Vector3
var links: Dictionary = {}
var shutters: Array[MeshInstance3D] = []
var organs: Array[MeshInstance3D] = []
var collected := [false,false,false]
var organ_cells := [Vector2i(0,8),Vector2i(8,4),Vector2i(4,4)]
var flesh: ShaderMaterial
var wall_materials: Array[ShaderMaterial] = []
var exit_gate: MeshInstance3D
var heartbeat: AudioStreamPlayer3D
var clock := 0.0
var complete := false
var entered := false
var opened := 0.0
var notice := ""
var notice_time := 0.0

func edge(a: Vector2i,b: Vector2i) -> String:
	var ia:=a.y*N+a.x
	var ib:=b.y*N+b.x
	return "%d:%d" % [mini(ia,ib),maxi(ia,ib)]

func cell_at(c: Vector2i) -> Vector3:
	return origin+Vector3((c.x-4)*CELL,0,-c.y*CELL-CELL/2)

func block(at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var node: MeshInstance3D=game.box(at,size,color)
	node.reparent(self)
	return node

func wall(at: Vector3,size: Vector3) -> MeshInstance3D:
	var node:=block(at,size,Color(0.15,0.035,0.045))
	# Subdivision gives the surface a soft, visibly breathing silhouette.
	var mesh:=BoxMesh.new()
	mesh.size=size
	mesh.subdivide_width=8;mesh.subdivide_height=10;mesh.subdivide_depth=8
	node.mesh=mesh
	# The deformed skin must not shadow itself using its undeformed box normals.
	# An inset, low-poly caster follows the membrane and keeps real wall shadows
	# without triangular acne or re-rendering every skin subdivision per light.
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var caster:=MeshInstance3D.new();caster.name="Volume_ombre"
	var shadow_mesh:=BoxMesh.new();shadow_mesh.size=(size-Vector3.ONE*0.18).max(Vector3.ONE*0.04)
	caster.mesh=shadow_mesh;caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	node.add_child(caster)
	var wall_skin: ShaderMaterial=flesh.duplicate()
	# A deterministic phase offset keeps adjacent membranes from breathing in lockstep.
	wall_skin.set_shader_parameter("phase",fposmod(at.x*0.73+at.z*1.17,TAU))
	node.material_override=wall_skin
	wall_materials.append(wall_skin)
	return node

func _ready() -> void:
	game=get_parent()
	origin=game.atmosphere.mushroom_position+Vector3(0,0,-41)
	flesh=ShaderMaterial.new()
	flesh.shader=preload("res://living_wall.gdshader")
	var rng:=RandomNumberGenerator.new();rng.seed=661903
	var stack: Array[Vector2i]=[Vector2i(4,0)]
	var visited: Dictionary={Vector2i(4,0):true}
	while not stack.is_empty():
		var c: Vector2i=stack.back()
		var choices: Array[Vector2i]=[]
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=c+d
			if next.x>=0 and next.x<N and next.y>=0 and next.y<N and not visited.has(next):choices.append(next)
		if choices.is_empty():stack.pop_back()
		else:
			var next: Vector2i=choices[rng.randi_range(0,choices.size()-1)]
			links[edge(c,next)]=true
			visited[next]=true;stack.append(next)
	block(origin+Vector3(0,-0.25,-18),Vector3(36,0.5,36),Color(0.11,0.12,0.12))
	wall(origin+Vector3(0,5.5,-18),Vector3(36,0.4,36))
	for x in [-18,18]:wall(origin+Vector3(x,2.65,-18),Vector3(0.35,5.3,36))
	# Room 02 already closes the shared wall up to x=11.5. A second breathing
	# face on that exact plane caused triangle flicker when lit from the maze.
	for x in [-14.75,14.75]:wall(origin+Vector3(x,2.65,0),Vector3(6.5,5.3,0.4))
	for z in [-36]:
		for x in [-10,10]:wall(origin+Vector3(x,2.65,z),Vector3(16,5.3,0.4))
		wall(origin+Vector3(0,4.9,z),Vector3(4,0.8,0.4))
	for y in range(N):
		for x in range(N):
			var c:=Vector2i(x,y)
			for d in [Vector2i.RIGHT,Vector2i.DOWN]:
				var next: Vector2i=c+d
				if next.x>=N or next.y>=N or links.has(edge(c,next)):continue
				var at: Vector3=(cell_at(c)+cell_at(next))/2+Vector3(0,2.65,0)
				var size:=Vector3(0.3,5.3,4.1) if d.x else Vector3(4.1,5.3,0.3)
				var node:=wall(at,size)
				if shutters.size()<10 and (x+y)%3==0:
					shutters.append(node)
					node.set_meta("rest_y",node.position.y)
			if (x+y)%3==0:
				var lamp:=OmniLight3D.new()
				lamp.position=cell_at(c)+Vector3(0,3.8,0)
				lamp.light_color=Color(1,0.18,0.065);lamp.light_energy=0.65;lamp.omni_range=5.5
				add_child(lamp)
				lamp.add_to_group("nacre_dynamic_light");lamp.set_meta("nacre_light_priority",0)
	for i in range(3):
		var sphere:=SphereMesh.new();sphere.radius=0.5;sphere.height=1.1
		var at:=cell_at(organ_cells[i])+Vector3(0,1.5,0)
		var organ: MeshInstance3D=game.atmosphere.form(self,sphere,at,Vector3.ONE,game.atmosphere.luminous(Color(1,0.08,0.025),2))
		organs.append(organ)
		block(at-Vector3(0,1,0),Vector3(0.6,1,0.6),Color(0.18,0.06,0.07))
		game.puzzle.label("NŒUD VITAL %d" % (i+1),at+Vector3(0,1.2,0),46)
	exit_gate=wall(origin+Vector3(0,2.25,-36),Vector3(3.95,4.5,0.4))
	# A walkable resting chamber beyond the heart's final seal.
	block(origin+Vector3(0,-0.25,-40),Vector3(8,0.5,8),Color(0.12,0.2,0.18))
	block(origin+Vector3(0,5.3,-40),Vector3(8,0.4,8),Color(0.1,0.15,0.15))
	for x in [-4,4]:wall(origin+Vector3(x,2.65,-40),Vector3(0.4,5.3,8))
	for x in [-3,3]:wall(origin+Vector3(x,2.65,-44),Vector3(2,5.3,0.4))
	wall(origin+Vector3(0,4.7,-44),Vector3(4,1.2,0.4))
	var safe:=OmniLight3D.new();safe.position=origin+Vector3(0,3,-40)
	safe.light_color=Color(0.3,0.8,0.7);safe.light_energy=2;safe.omni_range=9;add_child(safe)
	safe.add_to_group("nacre_dynamic_light");safe.set_meta("nacre_light_priority",2)
	game.puzzle.label("VOUS ÊTES HORS DE SON CORPS.\nPOUR L'INSTANT.",origin+Vector3(-3,2.5,-43.7),53)
	game.puzzle.label("CHAMBRE 03\nLABYRINTHE INFERNAL",origin+Vector3(0,4.1,0.5),42)
	heartbeat=AudioStreamPlayer3D.new()
	heartbeat.stream=preload("res://audio/coeur_labyrinthe.wav")
	heartbeat.position=origin+Vector3(0,2,-18);heartbeat.max_distance=50
	heartbeat.unit_size=15;heartbeat.volume_db=-9
	add_child(heartbeat)

func inside() -> bool:
	var p: Vector3=game.player.position-origin
	return game.arrived and p.z<0 and p.z> -44 and absf(p.x)<18.2 and absf(p.y)<6

func interact() -> bool:
	if not inside() or game.paused or game.editor.active:return false
	for i in range(3):
		if not collected[i] and can_reach(organs[i].global_position) and game.interaction_origin().distance_to(organs[i].global_position)<2.5:
			collected[i]=true
			game.inventory.resonate(collected.count(true))
			organs[i].material_override=game.atmosphere.luminous(Color(0.12,0.8,0.55),2)
			notice="Le nœud s'éveille. Quelque chose répond derrière les murs."
			notice_time=3
			return true
	return true

func can_reach(target: Vector3) -> bool:
	# Nodes are deliberately not solid, so an explicit line of sight check keeps
	# the interaction from working through a living wall.
	var source: Vector3=game.interaction_origin()
	var query:=PhysicsRayQueryParameters3D.create(source,target,1,[game.player.get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update(delta: float) -> void:
	if game.paused or game.editor.active:
		heartbeat.stream_paused=true
		return
	heartbeat.stream_paused=false
	var active:=inside()
	if active and not heartbeat.playing:heartbeat.play()
	if not active:heartbeat.stop()
	if not active:return
	entered=true
	clock+=delta;notice_time=maxf(0,notice_time-delta)
	for i in range(wall_materials.size()):
		wall_materials[i].set_shader_parameter("breath",clock*1.6+float(i%7)*0.035)
	for i in range(organs.size()):organs[i].scale=Vector3.ONE*(1+0.12*sin(clock*4.5+i))
	for i in range(shutters.size()):
		var node:=shutters[i]
		var rest: float=node.get_meta("rest_y")
		var opening:=fmod(clock+float(i)*2.3,16.0)<8.0
		# Hold open whenever the player overlaps or stands within one metre of the membrane.
		var size: Vector3=node.mesh.size
		var relative: Vector3=game.player.position-node.position
		if absf(relative.x)<size.x/2+1 and absf(relative.z)<size.z/2+1:opening=true
		if game.scares!=null and game.scares.shadow_time>0 and game.scares.maze_shadow.visible:
			var shadow_relative: Vector3=game.scares.maze_shadow.global_position-node.global_position
			if absf(shadow_relative.x)<size.x/2+0.6 and absf(shadow_relative.z)<size.z/2+0.6: opening=true
		node.position.y=move_toward(node.position.y,rest+(5.5 if opening else 0.0),delta*2)
	var count:=collected.count(true)
	if count==3:
		opened=minf(1,opened+delta/2)
		exit_gate.position.y=origin.y+2.25+opened*5
	if game.player.position.z<origin.z-38 and count==3 and game.player.position.x>origin.x-3.7 and game.player.position.x<origin.x+3.7 and not complete:
		complete=true;game.voice.say("victoire")
	game.hud.text="CHAMBRE 03 — LABYRINTHE INFERNAL\nNœuds vitaux : %d / 3" % count
	game.prompt.text="Explore les veines du labyrinthe. Les membranes changent de passage."
	for i in range(3):
		if not collected[i] and can_reach(organs[i].global_position) and game.interaction_origin().distance_to(organs[i].global_position)<2.5:
			game.prompt.text=game.controls.key("interact")+" — Réveiller le nœud vital"
	if count==3:game.prompt.text="Le cœur est ouvert. Trouve la sortie au fond du labyrinthe."
	if notice_time>0:game.prompt.text=notice
	if complete:
		game.hud.text="LABYRINTHE TRAVERSÉ\nTu es sorti de son corps."
		game.prompt.text="Zone de repos — tu peux revenir explorer. R : point de reprise."
