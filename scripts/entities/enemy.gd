class_name Enemy
extends CharacterBody2D

const PICKUP_SCENE_PATH: String = "res://scenes/entities/pickup.tscn"

# ────────────────────────────────────────────
# 通用参数（子类可以在 Inspector 里覆盖）
# ────────────────────────────────────────────
@export var max_health: int = 30
@export var move_speed: float = 60.0
@export var contact_damage: int = 20    # 撞到玩家时造成的伤害
@export var loot_table: Array = []      # [{id: "slime_gel", chance: 1.0, count: 1}]

# ────────────────────────────────────────────
# 节点引用（子类的 .tscn 必须包含这些子节点）
# ────────────────────────────────────────────
@onready var stats: Stats = $Stats
@onready var hurtbox: Hurtbox = $Hurtbox          # 接收玩家攻击
@onready var hitbox: Hitbox = $Hitbox             # 撞玩家造成伤害
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

# ────────────────────────────────────────────
# 运行时状态
# ────────────────────────────────────────────
var is_dead: bool = false

# 燃烧（DoT）状态
var _burn_remaining: float = 0.0          # 还剩多少秒
var _burn_dps: int = 0                    # 每秒掉多少血
var _burn_tick_timer: float = 0.0         # 距离下一次 tick 还有多久（每 1 秒一 tick）

# ────────────────────────────────────────────
# 初始化（子类如果重写 _ready 记得 super._ready()）
# ────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemy")
	stats.max_health = max_health
	stats.health = max_health         # 强制重置，否则用 Stats 默认值 100
	stats.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurtbox_hurt)

# ────────────────────────────────────────────
# 主循环：基类只处理重力 + 应用 velocity
# ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_apply_gravity(delta)
	move_and_slide()

# Burn tick 在 _process 里跑就行（不需要物理帧率）
func _process(delta: float) -> void:
	if is_dead or _burn_remaining <= 0.0:
		return
	_burn_remaining -= delta
	_burn_tick_timer += delta
	if _burn_tick_timer >= 1.0:
		_burn_tick_timer = 0.0
		stats.health -= _burn_dps
		_flash_burn()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += g * delta

# ────────────────────────────────────────────
# 受击与死亡
# ────────────────────────────────────────────
func _on_hurtbox_hurt(attacker: Hitbox) -> void:
	stats.health -= attacker.damage_amount
	_flash_hit()

# 公开接口：被附火状态附加
func apply_burn(dps: int, duration: float) -> void:
	_burn_dps = max(_burn_dps, dps)             # 取较强的 DPS
	_burn_remaining = max(_burn_remaining, duration)  # 不缩短现有持续时间

# ────────────────────────────────────────────
# 视觉反馈
# ────────────────────────────────────────────
func _flash_hit() -> void:
	if animator == null:
		return
	animator.modulate = Color(3, 3, 3, 1)
	var tween := create_tween()
	tween.tween_property(animator, "modulate", Color.WHITE, 0.12)

func _flash_burn() -> void:
	if animator == null:
		return
	animator.modulate = Color(2.0, 0.7, 0.4, 1)    # 橙红
	var tween := create_tween()
	tween.tween_property(animator, "modulate", Color.WHITE, 0.20)

func _on_died() -> void:
	is_dead = true
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	if loot_table.is_empty():
		return
	var pickup_scene: PackedScene = load(PICKUP_SCENE_PATH)
	if pickup_scene == null:
		push_warning("Pickup scene missing: %s" % PICKUP_SCENE_PATH)
		return
	for raw in loot_table:
		if not (raw is Dictionary):
			continue
		var id: String = str(raw.get("id", ""))
		if id == "":
			continue
		var chance: float = float(raw.get("chance", 1.0))
		if randf() > chance:
			continue
		var count: int = int(raw.get("count", 1))
		var p: Node = pickup_scene.instantiate()
		if p == null:
			continue
		p.global_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
		p.set("material_id", id)
		p.set("material_count", max(count, 1))
		# 受击/死亡常在物理信号里触发，不能当场 add 带 Area2D 的节点；延到本帧之后
		var scene_root: Node = get_tree().current_scene
		if scene_root == null:
			p.free()
			continue
		scene_root.call_deferred("add_child", p)
