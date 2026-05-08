class_name CardEffect
extends Resource

@export var effect_name: String = ""

# Called when card resolves (override in subclasses later)
func execute(_battle_manager: Node, _is_player: bool) -> void:
	pass