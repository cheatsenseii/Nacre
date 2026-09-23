extends RefCounted
## Follow the existing permanent maze graph; use a swept capsule for every move.
var game: Node3D
var route:=PackedVector3Array()
var goal:=Vector3.INF
var repath:=0.0
var capsule:=CapsuleShape3D.new()
var graph:=AStar3D.new()
var anchors: Dictionary={}

func _init() -> void:
	capsule.radius=0.43; capsule.height=3.1

func reset() -> void:
	route.clear(); goal=Vector3.INF; repath=0; graph.clear(); anchors.clear()

func cell(at: Vector3) -> Vector2i:
	var local: Vector3=at-game.labyrinth.origin
	return Vector2i(clampi(roundi(local.x/4)+4,0,8),clampi(floori(-local.z/4),0,8))

func center(at: Vector2i) -> Vector3:
	return game.labyrinth.cell_at(at)+Vector3.UP*0.05

func prepare_graph() -> void:
	# Permanent corridors stay usable with every membrane closed. Four anchors
	# around a node's pedestal prevent the pursuer from sticking to its center.
	for y in range(9):
		for x in range(9):
			var at:=Vector2i(x,y)
			var choices: Array[Vector3]=[center(at)]
			if not free_at(center(at)):
				choices.clear()
				for side_x in [-0.95,0.95]:
					for side_z in [-0.95,0.95]: choices.append(center(at)+Vector3(side_x,0,side_z))
			anchors[at]=[]
			for point in choices:
				if not free_at(point): continue
				var id:=graph.get_available_point_id()
				graph.add_point(id,point); anchors[at].append(id)
	for at: Vector2i in anchors:
		for adjacent in [at,at+Vector2i.RIGHT,at+Vector2i.DOWN]:
			if not anchors.has(adjacent): continue
			if at!=adjacent and not game.labyrinth.links.has(game.labyrinth.edge(at,adjacent)): continue
			for first: int in anchors[at]:
				for second: int in anchors[adjacent]:
					if first==second or graph.are_points_connected(first,second): continue
					if safe_fraction(graph.get_point_position(first),graph.get_point_position(second))>0.999:
						graph.connect_points(first,second)

func build_route(from: Vector3, target: Vector3) -> PackedVector3Array:
	if anchors.is_empty(): prepare_graph()
	var best:=PackedVector3Array()
	var best_length:=INF
	for first: int in anchors.get(cell(from),[]):
		if safe_fraction(from,graph.get_point_position(first))<0.999: continue
		for last: int in anchors.get(cell(target),[]):
			if safe_fraction(graph.get_point_position(last),target)<0.999: continue
			var path:=graph.get_point_path(first,last)
			if path.is_empty(): continue
			var length:=from.distance_to(path[0])+target.distance_to(path[-1])
			for i in range(1,path.size()): length+=path[i-1].distance_to(path[i])
			if length<best_length: best_length=length; best=path
	if not best.is_empty(): best.append(target)
	return best

func safe_fraction(from: Vector3, to: Vector3) -> float:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule; query.transform=Transform3D(Basis.IDENTITY,from+Vector3.UP*1.65)
	query.motion=to-from; query.collision_mask=1; query.margin=0.035
	query.exclude=[game.player.get_rid()]
	var result: PackedFloat32Array=game.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] if result.size()==2 else 0.0

func free_at(at: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule; query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*1.65)
	query.collision_mask=1; query.exclude=[game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func step(from: Vector3, target: Vector3, speed: float, delta: float) -> Vector3:
	target.y=game.labyrinth.origin.y+0.05
	repath=maxf(0,repath-delta)
	var destination:=target
	if safe_fraction(from,target)<0.999:
		if route.is_empty() or (target.distance_to(goal)>0.75 and repath<=0):
			goal=target; route=build_route(from,target); repath=0.45
		while not route.is_empty() and from.distance_to(route[0])<0.15: route.remove_at(0)
		# Skip the cell center only when the entire diagonal is physically clear.
		if route.size()>1 and safe_fraction(from,route[1])>0.999: route.remove_at(0)
		if route.is_empty(): return from
		destination=route[0]
	else: route.clear()
	var next:=from.move_toward(destination,speed*minf(delta,0.1))
	var fraction:=safe_fraction(from,next)
	return from.lerp(next,maxf(0,fraction-0.001))
