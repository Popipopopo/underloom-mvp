extends CanvasLayer

@onready var label: Label = $InfoLabel

func _process(_delta: float) -> void:
	var wand_text := "No wand"
	if GameState.equipped_wand != null:
		var main_core: Core = GameState.equipped_wand.get_main_core()
		if main_core != null:
			wand_text = "%s %d/%d" % [main_core.display_name, main_core.current_charges, main_core.max_charges]
		else:
			wand_text = "No main core"
	label.text = "Main core: %s\nWorkshop: %s\nBackpack: %s" % [
		wand_text,
		str(GameState.workshop_inventory),
		str(GameState.backpack),
	]
