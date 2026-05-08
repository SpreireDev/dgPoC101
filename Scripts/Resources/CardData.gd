class_name CardData
extends Resource

@export var card_name: String = "Strike"
@export var card_type: String = "Attack"  # "Attack", "Defend", "Power Atk", "Buff"
@export var tickdown: int = 3
@export var damage: int = 5
@export var guard: int = 0
@export var mana_add: int = 0
@export var mana_cost: int = 1
@export var requires_rage: bool = false
@export var effects: Array[Resource] = []  # future CardEffect resources

func _to_string() -> String:
	return "%s (%s)" % [card_name, card_type]
