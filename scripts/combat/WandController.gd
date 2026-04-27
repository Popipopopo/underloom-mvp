class_name WandController
extends Node

# ────────────────────────────────────────────
# 资源预加载
# ────────────────────────────────────────────
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/entities/projectile.tscn")

# ────────────────────────────────────────────
# 档位 → 具体数值映射表（GDD 5.4 + MVP 简化）
# 数值最终在 _compute_concrete 里统一翻译
# ────────────────────────────────────────────
const _DAMAGE_BY_TIER: Dictionary = {"small": 10, "medium": 20, "large": 30}
const _RANGE_BY_TIER: Dictionary  = {"small": 300.0, "medium": 500.0, "large": 800.0}
const _SPEED_BY_TIER: Dictionary  = {"small": 280.0, "medium": 360.0, "large": 460.0}

# ────────────────────────────────────────────
# 状态
# ────────────────────────────────────────────
@onready var owner_player: Node2D = get_parent()    # 假设挂在 Player 下
var _cooldown: float = 0.0                          # 还要等多少秒才能再射

# ────────────────────────────────────────────
# 主循环
# ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = max(0.0, _cooldown - delta)

	if not RunManager.in_run:
		return

	if Input.is_action_pressed("attack") and _cooldown <= 0.0:
		_try_cast()

# ────────────────────────────────────────────
# 把 Core 的档位字符串翻译成具体数值
# ────────────────────────────────────────────
func _compute_concrete(core: Core) -> Dictionary:
	return {
		"damage": int(_DAMAGE_BY_TIER.get(core.damage_tier, 10)),
		"speed":  float(_SPEED_BY_TIER.get(core.range_tier, 300.0)),  # 速度跟着 range 档位走
		"range":  float(_RANGE_BY_TIER.get(core.range_tier, 300.0)),
	}

# ────────────────────────────────────────────
# 尝试施放：从 GameState 读魔杖 → 应用辅核 → 生成子弹
# ────────────────────────────────────────────
func _try_cast() -> void:
	var wand: Wand = GameState.equipped_wand
	if wand == null:
		return

	var main_core: Core = wand.get_main_core()
	if main_core == null:
		return

	# 弹药检查：主核已耗尽就不发射（理论上不会触发，因为 _post_consume 会清掉
	# 但作为保险）
	if main_core.is_depleted():
		return

	# 1. 取主核基础属性（从档位翻译过来）
	var base: Dictionary = _compute_concrete(main_core)
	var damage: int = base["damage"]
	var speed: float = base["speed"]
	var fly_range: float = base["range"]
	var charge_time: float = main_core.charge_time

	# 2. 辅核状态聚合
	var multicast_extra: int = 0
	var split_levels: int = 0
	var homing_speed_deg: float = 0.0
	var burn_dps: int = 0

	# 3. 应用所有辅核效果
	for support in wand.get_supports():
		match support.support_effect:
			"amp":
				damage = int(damage * (1.0 + support.support_value))
				charge_time *= 1.10           # GDD：强化辅核代价 +10% 充能
			"speed_up":
				speed *= (1.0 + support.support_value)
			"multicast":
				multicast_extra += int(support.support_value)
				charge_time *= 1.50           # GDD：多重施法代价 +50% 充能
			"split":
				split_levels += int(support.support_value)
				damage = int(damage * pow(0.7, support.support_value))
			"homing":
				homing_speed_deg += support.support_value
				speed *= 0.80                                  # GDD：追踪代价 -20% 速度
			"fire":
				burn_dps = max(burn_dps, int(support.support_value))

	# 4. 应用魔杖的充能速度乘数
	var final_cooldown: float = charge_time / wand.charge_speed

	# 5. 算射击方向（朝鼠标）
	var mouse_pos: Vector2 = owner_player.get_global_mouse_position()
	var direction: Vector2 = (mouse_pos - owner_player.global_position).normalized()

	# 6. 生成子弹（按多重施法的数量做扇形展开）
	_spawn_projectile_fan(
		direction, multicast_extra + 1,
		damage, speed, fly_range, split_levels, homing_speed_deg
	)

	# 7. 进入冷却
	_cooldown = final_cooldown

	# 8. 扣弹药；如果这一发后核耗尽，从 owned_cores 移除并自动顶替队列
	#    （MVP 简化：1 次按键 = 1 弹药，无视 multicast/split 的实际产出量）
	main_core.consume_ammo(1)
	if main_core.is_depleted():
		_on_main_core_depleted(wand, main_core)

# ────────────────────────────────────────────
# 主核耗尽处理：销毁 + 队列顶替
# ────────────────────────────────────────────
func _on_main_core_depleted(wand: Wand, depleted: Core) -> void:
	GameState.owned_cores.erase(depleted)
	# 同步把可能在队列里的同一个引用也清干净（理论上不该有，保险一下）
	wand.main_core_queue.erase(depleted)
	var promoted: bool = wand.promote_next_main()
	if promoted:
		print("[Wand] 主核耗尽 → 队列顶替 → %s" % wand.get_main_core().display_name)
	else:
		print("[Wand] 主核耗尽，队列已空，魔杖主核槽变空")

# ────────────────────────────────────────────
# 扇形发射 N 发子弹
# ────────────────────────────────────────────
func _spawn_projectile_fan(
	base_direction: Vector2, count: int,
	damage: int, speed: float, fly_range: float,
	split_count: int, homing_deg: float
) -> void:
	var angle_step: float = deg_to_rad(10.0)        # 每发之间隔 10 度
	var start_offset: float = -((count - 1) * angle_step) / 2.0

	for i in count:
		var dir: Vector2 = base_direction.rotated(start_offset + i * angle_step)
		var p: Projectile = PROJECTILE_SCENE.instantiate()
		p.global_position = owner_player.global_position
		p.direction = dir
		p.speed = speed
		p.max_range = fly_range
		p.damage_amount = damage
		p.split_count = split_count
		p.homing_turn_speed_deg = homing_deg
		get_tree().current_scene.add_child(p)
