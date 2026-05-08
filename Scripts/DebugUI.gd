extends Control


# InfoCont
@onready var mode_label: Label = $InfoCont/ModeLabel
@onready var last_card_label: Label = $InfoCont/LastCardLabel
@onready var killed_label: Label = $InfoCont/KilledLabel

# DecklistsCont
@onready var deck_label: Label = $DecklistsCont/DeckLabel
@onready var discard_label: Label = $DecklistsCont/DiscardLabel
@onready var deck_zone: RichTextLabel = $DecklistsCont/DeckZone
@onready var discard_zone: RichTextLabel = $DecklistsCont/DiscardZone

# EnergyCont
@onready var mana_label: Label = $EnergyCont/ManaLabel
@onready var mana_timer_label: Label = $EnergyCont/ManaTimerLabel
@onready var mana_progress: ProgressBar = $EnergyCont/ManaProgress

# DrawCont
@onready var draw_timer_label: Label = $DrawCont/DrawTimerLabel
@onready var draw_progress: ProgressBar = $DrawCont/DrawProgress
@onready var hand_label: Label = $DrawCont/HandLabel
@onready var hand_zone: RichTextLabel = $DrawCont/HandZone

# Player stats
@onready var player_hp_label: Label = $PlayerCont/PlayerHPLabel
@onready var player_guard_label: Label = $GuardCont/PlayerGrdLabel

# Guard / Resolve / Exile zones
@onready var guard_zone_label: RichTextLabel = $GuardCont/GuardZone
@onready var resolving_zone_label: RichTextLabel = $ResolveCont/ResolvingZone
@onready var exile_zone_label: RichTextLabel = $ExileCont/ExileZone

# Enemy panel
@onready var enemy_name_label: Label = $EnemyCont/EnemyNameLabel
@onready var enemy_hp_label: Label = $EnemyCont/EnemyHPLabel
@onready var enemy_grd_label: Label = $EnemyCont/EnemyGrdLabel
@onready var enemy_hand_zone: RichTextLabel = $EnemyCont/EnemyHandZone
@onready var enemy_tele_label: Label = $EnemyCont/EnemyTeleLabel
@onready var enemy_progress: ProgressBar = $EnemyCont/EnemyProgress
@onready var enemy_rage_check: CheckBox = $EnemyCont/EnemyRage

# Dynamic Attack/Guard buttons (separate container)
@onready var hand_buttons_container = $DrawCont/HandZone

# RewardZone click support
@onready var reward_zone: RichTextLabel = $RewardCont/RewardZone

# Collection (for rewards)
@onready var collection_zone: RichTextLabel = $CollectionCont/CollectionZone

func _ready() -> void:
	BattleManager.state_changed.connect(_on_state_changed)
	BattleManager.zones_changed.connect(_on_state_changed)
	BattleManager.enemy_state_changed.connect(_on_enemy_state_changed)
	BattleManager.resolving_card_changed.connect(_on_resolving_card_changed)
	hand_zone.meta_clicked.connect(_on_hand_zone_meta_clicked)
	reward_zone.meta_clicked.connect(_on_reward_meta_clicked)
	
	_refresh_ui()
	set_process(true)

func _create_hand_buttons() -> void:
	# Always create a separate container to avoid conflict with HandZone RichTextLabel
	if hand_buttons_container == null or hand_buttons_container.name == "HandZone":
		hand_buttons_container = HBoxContainer.new()
		hand_buttons_container.name = "HandButtons"
		$DrawCont.add_child(hand_buttons_container)
	
	# Clear any existing buttons (prevents duplicates on refresh)
	for child in hand_buttons_container.get_children():
		child.queue_free()
	
	for i in range(5):
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var attack_btn = Button.new()
		attack_btn.text = "Attack %d" % i
		attack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attack_btn.pressed.connect(func(): BattleManager.play_card(i, false))
		
		var guard_btn = Button.new()
		guard_btn.text = "Guard %d" % i
		guard_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		guard_btn.pressed.connect(func(): BattleManager.play_card(i, true))
		
		hbox.add_child(attack_btn)
		hbox.add_child(guard_btn)
		hand_buttons_container.add_child(hbox)

func _on_state_changed() -> void:
	_refresh_ui()

func _on_enemy_state_changed() -> void:
	_refresh_ui()

func _on_resolving_card_changed(card_name: String) -> void:
	if is_instance_valid(resolving_zone_label):
		resolving_zone_label.text = "Resolving: " + card_name if card_name else ""
		
func _on_hand_zone_meta_clicked(meta: Variant) -> void:
	var parts = str(meta).split("_")
	if parts.size() != 2: return
	var action = parts[0]
	var index = int(parts[1])
	var as_guard = action == "guard"
	BattleManager.play_card(index, as_guard)
	
func _on_reward_meta_clicked(meta: Variant) -> void:
	var parts = str(meta).split("_")
	if parts.size() == 2 and parts[0] == "reward":
		var index = int(parts[1])
		if index >= 0 and index < BattleManager.reward_options.size():
			var chosen = BattleManager.reward_options[index]
			BattleManager.collection.append(chosen)
			BattleManager.reward_options.clear()
			BattleManager.current_mode = "Exploration"
			BattleManager.emit_signal("state_changed")
			BattleManager.emit_signal("zones_changed")
		
func _process(_delta: float) -> void:
	# Smooth per-frame progress bars
	if is_instance_valid(mana_progress):
		var time_left = BattleManager.mana_timer.time_left if BattleManager.mana_timer else 0.0
		mana_progress.value = (time_left / BattleConfig.mana_regen_time) * 100.0
	if is_instance_valid(draw_progress):
		var time_left = BattleManager.draw_timer.time_left if BattleManager.draw_timer else 0.0
		draw_progress.value = (time_left / BattleConfig.draw_time) * 100.0

func _refresh_ui() -> void:
	var data: Dictionary = BattleManager.get_debug_data()
	
	if is_instance_valid(mode_label):         mode_label.text = "Current Mode: " + data.mode
	if is_instance_valid(last_card_label):    last_card_label.text = "Last Card: " + data.get("last_card_played", "-")
	if is_instance_valid(killed_label):       killed_label.text = "Killed: " + ("Yes" if data.get("enemy_hp", 120) <= 0 else "No")
	
	if is_instance_valid(deck_label): 		deck_label.text = "Deck: " + str(data.deck_remaining)
	if is_instance_valid(discard_label):      discard_label.text = "Discard: " + str(data.discard_count)
	
	if is_instance_valid(mana_label):         mana_label.text = "Mana: " + str(data.mana)
	if is_instance_valid(mana_timer_label):   mana_timer_label.text = "Mana Timer: %.1f" % data.mana_timer
	if is_instance_valid(mana_progress):      mana_progress.value = (float(data.mana) / 10.0) * 100.0
	
	if is_instance_valid(draw_timer_label):   draw_timer_label.text = "Draw Timer: %.1f" % data.draw_timer
	if is_instance_valid(draw_progress):      draw_progress.value = (data.draw_timer / 3.0) * 100.0
	if is_instance_valid(hand_label):         hand_label.text = "Hand: " + str(data.hand_count)
	
	# Stage 2
	if is_instance_valid(player_hp_label):    player_hp_label.text = "Player HP: " + str(data.player_hp)
	if is_instance_valid(player_guard_label): player_guard_label.text = "Guard: " + str(data.player_guard)
	
	if is_instance_valid(guard_zone_label):   guard_zone_label.text = "GuardZone: " + str(data.guard_zone_size)
	if is_instance_valid(exile_zone_label):   exile_zone_label.text = "ExileZone: " + str(data.exile_size)
	
	# Enemy
	if is_instance_valid(enemy_name_label):   enemy_name_label.text = "Target: " + data.enemy_target
	if is_instance_valid(enemy_hp_label):     enemy_hp_label.text = "Enemy HP: " + str(data.enemy_hp)
	if is_instance_valid(enemy_grd_label):    enemy_grd_label.text = "Enemy Guard: " + str(data.enemy_guard)
	if is_instance_valid(enemy_hand_zone):    enemy_hand_zone.text = "Enemy Hand: " + data.enemy_hand
	if is_instance_valid(enemy_rage_check):   enemy_rage_check.button_pressed = data.enemy_rage
	# print("DEBUG: _refresh_ui() ran - mode = ", data.mode)
	
		# Card zone population (RichTextLabels)
	if is_instance_valid(deck_label): deck_label.text = "Deck: " + str(data.deck_remaining)
	if is_instance_valid(discard_label): discard_label.text = "Discard: " + str(data.discard_count)
	if is_instance_valid(hand_label): hand_label.text = "Hand: " + str(data.hand_count)
	if is_instance_valid(guard_zone_label): guard_zone_label.text = "GuardZone: " + str(data.guard_zone_size)
	if is_instance_valid(exile_zone_label): exile_zone_label.text = "ExileZone: " + str(data.exile_size)
	
	# RichTextLabel zones — one card per line (Day 2 style)
	if is_instance_valid(deck_zone):
		deck_zone.text = "Deck (" + str(data.deck_remaining) + ")\n" + "\n".join(data.get("deck_cards_list", []))
	if is_instance_valid(discard_zone):
		discard_zone.text = "Discard (" + str(data.discard_count) + ")\n" + "\n".join(data.get("discard_cards_list", []))
	if is_instance_valid(hand_zone):
		hand_zone.text = "Hand (" + str(data.hand_count) + ")\n" + "\n".join(data.get("hand_cards_list", []))
	if is_instance_valid(guard_zone_label):
		guard_zone_label.text = "GuardZone (" + str(data.guard_zone_size) + ")\n" + "\n".join(data.get("guard_cards_list", []))
	if is_instance_valid(exile_zone_label):
		exile_zone_label.text = "ExileZone (" + str(data.exile_size) + ")\n" + "\n".join(data.get("exile_cards_list", []))
		
	if is_instance_valid(resolving_zone_label):
		pass  # handled by signal
		
	if is_instance_valid(reward_zone):
		reward_zone.bbcode_enabled = true
		var reward_text = "Rewards (click to choose)\n"
		for i in range(data.get("reward_cards_list", []).size()):
			var card_name = data.get("reward_cards_list", [])[i]
			reward_text += "[url=reward_%d]%s[/url]\n" % [i, card_name]
		reward_zone.text = reward_text
		
	if is_instance_valid(collection_zone):
		collection_zone.text = "Collection (" + str(data.get("collection_size", 0)) + ")\n" + "\n".join(data.get("collection_cards_list", []))
		
	if is_instance_valid(hand_zone):
		hand_zone.bbcode_enabled = true
		var hand_text = "Hand (" + str(data.hand_count) + ")\n"
		var cards = data.get("hand_cards_list", [])
		for i in range(cards.size()):
			var card_name = cards[i]
			hand_text += "[url=attack_%d]Attack[/url] [url=guard_%d]Guard[/url] %s\n" % [i, i, card_name]
		hand_zone.text = hand_text

	# Mode visibility
	_update_mode_visibility(data)
	
	# Optional: show actual card names in HandZone for debugging
	if is_instance_valid(hand_label) and "hand_cards" in data:
		hand_label.text += "\n" + data.hand_cards
	
func _update_mode_visibility(data: Dictionary) -> void:
	var is_battle = data.mode == "Battle"
	var is_reward = data.mode == "Reward"

	$InfoCont.visible = true
	$ButtonCont.visible = true
	$DecklistsCont.visible = is_battle
	$ExileCont.visible = is_battle
	$EnergyCont.visible = is_battle
	$DrawCont.visible = is_battle
	$GuardCont.visible = is_battle
	$EnemyCont.visible = is_battle
	$ResolveCont.visible = is_battle
	$RewardCont.visible = is_reward
	$CollectionCont.visible = is_reward   # always visible so player can see full owned collection
	


# ── Debug button hooks (already wired in your scene) ────────────────────────
func _on_enter_battle_button_pressed() -> void:
	#print("DEBUG: _on_enter_battle_button_pressed() called")
	BattleManager.debug_enter_battle()

func _on_kill_enemy_button_pressed() -> void:
	print("DEBUG: Kill_enemy_button_pressed() called")
	BattleManager.debug_kill_enemy()

func _on_respawn_enemy_button_pressed() -> void:
	BattleManager.debug_respawn_enemy()


func _on_enter_battle_btn_pressed() -> void:
	#print("DEBUG: Enter Battle button pressed")
	BattleManager.debug_enter_battle()
	
