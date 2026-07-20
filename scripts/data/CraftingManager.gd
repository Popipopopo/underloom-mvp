## CraftingManager — pure logic layer for the crafting system.
##
## v1.1 原设计：元素在采集时定型（MaterialInstance），合成阶段零随机。
## Flow the UI drives:
##   1. set_recipe_by_id(id)
##   2. set_slot(i, instance) for each slot   ← 实例元素已定型，只做校验
##   3. build_element_pool()                  → 汇总各槽实例元素为干预池
##   4. compute_lv()                          → 品质 + 干涉点
##   5. 干涉工作台：toggle_lock(idx)（锁定花点）+ trigger_tag_resonance()
##      （第一个免费，之后花同一池的点），active_resonances 实时反馈
##   6. build_core()                          → 消耗实例，返回 Core
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
# 干涉点总量 per quality tier (index 0-3)，锁定元素和额外 Tag 共鸣共用
const QUALITY_TOTAL_POINTS: Array = [
	3,   # 石  lv 1-10
	5,   # 铜  lv 11-20
	7,   # 银  lv 21-30
	9,   # 金  lv 31-40
]

# ── Power/size labels ─────────────────────────────────────────────────────────
const POWER_LABELS: Array = ["小", "中小", "中", "大"]

# ── 解读镜头:同一元素,不同产物类型翻译成不同效果(基础配方表 §2)─────────────
const LENS: Dictionary = {
	"core":   {"火": "爆炸/燃烧",     "水": "减速/冻结",     "风": "追踪/提速",   "土": "穿透/击退"},
	"potion": {"火": "温热·回血+解冻", "水": "清凉·回血+解灼烧", "风": "提神·回MP",   "土": "滋养·回血++"},
	"charm":  {"火": "火焰抗性",       "水": "冰霜抗性",       "风": "疾风·闪避",   "土": "坚岩·防御"},
	"trade":  {"火": "赤红光泽",       "水": "澄澈光泽",       "风": "流光光泽",   "土": "厚重质感"},
}

# ── State ─────────────────────────────────────────────────────────────────────
var state: CraftingState = null

# 干预池：Array of Dictionaries {element: String, mat_index: int, state: String}
# state can be "inactive" / "locked"
# 元素来自各槽实例的定型元素，无任何合成期随机
var rolled_elements: Array = []

# Step 3 outputs
var result_lv: int = 0
var result_quality_index: int = 0    # 0=石 1=铜 2=银 3=金
var total_pts: int = 0               # 由品质决定
# 共享点数池：锁定元素、触发额外 Tag 共鸣都花这里。
# （2026-07-20 实测反馈：干涉合并为一屏后不再拆两种点、不再预分配）
var pts: int = 0


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
	rolled_elements.clear()
	triggered_tag_resonances.clear()
	consumed_tags.clear()
	total_pts = 0
	pts = 0
	return true

## Returns "" on success, error string on failure.
## 实例元素在采集时已定型，这里只做 tag 校验和占用检查。
func set_slot(slot_index: int, inst: MaterialInstance) -> String:
	if state == null:
		return "no recipe"
	if slot_index < 0 or slot_index >= state.recipe.slot_count():
		return "bad slot index"
	if inst == null:
		return "no instance"
	var mat: CraftingMaterial = inst.base()
	if mat == null:
		return "unknown material"
	if not state.recipe.slot_accepts(slot_index, mat):
		return "material tag [%s] doesn't match slot requirement [%s]" % [
			", ".join(mat.tags), state.recipe.slot_tags[slot_index]]
	for f in state.fills:
		if f == inst:
			return "instance already used in another slot"
	state.fills[slot_index] = inst
	return ""

func clear_slot(slot_index: int) -> void:
	if state != null and slot_index >= 0 and slot_index < state.fills.size():
		state.fills[slot_index] = null

## 该槽位实例的定型元素（UI 显示用）；未填返回空数组
func get_slot_elements(slot_index: int) -> Array:
	if state == null or slot_index < 0 or slot_index >= state.fills.size():
		return []
	var inst: MaterialInstance = state.fills[slot_index]
	return inst.elements if inst != null else []

func all_slots_filled() -> bool:
	return state != null and state.all_filled()

# ── Step 2: Assemble element pool ─────────────────────────────────────────────

## 把各槽实例的定型元素汇入干预池——合成阶段零随机。
## Call this after all slots are filled.
func build_element_pool() -> void:
	rolled_elements.clear()
	if state == null:
		return
	for i in state.recipe.slot_count():
		for el in get_slot_elements(i):
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
		var inst: MaterialInstance = state.fills[i]
		if inst != null and inst.base() != null:
			lvs.append(inst.base().lv)

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

func get_quality_name() -> String:
	return QUALITY_NAMES[result_quality_index]

func get_power_label() -> String:
	return POWER_LABELS[clampi(int(result_lv - 1) / 10, 0, 3)]

# ── Step 4: Element interference UI helpers ────────────────────────────────────
# Logic: all rolled elements start as "inactive" (grey, not counted).
# Player spends 干涉点 (pts) to "lock" (keep) elements.
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

## Collect all unique tags from placed material instances
func collect_all_tags() -> Array[String]:
	var tag_set: Array[String] = []
	if state == null:
		return tag_set
	for inst in state.fills:
		if inst == null:
			continue
		var mat: CraftingMaterial = (inst as MaterialInstance).base()
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
	for inst in state.fills:
		if inst == null:
			continue
		var mat: CraftingMaterial = (inst as MaterialInstance).base()
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
# Only locked elements survive. Inactive = discarded.

## Final list = only locked elements
func final_elements() -> Array[String]:
	var result: Array[String] = []
	for entry in rolled_elements:
		if entry["state"] == "locked":
			result.append(entry["element"])
	return result

# ── 招牌效果检测(仅此配方能出,元素数量门槛)───────────────────────────────────

## 检测当前锁定元素是否达到本配方招牌门槛。
## 返回 {name, effect, unlocked}(无招牌定义返回 unlocked=false)。
func check_signature() -> Dictionary:
	var out := {"name": "", "effect": "", "unlocked": false}
	if state == null or state.recipe.signature.is_empty():
		return out
	var sig: Dictionary = state.recipe.signature
	out["name"] = str(sig.get("name", ""))
	out["effect"] = str(sig.get("effect", ""))
	var kind: String = str(sig.get("threshold", ""))
	var counts := count_locked_elements()
	match kind:
		"capacity_full":
			out["unlocked"] = locked_count() >= state.recipe.element_capacity()
		"single_element":
			var need: int = int(sig.get("value", 0))
			for el in counts.keys():
				if int(counts[el]) >= need:
					out["unlocked"] = true
					break
		"element_full":
			var el: String = str(sig.get("element", ""))
			out["unlocked"] = int(counts.get(el, 0)) >= int(sig.get("value", 0))
	return out

## 招牌进度提示(UI 显示"目标"用),如 "过载 3/8" 或 "共鸣 火 4/6"
func signature_hint() -> String:
	if state == null or state.recipe.signature.is_empty():
		return ""
	var sig: Dictionary = state.recipe.signature
	var name: String = str(sig.get("name", ""))
	var counts := count_locked_elements()
	match str(sig.get("threshold", "")):
		"capacity_full":
			return "%s %d/%d" % [name, locked_count(), state.recipe.element_capacity()]
		"single_element":
			var need: int = int(sig.get("value", 0))
			var best_el := ""
			var best := 0
			for el in counts.keys():
				if int(counts[el]) > best:
					best = int(counts[el]); best_el = el
			return "%s %s%d/%d" % [name, best_el, best, need]
		"element_full":
			var el: String = str(sig.get("element", ""))
			return "%s %s%d/%d" % [name, el, int(counts.get(el, 0)), int(sig.get("value", 0))]
	return name

# ── 解读镜头:按产物类型把锁定元素翻译成效果描述 ─────────────────────────────────

func interpreted_effects() -> Array[String]:
	var out: Array[String] = []
	if state == null:
		return out
	var lens: Dictionary = LENS.get(state.recipe.product_type, LENS["core"])
	var counts := count_locked_elements()
	for el in counts.keys():
		var desc: String = str(lens.get(el, el))
		out.append("%s×%d → %s" % [el, int(counts[el]), desc])
	return out

# ── Step 7: Build product ─────────────────────────────────────────────────────

## Consume workshop material instances and return a new product (Core-typed).
## 产物类型由配方决定;应用解读镜头 + 招牌检测。Call after all UI steps.
func build_product() -> Core:
	if state == null or not state.all_filled():
		return null

	# Consume material instances from workshop
	for inst in state.fills:
		GameState.remove_workshop_item(inst)

	var recipe: Recipe = state.recipe
	var uid: int = int(Time.get_ticks_msec()) + randi() % 10000
	var pid: String = "%s_%d" % [recipe.id, uid]

	var c: Core = Core.make_product(
		pid,
		"%s·%s" % [recipe.display_name, get_quality_name()],
		recipe.product_type,
		recipe.base_uses,
		result_lv
	)
	c.elements = final_elements()
	c.element_effects = interpreted_effects()
	c.element_tags = triggered_element_resonances()
	c.tag_words = triggered_tag_resonances.duplicate()

	var sig := check_signature()
	c.signature_name = str(sig["name"])
	c.signature_unlocked = bool(sig["unlocked"])

	# 传世珍品招牌:交易品品质跃升(占位——真实经济系统接入时兑现售价)
	GameState.owned_items.append(c)
	return c

## 兼容旧名(测试/UI 可能仍调用)
func build_core() -> Core:
	return build_product()
