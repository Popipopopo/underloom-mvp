class_name Slime
extends Enemy

# ────────────────────────────────────────────
# 史莱姆特有参数
# ────────────────────────────────────────────
@export var detect_distance: float = 400.0    # 玩家在这个范围内才追

# ────────────────────────────────────────────
# 节点引用
# ────────────────────────────────────────────
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

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
		animator.flip_h = velocity.x < 0
	# Slime 只有 idle 一个移动状态动画，不区分 idle / walk
	animator.play("idle")

# ────────────────────────────────────────────
# 死亡：覆盖父类，先播 death 动画再销毁
# ────────────────────────────────────────────
func _on_died() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	animator.play("death")
	await animator.animation_finished
	queue_free()
