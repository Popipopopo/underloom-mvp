class_name CraftingState
extends RefCounted

var recipe: Recipe
# Same length as recipe.slot_tags; each entry is a MaterialInstance or null
# （v1.1：槽位持有已定型的材料实例，元素在采集时决定）
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
	fills.fill(null)

func reset_fills() -> void:
	_reset_fills()

func all_filled() -> bool:
	for v in fills:
		if v == null:
			return false
	return true
