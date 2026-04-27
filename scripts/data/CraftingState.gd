class_name CraftingState
extends RefCounted

var recipe: Recipe
# Same length as recipe.slots, each entry is material id or ""
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
	fills.resize(recipe.slots.size())
	fills.fill("")


func reset_fills() -> void:
	_reset_fills()
