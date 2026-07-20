class_name RecipeDB
extends Node

# ── Recipe registry ────────────────────────────────────────────────────────────
# 基础配方表 v0.1(见 documentation/Underloom_基础配方表_v0.1.md)。
# 招牌门槛类型:capacity_full=锁满全容量;single_element=任意单元素达N;element_full=指定元素达N。

static var _recipes: Array = []
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	# ── 核类(战斗消耗品,兼炸弹)──────────────────────────────────
	_recipes.append(Recipe.make(
		"魔力核", "魔力核", ["魔物", "真菌", "矿物"], "core", 5,
		{"name": "共鸣", "threshold": "single_element", "value": 6,
		 "effect": "单一元素锁满6 → 该元素效果升超阶"}))
	_recipes.append(Recipe.make(
		"速凝核", "速凝核", ["魔物", "矿物"], "core", 8,
		{"name": "连射", "threshold": "capacity_full",
		 "effect": "容量锁满 → 一回合打两发"}))
	_recipes.append(Recipe.make(
		"轰鸣核", "轰鸣核", ["魔物", "真菌", "矿物", "结晶"], "core", 3,
		{"name": "过载", "threshold": "capacity_full",
		 "effect": "8格全锁满 → 伤害×2(使用次数−1)"}))

	# ── 药剂(消耗品)──────────────────────────────────────────────
	_recipes.append(Recipe.make(
		"回复药", "回复药", ["食材", "植物"], "potion", 3,
		{"name": "回魂", "threshold": "element_full", "element": "水", "value": 4,
		 "effect": "水锁满4 → 倒下自动复活一次"}))

	# ── 装备(非消耗,长期被动)────────────────────────────────────
	_recipes.append(Recipe.make(
		"护符", "护符", ["结晶", "发光"], "charm", -1,
		{"name": "元素壁垒", "threshold": "single_element", "value": 4,
		 "effect": "单一元素锁满4 → 对该元素伤害免疫"}))

	# ── 交易品(纯换钱/好感)──────────────────────────────────────
	_recipes.append(Recipe.make(
		"石雕摆件", "石雕摆件", ["矿物", "粉末"], "trade", -1,
		{"name": "传世珍品", "threshold": "capacity_full",
		 "effect": "容量锁满 → 品质跃升,售价翻倍"}))

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
