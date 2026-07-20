extends Node

## 自动化冒烟测试：把 v1.1 合成流程完整跑一遍后退出。
## 运行：godot --path . res://tests/test_crafting_flow.tscn

var _fail_count: int = 0

func _ready() -> void:
	print("=== v1.1 crafting flow smoke test ===")
	_test_full_flow()
	_test_reroll_keeps_locked()
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

func _make_filled_manager() -> CraftingManager:
	var m := CraftingManager.new()
	m.set_recipe_by_id("魔力核")
	var err1: String = m.set_slot(0, "史莱姆凝胶")   # 魔物
	var err2: String = m.set_slot(1, "发光菌")       # 真菌
	var err3: String = m.set_slot(2, "火晶石")       # 矿物
	assert(err1 == "" and err2 == "" and err3 == "")
	return m

func _test_full_flow() -> void:
	print("[test] full flow")
	var m := _make_filled_manager()

	# 方案B：入槽即有真实 roll，保底元素必在其中
	_check(m.get_slot_roll(0).has("水"), "slot0 roll 含保底元素 水")
	_check(m.get_slot_roll(1).has("风"), "slot1 roll 含保底元素 风")
	_check(m.get_slot_roll(2).has("火"), "slot2 roll 含保底元素 火")

	# 汇入干预池：总数 = 三个槽 roll 之和（不再随机丢弃）
	m.roll_elements()
	var expected: int = m.get_slot_roll(0).size() + m.get_slot_roll(1).size() + m.get_slot_roll(2).size()
	_check(m.rolled_elements.size() == expected, "干预池与槽位 roll 完全一致（无隐藏随机）")

	# 点数分配
	m.compute_lv()
	_check(m.total_pts > 0, "总点数 > 0（品质 %s，共 %d 点）" % [m.get_quality_name(), m.total_pts])
	_check(m.allocate_points(m.total_pts + 1, -1) != "", "非法分配被拒绝")
	_check(m.allocate_points(m.total_pts - 1, 1) == "", "合法分配成功")
	_check(m.element_retain_pts == m.total_pts - 1 and m.resonance_retain_pts == 1, "两种保留点数值正确")

	# 锁定 + 结算
	var before: int = GameState.get_workshop_count("史莱姆凝胶")
	m.toggle_lock(0)
	var core: Core = m.build_core()
	_check(core != null, "build_core 产出核")
	_check(core.max_charges == 30 and core.current_charges == 30, "核带 30 充能")
	_check(GameState.get_workshop_count("史莱姆凝胶") == before - 1, "材料被消耗")

	# 可充能：耗掉再回家，应满
	core.consume_charge(10)
	_check(core.current_charges == 20, "consume_charge 生效")
	GameState.merge_backpack_into_workshop()
	_check(core.current_charges == 30, "回工作室后充能恢复")

func _test_reroll_keeps_locked() -> void:
	print("[test] reroll keeps locked")
	var m := _make_filled_manager()
	m.roll_elements()
	m.compute_lv()
	m.allocate_points(m.total_pts, 0)
	# 锁定第一个元素
	m.toggle_lock(0)
	var locked_el: String = m.rolled_elements[0]["element"]
	_check(m.reroll_charges == 1, "初始 1 次重炼机会")
	_check(m.reroll_unlocked(), "重炼执行成功")
	_check(m.reroll_charges == 0, "重炼机会扣减")
	_check(not m.reroll_unlocked(), "没机会时重炼被拒绝")
	# 锁定的元素仍在池中且仍是 locked
	var still_locked: bool = false
	for entry in m.rolled_elements:
		if entry["state"] == "locked" and entry["element"] == locked_el:
			still_locked = true
	_check(still_locked, "锁定元素在重炼后保留")
	# 每槽保底元素依然存在
	for i in 3:
		var mat: CraftingMaterial = MaterialDB.get_material(str(m.state.fills[i]))
		var found: bool = false
		for entry in m.rolled_elements:
			if entry["mat_index"] == i and entry["element"] == mat.default_element:
				found = true
		_check(found, "槽 %d 重炼后保底元素 %s 仍在" % [i, mat.default_element])

func _test_x1_and_threshold_order() -> void:
	print("[test] x1 micro effects & threshold order")
	var m := _make_filled_manager()
	m.roll_elements()
	m.compute_lv()
	m.allocate_points(m.total_pts, 0)
	# 手工构造锁定状态验证共鸣判定（绕过点数，直接改 state）
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
