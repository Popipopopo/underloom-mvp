## BattleManager — 回合制战斗的纯逻辑层(让核/招牌"通电")。
##
## 战斗与探索设计 v0.1:回合制,核=消耗品弹药,用完该回家。
## 结算:元素数量→伤害;命中敌人弱点×1.5;招牌过载×2、连射一回合两发。
## 核全部打光且未胜 → 撤退(损失部分采集,由上层处理)。
class_name BattleManager
extends RefCounted

var player_hp: int = 0
var player_max_hp: int = 0
var cores: Array = []          # Array[Core] 玩家可用的核(装备/携带)
var enemy: Dictionary = {}     # {name, hp, max_hp, weakness, attack}

var battle_log: Array[String] = []
var finished: bool = false
var victory: bool = false
var retreated: bool = false    # true = 核打光被迫撤退(触发采集损失)

func _init(p_hp: int, p_cores: Array, p_enemy: Dictionary) -> void:
	player_max_hp = p_hp
	player_hp = p_hp
	cores = p_cores
	enemy = p_enemy
	if not enemy.has("max_hp"):
		enemy["max_hp"] = enemy.get("hp", 1)

# ── 查询 ──────────────────────────────────────────────────────────────────────

## 尚未打光的核
func available_cores() -> Array:
	return cores.filter(func(c): return not (c as Core).is_depleted())

func can_act() -> bool:
	return not available_cores().is_empty()

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
	elif not can_act():
		# 核全部打光,打不过了 → 撤退(设计 §1.2)
		finished = true
		victory = false
		retreated = true
		battle_log.append("核全部用尽，只能撤退。")
	return msg
