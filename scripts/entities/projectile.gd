class_name Projectile
extends Hitbox

# ────────────────────────────────────────────
# 飞行参数（WandController 在生成时会覆盖这些）
# ────────────────────────────────────────────
@export var speed: float = 300.0           # 像素/秒
@export var max_range: float = 400.0       # 飞这么远还没打到东西就销毁

var direction: Vector2 = Vector2.RIGHT     # 飞行方向（单位向量）

# ────────────────────────────────────────────
# 分裂相关
# ────────────────────────────────────────────
var split_count: int = 0                   # 还会分裂几次（0 = 不分裂）
var split_delay: float = 0.3               # 飞多少秒后分裂
const SPLIT_SPREAD_DEG: float = 25.0       # 分裂角度

# ────────────────────────────────────────────
# 追踪相关
# ────────────────────────────────────────────
var homing_turn_speed_deg: float = 0.0     # 度/秒。0 = 不追踪
var homing_seek_range: float = 600.0       # 这个范围内的敌人才会被追

# ────────────────────────────────────────────
# 附火相关
# ────────────────────────────────────────────
var burn_dps: int = 0                      # 0 = 不附火
var burn_duration: float = 3.0             # 命中后燃烧多少秒

# ────────────────────────────────────────────
# 内部
# ────────────────────────────────────────────
var _start_position: Vector2
var _time_alive: float = 0.0

func _ready() -> void:
	_start_position = global_position
	hit.connect(_on_hit)

func _physics_process(delta: float) -> void:
	_time_alive += delta

	_apply_homing(delta)
	global_position += direction * speed * delta

	# 优先检查分裂
	if split_count > 0 and _time_alive >= split_delay:
		_do_split()
		return

	# 超距销毁
	if global_position.distance_to(_start_position) > max_range:
		queue_free()

func _apply_homing(delta: float) -> void:
	if homing_turn_speed_deg <= 0.0:
		return
	var target: Node2D = _find_nearest_enemy()
	if target == null:
		return
	var to_target: Vector2 = (target.global_position - global_position).normalized()
	var angle_to_target: float = direction.angle_to(to_target)
	var max_turn: float = deg_to_rad(homing_turn_speed_deg) * delta
	var turn: float = clampf(angle_to_target, -max_turn, max_turn)
	direction = direction.rotated(turn)

func _find_nearest_enemy() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var nearest: Node2D = null
	var min_dist_sq: float = homing_seek_range * homing_seek_range
	for e in enemies:
		if not (e is Node2D):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < min_dist_sq:
			min_dist_sq = d
			nearest = e
	return nearest

func _do_split() -> void:
	var spread: float = deg_to_rad(SPLIT_SPREAD_DEG)
	for angle_offset in [-spread, spread]:
		var child: Projectile = preload("res://scenes/entities/projectile.tscn").instantiate()
		child.global_position = global_position
		child.direction = direction.rotated(angle_offset)
		child.speed = speed
		child.max_range = max_range
		child.damage_amount = damage_amount
		child.split_count = split_count - 1
		child.split_delay = split_delay
		child.homing_turn_speed_deg = homing_turn_speed_deg    # 继承追踪
		child.burn_dps = burn_dps                              # 继承附火
		child.burn_duration = burn_duration
		get_tree().current_scene.add_child(child)
	queue_free()

func _on_hit(hurtbox: Hurtbox) -> void:
	# 命中后挂 burn 状态（如果有）
	if burn_dps > 0 and burn_duration > 0.0:
		var enemy: Node = hurtbox.get_parent()
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(burn_dps, burn_duration)
	queue_free()
