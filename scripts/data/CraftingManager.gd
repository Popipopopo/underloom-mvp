## CraftingManager — pure logic layer for the new crafting system.
##
## Flow the UI drives:
##   1. set_recipe(id)
##   2. set_slot(i, material_id) for each slot
##   3. roll_elements()           → populates rolled_elements (Array of {element, mat_index})
##   4. compute_lv()              → populates result_lv, result_quality, point budgets
##   5. UI handles Step 4 (element interference) by calling:
##        lock_element(idx) / discard_element(idx)
##      and reading active_resonances for live feedback
##   6. UI handles Step 5 (tag resonance) by calling:
##        trigger_tag_resonance(resonance_id)
##   7. roll_remaining_elements() → finalises element list
##   8. build_core()              → consumes workshop materials, returns Core
##
class_name CraftingManager
extends RefCounted

# ── Element resonance table ────────────────────────────────────────────────────
# key: tuple string like "风x2" or "火+水"   value: resonance display name
const ELEMENT_RESONANCES: Array = [
	# Single-element thresholds (order: check dual combos first, then singles
	# from highest threshold down — see _ordered_element_resonances)
	# x1 微效果：保证任何 roll 都不是纯垃圾（v1.1 §2.4）
	{"key": "风x1", "name": "微量提速"},
	{"key": "水x1", "name": "微量减速"},
	{"key": "火x1", "name": "微量火伤"},
	{"key": "土x1", "name": "微量破防"},
	{"key": "风x2", "name": "轻微追踪"},
	{"key": "风x3", "name": "明显追踪/弹速提升"},
	{"key": "风x4", "name": "暴风"},
	{"key": "水x2", "name": "命中轻微减速"},
	{"key": "水x3", "name": "减速加强/小范围扩散"},
	{"key": "水x4", "name": "冻结"},
	{"key": "火x2", "name": "命中小爆炸"},
	{"key": "火x3", "name": "爆炸范围增大/燃烧DoT"},
	{"key": "火x4", "name": "连锁爆炸"},
	{"key": "土x2", "name": "轻微击退"},
	{"key": "土x3", "name": "穿透"},
	{"key": "土x4", "name": "震地"},
	# Dual-element combos (each requires ≥1 of each)
	{"key": "风+水", "name": "冰弹"},
	{"key": "风+火", "name": "火箭弹"},
	{"key": "火+水", "name": "蒸汽弹"},
	{"key": "火+土", "name": "熔岩弹"},
	{"key": "水+土", "name": "泥沼弹"},
	{"key": "风+土", "name": "沙暴弹"},
]

# ── Tag resonance table ────────────────────────────────────────────────────────
const TAG_RESONANCES: Array = [
	{"tags": ["食材", "芬芳"],   "name": "美味"},
	{"tags": ["剧毒", "食材"],   "name": "以毒攻毒"},
	{"tags": ["发光", "幽影"],   "name": "鬼火"},
	{"tags": ["亡灵", "液体"],   "name": "腐化"},
	{"tags": ["高温", "液体"],   "name": "沸腾"},
	{"tags": ["昆虫", "芬芳"],   "name": "蜂群"},
	{"tags": ["矿物", "高温"],   "name": "熔岩核"},
]

# ── Quality table ─────────────────────────────────────────────────────────────
const QUALITY_NAMES: Array = ["石", "铜", "银", "金"]
# 总点数 per quality tier (index 0-3)。
# v1.1：玩家在干预开始前自主分配给「元素保留点」和「共鸣保留点」（allocate_points）
const QUALITY_TOTAL_POINTS: Array = [
	3,   # 石  lv 1-10
	5,   # 铜  lv 11-20
	7,   # 银  lv 21-30
	9,   # 金  lv 31-40
]

# ── Power/size labels ─────────────────────────────────────────────────────────
const POWER_LABELS: Array = ["小", "中小", "中", "大"]

# ── State ─────────────────────────────────────────────────────────────────────
var state: CraftingState = null

# v1.1 方案B：每个槽位在 set_slot 时立刻 roll，结果存这里（Array of Array[String]）。
# 玩家入槽即见真实结果，换材料重掷该槽。所见即所得，后续不再有隐藏随机。
var slot_rolls: Array = []

# 干预池：Array of Dictionaries {element: String, mat_index: int, state: String}
# state can be "inactive" / "locked"
var rolled_elements: Array = []

# Step 3 outputs
var result_lv: int = 0
var result_quality_index: int = 0    # 0=石 1=铜 2=银 3=金
var total_pts: int = 0               # 由品质决定
# 共享点数池：锁定元素、触发额外 Tag 共鸣都花这里。
# （2026-07-20 实测反馈：干涉合并为一屏后不再拆两种点、不再预分配）
var pts: int = 0

# 重炼：锁定的保留，未锁定的重掷。每次合成 1 次机会（v1.1 §2.4）
var reroll_charges: int = 0

# Step 5 state: which tag resonances the player has triggered
var triggered_tag_resonances: Array[String] = []
# Tags consumed so far (to prevent double-triggering)
var consumed_tags: Array[String] = []

# ── Slot management ───────────────────────────────────────────────────────────

func set_recipe_by_id(id: String) -> bool:
	var r: Recipe = RecipeDB.by_id(id)
	if r == null:
		return false
	state = CraftingState.new(r)
	slot_rolls.clear()
	slot_rolls.resize(r.slot_count())
	rolled_elements.clear()
	triggered_tag_resonances.clear()
	consumed_tags.clear()
	total_pts = 0
	pts = 0
	reroll_charges = 0
	return true

## Returns "" on success, error string on failure.
func set_slot(slot_index: int, mat_id: String) -> String:
	if state == null:
		return "no recipe"
	if slot_index < 0 or slot_index >= state.recipe.slot_count():
		return "bad slot index"
	var mat: CraftingMaterial = MaterialDB.get_material(mat_id)
	if mat == null:
		return "unknown material"
	if not state.recipe.slot_accepts(slot_index, mat):
		return "material tag [%s] doesn't match slot requirement [%s]" % [
			", ".join(mat.tags), state.recipe.slot_tags[slot_index]]
	if GameState.get_workshop_count(mat_id) <= 0:
		return "not enough in workshop"
	state.fills[slot_index] = mat_id
	# 方案B：入槽立刻 roll 并保留结果（真实结果，非预览装饰）
	slot_rolls[slot_index] = _roll_material(mat)
	return ""

func clear_slot(slot_index: int) -> void:
	if state != null and slot_index >= 0 and slot_index < state.fills.size():
		state.fills[slot_index] = ""
		slot_rolls[slot_index] = null

## 该槽位已 roll 出的元素（UI 显示用）；未填返回空数组
func get_slot_roll(slot_index: int) -> Array:
	if slot_index < 0 or slot_index >= slot_rolls.size() or slot_rolls[slot_index] == null:
		return []
	return slot_rolls[slot_index]

## 单个材料的 roll：保底元素必出 1 个，其余每单位 50% 出
func _roll_material(mat: CraftingMaterial) -> Array:
	var result: Array = []
	result.append(mat.default_element)
	for el in mat.elements_max.keys():
		var max_units: int = int(mat.elements_max[el])
		var already: int = 1 if el == mat.default_element else 0
		for _u in range(already, max_units):
			if randi() % 2 == 0:
				result.append(el)
	return result

func all_slots_filled() -> bool:
	return state != null and state.all_filled()

# ── Step 2: Assemble element pool ─────────────────────────────────────────────

## v1.1：不再重新 roll——把入槽时已 roll 好的结果汇入干预池。
## 也不再随机丢弃超上限部分（锁定数量本身受点数限制，池子只是选择广度）。
## Call this after all slots are filled.
func roll_elements() -> void:
	rolled_elements.clear()
	if state == null:
		return
	for i in state.recipe.slot_count():
		for el in get_slot_roll(i):
			rolled_elements.append({
				"element": el,
				"mat_index": i,
				"state": "inactive"    # inactive(default) / locked
			})

# ── Step 3: Compute lv & quality ──────────────────────────────────────────────

func compute_lv() -> void:
	if state == null:
		return
	var slot_count: int = state.recipe.slot_count()
	var lvs: Array[int] = []
	for i in slot_count:
		var mat: CraftingMaterial = MaterialDB.get_material(str(state.fills[i]))
		if mat:
			lvs.append(mat.lv)

	if lvs.is_empty():
		result_lv = 1
	else:
		var lv_sum: float = 0.0
		for v in lvs:
			lv_sum += v
		var base_lv: float = lv_sum / float(slot_count)
		var max_tier: int = lvs.max()
		var min_tier: int = lvs.min()
		var tier_gap: float = float(max_tier - min_tier)
		var low_ceiling: float = float(min_tier) * 10.0
		var penalized: float = base_lv - (base_lv - low_ceiling) * (tier_gap * 0.15)
		var low_count: int = 0
		for v in lvs:
			if v < max_tier:
				low_count += 1
		var low_ratio: float = float(low_count) / float(slot_count)
		var final_lv: float = penalized * (1.0 - low_ratio * 0.1)
		result_lv = clampi(int(round(final_lv)), 1, 40)

	# Quality tier  (explicit int cast silences integer-division warning)
	result_quality_index = clampi(int(result_lv - 1) / 10, 0, 3)
	total_pts = QUALITY_TOTAL_POINTS[result_quality_index]
	pts = total_pts
	reroll_charges = 1

func get_quality_name() -> String:
	return QUALITY_NAMES[result_quality_index]

func get_power_label() -> String:
	return POWER_LABELS[clampi(int(result_lv - 1) / 10, 0, 3)]

# ── Step 4: Element interference UI helpers ────────────────────────────────────
# Logic: all rolled elements start as "inactive" (grey, not counted).
# Player spends element_retain_pts to "lock" (keep) elements.
# Only locked elements count toward resonances.

## How many elements are currently locked
func locked_count() -> int:
	var n: int = 0
	for entry in rolled_elements:
		if entry["state"] == "locked":
			n += 1
	return n

## Count locked elements by type — used for resonance calculation
func count_locked_elements() -> Dictionary:
	var counts: Dictionary = {}
	for entry in rolled_elements:
		if entry["state"] != "locked":
			continue
		var el: String = entry["element"]
		counts[el] = counts.get(el, 0) + 1
	return counts

## Toggle lock on a dot. Returns true if the state changed.
## Locking costs 1 element_retain_pt; unlocking refunds it.
func toggle_lock(element_index: int) -> bool:
	if element_index < 0 or element_index >= rolled_elements.size():
		return false
	var entry: Dictionary = rolled_elements[element_index]
	if entry["state"] == "locked":
		entry["state"] = "inactive"
		pts += 1
		return true
	elif entry["state"] == "inactive":
		if pts <= 0:
			return false   # no points left
		entry["state"] = "locked"
		pts -= 1
		return true
	return false

## v1.1 §2.4 重炼：锁定的元素保留，未锁定的按各材料的分布重新 roll。
## 每次合成 reroll_charges 次机会。Returns true if reroll happened.
func reroll_unlocked() -> bool:
	if reroll_charges <= 0 or state == null:
		return false
	reroll_charges -= 1

	var new_pool: Array = []
	for i in state.recipe.slot_count():
		var mat: CraftingMaterial = MaterialDB.get_material(str(state.fills[i]))
		if mat == null:
			continue
		# 该槽已锁定的元素计数（这些保留，且占用对应元素的上限额度）
		var locked_counts: Dictionary = {}
		for entry in rolled_elements:
			if entry["mat_index"] == i and entry["state"] == "locked":
				var lel: String = entry["element"]
				locked_counts[lel] = locked_counts.get(lel, 0) + 1
				new_pool.append(entry)

		# 保底元素：若没有锁定的保底，重掷后仍必出 1 个
		var floor_counts: Dictionary = locked_counts.duplicate()
		if int(floor_counts.get(mat.default_element, 0)) == 0:
			new_pool.append({"element": mat.default_element, "mat_index": i, "state": "inactive"})
			floor_counts[mat.default_element] = 1

		# 剩余额度逐单位 50% 重掷
		for el in mat.elements_max.keys():
			var max_units: int = int(mat.elements_max[el])
			for _u in range(int(floor_counts.get(el, 0)), max_units):
				if randi() % 2 == 0:
					new_pool.append({"element": el, "mat_index": i, "state": "inactive"})

		# 同步该槽的 roll 记录（保持 get_slot_roll 与干预池一致）
		var slot_els: Array = []
		for entry in new_pool:
			if entry["mat_index"] == i:
				slot_els.append(entry["element"])
		slot_rolls[i] = slot_els

	rolled_elements = new_pool
	return true

## Resonances currently triggered by locked elements (real-time feedback)
func active_resonances() -> Array[String]:
	var remaining_counts := count_locked_elements()
	var results: Array[String] = []
	for res in _ordered_element_resonances():
		var req: Dictionary = _resonance_requirements(str(res["key"]))
		if req.is_empty():
			continue
		if _can_pay_requirements(remaining_counts, req):
			_consume_requirements(remaining_counts, req)
			results.append(str(res["name"]))
	return results

## Final element resonances = what's locked at confirm time
func triggered_element_resonances() -> Array[String]:
	return active_resonances()

func _ordered_element_resonances() -> Array:
	var duals: Array = []
	var singles: Array = []
	for res in ELEMENT_RESONANCES:
		var key: String = str(res["key"])
		if key.contains("+"):
			duals.append(res)
		else:
			singles.append(res)
	# 单元素按阈值从高到低检查：锁了 3 个风应触发 风x3 而不是被 风x2 抢走
	singles.sort_custom(func(a, b) -> bool:
		return _resonance_threshold(str(a["key"])) > _resonance_threshold(str(b["key"])))
	return duals + singles

func _resonance_threshold(key: String) -> int:
	var parts: PackedStringArray = key.split("x")
	return int(parts[1]) if parts.size() == 2 else 0

func _resonance_requirements(key: String) -> Dictionary:
	var req: Dictionary = {}
	if key.contains("+"):
		var parts: PackedStringArray = key.split("+")
		for p in parts:
			var el := p.strip_edges()
			if el == "":
				return {}
			req[el] = req.get(el, 0) + 1
		return req
	var single_parts: PackedStringArray = key.split("x")
	if single_parts.size() != 2:
		return {}
	var single_el: String = single_parts[0].strip_edges()
	var single_need: int = int(single_parts[1])
	if single_el == "" or single_need <= 0:
		return {}
	req[single_el] = single_need
	return req

func _can_pay_requirements(remaining_counts: Dictionary, req: Dictionary) -> bool:
	for el in req.keys():
		if int(remaining_counts.get(el, 0)) < int(req[el]):
			return false
	return true

func _consume_requirements(remaining_counts: Dictionary, req: Dictionary) -> void:
	for el in req.keys():
		remaining_counts[el] = int(remaining_counts.get(el, 0)) - int(req[el])

# ── Step 5: Tag resonance ──────────────────────────────────────────────────────

## Collect all unique tags from placed materials
func collect_all_tags() -> Array[String]:
	var tag_set: Array[String] = []
	if state == null:
		return tag_set
	for mat_id in state.fills:
		var mat: CraftingMaterial = MaterialDB.get_material(str(mat_id))
		if mat == null:
			continue
		for t in mat.tags:
			if not tag_set.has(t):
				tag_set.append(t)
	return tag_set

## 哪些已入槽材料带这个 tag（UI 显示共鸣来源用）
func get_tag_providers(tag: String) -> Array[String]:
	var names: Array[String] = []
	if state == null:
		return names
	for mat_id in state.fills:
		var mat: CraftingMaterial = MaterialDB.get_material(str(mat_id))
		if mat != null and mat.has_tag(tag) and not names.has(mat.display_name):
			names.append(mat.display_name)
	return names

## Which tag resonances are currently available given remaining tags
func available_tag_resonances() -> Array[Dictionary]:
	var all_tags := collect_all_tags()
	# Remove consumed tags
	var remaining: Array[String] = []
	for t in all_tags:
		if not consumed_tags.has(t):
			remaining.append(t)

	var available: Array[Dictionary] = []
	for res in TAG_RESONANCES:
		var req_tags: Array = res["tags"]
		var ok: bool = true
		for req in req_tags:
			if not remaining.has(req):
				ok = false
				break
		if ok and not triggered_tag_resonances.has(res["name"]):
			available.append(res.duplicate())
	return available

## Trigger a tag resonance by name. Returns "" on success, error on failure.
## first_trigger_free: the UI should pass true for the first triggered resonance.
func trigger_tag_resonance(resonance_name: String, first_trigger_free: bool) -> String:
	if triggered_tag_resonances.has(resonance_name):
		return "already triggered"
	if not first_trigger_free:
		if pts <= 0:
			return "no points left"
		pts -= 1

	# Find the resonance entry and consume its tags
	for res in TAG_RESONANCES:
		if res["name"] == resonance_name:
			for t in res["tags"]:
				if not consumed_tags.has(t):
					consumed_tags.append(t)
			break
	triggered_tag_resonances.append(resonance_name)
	return ""

# ── Step 6: Finalise elements ─────────────────────────────────────────────────
# New logic: only locked elements survive. Inactive = discarded.
# No random roll needed — player already made explicit choices with retain pts.

func roll_remaining_elements() -> void:
	pass   # No-op: player's lock choices ARE the final result

## Final list = only locked elements
func final_elements() -> Array[String]:
	var result: Array[String] = []
	for entry in rolled_elements:
		if entry["state"] == "locked":
			result.append(entry["element"])
	return result

# ── Step 7: Build Core ────────────────────────────────────────────────────────

## Consume workshop materials and return a new Core.
## Call after all UI steps are complete.
func build_core() -> Core:
	if state == null or not state.all_filled():
		return null

	# Consume materials from workshop
	for mat_id in state.fills:
		GameState.remove_workshop_material(str(mat_id), 1)

	var el_tags := triggered_element_resonances()
	var tag_words := triggered_tag_resonances.duplicate()
	var power_label := get_power_label()

	# Map power → damage_tier, diameter → range_tier (same scale for now)
	var tier_map: Dictionary = {"小": "small", "中小": "small", "中": "medium", "大": "large"}
	var damage_tier: String = tier_map.get(power_label, "small")
	var range_tier: String = damage_tier

	var uid: int = int(Time.get_ticks_msec()) + randi() % 10000
	var core_id: String = "%s_%d" % [state.recipe.id, uid]

	var c: Core = Core.make_main_from_tiers(
		core_id,
		"%s·%s" % [state.recipe.display_name, get_quality_name()],
		"bullet",
		damage_tier, range_tier, "small",
		30,   # default max_charges（可充能，回工作室恢复）
		"",
		0.3
	)
	c.element_tags = el_tags
	c.tag_words = tag_words
	c.result_lv = result_lv

	GameState.owned_cores.append(c)
	return c
