## BattleManager — 回合制战斗的纯逻辑层(让核/招牌"通电")。
##
## 战斗与探索设计 v0.1:回合制,核=消耗品弹药,用完该回家。
## 结算:元素数量→伤害;命中敌人弱点×1.5;招牌过载×2、连射一回合两发。
## 核全部打光且未胜 → 撤退(损失部分采集,由上层处理)。
class_name BattleManager
extends RefCounted

const BASIC_ATK := 3           # 主角普攻:弱保底,不消耗核

var player_hp: int = 0
var player_max_hp: int = 0
var cores: Array = []          # Array[Core] 可用的核
var potions: Array = []        # Array[Core] 可用的恢复药(product_type=="potion")
var enemy: Dictionary = {}     # {name, hp, max_hp, weakness, attack}

var battle_log: Array[String] = []
var finished: bool = false
var victory: bool = false
var retreated: bool = false    # true = 核打光被迫撤退(触发采集损失)

func _init(p_hp: int, p_cores: Array, p_enemy: Dictionary, p_potions: Array = []) -> void:
	player_max_hp = p_hp
	player_hp = p_hp
	cores = p_cores
	potions = p_potions
	enemy = p_enemy
	if not enemy.has("max_hp"):
		enemy["max_hp"] = enemy.get("hp", 1)

# ── 查询 ──────────────────────────────────────────────────────────────────────

## 尚未打光的核
func available_cores() -> Array:
	return cores.filter(func(c): return not (c as Core).is_depleted())

func available_potions() -> Array:
	return potions.filter(func(p): return not (p as Core).is_depleted())

# ── 玩家回合 ──────────────────────────────────────────────────────────────────

## 用第 idx 颗可用核攻击敌人。返回结算描述。
func player_attack(idx: int) -> String:
	if finished:
		return ""
	var avail := available_cores()
	if idx < 0 or idx >= avail.size():
		return "无效的核"
	var core: Core = avail[idx]

	# 连射招牌:一回合发两次(每次各消耗一次)
	var hits: int = 1
	var note: String = ""
	if core.signature_unlocked and core.signature_name == "连射":
		hits = 2
		note = "（连射×2）"

	var total: int = 0
	for _h in hits:
		if core.is_depleted():
			break
		total += _core_damage(core)
		core.consume_use(1)
	enemy["hp"] = max(0, int(enemy["hp"]) - total)

	var msg := "用 %s 造成 %d 伤害%s（剩 %d/%d 次），敌人 HP %d/%d" % [
		core.display_name, total, note,
		core.current_uses, core.max_uses,
		int(enemy["hp"]), int(enemy["max_hp"])]
	battle_log.append(msg)
	_check_enemy_dead()
	return msg

## 主角普攻(弱,不消耗核;核用光时的保底手段)
func player_basic_attack() -> String:
	if finished:
		return ""
	enemy["hp"] = max(0, int(enemy["hp"]) - BASIC_ATK)
	var msg := "主角普攻,造成 %d 伤害,敌人 HP %d/%d" % [
		BASIC_ATK, int(enemy["hp"]), int(enemy["max_hp"])]
	battle_log.append(msg)
	_check_enemy_dead()
	return msg

## 喝下第 idx 个可用恢复药回血(土元素越多回得越多——疗愈镜头)
func player_use_potion(idx: int) -> String:
	if finished:
		return ""
	var avail := available_potions()
	if idx < 0 or idx >= avail.size():
		return "无效的药"
	var pot: Core = avail[idx]
	var heal: int = 8 + pot.result_lv + pot.elements.count("土") * 2
	player_hp = min(player_max_hp, player_hp + heal)
	pot.consume_use(1)
	var msg := "喝下 %s,回复 %d HP(现 %d/%d),剩 %d 次" % [
		pot.display_name, heal, player_hp, player_max_hp, pot.current_uses]
	battle_log.append(msg)
	return msg

## 主动撤退:核不够时的温和退出(无战利品,也无惩罚)
func retreat() -> void:
	if finished:
		return
	finished = true
	victory = false
	retreated = true
	battle_log.append("你选择了撤退。")

## 单次核伤害:品质基数 + 元素数量;弱点×1.5;过载×2
func _core_damage(core: Core) -> int:
	var dmg: float = 5.0 + float(core.result_lv) + float(core.elements.size()) * 2.0
	var weak: String = str(enemy.get("weakness", ""))
	if weak != "" and core.elements.has(weak):
		dmg *= 1.5
	if core.signature_unlocked and core.signature_name == "过载":
		dmg *= 2.0
	return int(round(dmg))

func _check_enemy_dead() -> void:
	if int(enemy["hp"]) <= 0:
		finished = true
		victory = true
		battle_log.append("击败了 %s！" % str(enemy.get("name", "敌人")))

# ── 敌人回合 ──────────────────────────────────────────────────────────────────

func enemy_turn() -> String:
	if finished:
		return ""
	var dmg: int = int(enemy.get("attack", 5))
	player_hp = max(0, player_hp - dmg)
	var msg := "%s 反击，造成 %d 伤害，你 HP %d/%d" % [
		str(enemy.get("name", "敌人")), dmg, player_hp, player_max_hp]
	battle_log.append(msg)

	if player_hp <= 0:
		finished = true
		victory = false
		battle_log.append("你倒下了……")
	return msg
