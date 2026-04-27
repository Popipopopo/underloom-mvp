class_name Slime
extends Enemy

# ────────────────────────────────────────────
# 史莱姆特有参数
# ────────────────────────────────────────────
@export var detect_distance: float = 400.0    # 玩家在这个范围内才追

# ────────────────────────────────────────────
# 初始化：把自己的接触伤害同步到 Hitbox
# （animator 由 Enemy 基类提供）
# ────────────────────────────────────────────
func _ready() -> void:
	super._ready()                       # 重要！基类的 _ready 不能丢
	hitbox.damage_amount = contact_damage
	if loot_table.is_empty():
		loot_table = [
			{"id": "slime_gel", "chance": 1.0, "count": 1}
		]

# ────────────────────────────────────────────
# 主循环：先做自己的 AI（决定 velocity.x），
# 再调 super._physics_process(delta) 让父类处理重力 + move_and_slide
# ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_chase_player()
	super._physics_process(delta)
	_update_animation()

func _chase_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		velocity.x = 0.0
		return

	var dx: float = player.global_position.x - global_position.x
	if abs(dx) > detect_distance:
		velocity.x = 0.0
		return

	velocity.x = signf(dx) * move_speed

# ────────────────────────────────────────────
# 动画
# ────────────────────────────────────────────
func _update_animation() -> void:
	if velocity.x != 0:
		animator.flip_h = velocity.x > 0    # Slimer.png 默认朝左，反向 flip
	# Slime 只有 idle 一个移动状态动画，不区分 idle / walk
	animator.play("idle")

# ────────────────────────────────────────────
# 死亡：覆盖父类，先播 death 动画再销毁
# ────────────────────────────────────────────
func _on_died() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	# 基类 Enemy._on_died 里的 _drop_loot 不会走（我们覆盖了 _on_died 且未 super），必须自己掉
	_drop_loot()
	animator.play("death")
	await animator.animation_finished
	queue_free()
