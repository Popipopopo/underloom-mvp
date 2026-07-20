extends Node

## 自动化冒烟测试：v1.1 实例化合成流程（采集时 roll、合成零随机）。
## 运行：godot --path . res://tests/test_crafting_flow.tscn

var _fail_count: int = 0

func _ready() -> void:
	print("=== v1.1 crafting flow smoke test (instance model) ===")
	_test_acquisition_roll()
	_test_full_flow()
	_test_x1_and_threshold_order()
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
	var core: Core = m.build_core()
	_check(core != null, "build_core 产出核")
	_check(core.tag_words.has("鬼火") and core.tag_words.has("沸腾"), "Tag 词条写入成品")
	_check(core.max_charges == 30 and core.current_charges == 30, "核带 30 充能")
	_check(GameState.workshop_count_of("史莱姆凝胶") == count_before - 1, "材料实例被消耗")

	# 可充能：耗掉再回家，应满
	core.consume_charge(10)
	_check(core.current_charges == 20, "consume_charge 生效")
	GameState.merge_backpack_into_workshop()
	_check(core.current_charges == 30, "回工作室后充能恢复")

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
