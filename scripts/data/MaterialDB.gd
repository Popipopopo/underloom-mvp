class_name MaterialDB
extends Node

# ── Internal registry (built once on first access) ────────────────────────────
static var _db: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_r("白蘑菇",     ["真菌", "食材"],              {"土": 2},               "土", 3)
	_r("发光菌",     ["真菌", "幽影", "发光"],        {"风": 2, "土": 2},      "风", 5)
	_r("温热孢子",   ["真菌", "高温"],               {"火": 2},               "火", 4)
	_r("史莱姆凝胶", ["魔物", "液体"],               {"水": 2},               "水", 2)
	_r("蝙蝠翼膜",   ["动物", "魔物"],               {"风": 2},               "风", 4)
	_r("骷髅碎骨",   ["亡灵", "魔物"],               {"土": 2},               "土", 3)
	_r("毒蜘蛛腺体", ["昆虫", "剧毒"],               {"土": 1, "水": 1},      "水", 3)
	_r("火蜥蜴鳞片", ["动物", "高温"],               {"火": 2},               "火", 6)
	_r("苔藓",       ["植物"],                       {"水": 2, "风": 1},      "水", 2)
	_r("草药",       ["植物", "食材", "芬芳"],        {"水": 2},               "水", 3)
	_r("洋甘菊",     ["植物", "芬芳"],               {"风": 2, "水": 1},      "风", 3)
	_r("薰衣草",     ["植物", "芬芳"],               {"风": 2, "水": 1},      "风", 4)
	_r("迷迭香",     ["植物", "芬芳"],               {"风": 2, "火": 1},      "风", 4)
	_r("月见草",     ["植物", "发光"],               {"风": 2, "水": 1},      "风", 5)
	_r("毒堇",       ["植物", "剧毒"],               {"水": 2, "土": 1, "风": 1}, "水", 5)
	_r("火晶石",     ["矿物", "高温"],               {"火": 2},               "火", 7)
	_r("冰蓝水晶",   ["矿物", "冰冷"],               {"水": 2},               "水", 6)
	_r("风化石英",   ["矿物", "粉末"],               {"风": 2, "土": 1},      "风", 4)
	_r("地底黑曜石", ["矿物", "地底"],               {"土": 2, "火": 1},      "土", 6)
	_r("鹰羽",       ["动物", "天空"],               {"风": 3},               "风", 5)
	_r("蜂蜜",       ["昆虫", "食材", "芬芳"],        {"土": 1, "风": 1},      "土", 2)
	_r("盐",         ["食材", "矿物"],               {"土": 2},               "土", 1)

static func _r(p_name: String, tags: Array, elements_max: Dictionary, default_el: String, lv: int) -> void:
	_db[p_name] = CraftingMaterial.make(p_name, p_name, tags, elements_max, default_el, lv)

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

# ── Legacy shims (ancient_seal still used by pickup/ending system) ─────────────

static func get_contribution(_id: String) -> int:
	return 0

static func get_data(id: String) -> Dictionary:
	var mat: CraftingMaterial = get_material(id)
	if mat == null:
		return {}
	return {"display_name": mat.display_name, "lv": mat.lv, "tags": mat.tags.duplicate()}

static func make_material(id: String) -> CraftingMaterial:
	return get_material(id)
