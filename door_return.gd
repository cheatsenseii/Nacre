extends RefCounted
## Canonical door positions, never a raw save-file teleport coordinate.
const NAMES:=["ENTRÉE DE NACRE","LE REPAS","LA CHAMBRE DU SILENCE","LABYRINTHE INFERNAL","LA FOSSE DES RATÉS","LA MÉMOIRE DU MAL","SALLE DE TORTURE","SALLE DES HORREURS"]
var game: Node
var doors: Array[Vector3]=[]
var index:=0
var backwards:=false
var last_position:=Vector3.ZERO

func setup(owner_game: Node) -> void:
	game=owner_game
	doors=[Vector3(0,0,1.8),game.puzzle.origin+Vector3(0,0,10),game.puzzle.origin+Vector3(0,0,-11),game.labyrinth.origin,game.combat.origin,game.simon.origin,game.torture.origin,game.horrors.origin]
	seed_from_position()

func destination() -> Vector3:
	if index==0:return doors[0]+Vector3.UP*0.05
	return doors[index]+Vector3(0,0.05,2 if backwards else -2)

func facing() -> float:
	return PI if backwards else 0.0

func seed_from_position() -> void:
	index=0;backwards=false;last_position=game.player.position
	if not game.arrived:return
	index=1
	for i in range(2,doors.size()):
		if game.player.position.z<doors[i].z:index=i

func restore(at: int, from_back: bool) -> void:
	index=clampi(at,0,doors.size()-1);backwards=from_back and index>=2
	last_position=game.player.position

func observe() -> void:
	if game.paused or game.editor.active or game.front_end.active:return
	var at: Vector3=game.player.position
	if game.sliding or not game.arrived:last_position=at;return
	# Explicit teleports (inspection, scripted landing) seed a safe room entrance.
	if index==0 or at.distance_to(last_position)>5:
		seed_from_position();return
	var distance: float=at.z-last_position.z
	if absf(distance)<0.0001:last_position=at;return
	var nearest_t: float=-1
	for i in range(2,doors.size()):
		var door: Vector3=doors[i]
		var crossed: bool=(last_position.z>=door.z and at.z<door.z) or (last_position.z<=door.z and at.z>door.z)
		if not crossed:continue
		var t: float=(door.z-last_position.z)/distance
		var crossing: Vector3=last_position.lerp(at,t)
		if absf(crossing.x-door.x)>2.1 or absf(crossing.y-door.y)>2.5:continue
		if t>nearest_t:
			nearest_t=t;index=i;backwards=distance>0
	last_position=at
