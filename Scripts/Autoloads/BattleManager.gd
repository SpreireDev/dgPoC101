extends Node

signal state_changed

# All tunable values now live in BattleConfig (single source of truth)
var max_hand_size: int
var starting_hand: int
var starting_mana: int
var mana_max: int
var draw_time: float
var mana_regen_time: float
var reshuffle_animation_delay: float
var enemy_death_delay: float

# ... (keep the rest of your existing member variables unchanged)

# Permanent
var player_collection: Array[CardData] = []

# Battle-only
var battle_deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []

var mana: int = 0
var full_hand: bool = false
var draw_queued: bool = false
var last_card_played: String = ""
var current_mode: String = "Exploration"
var reward_options: Array[CardData] = []

var draw_timer: Timer
var mana_timer: Timer
var player_capsule: Node3D
var enemy: Node

func _ready() -> void:
	# Load centralized config
	max_hand_size = BattleConfig.max_hand_size
	starting_hand = BattleConfig.starting_hand
	starting_mana = BattleConfig.starting_mana
	mana_max = BattleConfig.mana_max
	draw_time = BattleConfig.draw_time
	mana_regen_time = BattleConfig.mana_regen_time
	reshuffle_animation_delay = BattleConfig.reshuffle_animation_delay
	enemy_death_delay = BattleConfig.enemy_death_delay
	
	draw_timer = Timer.new()
	mana_timer = Timer.new()
	add_child(draw_timer)
	add_child(mana_timer)
	
	draw_timer.wait_time = draw_time
	mana_timer.wait_time = mana_regen_time
	draw_timer.one_shot = true
	mana_timer.one_shot = true
	
	draw_timer.timeout.connect(_on_draw_timer_timeout)
	mana_timer.timeout.connect(_on_mana_timer_timeout)
	
	_create_deck_from_database()
	_init_starter_collection()
	_reset_game()
	
	player_capsule = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")
	if not player_capsule: print("Warning: player group missing")
	if not enemy: print("Warning: enemy group missing")


func _init_starter_collection() -> void:
	if player_collection.size() > 0: return
	var all = CardDatabase.get_all_cards()
	player_collection = [all[0].duplicate(), all[0].duplicate(), all[1].duplicate(), all[1].duplicate(), all[2].duplicate()]
	print("Starter collection: %d cards" % player_collection.size())


func start_new_battle() -> void:
	current_mode = "Battle"
	battle_deck = player_collection.duplicate()
	battle_deck.shuffle()
	hand.clear()
	discard.clear()
	_reset_battle_state()
	
	mana_timer.start()   # mana starts immediately when battle begins
	
	print("=== START NEW BATTLE ===")
	print("Collection size:", player_collection.size())
	print("Battle deck created with", battle_deck.size(), "cards")
	_trigger_animation("battle_started", {"hand_size": starting_hand})
	
	# === Staggered starting hand ===
	await _draw_starting_hand_sequenced()
	
	# Only now start the normal draw timer
	draw_timer.start()
	
	emit_signal("state_changed")
	
func _draw_card(start_draw_timer: bool = true) -> void:
	if not await _ensure_battle_deck_not_empty():
		return
	
	var card = battle_deck.pop_front()
	if card == null:
		return
	
	hand.append(card)
	_update_full_hand_state()
	_trigger_animation("card_drawn", {"card_name": card.card_name})
	emit_signal("state_changed")
	
	if start_draw_timer:
		draw_timer.start()


func _draw_starting_hand_sequenced() -> void:
	"""Draw starting hand one card at a time with visual stagger delay."""
	for i in starting_hand:
		if hand.size() >= max_hand_size:
			break
		
		_draw_card(false)   # positional call — no named-argument parser issue
		
		# Small delay between each card for nice pacing
		if i < starting_hand - 1:
			await get_tree().create_timer(BattleConfig.draw_stagger_delay).timeout
			
func _show_resolving_card(card: CardData) -> void:
	# Let DebugUI handle its own UI (cleaner)
	if has_node("/root/Main/CanvasLayer/DebugUI"):
		var debug_ui = get_node("/root/Main/CanvasLayer/DebugUI")
		debug_ui.show_resolving_card(card)
	else:
		print("Warning: DebugUI not found for resolving zone")

func _reset_battle_state() -> void:
	mana = starting_mana
	full_hand = false
	draw_queued = false
	last_card_played = ""


func _reset_game() -> void:
	hand.clear()
	battle_deck.clear()
	discard.clear()
	current_mode = "Exploration"
	_reset_battle_state()


func _create_deck_from_database() -> void:
	pass # only for validation


func _ensure_battle_deck_not_empty() -> bool:
	if battle_deck.is_empty():
		if discard.is_empty():
			return false
		
		battle_deck = discard.duplicate()
		battle_deck.shuffle()
		discard.clear()
		
		_trigger_animation("reshuffle_started")
		await get_tree().create_timer(BattleConfig.reshuffle_animation_delay).timeout
		_trigger_animation("reshuffle_completed")
		
		print("Battle deck reshuffled from discard (%d cards) [%.2fs delay]" % [battle_deck.size(), BattleConfig.reshuffle_animation_delay])
	return true



func _update_full_hand_state() -> void:
	full_hand = hand.size() >= max_hand_size


func _on_draw_timer_timeout() -> void:
	if hand.size() < max_hand_size:
		_draw_card()
	else:
		draw_queued = true
	draw_timer.start()


func _on_mana_timer_timeout() -> void:
	mana = clampi(mana + 1, 0, mana_max)
	mana_timer.start()
	emit_signal("state_changed")


func play_card_at_index(index: int) -> void:
	if index < 0 or index >= hand.size() or mana < 1:
		return
	
	var card = hand.pop_at(index)
	if card == null:
		return
	
	last_card_played = card.card_name
	
	# Resolving zone + animation trigger
	if has_node("/root/Main/CanvasLayer/DebugUI"):
		get_node("/root/Main/CanvasLayer/DebugUI").show_resolving_card(card)
	_trigger_animation("card_played", {"card_name": card.card_name, "damage": card.damage})
	
	await get_tree().create_timer(BattleConfig.resolving_time).timeout
	
	discard.append(card)
	mana -= 1
	
	_update_full_hand_state()
	_trigger_attack_animation(card.damage)
	
	if draw_queued and hand.size() < max_hand_size:
		_draw_card()
		draw_queued = false
	
	emit_signal("state_changed")
	
	




func force_discard_from_hand(index: int) -> void:
	if index < 0 or index >= hand.size():
		return
	
	var card = hand.pop_at(index)
	if card == null:
		return
	
	discard.append(card)
	_update_full_hand_state()
	
	_trigger_animation("card_discarded", {
		"card_name": card.card_name,
		"source": "force_discard_from_hand"
	})
	
	emit_signal("state_changed")
	
	
func force_draw() -> void:
	if hand.size() < max_hand_size:
		_draw_card()
	else:
		print("Force draw ignored — hand full")


func add_mana(amount: int = 1) -> void:          # ← this was missing / broken
	mana = mini(mana + amount, mana_max)
	emit_signal("state_changed")


func end_battle() -> void:
	_trigger_animation("battle_ended")
	draw_timer.stop()
	mana_timer.stop()
	hand.clear()
	battle_deck.clear()
	discard.clear()
	draw_queued = false
	current_mode = "Reward"
	offer_rewards()
	emit_signal("state_changed")


func offer_rewards() -> void:
	reward_options = []
	var all = CardDatabase.get_all_cards()
	all.shuffle()
	for i in 3:
		if i < all.size():
			reward_options.append(all[i])
	emit_signal("state_changed")


func claim_reward(index: int) -> void:
	if current_mode != "Reward" or index < 0 or index >= reward_options.size():
		return
	
	var chosen_card = reward_options[index]
	player_collection.append(chosen_card)
	
	_trigger_animation("reward_claimed", {"card_name": chosen_card.card_name})
	
	print("Claimed card: ", chosen_card.card_name)
	
	reward_options.clear()
	current_mode = "Exploration"
	emit_signal("state_changed")

func _trigger_attack_animation(damage: int) -> void:
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		
		# Safe HP check
		var hp = 100
		if enemy:
			if "hp" in enemy:
				hp = enemy.hp
			elif "current_hp" in enemy:
				hp = enemy.current_hp
		
		if hp <= 0:
			_trigger_animation("enemy_died")
			await get_tree().create_timer(BattleConfig.enemy_death_delay).timeout
			end_battle()

func kill_enemy() -> void:
	if enemy and enemy.has_method("reset_hp"):
		enemy.reset_hp()
	end_battle()


func respawn_enemy() -> void:
	if enemy and enemy.has_method("reset_hp"):
		enemy.reset_hp()
	emit_signal("state_changed")
	
func _trigger_animation(event_name: String, data: Dictionary = {}) -> void:
	# Placeholder for VFX / animations / sound later
	print("[ANIM_TRIGGER] %s %s" % [event_name, data])


func get_debug_data() -> Dictionary:
	var enemy_hp = 100
	if enemy and "hp" in enemy:
		enemy_hp = enemy.hp
	elif enemy and "current_hp" in enemy:
		enemy_hp = enemy.current_hp
	
	return {
		"mode": current_mode,
		"enemy_name": "Goblin",
		"enemy_hp": enemy_hp,
		"collection_size": player_collection.size(),
		"collection_cards": player_collection.duplicate(),
		"battle_deck": battle_deck.size(),
		"hand_count": hand.size(),
		"hand_limit": max_hand_size,
		"discard_count": discard.size(),
		"mana": mana,
		"mana_max": mana_max,
		"mana_timer": mana_timer.time_left,
		"draw_timer": draw_timer.time_left if not draw_timer.is_stopped() else 0.0,
		"last_card_played": last_card_played,
		"reward_options": reward_options.size(),
		# === NEW: actual cards for UI ===
		"reward_cards": reward_options.duplicate(),
		"battle_deck_cards": battle_deck.duplicate(),
		"hand_cards": hand.duplicate(),
		"discard_cards": discard.duplicate()
	}
	
