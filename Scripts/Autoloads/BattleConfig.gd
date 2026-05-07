extends Node

# === Core Battle Parameters (tweak these in the inspector) ===
@export var max_hand_size: int = 5
@export var starting_hand: int = 3
@export var starting_mana: int = 1
@export var mana_max: int = 3

@export var draw_time: float = 4.0
@export var mana_regen_time: float = 3.0

# === Future improvements (already prepared) ===
@export var battle_start_delay: float = 0.5      # delay before first draw
@export var draw_stagger_delay: float = 0.2     # delay between starting-hand draws
@export var resolving_time: float = 0.5          # how long a played card stays in ResolvingZone

func _ready() -> void:
	print("✅ BattleConfig loaded — all values editable at runtime")
