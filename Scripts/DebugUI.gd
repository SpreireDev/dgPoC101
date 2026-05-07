extends Control

@onready var battle_manager = get_node("/root/BattleManager")

func _ready() -> void:
	if not battle_manager:
		print("ERROR: BattleManager not found!")
		return
	
	battle_manager.state_changed.connect(_update_static_ui)
	_update_static_ui()
	
	# Connect all buttons (correct names from scene)
	_connect_button("ButtonCont/EnterBattleBtn", _on_enter_battle)
	_connect_button("ButtonCont/PlayCardBtn", _on_play_card)
	_connect_button("ButtonCont/AddManaBtn", _on_add_mana)
	_connect_button("ButtonCont/DrawCardBtn", _on_draw_card)
	_connect_button("ButtonCont/KillEnemyBtn", _on_kill_enemy)
	_connect_button("ButtonCont/RespawnBtn", _on_respawn)

# Runs every frame for smooth progress bars and timer labels
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
	if not battle_manager: return
	
	var data = battle_manager.get_debug_data()
	
	# Info Section
	_set_label_text("InfoCont/ModeLabel", "Mode: " + data.mode)
	_set_label_text("InfoCont/LastCardLabel", "Last Played: " + data.last_card_played)
	_set_label_text("InfoCont/KilledLabel", "Killed: " + str(data.enemies_killed))
	
	# Enemy Section
	_set_label_text("EnemyCont/EnemyNameLabel", "Enemy: " + data.enemy_name)
	_set_label_text("EnemyCont/EnemyHPLabel", "Enemy HP: %d" % data.enemy_hp)
	
	# Energy Section (static values)
	_set_label_text("EnergyCont/ManaLabel", "Mana: %d / %d" % [data.mana, data.mana_max])
	
	# Draw Section (static values)
	_set_label_text("DrawCont/HandLabel", "Hand: %d / %d" % [data.hand_count, data.hand_limit])
	
	# Card Zones
	_update_card_zone("DecklistsCont/DeckZone", battle_manager.deck, "Deck")
	_update_card_zone("DecklistsCont/DiscardZone", battle_manager.discard, "Discard")
	_update_card_zone("DrawCont/HandZone", battle_manager.hand, "Hand")
	_update_card_zone("DrawCont/ResolvingZone", [], "Resolving")

func _set_label_text(path: String, text: String) -> void:
	var label = get_node_or_null(path)
	if label:
		label.text = text

func _update_card_zone(path: String, card_array: Array, zone_name: String) -> void:
	var zone = get_node_or_null(path)
	if not zone:
		return
	
	var text = "[b]%s (%d):[/b]\n" % [zone_name, card_array.size()]
	
	if card_array.is_empty():
		text += "[i]Empty[/i]"
	else:
		for i in card_array.size():
			var card = card_array[i]
			if card == null:
				text += "• [color=red]NULL CARD[/color]\n"
				print("WARNING: Null card found in ", zone_name, " at index ", i)
				continue
			
			text += "• %s" % card.card_name
			if i < card_array.size() - 1:
				text += "\n"
	
	zone.bbcode_enabled = true
	zone.text = text

# Button functions (same as before)
func _on_enter_battle() -> void:
	battle_manager.current_mode = "Battle"
	battle_manager._reset_game()

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
	
func _connect_button(button_path: String, callable: Callable) -> void:
	var button = get_node_or_null(button_path)
	if button:
		button.pressed.connect(callable)
	else:
		print("Warning: Button not found → ", button_path)	
