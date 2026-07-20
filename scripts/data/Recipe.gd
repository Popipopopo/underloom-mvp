class_name Recipe
extends RefCounted

var id: String = ""
var display_name: String = ""

# Each entry is a tag String that the material placed in that slot must have.
# e.g. ["魔物", "真菌", "矿物"]
var slot_tags: Array[String] = []

# 产物类型:core / potion / charm / trade —— 决定解读镜头(见 CraftingManager.LENS)
var product_type: String = "core"

# 使用次数基准(消耗品 core/potion > 0;装备/交易 charm/trade = -1 不消耗)
var base_uses: int = -1

# 招牌效果(仅此配方能出),Dictionary:
#   name: String            招牌名
#   threshold: String       门槛类型 "capacity_full" / "single_element" / "element_full"
#   value: int              门槛数量(capacity_full 忽略,取槽×2)
#   element: String         仅 element_full 用,指定元素
#   effect: String          效果描述(展示 + 未来战斗兑现)
var signature: Dictionary = {}

## Number of ingredient slots
func slot_count() -> int:
	return slot_tags.size()

## 元素容量 = 槽位数 × 2
func element_capacity() -> int:
	return slot_tags.size() * 2

## Check whether a CraftingMaterial satisfies the requirement for slot_index
func slot_accepts(slot_index: int, mat: CraftingMaterial) -> bool:
	if slot_index < 0 or slot_index >= slot_tags.size():
		return false
	return mat.has_tag(slot_tags[slot_index])

static func make(
	p_id: String, p_name: String, p_slot_tags: Array,
	p_product_type: String = "core", p_base_uses: int = -1, p_signature: Dictionary = {}
) -> Recipe:
	var r := Recipe.new()
	r.id = p_id
	r.display_name = p_name
	for t in p_slot_tags:
		r.slot_tags.append(str(t))
	r.product_type = p_product_type
	r.base_uses = p_base_uses
	r.signature = p_signature
	return r
