extends Node

signal state_changed

@export var max_hand_size: int = 5
@export var starting_hand: int = 3
@export var starting_mana: int = 1
@export var mana_max: int = 3
@export var draw_time: float = 3.0
@export var mana_regen_time: float = 2.0

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []

var mana: int = 0
var full_hand: bool = false
var draw_queued: bool = false
var last_card_played: String = ""
var enemies_killed_since_reward: Array[String] = []

var current_mode: String = "Battle"

var draw_timer: Timer
var mana_timer: Timer


var player_capsule: Node3D
var enemy: Node

func _ready() -> void:
	draw_timer = Timer.new()
	mana_timer = Timer.new()
	add_child(draw_timer)
	add_child(mana_timer)
	
	draw_timer.wait_time = draw_time
	mana_timer.wait_time = mana_regen_time
	
	draw_timer.timeout.connect(_on_draw_timer_timeout)
	mana_timer.timeout.connect(_on_mana_timer_timeout)
	
	_create_deck_from_database()
	_reset_game()
	
	player_capsule = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")
	if not player_capsule:
		print("Warning: Add capsule to 'player' group")
	if not enemy:
		print("Warning: Add cube to 'enemy' group")
	
	mana_timer.start()
	draw_timer.start()          # timer now runs forever (one-shot, restarted only after real draws)

func _create_deck_from_database() -> void:
	deck.clear()
	
	# Wait for CardDatabase to finish loading if needed
	if CardDatabase.cards.is_empty():
		await get_tree().process_frame
		if CardDatabase.cards.is_empty():
			print("ERROR: CardDatabase still empty after waiting!")
			return
	
	var all_cards = CardDatabase.get_all_cards()
	
	for card in all_cards:
		deck.append(card.duplicate())
	
	deck.shuffle()
	print("Deck created with %d cards from JSON" % deck.size())

func _reset_game() -> void:
	hand.clear()
	discard.clear()
	mana = starting_mana
	full_hand = false
	last_card_played = ""
	enemies_killed_since_reward.clear()
	
	for i in starting_hand:
		_draw_card()
	
	emit_signal("state_changed")

func _ensure_deck_not_empty() -> bool:
	"""If deck is empty, shuffle discard into deck. Returns true if we can draw."""
	if deck.is_empty():
		if discard.is_empty():
			return false
		
		# Proper copy (not reference aliasing)
		deck = discard.duplicate()
		deck.shuffle()
		discard.clear()
		print("Deck reshuffled from discard (%d cards)" % deck.size())
	
	return true


func _draw_card() -> void:
	if not _ensure_deck_not_empty():
		return
	
	var card = deck.pop_front()
	if card == null:
		return
	
	hand.append(card)
	_update_full_hand_state()
	emit_signal("state_changed")
	
	# CRITICAL: Restart timer after EVERY successful draw
	draw_timer.start()

func _update_full_hand_state() -> void:
	full_hand = hand.size() >= max_hand_size
	if full_hand:
		draw_timer.stop()

func _on_draw_timer_timeout() -> void:
	if hand.size() < max_hand_size:
		_draw_card()
	else:
		draw_queued = true
		emit_signal("state_changed")
	
	draw_timer.start()   # always restart after timeout
		
func _on_mana_timer_timeout() -> void:
	mana = clampi(mana + 1, 0, mana_max)
	mana_timer.start()          # restart one-shot timer
	emit_signal("state_changed")

func play_card_at_index(index: int) -> void:
	if index < 0 or index >= hand.size() or mana < 1:
		return
	
	var card = hand.pop_at(index)
	if card == null:
		return
	
	last_card_played = card.card_name
	discard.append(card)
	mana -= 1
	
	_update_full_hand_state()
	_trigger_attack_animation(card.damage)
	
	# Handle queued draw
	if draw_queued and hand.size() < max_hand_size:
		_draw_card()                  # this will restart the timer
		draw_queued = false
	
	emit_signal("state_changed")
	
func force_draw() -> void:
	"""Public method used by DebugUI button and future card effects.
	Completely independent of the automatic draw timer / queued system."""
	if hand.size() < max_hand_size:
		_draw_card()
	else:
		print("Force draw ignored — hand is full")
		emit_signal("state_changed")

func _trigger_attack_animation(damage: int) -> void:
	if not player_capsule or not enemy: return
	
	var tween = create_tween()
	var original_pos = player_capsule.position
	tween.tween_property(player_capsule, "position", original_pos + Vector3(0, 0, 2), 0.15)
	tween.tween_property(player_capsule, "position", original_pos, 0.2)
	
	await get_tree().create_timer(0.1).timeout
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)

func add_mana(amount: int = 1) -> void:
	mana = min(mana + amount, mana_max)
	emit_signal("state_changed")


func kill_enemy() -> void:
	if enemy and enemy.has_method("reset_hp"):
		enemy.reset_hp()
	enemies_killed_since_reward.append("Goblin")
	emit_signal("state_changed")

func respawn_enemy() -> void:
	if enemy and enemy.has_method("reset_hp"):
		enemy.reset_hp()
	emit_signal("state_changed")

func get_debug_data() -> Dictionary:
	var enemy_hp = 100
	if enemy and "current_hp" in enemy:
		enemy_hp = enemy.current_hp
	
	return {
		"mode": current_mode,
		"enemy_name": "Goblin",
		"enemy_hp": enemy_hp,
		"deck_count": deck.size(),
		"hand_count": hand.size(),
		"hand_limit": max_hand_size,
		"discard_count": discard.size(),
		"mana": mana,
		"mana_max": mana_max,
		"mana_timer": mana_timer.time_left,
		"draw_timer": draw_timer.time_left if not draw_timer.is_stopped() else 0.0,
		"full_hand": full_hand,
		"last_card_played": last_card_played,
		"enemies_killed": enemies_killed_since_reward
	}
