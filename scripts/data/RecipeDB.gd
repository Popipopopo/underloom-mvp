class_name RecipeDB
extends Node

# ── Recipe registry ────────────────────────────────────────────────────────────
# Each recipe lists the tag requirement per slot.
# The CraftingScreen enforces that placed materials carry the required tag.

static var _recipes: Array = []
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_recipes.append(Recipe.make("魔力核", "魔力核", ["魔物", "真菌", "矿物"]))

# ── Public API ─────────────────────────────────────────────────────────────────

static func get_all() -> Array:
	_ensure_init()
	return _recipes.duplicate()

static func by_id(id: String) -> Recipe:
	_ensure_init()
	for r in _recipes:
		if (r as Recipe).id == id:
			return r
	return null

# Legacy shim used by old CraftingManager — returns {} so callers get null-safe
static func make_recipe(id: String) -> Recipe:
	return by_id(id)
