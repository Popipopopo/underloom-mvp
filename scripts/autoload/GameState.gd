extends Node

# ────────────────────────────────────────────
# 玩家全局状态（单例，由 autoload 加载）
# ────────────────────────────────────────────

# 材料分两处：
# - workshop_inventory：工作室仓库，合成 Crafting 只认这里
# - backpack：出门 / 局内背包；拾取进背包；回工作室时一次性并入 workshop，再清空
var workshop_inventory: Dictionary = {}
var backpack: Dictionary = {}

# 货币（Phase I 经济系统时启用）
var gold: int = 0

# 已合成的核与已收集的魔杖
var owned_cores: Array = []        # Array[Core]
var owned_wands: Array = []        # Array[Wand]

# 当前装备的魔杖（射击系统读这个）
var equipped_wand: Wand = null

# ────────────────────────────────────────────
# 启动时硬编码一套测试装备（M0 验证用，最小可玩）
# - 1 根空 3 槽学徒杖
# - 1 个最弱魔力弹主核（small/small/small，30 发弹药），装在槽 0
# - 没有辅核，没有队列
# 等 M3/M4 合成系统接通后这段会换成「玩家从空仓库起步」
# ────────────────────────────────────────────
func _ready() -> void:
	_setup_test_loadout()
	_seed_debug_workshop_inventory()


# 调试：每次启动给工作室仓库一批材料，方便测合成（正式流程可关掉）
func _seed_debug_workshop_inventory() -> void:
	var amounts := {
		"firefly_crystal": 12,
		"bolt_shard": 8,
		"mana_dust": 12,
		"spread_powder": 12,
		"slime_gel": 12,
		"mirror_shard": 10,
		"fire_essence": 6,
	}
	for id in amounts.keys():
		add_workshop_material(id, int(amounts[id]))
	print("[GameState] Debug workshop stash: %s" % [str(workshop_inventory)])


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

	print("[GameState] 测试装备：%s（%d 槽）+ %s（%d/%d 弹药）" % [
		equipped_wand.display_name,
		equipped_wand.slot_count,
		bullet.display_name,
		bullet.current_ammo,
		bullet.max_ammo,
	])

# ────────────────────────────────────────────
# 工作室仓库（合成用）
# ────────────────────────────────────────────
func add_workshop_material(id: String, count: int = 1) -> void:
	workshop_inventory[id] = workshop_inventory.get(id, 0) + count

func remove_workshop_material(id: String, count: int = 1) -> void:
	var current: int = workshop_inventory.get(id, 0)
	var after: int = current - count
	if after <= 0:
		workshop_inventory.erase(id)
	else:
		workshop_inventory[id] = after

func get_workshop_count(id: String) -> int:
	return workshop_inventory.get(id, 0)

func has_workshop_material(id: String, count: int = 1) -> bool:
	return get_workshop_count(id) >= count

# ────────────────────────────────────────────
# 出门背包（局内）
# ────────────────────────────────────────────
func add_backpack_material(id: String, count: int = 1) -> void:
	backpack[id] = backpack.get(id, 0) + count

func remove_backpack_material(id: String, count: int = 1) -> void:
	var current: int = backpack.get(id, 0)
	var after: int = current - count
	if after <= 0:
		backpack.erase(id)
	else:
		backpack[id] = after

func get_backpack_count(id: String) -> int:
	return backpack.get(id, 0)

# 出发前从仓库装进背包（之后做装箱 UI 时用）
func try_transfer_workshop_to_backpack(id: String, count: int = 1) -> bool:
	if get_workshop_count(id) < count:
		return false
	remove_workshop_material(id, count)
	add_backpack_material(id, count)
	return true

# 局外把背包里的先倒回仓库（可选，做 UI 时用）
func try_transfer_backpack_to_workshop(id: String, count: int = 1) -> bool:
	if get_backpack_count(id) < count:
		return false
	remove_backpack_material(id, count)
	add_workshop_material(id, count)
	return true

# 回到工作室时：背包全部并入仓库后清空背包
func merge_backpack_into_workshop() -> void:
	for k in backpack.keys():
		workshop_inventory[k] = workshop_inventory.get(k, 0) + int(backpack[k])
	backpack.clear()
	print("[GameState] Merged backpack into workshop; workshop=%s" % [str(workshop_inventory)])
