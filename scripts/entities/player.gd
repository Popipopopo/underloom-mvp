class_name Player
extends CharacterBody2D

# ────────────────────────────────────────────
# 工作室内移动控制器（v1.1：战斗已移出实时场景，
# 这里只保留走动/飞行，用于在工作室里逛和触发交互区）
# ────────────────────────────────────────────

# 移动参数（可在 Inspector 里调）
@export var move_speed: float = 150.0          # 左右移动速度

# 飞行参数
@export var fly_force: float = -100.0          # 按住飞行键时的上升速度（负值=向上）
@export var max_fly_energy: float = 100.0
@export var fly_drain_rate: float = 40.0       # 飞行时每秒消耗
@export var fly_recharge_rate: float = 30.0    # 在地面每秒恢复

# ────────────────────────────────────────────
# 节点引用（需要在 .tscn 里有对应子节点）
# ────────────────────────────────────────────
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

# ────────────────────────────────────────────
# 运行时状态
# ────────────────────────────────────────────
var fly_energy: float
var is_flying: bool = false

# ────────────────────────────────────────────
# 初始化
# ────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	fly_energy = max_fly_energy

# ────────────────────────────────────────────
# 主循环
# ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_flying(delta)
	_handle_horizontal_movement()
	_recharge_fly_on_ground(delta)
	move_and_slide()
	_update_animation()

# ────────────────────────────────────────────
# 移动逻辑
# ────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += g * delta

func _handle_flying(delta: float) -> void:
	if Input.is_action_pressed("fly") and fly_energy > 0:
		velocity.y = fly_force
		fly_energy = max(fly_energy - fly_drain_rate * delta, 0)
		is_flying = true
	else:
		is_flying = false

func _handle_horizontal_movement() -> void:
	var dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = dir * move_speed

func _recharge_fly_on_ground(delta: float) -> void:
	if is_on_floor() and not Input.is_action_pressed("fly"):
		fly_energy = min(fly_energy + fly_recharge_rate * delta, max_fly_energy)

# ────────────────────────────────────────────
# 动画
# ────────────────────────────────────────────
func _update_animation() -> void:
	# 朝向：根据水平速度翻转
	if velocity.x != 0:
		animator.flip_h = velocity.x < 0

	# 状态优先级：飞行 > 跑动 > 待机
	if is_flying or (velocity.x != 0 and is_on_floor()):
		animator.play("run")
	else:
		animator.play("idle")
