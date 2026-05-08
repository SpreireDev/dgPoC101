class_name CardEffect
extends Resource

@export var effect_name: String = ""

# Override in subclasses for special card effects
func execute(battle_manager: Node, is_player: bool = true) -> void:
	pass
