extends CanvasLayer

@onready var label: Label = $InfoLabel

func _process(_delta: float) -> void:
	var wand_text := "No wand"
	if GameState.equipped_wand != null:
		var main_core: Core = GameState.equipped_wand.get_main_core()
		if main_core != null:
			wand_text = "%s %d/%d" % [main_core.display_name, main_core.current_uses, main_core.max_uses]
		else:
			wand_text = "No main core"
	label.text = "Main core: %s\nWorkshop: %d items\nBackpack: %d items\nCrafted: %d" % [
		wand_text,
		GameState.workshop_items.size(),
		GameState.backpack_items.size(),
		GameState.owned_items.size(),
	]
