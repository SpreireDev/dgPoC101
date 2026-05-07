extends Node

var cards: Array[CardData] = []

func _ready() -> void:
	load_cards()

func load_cards() -> void:
	cards.clear()
	
	var file = FileAccess.open("res://Resources/cards.json", FileAccess.READ)
	if not file:
		print("ERROR: Could not open cards.json")
		return
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("ERROR: Failed to parse cards.json")
		return
	
	var card_list = json.data
	
	for card_data in card_list:
		var card = CardData.new()
		card.card_name = card_data.get("name", "Unknown")
		card.damage = card_data.get("damage", 0)
		cards.append(card)
	
	print("Loaded %d cards from JSON" % cards.size())

func get_all_cards() -> Array[CardData]:
	return cards

func get_random_card() -> CardData:
	if cards.is_empty():
		return null
	return cards.pick_random()
