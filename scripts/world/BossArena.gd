class_name BossArena
extends RoomTrigger

# ────────────────────────────────────────────
# 玩家进入 → 显示屏障 + 锁视角
# Boss 被销毁（queue_free）→ 屏障消失，玩家可离开
# ────────────────────────────────────────────

@onready var barrier: Node2D = get_node_or_null("Barrier")
var _activated: bool = false

func _ready() -> void:
	super._ready()
	_set_barrier_active(false)        # 启动时屏障不可见

func _on_player_entered(_player: Node) -> void:
	if _activated:
		return
	_activated = true
	_set_barrier_active(true)

	var boss: Node = _find_boss()
	if boss == null:
		push_warning("BossArena %s 找不到 'boss' 组中的敌人。屏障会一直在！" % name)
		return
	# tree_exited 在节点被 queue_free 销毁时触发，最稳的"boss 真的死了"信号
	boss.tree_exited.connect(_on_boss_died)

func _on_boss_died() -> void:
	_set_barrier_active(false)
	print("[BossArena] Boss 死亡 → 屏障消失")

# ────────────────────────────────────────────
# 屏障启用/禁用：控制 visible + 子 CollisionShape2D 的 disabled
# ────────────────────────────────────────────
func _set_barrier_active(active: bool) -> void:
	if barrier == null:
		return
	barrier.visible = active
	for child in barrier.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = not active

func _find_boss() -> Node:
	var bosses: Array = get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		return bosses[0]
	return null
