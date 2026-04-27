class_name RecipeDB
extends Node

# MVP: 5 recipes (plan)
const _ALL = [
	{
		"id": "recipe_bullet",
		"display_name": "Basic Magic Missile",
		"core_type": "main",
		"attack_pattern": "bullet",
		"max_ammo": 30,
		"base_charge": 0.3,
		"slots": ["damage", "damage", "range"]
	},
	{
		"id": "recipe_ball",
		"display_name": "Basic Magic Orb",
		"core_type": "main",
		"attack_pattern": "ball",
		"max_ammo": 20,
		"base_charge": 0.45,
		"slots": ["damage", "range", "range"]
	},
	{
		"id": "recipe_amp",
		"display_name": "Empower (support)",
		"core_type": "support",
		"support_effect": "amp",
		"support_value": 0.2,
		"max_ammo": -1,
		"slots": ["damage", "damage"]
	},
	{
		"id": "recipe_speedup",
		"display_name": "Haste (support)",
		"core_type": "support",
		"support_effect": "speed_up",
		"support_value": 0.5,
		"max_ammo": -1,
		"slots": ["range", "range"]
	},
	{
		"id": "recipe_multicast",
		"display_name": "Multicast (support)",
		"core_type": "support",
		"support_effect": "multicast",
		"support_value": 1.0,
		"max_ammo": -1,
		"slots": ["special", "special"]
	}
]

static func get_all() -> Array:
	return _ALL.duplicate()

static func by_id(p_id: String) -> Dictionary:
	for d in _ALL:
		if d.get("id", "") == p_id:
			return d.duplicate()
	return {}

static func make_recipe(p_id: String) -> Recipe:
	var d: Dictionary = by_id(p_id)
	if d.is_empty():
		return null
	return Recipe.from_dict(d)
