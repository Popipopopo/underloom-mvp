extends Node

# ────────────────────────────────────────────
# 玩家全局状态（单例，由 autoload 加载）
# ────────────────────────────────────────────

# 材料库存（v1.1：炼金工房式卡片背包——每份材料是一个 MaterialInstance，
# 元素在采集时已定型。同名材料的不同实例元素可以不同）
# - workshop_items：工作室仓库，合成只认这里
# - backpack_items：出门 / 局内背包；拾取进背包；回工作室时一次性并入仓库
var workshop_items: Array = []   # Array[MaterialInstance]
var backpack_items: Array = []   # Array[MaterialInstance]

# 货币（Phase I 经济系统时启用）
var gold: int = 0

# 合成产物(核/药/护符/交易品,统一 Core-typed)
var owned_items: Array = []        # Array[Core]
# 装备槽相关(测试装备/未来战斗)
var owned_cores: Array = []        # Array[Core]
var owned_wands: Array = []        # Array[Wand]

# 当前装备的魔杖
var equipped_wand: Wand = null

# ────────────────────────────────────────────
# 启动时硬编码一套测试装备（M0 验证用，最小可玩）
# 等节点地图采集接通后，仓库种子会换成真实采集流程
# ────────────────────────────────────────────
func _ready() -> void:
	_setup_test_loadout()
	_seed_debug_workshop_inventory()


# 调试：每种代表材料按三档丰度各 roll 两份，方便测合成时看到
# "同名材料不同元素"的卡片效果（正式流程可关掉）
func _seed_debug_workshop_inventory() -> void:
	var seed_ids := [
		# 魔物类
		"史莱姆凝胶", "蝙蝠翼膜", "骷髅碎骨",
		# 真菌类
		"白蘑菇", "发光菌", "温热孢子",
		# 矿物/结晶类
		"火晶石", "冰蓝水晶", "风化石英", "地底黑曜石", "盐",
	]
	var richness_levels := [0.15, 0.5, 0.9]   # 贫瘠 / 普通 / 丰饶
	for id in seed_ids:
		var mat: CraftingMaterial = MaterialDB.get_material(id)
		if mat == null:
			push_warning("[GameState] seed material missing: %s" % id)
			continue
		for r in richness_levels:
			for _i in 2:
				workshop_items.append(MaterialInstance.roll_from(mat, r))
	print("[GameState] Debug workshop seeded: %d material instances" % workshop_items.size())


func _setup_test_loadout() -> void:
	var bullet := Core.make_main_from_tiers(
		"basic_bullet",
		"基础魔力弹",
		"bullet",
		"small", "small", "small",
		30
	)
	owned_cores.append(bullet)

	var wand := Wand.make("starter_wand", "学徒杖", 3, 1.0)
	wand.equip(0, bullet)

	owned_wands.append(wand)
	equipped_wand = wand

	print("[GameState] 测试装备：%s（%d 槽）+ %s（%d/%d 使用次数）" % [
		equipped_wand.display_name,
		equipped_wand.slot_count,
		bullet.display_name,
		bullet.current_uses,
		bullet.max_uses,
	])

# ────────────────────────────────────────────
# 工作室仓库（合成用）
# ────────────────────────────────────────────
func add_workshop_item(inst: MaterialInstance) -> void:
	workshop_items.append(inst)

## Returns true if the instance was found and removed
func remove_workshop_item(inst: MaterialInstance) -> bool:
	var idx: int = workshop_items.find(inst)
	if idx < 0:
		return false
	workshop_items.remove_at(idx)
	return true

## 仓库里带指定 tag 的所有实例（选材界面用）
func workshop_items_by_tag(tag: String) -> Array:
	var result: Array = []
	for inst in workshop_items:
		var mat: CraftingMaterial = (inst as MaterialInstance).base()
		if mat != null and mat.has_tag(tag):
			result.append(inst)
	return result

## 某种材料在仓库里有几份（HUD/图鉴用）
func workshop_count_of(base_id: String) -> int:
	var n: int = 0
	for inst in workshop_items:
		if (inst as MaterialInstance).base_id == base_id:
			n += 1
	return n

# ────────────────────────────────────────────
# 出门背包（局内）
# ────────────────────────────────────────────
func add_backpack_item(inst: MaterialInstance) -> void:
	backpack_items.append(inst)

func remove_backpack_item(inst: MaterialInstance) -> bool:
	var idx: int = backpack_items.find(inst)
	if idx < 0:
		return false
	backpack_items.remove_at(idx)
	return true

# 回到工作室时：背包全部并入仓库后清空背包
# (v1.1:核是消耗品,用完销毁,不再有"回工作室充能"这一步)
func merge_backpack_into_workshop() -> void:
	workshop_items.append_array(backpack_items)
	backpack_items.clear()
	print("[GameState] Merged backpack into workshop; %d items total" % workshop_items.size())
