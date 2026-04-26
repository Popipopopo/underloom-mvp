class_name Player
extends CharacterBody2D

# ────────────────────────────────────────────
# 移动参数（可在 Inspector 里调）
# ────────────────────────────────────────────
@export var move_speed: float = 150.0          # 左右移动速度

# 飞行参数
@export var fly_force: float = -100.0          # 按住飞行键时的上升速度（负值=向上）
@export var max_fly_energy: float = 100.0
@export var fly_drain_rate: float = 40.0       # 飞行时每秒消耗
@export var fly_recharge_rate: float = 30.0    # 在地面每秒恢复

# 受击参数
@export var invincibility_duration: float = 1.0    # 受击后无敌秒数
@export var damage_taken_per_hit: int = 20         # 一次受击扣多少血

# ────────────────────────────────────────────
# 节点引用（需要在 .tscn 里有对应子节点）
# ────────────────────────────────────────────
@onready var stats: Stats = $Stats
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

# ────────────────────────────────────────────
# 运行时状态
# ────────────────────────────────────────────
var fly_energy: float
var is_flying: bool = false
var is_invincible: bool = false
var is_dead: bool = false
var is_playing_hit_anim: bool = false    # 受击动画播放中，不被其他动画打断

# ────────────────────────────────────────────
# 初始化
# ────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	fly_energy = max_fly_energy
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	stats.died.connect(_on_died)

# ────────────────────────────────────────────
# 主循环
# ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return

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
	if Input.is_action_pressed("ui_up") and fly_energy > 0:
		velocity.y = fly_force
		fly_energy = max(fly_energy - fly_drain_rate * delta, 0)
		is_flying = true
	else:
		is_flying = false

func _handle_horizontal_movement() -> void:
	var dir: float = Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * move_speed

func _recharge_fly_on_ground(delta: float) -> void:
	if is_on_floor() and not Input.is_action_pressed("ui_up"):
		fly_energy = min(fly_energy + fly_recharge_rate * delta, max_fly_energy)

# ────────────────────────────────────────────
# 动画
# ────────────────────────────────────────────
func _update_animation() -> void:
	# 受击动画播放中，不切换
	if is_playing_hit_anim:
		return

	# 朝向：根据水平速度翻转
	if velocity.x != 0:
		animator.flip_h = velocity.x < 0

	# 状态优先级：飞行 > 跑动 > 待机
	if is_flying or (velocity.x != 0 and is_on_floor()):
		animator.play("run")
	else:
		animator.play("idle")

# ────────────────────────────────────────────
# 受击与死亡
# ────────────────────────────────────────────
func _on_hurtbox_hurt(_hitbox) -> void:
	if is_invincible or is_dead:
		return
	stats.health -= damage_taken_per_hit
	is_invincible = true

	# 如果这次没死就播受击动画，死了就交给 _on_died 处理
	if not is_dead:
		is_playing_hit_anim = true
		animator.play("take_damage")
		await animator.animation_finished
		is_playing_hit_anim = false

	# 无敌时间
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false

func _on_died() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	animator.play("death")
	print("[Player] 死亡")
	# TODO: 之后接死亡流程（掉落素材、回工作室、复活等）
