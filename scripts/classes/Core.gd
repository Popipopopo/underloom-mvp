class_name Core
extends RefCounted

# ────────────────────────────────────────────
# 通用字段
# ────────────────────────────────────────────
var id: String
var display_name: String
var core_type: String          # "main" / "support"

# 弹药（GDD 6.6 + 用户自定）
# - 主核：max_ammo > 0，current_ammo 用光后核销毁
# - 辅核：max_ammo = -1 表示无限
var max_ammo: int = -1
var current_ammo: int = -1

# 充能（充能时长，由 WandController 用 wand.charge_speed 折算）
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
# 弹药 API
# ────────────────────────────────────────────
func is_depleted() -> bool:
	return max_ammo > 0 and current_ammo <= 0

func consume_ammo(n: int = 1) -> void:
	if max_ammo > 0:
		current_ammo = max(0, current_ammo - n)

# ────────────────────────────────────────────
# 工厂方法
# ────────────────────────────────────────────
# 主核：从档位字符串造（合成产物会走这条）
static func make_main_from_tiers(
	p_id: String, p_name: String, p_pattern: String,
	p_dmg_tier: String, p_range_tier: String, p_special_tier: String,
	p_max_ammo: int, p_element: String = "", p_charge: float = 0.3
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
	c.max_ammo = p_max_ammo
	c.current_ammo = p_max_ammo
	c.charge_time = p_charge
	return c

# 辅核：MVP 阶段无弹药（max_ammo = -1）
static func make_support(p_id: String, p_name: String, p_effect: String, p_value: float) -> Core:
	var c := Core.new()
	c.id = p_id
	c.display_name = p_name
	c.core_type = "support"
	c.support_effect = p_effect
	c.support_value = p_value
	c.max_ammo = -1
	c.current_ammo = -1
	return c
