extends Control

@onready var battle_manager = get_node("/root/BattleManager")

func _ready() -> void:
	if not battle_manager:
		print("ERROR: BattleManager not found!")
		return
	
	battle_manager.state_changed.connect(_update_static_ui)
	_update_static_ui()
	
	# Debug control buttons
	_connect_button("ButtonCont/EnterBattleBtn", _on_enter_battle)
	_connect_button("ButtonCont/PlayCardBtn", _on_play_card)
	_connect_button("ButtonCont/AddManaBtn", _on_add_mana)
	_connect_button("ButtonCont/DrawCardBtn", _on_draw_card)
	_connect_button("ButtonCont/KillEnemyBtn", _on_kill_enemy)
	_connect_button("ButtonCont/RespawnBtn", _on_respawn)
	
	# Reward buttons
	_connect_button("RewardCont/ClaimReward0Btn", _on_claim_reward_0)
	_connect_button("RewardCont/ClaimReward1Btn", _on_claim_reward_1)
	_connect_button("RewardCont/ClaimReward2Btn", _on_claim_reward_2)


# === Reward button handlers (named functions) ===
func _on_claim_reward_0() -> void:  battle_manager.claim_reward(0)
func _on_claim_reward_1() -> void:  battle_manager.claim_reward(1)
func _on_claim_reward_2() -> void:  battle_manager.claim_reward(2)
	
func _process(_delta: float) -> void:
	if not battle_manager: return
	
	var data = battle_manager.get_debug_data()
	
	# Smooth timer labels
	_set_label_text("EnergyCont/ManaTimerLabel", "Mana Timer: %.2f" % data.mana_timer)
	_set_label_text("DrawCont/DrawTimerLabel", "Draw Timer: %.2f" % data.draw_timer)
	
	# Smooth progress bars
	var mana_progress = get_node_or_null("EnergyCont/ManaProgress")
	var draw_progress = get_node_or_null("DrawCont/DrawProgress")
	
	if mana_progress:
		var percent = (data.mana_timer / battle_manager.mana_regen_time) * 100.0
		mana_progress.value = clamp(percent, 0, 100)
	
	if draw_progress:
		var percent = (data.draw_timer / battle_manager.draw_time) * 100.0
		draw_progress.value = clamp(percent, 0, 100)

# Only updates when something important changes (card played, etc.)


func _update_static_ui() -> void:
	var data: Dictionary = battle_manager.get_debug_data()
	
	# InfoCont
	var node = get_node_or_null("InfoCont/ModeLabel")
	if node: node.text = "Mode: %s" % data.mode
	
	node = get_node_or_null("InfoCont/LastCardLabel")
	if node: node.text = "Last Card: %s" % (data.last_card_played if data.last_card_played else "—")
	
	# EnemyCont
	node = get_node_or_null("EnemyCont/EnemyNameLabel")
	if node: node.text = "Enemy: %s" % data.enemy_name
	
	node = get_node_or_null("EnemyCont/EnemyHPLabel")
	if node: node.text = "Enemy HP: %d" % data.enemy_hp
	
	# DecklistsCont (Battle Deck + Discard)
	node = get_node_or_null("DecklistsCont/DeckZone/DeckLabel")
	if node: node.text = "Battle Deck: %d" % data.battle_deck
	
	node = get_node_or_null("DecklistsCont/DiscardLabel")
	if node: node.text = "Discard: %d" % data.discard_count
	
	# EnergyCont
	node = get_node_or_null("EnergyCont/ManaLabel")
	if node: node.text = "Mana: %d / %d" % [data.mana, data.mana_max]
	
	node = get_node_or_null("EnergyCont/ManaTimerLabel")
	if node: node.text = "Mana Timer: %.1f" % data.mana_timer
	
	# DrawCont
	node = get_node_or_null("DrawCont/DrawTimerLabel")
	if node: node.text = "Draw Timer: %.1f" % data.draw_timer
	
	node = get_node_or_null("DrawCont/HandLabel")
	if node: node.text = "Hand: %d / %d" % [data.hand_count, data.hand_limit]
	
		# === Populate RichTextLabels with actual cards ===
	_update_card_zone("DecklistsCont/DeckZone", data.battle_deck_cards, "Battle Deck")
	_update_card_zone("DrawCont/HandZone", data.hand_cards, "Hand")
	_update_card_zone("DecklistsCont/DiscardZone", data.discard_cards, "Discard")
	_update_card_zone("CollectionCont/CollectionZone", data.collection_cards, "Player Collection")  # adjust path if your discard label is named differently
	
	# Reward (already handled)
	_update_reward_ui(data)
	
	

func _set_label_text(path: String, text: String) -> void:
	var label = get_node_or_null(path)
	if label:
		label.text = text

func _update_card_zone(path: String, cards: Array, title: String) -> void:
	var zone = get_node_or_null(path)
	if not zone:
		return
	
	zone.bbcode_enabled = true
	var text = "[b]%s (%d):[/b]\n" % [title, cards.size()]
	
	if cards.is_empty():
		text += "[i]empty[/i]"
	else:
		for card in cards:
			text += "• %s (DMG %d)\n" % [card.card_name, card.damage]
	
	zone.text = text

# Button functions (same as before)
#func _on_enter_battle() -> void:
	#battle_manager.current_mode = "Battle"
	#battle_manager._reset_game()
	
func _on_enter_battle() -> void:
	battle_manager.start_new_battle()

func _on_play_card() -> void:
	battle_manager.play_card_at_index(0)

func _on_add_mana() -> void:
	battle_manager.add_mana(1)

func _on_draw_card() -> void:
	battle_manager.force_draw()

func _on_kill_enemy() -> void:
	battle_manager.kill_enemy()

func _on_respawn() -> void:
	battle_manager.respawn_enemy()
	
func _on_claim_reward(index: int) -> void:
	battle_manager.claim_reward(index)

func _update_reward_ui(data: Dictionary) -> void:
	var label = get_node_or_null("RewardCont/RewardOptionsLabel")
	if not label:
		return
	
	if data.mode != "Reward":
		label.text = ""
		return
	
	label.bbcode_enabled = true
	label.text = "[b]Choose one reward:[/b]\n"
	
	var cards = data.get("reward_cards", [])
	for i in cards.size():
		var card = cards[i]
		label.text += "%d. %s (DMG %d)\n" % [i, card.card_name, card.damage] 
		

func _connect_button(button_path: String, callable: Callable) -> void:
	var button = get_node_or_null(button_path)
	if button:
		button.pressed.connect(callable)
	else:
		print("Warning: Button not found → ", button_path)	
