extends Control

## 战斗界面:把 BattleManager 接上 UI。
## 玩家点可用核攻击 → 敌人回合 → 循环,直到胜/负/撤退,再返回工作室。

const WORKSHOP := "res://scenes/world/workshop.tscn"
const EL_COLOR := {
	"风": Color(0.45, 0.85, 0.45), "水": Color(0.35, 0.65, 1.0),
	"火": Color(1.0, 0.4, 0.25),  "土": Color(0.9, 0.75, 0.25),
}

var _mgr: BattleManager
var _busy: bool = false

# UI 引用
var _enemy_lbl: Label
var _enemy_bar: ProgressBar
var _player_lbl: Label
var _player_bar: ProgressBar
var _cores_box: HFlowContainer
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _footer: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_battle()
	_build_ui()
	_refresh()

# ── 战斗初始化 ────────────────────────────────────────────────────────────────
func _start_battle() -> void:
	var cores := _collect_player_cores()
	# MVP:固定一个弱火的地穴史莱姆
	var enemy := {"name": "地穴史莱姆", "hp": 30, "max_hp": 30, "weakness": "火", "attack": 4}
	_mgr = BattleManager.new(20, cores, enemy)

## 玩家可用的核:合成产物 owned_items 里的核 + 装备核;没有则给应急核
func _collect_player_cores() -> Array:
	var result: Array = []
	for it in GameState.owned_items:
		var c := it as Core
		if c.product_type == "core" and not c.is_depleted():
			result.append(c)
	if GameState.equipped_wand != null:
		for c in GameState.equipped_wand.equipped_cores:
			if c != null and not (c as Core).is_depleted() and not result.has(c):
				result.append(c)
	if result.is_empty():
		var t := Core.make_product("emergency_core", "应急核", "core", 3, 3)
		t.elements.assign(["火", "火"])
		result.append(t)
	return result

# ── UI 构建 ───────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.09, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40; root.offset_right = -40
	root.offset_top = 30; root.offset_bottom = -30
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# 敌人区
	var title := Label.new()
	title.text = "⚔ 遭遇战"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	_enemy_lbl = Label.new()
	_enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_lbl.add_theme_font_size_override("font_size", 16)
	root.add_child(_enemy_lbl)

	_enemy_bar = _make_bar(Color(0.85, 0.3, 0.3))
	root.add_child(_enemy_bar)

	root.add_child(HSeparator.new())

	# 战斗日志(可滚动)
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.custom_minimum_size = Vector2(0, 160)
	root.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)

	root.add_child(HSeparator.new())

	# 玩家区
	_player_lbl = Label.new()
	_player_lbl.add_theme_font_size_override("font_size", 15)
	root.add_child(_player_lbl)
	_player_bar = _make_bar(Color(0.4, 0.75, 0.4))
	root.add_child(_player_bar)

	var tip := Label.new()
	tip.text = "选一颗核攻击(核用完就得撤退):"
	tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	tip.add_theme_font_size_override("font_size", 12)
	root.add_child(tip)

	_cores_box = HFlowContainer.new()
	_cores_box.add_theme_constant_override("h_separation", 8)
	_cores_box.add_theme_constant_override("v_separation", 8)
	root.add_child(_cores_box)

	# 底栏(结算时放返回按钮)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_footer)

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3; sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3; sb.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", sb)
	return bar

# ── 刷新 ──────────────────────────────────────────────────────────────────────
func _refresh() -> void:
	var weak: String = str(_mgr.enemy.get("weakness", ""))
	_enemy_lbl.text = "%s   HP %d/%d   弱点:%s" % [
		_mgr.enemy["name"], int(_mgr.enemy["hp"]), int(_mgr.enemy["max_hp"]), weak]
	_enemy_bar.max_value = int(_mgr.enemy["max_hp"])
	_enemy_bar.value = int(_mgr.enemy["hp"])

	_player_lbl.text = "你   HP %d/%d" % [_mgr.player_hp, _mgr.player_max_hp]
	_player_bar.max_value = _mgr.player_max_hp
	_player_bar.value = _mgr.player_hp

	_rebuild_log()
	_rebuild_cores()

func _rebuild_log() -> void:
	for ch in _log_box.get_children():
		ch.queue_free()
	for line in _mgr.battle_log:
		var lbl := Label.new()
		lbl.text = "· " + line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		_log_box.add_child(lbl)
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

func _rebuild_cores() -> void:
	for ch in _cores_box.get_children():
		ch.queue_free()
	if _mgr.finished:
		return
	var avail := _mgr.available_cores()
	for i in avail.size():
		var core: Core = avail[i]
		var els := "".join(core.elements) if not core.elements.is_empty() else "—"
		var sig := "  ★%s" % core.signature_name if core.signature_unlocked else ""
		var btn := Button.new()
		btn.text = "%s\n[%s] 剩%d次%s" % [core.display_name, els, core.current_uses, sig]
		btn.custom_minimum_size = Vector2(150, 52)
		btn.disabled = _busy
		btn.pressed.connect(_on_use_core.bind(i))
		_cores_box.add_child(btn)

# ── 交互 ──────────────────────────────────────────────────────────────────────
func _on_use_core(idx: int) -> void:
	if _busy or _mgr.finished:
		return
	_busy = true
	_mgr.player_attack(idx)
	_refresh()
	if not _mgr.finished:
		await get_tree().create_timer(0.55).timeout
		_mgr.enemy_turn()
	_busy = false
	_refresh()
	if _mgr.finished:
		_show_result()

func _show_result() -> void:
	for ch in _footer.get_children():
		ch.queue_free()

	var result_lbl := Label.new()
	result_lbl.add_theme_font_size_override("font_size", 20)
	if _mgr.victory:
		result_lbl.text = "🎉 胜利!"
		result_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		_grant_drop()
	elif _mgr.retreated:
		result_lbl.text = "🏳 核用尽,撤退(损失部分采集)"
		result_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		_retreat_loss()
	else:
		result_lbl.text = "💀 战败,被传送回工作室(损失部分采集)"
		result_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		_retreat_loss()
	_log_box.add_child(result_lbl)

	var back := Button.new()
	back.text = "返回工作室"
	back.custom_minimum_size = Vector2(160, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file(WORKSHOP))
	_footer.add_child(back)

func _grant_drop() -> void:
	var mat := MaterialDB.get_material("史莱姆凝胶")
	if mat != null:
		GameState.add_backpack_item(MaterialInstance.roll_from(mat, 0.6))
		var lbl := Label.new()
		lbl.text = "· 掉落:史莱姆凝胶 ×1"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		_log_box.add_child(lbl)

func _retreat_loss() -> void:
	# 撤退惩罚:丢背包里最多 2 份采集(设计 §1.2)
	var lost := 0
	for _i in 2:
		if GameState.backpack_items.is_empty():
			break
		GameState.backpack_items.pop_back()
		lost += 1
	var lbl := Label.new()
	lbl.text = "· 损失采集物 ×%d" % lost
	lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	_log_box.add_child(lbl)
