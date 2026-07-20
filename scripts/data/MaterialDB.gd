class_name MaterialDB
extends Node

## 材料数据库。数据唯一来源是 res://data/materials.json，
## 改材料请改 JSON，不要在这里硬编码。

const DATA_PATH := "res://data/materials.json"

# ── Internal registry (built once on first access) ────────────────────────────
static var _db: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("[MaterialDB] cannot open %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("materials"):
		push_error("[MaterialDB] bad JSON format in %s" % DATA_PATH)
		return

	for entry in (parsed as Dictionary)["materials"]:
		var e: Dictionary = entry
		var id: String = str(e.get("id", ""))
		if id == "":
			continue
		# JSON 数字是 float，元素上限转回 int
		var elements_max: Dictionary = {}
		for el in (e.get("elements_max", {}) as Dictionary).keys():
			elements_max[el] = int(e["elements_max"][el])
		_db[id] = CraftingMaterial.make(
			id,
			str(e.get("display_name", id)),
			e.get("tags", []),
			elements_max,
			str(e.get("default_element", "")),
			int(e.get("lv", 1))
		)
	print("[MaterialDB] loaded %d materials from %s" % [_db.size(), DATA_PATH])

# ── Public API ─────────────────────────────────────────────────────────────────

static func has(id: String) -> bool:
	_ensure_init()
	return _db.has(id)

static func get_material(id: String) -> CraftingMaterial:
	_ensure_init()
	return _db.get(id, null)

static func get_all() -> Array:
	_ensure_init()
	return _db.values()

static func get_all_ids() -> Array:
	_ensure_init()
	return _db.keys()

## All materials that carry a given tag
static func get_by_tag(tag: String) -> Array:
	_ensure_init()
	var result: Array = []
	for mat in _db.values():
		if (mat as CraftingMaterial).has_tag(tag):
			result.append(mat)
	return result
