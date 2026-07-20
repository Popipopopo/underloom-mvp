class_name Core
extends RefCounted

## 合成产物的通用运行时结构(历史名 Core;现承载核/药/护符/交易品四类)。
## v1.1:核是消耗品(有使用次数,用完销毁),不再可充能。

# ────────────────────────────────────────────
# 通用字段
# ────────────────────────────────────────────
var id: String
var display_name: String
var product_type: String = "core"   # core / potion / charm / trade
var core_type: String = "main"      # 装备用(仅 core):main / support

# 使用次数(消耗品:core/potion 有次数,用完销毁;charm/trade = -1 不消耗)
var max_uses: int = -1
var current_uses: int = -1

# ────────────────────────────────────────────
# 合成结果
# ────────────────────────────────────────────
var result_lv: int = 0
var elements: Array[String] = []          # 最终锁定的元素,如 ["火","火","风"]
var element_effects: Array[String] = []   # 经解读镜头翻译的效果描述(按产物类型)
var element_tags: Array[String] = []      # 元素共鸣词条(通用,如 ["蒸汽弹"])
var tag_words: Array[String] = []         # tag 共鸣词条(通用,如 ["鬼火"])

# 招牌效果(仅该配方能出)
var signature_name: String = ""
var signature_unlocked: bool = false

# ────────────────────────────────────────────
# 核专用(装备/战斗用,MVP 先保留)
# ────────────────────────────────────────────
var attack_pattern: String = "bullet"
var damage_tier: String = "small"
var range_tier: String = "small"
var special_tier: String = "small"
var element: String = ""
var support_effect: String = ""
var support_value: float = 0.0
var charge_time: float = 0.3

# ────────────────────────────────────────────
# 使用次数 API(消耗品)
# ────────────────────────────────────────────
func is_consumable() -> bool:
	return max_uses > 0

func is_depleted() -> bool:
	return max_uses > 0 and current_uses <= 0

func consume_use(n: int = 1) -> void:
	if max_uses > 0:
		current_uses = max(0, current_uses - n)

# ────────────────────────────────────────────
# 工厂方法
# ────────────────────────────────────────────
## 通用合成产物(合成结算走这条)
static func make_product(
	p_id: String, p_name: String, p_product_type: String, p_max_uses: int, p_lv: int
) -> Core:
	var c := Core.new()
	c.id = p_id
	c.display_name = p_name
	c.product_type = p_product_type
	c.max_uses = p_max_uses
	c.current_uses = p_max_uses
	c.result_lv = p_lv
	return c

## 核(装备用,给测试装备/未来战斗)。核是消耗品:max_uses>0,用完销毁。
static func make_main_from_tiers(
	p_id: String, p_name: String, p_pattern: String,
	p_dmg_tier: String, p_range_tier: String, p_special_tier: String,
	p_max_uses: int, p_element: String = "", p_charge: float = 0.3
) -> Core:
	var c := Core.new()
	c.id = p_id
	c.display_name = p_name
	c.product_type = "core"
	c.core_type = "main"
	c.attack_pattern = p_pattern
	c.damage_tier = p_dmg_tier
	c.range_tier = p_range_tier
	c.special_tier = p_special_tier
	c.element = p_element
	c.max_uses = p_max_uses
	c.current_uses = p_max_uses
	c.charge_time = p_charge
	return c

# 辅核:无使用次数限制(max_uses = -1)
static func make_support(p_id: String, p_name: String, p_effect: String, p_value: float) -> Core:
	var c := Core.new()
	c.id = p_id
	c.display_name = p_name
	c.product_type = "core"
	c.core_type = "support"
	c.support_effect = p_effect
	c.support_value = p_value
	c.max_uses = -1
	c.current_uses = -1
	return c
