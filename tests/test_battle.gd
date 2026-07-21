extends Node

## 战斗逻辑冒烟测试:核=弹药、元素/弱点/招牌兑现、核打光撤退。
## 运行:godot --headless --path . res://tests/test_battle.tscn

var _fail_count: int = 0

func _ready() -> void:
	print("=== battle logic smoke test ===")
	_test_basic_attack()
	_test_weakness_bonus()
	_test_overload_signature()
	_test_rapidfire_signature()
	_test_hero_basic_attack()
	_test_potion_heal()
	_test_retreat()
	_test_victory()
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

func _make_core(name: String, lv: int, elements: Array, uses: int, sig := "", sig_on := false) -> Core:
	var c := Core.make_product("t_" + name, name, "core", uses, lv)
	c.elements.assign(elements)
	c.signature_name = sig
	c.signature_unlocked = sig_on
	return c

func _enemy(hp: int, weakness := "", attack := 3) -> Dictionary:
	return {"name": "史莱姆", "hp": hp, "max_hp": hp, "weakness": weakness, "attack": attack}

func _test_basic_attack() -> void:
	print("[test] basic attack")
	var core := _make_core("石核", 3, ["火", "火"], 3)   # base 5+3 + 2*2 = 12
	var bm := BattleManager.new(20, [core], _enemy(30))
	bm.player_attack(0)
	_check(bm.enemy["hp"] == 30 - 12, "基础伤害 12(5+lv3+2元素×2): 敌HP=%d" % bm.enemy["hp"])
	_check(core.current_uses == 2, "核消耗 1 次使用: %d" % core.current_uses)

func _test_weakness_bonus() -> void:
	print("[test] weakness ×1.5")
	var core := _make_core("火核", 3, ["火", "火"], 3)
	var bm := BattleManager.new(20, [core], _enemy(60, "火"))   # 弱火
	bm.player_attack(0)
	_check(bm.enemy["hp"] == 60 - 18, "命中火弱点伤害18(12×1.5): 敌HP=%d" % bm.enemy["hp"])

func _test_overload_signature() -> void:
	print("[test] overload ×2")
	var plain := _make_core("普通", 3, ["火", "火"], 3)
	var over := _make_core("轰鸣", 3, ["火", "火"], 3, "过载", true)
	var bm1 := BattleManager.new(20, [plain], _enemy(100))
	var bm2 := BattleManager.new(20, [over], _enemy(100))
	bm1.player_attack(0)
	bm2.player_attack(0)
	var d1 := 100 - int(bm1.enemy["hp"])
	var d2 := 100 - int(bm2.enemy["hp"])
	_check(d2 == d1 * 2, "过载伤害是普通的2倍: 普通%d 过载%d" % [d1, d2])

func _test_rapidfire_signature() -> void:
	print("[test] rapidfire ×2 shots")
	var core := _make_core("速凝", 3, ["风"], 8, "连射", true)   # 单发 5+3+1*2=10
	var bm := BattleManager.new(20, [core], _enemy(100))
	bm.player_attack(0)
	_check(bm.enemy["hp"] == 100 - 20, "连射一回合打两发共20: 敌HP=%d" % bm.enemy["hp"])
	_check(core.current_uses == 6, "连射消耗2次使用: %d" % core.current_uses)

func _test_hero_basic_attack() -> void:
	print("[test] hero basic attack (弱保底,不耗核)")
	var bm := BattleManager.new(20, [], _enemy(30))   # 无核也能行动
	bm.player_basic_attack()
	_check(bm.enemy["hp"] == 30 - BattleManager.BASIC_ATK,
		"普攻固定伤害 %d: 敌HP=%d" % [BattleManager.BASIC_ATK, bm.enemy["hp"]])

func _test_potion_heal() -> void:
	print("[test] potion heal")
	var pot := Core.make_product("p1", "回复药", "potion", 3, 3)   # heal 8+3=11
	var bm := BattleManager.new(20, [], _enemy(30), [pot])
	bm.player_hp = 5
	bm.player_use_potion(0)
	_check(bm.player_hp == 16, "喝药回血 5→16(8+lv3): %d" % bm.player_hp)
	_check(pot.current_uses == 2, "药消耗 1 次: %d" % pot.current_uses)

func _test_retreat() -> void:
	print("[test] voluntary retreat")
	var bm := BattleManager.new(20, [], _enemy(30))
	bm.retreat()
	_check(bm.finished and bm.retreated and not bm.victory, "主动撤退结束战斗(无战败)")

func _test_victory() -> void:
	print("[test] victory")
	var core := _make_core("强核", 20, ["火", "火", "火"], 5)   # 5+20+6=31
	var bm := BattleManager.new(20, [core], _enemy(30, "火"))   # 31×1.5=46 > 30
	bm.player_attack(0)
	_check(bm.finished and bm.victory, "一击击败,胜利")
