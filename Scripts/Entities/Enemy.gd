extends Node3D

@export var max_hp: int = 100
var current_hp: int = 100

signal hp_changed(new_hp: int)

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)
	emit_signal("hp_changed", current_hp)
	print("Enemy took %d damage. HP: %d" % [amount, current_hp])
	
	if current_hp <= 0:
		print("Enemy defeated!")

func reset_hp() -> void:
	current_hp = max_hp
	emit_signal("hp_changed", current_hp)
	print("Enemy respawned with full HP")
