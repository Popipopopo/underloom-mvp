class_name RoomTrigger
extends Area2D

# ────────────────────────────────────────────
# 房间边界 = 自己的 CollisionShape2D（必须是 RectangleShape2D）
# 玩家走进时自动给玩家的 Camera2D 设 limit_*
# ────────────────────────────────────────────

func _ready() -> void:
	body_entered.connect(_on_body_entered_internal)
	monitoring = true

# 子类（如 BossArena）可以重写 _on_player_entered 添加额外行为
func _on_player_entered(_player: Node) -> void:
	pass

# ────────────────────────────────────────────
# 内部
# ────────────────────────────────────────────
func _on_body_entered_internal(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_apply_camera_bounds(body)
	_on_player_entered(body)

func _apply_camera_bounds(player: Node) -> void:
	var cam: Camera2D = _find_camera(player)
	if cam == null:
		push_warning("RoomTrigger: Player 下找不到 Camera2D")
		return
	var rect: Rect2 = _get_world_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_warning("RoomTrigger %s 没有有效的 RectangleShape2D" % name)
		return
	cam.limit_left = int(rect.position.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_right = int(rect.position.x + rect.size.x)
	cam.limit_bottom = int(rect.position.y + rect.size.y)

func _find_camera(player: Node) -> Camera2D:
	for child in player.get_children():
		if child is Camera2D:
			return child
	return null

func _get_world_rect() -> Rect2:
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = (child.shape as RectangleShape2D).size
			var center: Vector2 = global_position + child.position
			return Rect2(center - size * 0.5, size)
	return Rect2()
