extends CanvasLayer

# 演示版结局屏：黑屏 + 居中文字 + 回工作室按钮
# 由 TestCombatController 在玩家拾取到 ancient_seal 时实例化

@onready var _continue_btn: Button = %ContinueButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # 暂停状态下也能点
	get_tree().paused = true
	if _continue_btn != null:
		_continue_btn.pressed.connect(_on_continue_pressed)
		_continue_btn.grab_focus()

func _on_continue_pressed() -> void:
	get_tree().paused = false
	# 把背包并回工作室仓库（ancient_seal 也会进去）
	GameState.merge_backpack_into_workshop()
	RunManager.in_run = false
	get_tree().change_scene_to_file("res://scenes/world/workshop.tscn")
