class_name CraftingState
extends RefCounted

var recipe: Recipe
# Same length as recipe.slot_tags; each entry is material id String or ""
var fills: Array = []

func _init(p_recipe: Recipe) -> void:
	recipe = p_recipe
	_reset_fills()

func set_recipe(p_recipe: Recipe) -> void:
	recipe = p_recipe
	_reset_fills()

func _reset_fills() -> void:
	if recipe == null:
		fills.clear()
		return
	fills.resize(recipe.slot_count())
	fills.fill("")

func reset_fills() -> void:
	_reset_fills()

func all_filled() -> bool:
	for v in fills:
		if str(v) == "":
			return false
	return true
