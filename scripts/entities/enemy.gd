class_name Enemy
extends CharacterBody2D

# ────────────────────────────────────────────
# 通用参数（子类可以在 Inspector 里覆盖）
# ────────────────────────────────────────────
@export var max_health: int = 30
@export var move_speed: float = 60.0
@export var contact_damage: int = 20    # 撞到玩家时造成的伤害

# ────────────────────────────────────────────
# 节点引用（子类的 .tscn 必须包含这些子节点）
# ────────────────────────────────────────────
@onready var stats: Stats = $Stats
@onready var hurtbox: Hurtbox = $Hurtbox    # 接收玩家攻击
@onready var hitbox: Hitbox = $Hitbox       # 撞玩家造成伤害

# ────────────────────────────────────────────
# 运行时状态
# ────────────────────────────────────────────
var is_dead: bool = false

# ────────────────────────────────────────────
# 初始化（子类如果重写 _ready 记得 super._ready()）
# ────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemy")
	stats.max_health = max_health
	stats.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurtbox_hurt)

# ────────────────────────────────────────────
# 主循环：基类只处理重力 + 应用 velocity
# 具体 AI（朝玩家走、跳跃等）由子类在 _physics_process 里实现，
# 然后调用 super._physics_process(delta)
# ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
		velocity.y += g * delta

# ────────────────────────────────────────────
# 受击与死亡
# ────────────────────────────────────────────
func _on_hurtbox_hurt(_hitbox) -> void:
	# 暂时固定每次受击扣 10 血。之后 Phase D 加入子弹时会改成读 hitbox 的 damage 值。
	stats.health -= 10

func _on_died() -> void:
	is_dead = true
	# TODO: 之后接死亡动画 / 掉落素材
	print("[Enemy] %s 死亡" % name)
	queue_free()
