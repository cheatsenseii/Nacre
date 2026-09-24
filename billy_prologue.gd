extends Node
## Playable narrative spine for Billy's return to NACRE.
## It establishes motivation without explaining the park's mysteries for the player.

signal prologue_finished

enum Step {
	BORED,
	FIND_PHOTO,
	FIND_KEYS,
	GET_GEAR,
	LEAVE_HOME,
	DRIVE,
	ARRIVE_NACRE,
	DONE
}

var step: Step = Step.BORED
var inspected_boredom_objects := 0
var required_boredom_objects := 2
var has_seen_photo := false
var has_keys := false
var has_gear := false
var current_objective := "Faire un tour dans la maison"
var current_thought := ""

func begin() -> void:
	step = Step.BORED
	inspected_boredom_objects = 0
	has_seen_photo = false
	has_keys = false
	has_gear = false
	current_objective = "Faire un tour dans la maison"
	current_thought = "Même programme qu’hier… passionnant."

func inspect_boredom_object(id: String) -> String:
	if step != Step.BORED:
		return ""
	inspected_boredom_objects += 1
	var line := ""
	match id:
		"urbex_lamp":
			line = "Ça fait combien de temps que j’ai pas utilisé ça ?"
		"old_shoes":
			line = "Elles ont connu des endroits plus intéressants que ce salon."
		"phone":
			line = "Rien. Encore une soirée passionnante."
		_:
			line = "J’ai vraiment besoin de sortir d’ici."
	current_thought = line
	if inspected_boredom_objects >= required_boredom_objects:
		step = Step.FIND_PHOTO
		current_objective = "Regarder les souvenirs d’urbex"
	return line

func inspect_nacre_photo() -> String:
	if step == Step.BORED:
		current_thought = "Toutes ces vieilles sorties… Ça me manque plus que je veux l’admettre."
		return current_thought
	if step != Step.FIND_PHOTO:
		return ""
	has_seen_photo = true
	step = Step.FIND_KEYS
	current_objective = "Retrouver les clés de voiture"
	current_thought = "NACRE… J’étais tombé dessus en me paumant dans le coin. On partait sans savoir où on finirait. Pourquoi j’ai arrêté ?"
	return current_thought

func collect_keys() -> String:
	if step != Step.FIND_KEYS:
		return ""
	has_keys = true
	step = Step.GET_GEAR
	current_objective = "Récupérer le matériel d’urbex"
	current_thought = "Bon. Les clés. Maintenant, autant éviter de partir les mains dans les poches."
	return current_thought

func collect_urbex_gear() -> String:
	if step != Step.GET_GEAR:
		return ""
	has_gear = true
	step = Step.LEAVE_HOME
	current_objective = "Quitter la maison"
	current_thought = "Lampe, sac, appareil… ça fera l’affaire."
	return current_thought

func leave_home() -> String:
	if step != Step.LEAVE_HOME or not has_keys or not has_gear:
		return ""
	step = Step.DRIVE
	current_objective = "Rejoindre NACRE"
	current_thought = "Allez Billy. Une vraie sortie. Ça changera."
	return current_thought

func finish_drive() -> String:
	if step != Step.DRIVE:
		return ""
	step = Step.ARRIVE_NACRE
	current_objective = "Observer l’entrée du parc"
	current_thought = "Voilà… c’était ici."
	return current_thought

func confirm_arrival() -> String:
	if step != Step.ARRIVE_NACRE:
		return ""
	step = Step.DONE
	current_objective = "Explorer NACRE"
	current_thought = "Cet endroit est encore plus grand que dans mon souvenir."
	prologue_finished.emit()
	return current_thought

func get_objective() -> String:
	return current_objective
