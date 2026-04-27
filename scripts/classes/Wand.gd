class_name Wand
extends RefCounted

# ────────────────────────────────────────────
# 基本字段
# ────────────────────────────────────────────
var id: String
var display_name: String
var slot_count: int
var charge_speed: float = 1.0      # 充能速度乘数（1.0 正常 / 2.0 加倍 / 0.5 减半）

# ────────────────────────────────────────────
# 装备状态（运行时数据）
# ────────────────────────────────────────────
var equipped_cores: Array          # Array[Core or null]，长度 = slot_count

# 主核替补队列：当前 active 主核打光后，自动从队列头弹出顶替
# 玩家可在装核 UI 中决定顺序；dungeon 中按 Tab 也能调整
var main_core_queue: Array = []    # Array[Core]

# ────────────────────────────────────────────
# 初始化：传入槽位数，自动创建空槽位数组
# ────────────────────────────────────────────
func _init(p_slot_count: int = 3) -> void:
	slot_count = p_slot_count
	equipped_cores.resize(slot_count)
	equipped_cores.fill(null)

# ────────────────────────────────────────────
# 装核 / 卸核
# ────────────────────────────────────────────
func equip(slot_index: int, core: Core) -> bool:
	if slot_index < 0 or slot_index >= slot_count:
		return false
	# 主核唯一性：一根魔杖最多 1 个 active 主核（替补在 main_core_queue）
	if core.core_type == "main" and has_main_core():
		return false
	equipped_cores[slot_index] = core
	return true

func unequip(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_count:
		return
	equipped_cores[slot_index] = null

# ────────────────────────────────────────────
# 主核相关查询
# ────────────────────────────────────────────
func get_main_core() -> Core:
	for c in equipped_cores:
		if c != null and c.core_type == "main":
			return c
	return null

func has_main_core() -> bool:
	return get_main_core() != null

func get_main_slot_index() -> int:
	for i in equipped_cores.size():
		var c: Core = equipped_cores[i]
		if c != null and c.core_type == "main":
			return i
	return -1

func get_supports() -> Array:
	var result: Array = []
	for c in equipped_cores:
		if c != null and c.core_type == "support":
			result.append(c)
	return result

# ────────────────────────────────────────────
# 主核打光时调用：把 active 主核替换为队列首
# 返回 true = 成功顶替了一个新主核，false = 队列空，主核槽留 null
# ────────────────────────────────────────────
func promote_next_main() -> bool:
	var slot_index: int = get_main_slot_index()
	if slot_index < 0:
		# 当前根本没有主核，找一个空槽放（优先用 0 号槽）
		slot_index = 0
	equipped_cores[slot_index] = null
	if main_core_queue.is_empty():
		return false
	var next_core: Core = main_core_queue.pop_front()
	equipped_cores[slot_index] = next_core
	return true

# ────────────────────────────────────────────
# 工厂方法
# ────────────────────────────────────────────
static func make(p_id: String, p_name: String, p_slot_count: int, p_charge_speed: float = 1.0) -> Wand:
	var w := Wand.new(p_slot_count)
	w.id = p_id
	w.display_name = p_name
	w.charge_speed = p_charge_speed
	return w
