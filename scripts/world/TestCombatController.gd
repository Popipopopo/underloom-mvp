extends Node2D

const ENDING_SCENE_PATH: String = "res://scenes/ui/ending_screen.tscn"
const ENDING_TRIGGER_MATERIAL: String = "ancient_seal"

# 清场后不再弹任何窗；玩家随时用按钮结束本局，才看到战利品 + 回工作室
var _cleared: bool = false
var _summary_open: bool = false
var _ending_triggered: bool = false

func _ready() -> void:
	_add_leave_run_hud()

func _add_leave_run_hud() -> void:
	if not RunManager.in_run:
		return
	var layer := CanvasLayer.new()
	layer.name = "LeaveRunHud"
	layer.layer = 15
	add_child(layer)

	var btn := Button.new()
	btn.text = "Leave run"
	btn.custom_minimum_size = Vector2(160, 40)
	btn.anchor_left = 1.0
	btn.anchor_top = 0.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 0.0
	btn.offset_left = -180.0
	btn.offset_top = 12.0
	btn.offset_right = -20.0
	btn.offset_bottom = 52.0
	btn.pressed.connect(_on_leave_run_pressed)
	layer.add_child(btn)

func _process(_delta: float) -> void:
	# 1. 检测拾取了 boss 掉落 → 直接进结局，不再走清场/总结流程
	if not _ending_triggered and GameState.get_backpack_count(ENDING_TRIGGER_MATERIAL) > 0:
		_ending_triggered = true
		_show_ending()
		return

	# 2. 普通清场检测
	if _cleared or not RunManager.in_run:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		_on_room_cleared()

func _show_ending() -> void:
	# 屏蔽 leave-run 按钮的总结弹窗
	_summary_open = true
	RunManager.in_run = false
	var ps: PackedScene = load(ENDING_SCENE_PATH)
	if ps == null:
		push_warning("Ending scene missing: %s" % ENDING_SCENE_PATH)
		return
	var inst: Node = ps.instantiate()
	add_child(inst)

func _on_room_cleared() -> void:
	# 只打标志，不显示任何 UI；玩家可继续探索 / 拾取，或点 Leave run 离开
	_cleared = true

func _on_leave_run_pressed() -> void:
	if _summary_open or not RunManager.in_run:
		return
	var loot_snapshot: Dictionary = GameState.backpack.duplicate(true)
	RunManager.end_victory()
	_summary_open = true
	_show_result_popup(loot_snapshot)

func _show_result_popup(loot_snapshot: Dictionary) -> void:
	var ui := CanvasLayer.new()
	ui.name = "RunResultUI"
	ui.layer = 20
	add_child(ui)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 320)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -160
	panel.offset_right = 260
	panel.offset_bottom = 160
	ui.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_top = 20
	box.offset_right = -20
	box.offset_bottom = -20
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Run summary"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var loot_title := Label.new()
	loot_title.text = "Loot this run"
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_title.add_theme_font_size_override("font_size", 18)
	box.add_child(loot_title)

	var loot_text := Label.new()
	loot_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loot_text.text = _format_loot_text(loot_snapshot)
	box.add_child(loot_text)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var btn := Button.new()
	btn.text = "Return to workshop"
	btn.custom_minimum_size = Vector2(260, 52)
	btn.pressed.connect(_on_return_button_pressed)
	box.add_child(btn)

func _format_loot_text(loot_snapshot: Dictionary) -> String:
	if loot_snapshot.is_empty():
		return "No loot collected."
	var parts: Array[String] = []
	for id in loot_snapshot.keys():
		parts.append("%s x%d" % [str(id), int(loot_snapshot[id])])
	parts.sort()
	return ", ".join(parts)

func _on_return_button_pressed() -> void:
	GameState.merge_backpack_into_workshop()
	get_tree().change_scene_to_file("res://scenes/world/workshop.tscn")
