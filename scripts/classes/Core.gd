class_name Core
extends RefCounted

# ────────────────────────────────────────────
# 通用字段
# ────────────────────────────────────────────
var id: String
var display_name: String
var core_type: String          # "main" / "support"

# 充能（v1.1：核是可充能技能，不是消耗品）
# - 主核：max_charges > 0，用光后不销毁，回工作室自动恢复
# - 辅核：max_charges = -1 表示无限
var max_charges: int = -1
var current_charges: int = -1

# 施放前摇（回合制战斗系统接入后决定具体语义）
var charge_time: float = 0.3

# ────────────────────────────────────────────
# 主核字段（core_type == "main"）
# ────────────────────────────────────────────
var attack_pattern: String     # "bullet" / "ball" / "chain" / "arrow"
var damage_tier: String = "small"      # "small" / "medium" / "large"
var range_tier: String = "small"
var special_tier: String = "small"     # 不同 attack_pattern 含义不同
var element: String = ""               # "fire" / "ice" / "lightning" / ""

# ────────────────────────────────────────────
# 辅核字段（core_type == "support"）
# ────────────────────────────────────────────
var support_effect: String     # "amp" / "speed_up" / "multicast" / "split" / "homing" / "fire"
var support_value: float = 0.0

# ────────────────────────────────────────────
# 新合成系统附加字段
# ────────────────────────────────────────────
# 元素共鸣词条（如 ["冰弹", "轻微追踪"]），合成时写入
var element_tags: Array[String] = []
# Tag共鸣词条（如 ["鬼火"]），合成时写入
var tag_words: Array[String] = []
# 合成结果等级 1-40
var result_lv: int = 0

# ────────────────────────────────────────────
# 充能 API
# ────────────────────────────────────────────
func is_depleted() -> bool:
	return max_charges > 0 and current_charges <= 0

func consume_charge(n: int = 1) -> void:
	if max_charges > 0:
		current_charges = max(0, current_charges - n)

## 回工作室时调用：充能全满
func recharge_full() -> void:
	if max_charges > 0:
		current_charges = max_charges

# ────────────────────────────────────────────
# 工厂方法
# ────────────────────────────────────────────
# 主核：从档位字符串造（合成产物会走这条）
static func make_main_from_tiers(
	p_id: String, p_name: String, p_pattern: String,
	p_dmg_tier: String, p_range_tier: String, p_special_tier: String,
	p_max_charges: int, p_element: String = "", p_charge: float = 0.3
) -> Core:
	var c := Core.new()
	c.id = p_id
	c.display_name = p_name
	c.core_type = "main"
	c.attack_pattern = p_pattern
	c.damage_tier = p_dmg_tier
	c.range_tier = p_range_tier
	c.special_tier = p_special_tier
	c.element = p_element
	c.max_charges = p_max_charges
	c.current_charges = p_max_charges
	c.charge_time = p_charge
	return c

# 辅核：MVP 阶段无充能限制（max_charges = -1）
static func make_support(p_id: String, p_name: String, p_effect: String, p_value: float) -> Core:
	var c := Core.new()
	c.id = p_id
	c.display_name = p_name
	c.core_type = "support"
	c.support_effect = p_effect
	c.support_value = p_value
	c.max_charges = -1
	c.current_charges = -1
	return c
