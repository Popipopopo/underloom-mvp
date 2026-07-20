extends Node

## 自动化冒烟测试：v1.1 实例化合成流程（采集时 roll、合成零随机）。
## 运行：godot --path . res://tests/test_crafting_flow.tscn

var _fail_count: int = 0

func _ready() -> void:
	print("=== v1.1 crafting flow smoke test (instance model) ===")
	_test_acquisition_roll()
	_test_full_flow()
	_test_x1_and_threshold_order()
	_test_signature_and_lens()
	_test_ui_script_compiles()
	if _fail_count == 0:
		print("=== ALL TESTS PASSED ===")
	else:
		print("=== %d TEST(S) FAILED ===" % _fail_count)
	get_tree().quit(_fail_count)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_fail_count += 1
		printerr("  FAIL: " + msg)

## 造一份实例并放进工作室仓库
func _spawn(id: String, richness: float) -> MaterialInstance:
	var inst := MaterialInstance.roll_from(MaterialDB.get_material(id), richness)
	GameState.add_workshop_item(inst)
	return inst

func _make_filled_manager(insts: Array) -> CraftingManager:
	var m := CraftingManager.new()
	m.set_recipe_by_id("魔力核")
	var err1: String = m.set_slot(0, insts[0])   # 魔物
	var err2: String = m.set_slot(1, insts[1])   # 真菌
	var err3: String = m.set_slot(2, insts[2])   # 矿物
	assert(err1 == "" and err2 == "" and err3 == "")
	return m

func _test_acquisition_roll() -> void:
	print("[test] acquisition roll (元素在采集时定型)")
	var mat: CraftingMaterial = MaterialDB.get_material("发光菌")   # 风x2 土x2，保底风

	var poor := MaterialInstance.roll_from(mat, 0.0)
	_check(poor.elements == ["风"], "丰度 0 → 只有保底元素: %s" % str(poor.elements))

	var rich := MaterialInstance.roll_from(mat, 1.0)
	_check(rich.elements.size() == 4, "丰度 1 → 拉满上限 4 个: %s" % str(rich.elements))
	_check(rich.elements.count("风") == 2 and rich.elements.count("土") == 2, "丰度 1 → 元素构成等于上限")

	# 定型：入包后元素不再变化
	var snapshot: Array = rich.elements.duplicate()
	var m := CraftingManager.new()
	m.set_recipe_by_id("魔力核")
	m.set_slot(1, rich)
	_check(rich.elements == snapshot, "入槽后实例元素不变（合成零随机）")

func _test_full_flow() -> void:
	print("[test] full flow")
	var i_slime := _spawn("史莱姆凝胶", 1.0)   # 魔物,液体  水x2
	var i_fungus := _spawn("发光菌", 1.0)      # 真菌,幽影,发光  风x2土x2
	var i_crystal := _spawn("火晶石", 1.0)     # 矿物,结晶,高温  火x2
	var m := _make_filled_manager([i_slime, i_fungus, i_crystal])

	_check(m.get_slot_elements(0) == i_slime.elements, "槽 0 元素 = 实例定型元素")

	# 汇入干预池：总数 = 三份实例元素之和，零随机
	m.build_element_pool()
	var expected: int = i_slime.elements.size() + i_fungus.elements.size() + i_crystal.elements.size()
	_check(m.rolled_elements.size() == expected, "干预池与实例元素完全一致（8 个）: %d" % m.rolled_elements.size())

	# 干涉点池
	m.compute_lv()
	_check(m.total_pts > 0, "干涉点 > 0（品质 %s，共 %d 点）" % [m.get_quality_name(), m.total_pts])
	_check(m.pts == m.total_pts, "共享干涉点池初始化为总点数")

	# Tag 共鸣扣点：第一个免费，之后每个 1 点
	# 该组合可用共鸣：鬼火(发光+幽影)、沸腾(高温+液体)、熔岩核(矿物+高温)
	var pts_before: int = m.pts
	_check(m.trigger_tag_resonance("鬼火", true) == "", "第一个 Tag 共鸣触发成功")
	_check(m.pts == pts_before, "免费触发不扣点")
	_check(m.trigger_tag_resonance("沸腾", false) == "", "第二个 Tag 共鸣触发成功")
	_check(m.pts == pts_before - 1, "付费触发扣 1 点")

	# 锁定 + 结算
	var count_before: int = GameState.workshop_count_of("史莱姆凝胶")
	m.toggle_lock(0)
	_check(m.pts == pts_before - 2, "锁定元素扣 1 点（与共鸣同池）")
	var core: Core = m.build_product()
	_check(core != null, "build_product 产出产物")
	_check(core.product_type == "core", "魔力核产物类型 = core")
	_check(core.tag_words.has("鬼火") and core.tag_words.has("沸腾"), "Tag 词条写入成品")
	_check(core.max_uses == 5, "魔力核=消耗品,5 次使用")
	_check(not core.element_effects.is_empty(), "解读镜头效果已写入")
	_check(GameState.workshop_count_of("史莱姆凝胶") == count_before - 1, "材料实例被消耗")
	_check(GameState.owned_items.has(core), "产物入 owned_items")

	# 消耗品:用一次减一次,用完销毁(is_depleted)
	core.consume_use(1)
	_check(core.current_uses == 4, "consume_use 生效")
	core.consume_use(4)
	_check(core.is_depleted(), "用完后 is_depleted")

func _test_x1_and_threshold_order() -> void:
	print("[test] x1 micro effects & threshold order")
	var m := CraftingManager.new()
	m.set_recipe_by_id("魔力核")
	# 手工构造锁定状态验证共鸣判定（直接改 rolled_elements）
	m.rolled_elements = [
		{"element": "风", "mat_index": 0, "state": "locked"},
		{"element": "风", "mat_index": 1, "state": "locked"},
		{"element": "风", "mat_index": 2, "state": "locked"},
	]
	var res: Array[String] = m.active_resonances()
	_check(res.has("明显追踪/弹速提升"), "3 风触发 风x3（而非被 风x2 抢走）: %s" % str(res))

	m.rolled_elements = [
		{"element": "土", "mat_index": 0, "state": "locked"},
	]
	res = m.active_resonances()
	_check(res.has("微量破防"), "单个土触发 x1 微效果: %s" % str(res))

	m.rolled_elements = [
		{"element": "火", "mat_index": 0, "state": "locked"},
		{"element": "水", "mat_index": 1, "state": "locked"},
	]
	res = m.active_resonances()
	_check(res.has("蒸汽弹"), "火+水 双元素共鸣优先: %s" % str(res))

## 招牌门槛检测 + 解读镜头(本轮核心)
func _test_signature_and_lens() -> void:
	print("[test] signature & lens")
	var m := CraftingManager.new()

	# 魔力核·共鸣:单元素满 6
	m.set_recipe_by_id("魔力核")
	m.rolled_elements = _locked("火", 6)
	_check(m.check_signature()["unlocked"], "魔力核 6火 → 共鸣解锁")
	m.rolled_elements = _locked("火", 5)
	_check(not m.check_signature()["unlocked"], "魔力核 5火 → 共鸣未达成")

	# 轰鸣核·过载:容量满 8(4槽)
	m.set_recipe_by_id("轰鸣核")
	m.rolled_elements = _locked("火", 8)
	_check(m.check_signature()["unlocked"], "轰鸣核 满8 → 过载解锁")
	m.rolled_elements = _locked("火", 7)
	_check(not m.check_signature()["unlocked"], "轰鸣核 7 → 过载未达成")

	# 速凝核·连射:容量满 4(它做不出过载,因为容量只有4)
	m.set_recipe_by_id("速凝核")
	m.rolled_elements = _locked("风", 4)
	var s := m.check_signature()
	_check(s["unlocked"] and s["name"] == "连射", "速凝核 满4 → 连射解锁(名字对)")

	# 回复药·回魂:指定元素 水 满 4
	m.set_recipe_by_id("回复药")
	m.rolled_elements = _locked("水", 4)
	_check(m.check_signature()["unlocked"], "回复药 4水 → 回魂解锁")
	m.rolled_elements = _locked("火", 4)
	_check(not m.check_signature()["unlocked"], "回复药 4火 → 回魂未解锁(要水)")

	# 解读镜头:同样的火,在药里翻译成"温热"
	var joined := ", ".join(m.interpreted_effects())
	_check(joined.contains("温热"), "回复药里 火→温热: %s" % joined)

	# 护符·元素壁垒:单元素满 4
	m.set_recipe_by_id("护符")
	m.rolled_elements = _locked("土", 4)
	_check(m.check_signature()["unlocked"], "护符 4土 → 元素壁垒解锁")
	# 护符镜头:土翻译成防御
	_check(", ".join(m.interpreted_effects()).contains("坚岩"), "护符里 土→坚岩·防御")

func _locked(el: String, n: int) -> Array:
	var a: Array = []
	for _i in n:
		a.append({"element": el, "mat_index": 0, "state": "locked"})
	return a

func _test_ui_script_compiles() -> void:
	print("[test] CraftingScreen loads & instantiates")
	var ps: PackedScene = load("res://scenes/ui/CraftingScreen.tscn")
	_check(ps != null, "CraftingScreen.tscn 加载成功")
	if ps == null:
		return
	var inst: Node = ps.instantiate()
	_check(inst != null, "CraftingScreen 实例化成功（脚本编译通过）")
	add_child(inst)   # 触发 _ready，走到 Step 0
	inst.queue_free()
