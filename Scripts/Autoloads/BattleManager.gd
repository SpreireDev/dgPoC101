#class_name BattleManager
extends Node

# ── Config (tunable via BattleConfig.gd) ─────────────────────────────────────
# @onready var config = BattleConfig  # assume BattleConfig.gd exists as before

# ── Player State ─────────────────────────────────────────────────────────────
var player_hp: int = 100
var player_guard: int = 0
var guard_zone: Array[CardData] = []
var exile_pile: Array[CardData] = []

# ── Enemy State (Goblin) ─────────────────────────────────────────────────────
var enemy_hp: int = 120
var enemy_guard: int = 0
var enemy_mana: int = 4
var enemy_hand: Array[CardData] = []
var enemy_rage_mode: bool = false
var enemy_action_timer: Timer

# ── Deck / Hand / Discard (existing real-time system) ────────────────────────
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var max_hand_size: int = 5
var mana: int = 3
var draw_timer: Timer
var mana_timer: Timer
var draw_queued: bool = false

var last_card_played: String = ""
var current_mode: String = "Exploration"  # Exploration | Battle | Reward

var collection: Array[CardData] = []
var reward_options: Array[CardData] = []

# ── Signals ──────────────────────────────────────────────────────────────────
signal state_changed
signal zones_changed
signal enemy_state_changed
signal resolving_card_changed(card_name: String)  # "" = clear

# ── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_timers()
	enemy_action_timer = Timer.new()
	enemy_action_timer.one_shot = true
	add_child(enemy_action_timer)
	enemy_action_timer.timeout.connect(_on_enemy_action_timer_timeout)
	_init_collection()
	
func _init_collection() -> void:
	collection.clear()
	var all_cards = CardDatabase.get_all_cards()
	for card in all_cards:
		collection.append(card.duplicate())  # full owned pool
	print("DEBUG: Collection initialized with ", collection.size(), " cards")

func _setup_timers() -> void:
	draw_timer = Timer.new()
	draw_timer.one_shot = true
	draw_timer.timeout.connect(_on_draw_timer_timeout)
	add_child(draw_timer)

	mana_timer = Timer.new()
	mana_timer.wait_time = BattleConfig.mana_regen_time
	mana_timer.timeout.connect(_on_mana_timer_timeout)
	add_child(mana_timer)

# ── Battle Lifecycle ─────────────────────────────────────────────────────────
func start_new_battle() -> void:
	current_mode = "Battle"
	_reset_battle_state()
	_reset_enemy_state()
	
	await get_tree().create_timer(BattleConfig.battle_start_delay).timeout   # Day 2 delay
	
	_build_deck()
	_draw_initial_hand()
	mana = BattleConfig.starting_mana
	_start_timers()
	
	emit_signal("state_changed")
	emit_signal("zones_changed")
	emit_signal("enemy_state_changed")

func _reset_battle_state() -> void:
	player_hp = 100
	player_guard = 0
	guard_zone.clear()
	exile_pile.clear()
	hand.clear()
	discard.clear()
	deck.clear()
	draw_queued = false
	mana = BattleConfig.starting_mana

func _reset_enemy_state() -> void:
	enemy_hp = 120
	enemy_guard = 0
	enemy_mana = 4
	enemy_hand.clear()
	enemy_rage_mode = false
	_draw_enemy_hand()

func end_battle() -> void:
	current_mode = "Reward"
	draw_timer.stop()
	mana_timer.stop()
	enemy_action_timer.stop()
	offer_rewards()   # ← added
	emit_signal("state_changed")
	
func offer_rewards() -> void:
	reward_options.clear()
	var all_cards = CardDatabase.get_all_cards()
	all_cards.shuffle()
	for i in 3:
		if all_cards.size() > i:
			reward_options.append(all_cards[i].duplicate())
	current_mode = "Reward"
	emit_signal("state_changed")
	emit_signal("zones_changed")

# ── Deck & Card Management (existing + CardDatabase) ─────────────────────────
func _build_deck() -> void:
	deck.clear()
	deck = collection.duplicate()  # copy owned cards
	deck.shuffle()

func _draw_initial_hand() -> void:
	for i in BattleConfig.starting_hand:
		_draw_card()
		if i < BattleConfig.starting_hand - 1:  # don't delay after the last card
			await get_tree().create_timer(BattleConfig.draw_stagger_delay).timeout

func _draw_card() -> void:
	if deck.is_empty():
		_shuffle_discard_into_deck()
	if deck.is_empty(): return
	var card = deck.pop_back()
	hand.append(card)
	if hand.size() > max_hand_size:
		discard.append(hand.pop_front())  # overflow to discard
	emit_signal("state_changed")

func _shuffle_discard_into_deck() -> void:
	deck = discard.duplicate()
	deck.shuffle()
	discard.clear()
	await get_tree().create_timer(BattleConfig.reshuffle_animation_delay).timeout

func _update_full_hand_state() -> void:
	emit_signal("state_changed")

# ── Timers ───────────────────────────────────────────────────────────────────
func _start_timers() -> void:
	draw_timer.start(BattleConfig.draw_time)
	mana_timer.start()

func _on_draw_timer_timeout() -> void:
	if hand.size() < max_hand_size:
		_draw_card()
	else:
		draw_queued = true
	draw_timer.start(BattleConfig.draw_time)

func _on_mana_timer_timeout() -> void:
	mana = mini(mana + 1, BattleConfig.mana_max)
	emit_signal("state_changed")
	mana_timer.start()

# ── Player Card Play (new) ───────────────────────────────────────────────────
func play_card(index: int, as_guard: bool) -> void:
	if index < 0 or index >= hand.size(): return
	var card: CardData = hand[index]
	if mana < card.mana_cost: return

	hand.remove_at(index)
	mana -= card.mana_cost
	last_card_played = card.card_name

	if as_guard:
		player_guard += card.guard
		guard_zone.append(card)
		_trigger_animation("guard_assigned", {"card_name": card.card_name, "guard": card.guard})
	else:
		# Attack path
		_show_resolving_card(card)
		await get_tree().create_timer(BattleConfig.resolving_time).timeout
		_apply_player_attack(card)
		discard.append(card)
		_trigger_attack_animation(card.damage)
		emit_signal("resolving_card_changed", "")  # clear ResolvingZone

	# ← COMMON POST-PLAY LOGIC (this was missing for Guard cards)
	_update_full_hand_state()
	if draw_queued and hand.size() < max_hand_size:
		_draw_card()
		draw_queued = false

	emit_signal("state_changed")
	emit_signal("zones_changed")

# ── Attack Resolution ────────────────────────────────────────────────────────
func _apply_player_attack(card: CardData) -> void:
	var dmg: int = card.damage
	# Enemy guard absorbs first
	if enemy_guard > 0:
		var absorbed = mini(dmg, enemy_guard)
		enemy_guard -= absorbed
		dmg -= absorbed
	enemy_hp -= dmg
	if enemy_hp <= 0:
		enemy_hp = 0
		_trigger_animation("enemy_died")
		await get_tree().create_timer(BattleConfig.enemy_death_delay).timeout
		end_battle()
		return

	# Rage check
	if not enemy_rage_mode and float(enemy_hp) / 120.0 <= 0.2:
		enemy_rage_mode = true
		emit_signal("enemy_state_changed")

func _trigger_animation(_anim: String, _data: Dictionary = {}) -> void:
	# Stub - connect to actual animation player later
	pass

func _show_resolving_card(card: CardData) -> void:
	emit_signal("resolving_card_changed", card.card_name)

func _trigger_attack_animation(_damage: int) -> void:
	# Stub
	pass

# ── Enemy AI & Telegraph (new) ───────────────────────────────────────────────
func _draw_enemy_hand() -> void:
	enemy_hand.clear()
	var all_cards = CardDatabase.get_all_cards()
	var valid_pool = all_cards.filter(func(c): return not c.requires_rage or enemy_rage_mode)
	valid_pool.shuffle()
	for i in 4:  # enemy hand size
		if valid_pool.size() > i:
			enemy_hand.append(valid_pool[i].duplicate())

func _on_enemy_action_timer_timeout() -> void:
	if enemy_hand.is_empty(): 
		enemy_action_timer.start(1.0)
		return

	# Simple random valid AI
	var valid = enemy_hand.filter(func(c): return c.mana_cost <= enemy_mana)
	if valid.is_empty():
		enemy_action_timer.start(1.0)
		return

	var card: CardData = valid.pick_random()
	enemy_hand.erase(card)
	enemy_mana -= card.mana_cost

	# Telegraph via UI (signal)
	emit_signal("enemy_state_changed")  # DebugUI will pick up the card for display

	await get_tree().create_timer(float(card.tickdown)).timeout

	# Resolve enemy attack
	var incoming: int = card.damage
	if player_guard >= incoming:
		player_guard -= incoming
		guard_zone.clear()  # full block → discard later
	else:
		var excess = incoming - player_guard
		player_hp = maxi(player_hp - excess, 0)
		exile_pile.append_array(guard_zone)
		guard_zone.clear()
		player_guard = 0

	emit_signal("zones_changed")
	emit_signal("state_changed")
	emit_signal("enemy_state_changed")

	# Next enemy action
	_draw_enemy_hand()
	enemy_mana = mini(enemy_mana + 1, 4)  # enemy mana regen
	enemy_action_timer.start(2.0 + randf_range(0.0, 1.0))

# ── Debug Helpers (used by DebugUI.gd) ───────────────────────────────────────
func get_debug_data() -> Dictionary:
	return {
		"mode": current_mode,
		"enemy_target": "Goblin",
		"enemy_hp": enemy_hp,
		"deck_remaining": deck.size(),
		"hand_count": hand.size(),
		"discard_count": discard.size(),
		"mana": mana,
		"mana_timer": mana_timer.time_left if mana_timer else 0.0,
		"draw_timer": draw_timer.time_left if draw_timer else 0.0,
		"player_hp": player_hp,
		"player_guard": player_guard,
		"guard_zone_size": guard_zone.size(),
		"exile_size": exile_pile.size(),
		"enemy_guard": enemy_guard,
		"enemy_hand": ", ".join(enemy_hand.map(func(c): return c.card_name)),
		"enemy_rage": enemy_rage_mode,
		"last_card_played": last_card_played,
		"deck_cards": ", ".join(deck.map(func(c): return c.card_name if c else "")),
		"discard_cards": ", ".join(discard.map(func(c): return c.card_name if c else "")),
		"guard_cards": ", ".join(guard_zone.map(func(c): return c.card_name if c else "")),
		"exile_cards": ", ".join(exile_pile.map(func(c): return c.card_name if c else "")),
		"deck_cards_list": deck.map(func(c): return c.card_name if c else ""),
		"hand_cards_list": hand.map(func(c): return c.card_name if c else ""),
		"discard_cards_list": discard.map(func(c): return c.card_name if c else ""),
		"guard_cards_list": guard_zone.map(func(c): return c.card_name if c else ""),
		"exile_cards_list": exile_pile.map(func(c): return c.card_name if c else ""),
		"reward_cards_list": reward_options.map(func(c): return c.card_name if c else ""),
		"collection_cards_list": collection.map(func(c): return c.card_name if c else ""),
		"collection_size": collection.size(),
	}

# ── Debug Buttons (called from DebugUI) ──────────────────────────────────────
func debug_enter_battle() -> void:
	print("DEBUG: Enter Battle button pressed - current mode = ", current_mode)
	if current_mode != "Battle":
		start_new_battle()
		
func debug_kill_enemy() -> void:
	enemy_hp = 0
	end_battle()

func debug_respawn_enemy() -> void:
	if current_mode == "Battle":
		_reset_enemy_state()
		emit_signal("state_changed")
		emit_signal("enemy_state_changed")
