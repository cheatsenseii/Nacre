extends Node3D
# Compatibility state for older progress files. The introductory room has no spore hazards.
var clock := 0.0
var toxicity := 0.0
var sheltered := false
var movement_factor := 1.0
func advance(_delta: float) -> void:
	movement_factor=1.0
func decorate() -> void:
	pass
func try_shelter() -> bool:
	return false
