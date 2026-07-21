extends Control

## 战斗界面(JRPG 正面视角布局,仿 RPG Maker / 美少女梦工厂5)。
## 敌人区在上(含立绘占位)、命令菜单在右下、消息窗在左下、玩家状态在底。
## 逻辑全在 BattleManager;本文件只负责呈现与交互。

const WORKSHOP := "res://scenes/world/workshop.tscn"

var _mgr: BattleManager
var _busy: bool = false

# UI 引用
var _enemy_name: Label
var _enemy_bar: ProgressBar
var _enemy_hp_lbl: Label
var _enemy_weak: Label
var _cmd_title: Label
var _cmd_box: VBoxContainer
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _player_bar: ProgressBar
var _player_hp_lbl: Label
var _footer: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_battle()
	_build_ui()
	_refresh()

# ── 战斗初始化 ────────────────────────────────────────────────────────────────
func _start_battle() -> void:
	var cores := _collect_player_cores()
	var potions := _collect_player_potions()
	var enemy := {"name": "地穴史莱姆", "hp": 30, "max_hp": 30, "weakness": "火", "attack": 4}
	_mgr = BattleManager.new(20, cores, enemy, potions)

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

## 可用的恢复药(product_type == "potion")
func _collect_player_potions() -> Array:
	var result: Array = []
	for it in GameState.owned_items:
		var c := it as Core
		if c.product_type == "potion" and not c.is_depleted():
			result.append(c)
	return result

# ── UI 构建(JRPG 布局)────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.11, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24; root.offset_right = -24
	root.offset_top = 20; root.offset_bottom = -20
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# ── 上区:敌人(立绘占位 + 信息)──
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 20)
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(enemy_row)

	enemy_row.add_child(_make_portrait("[ 敌人立绘 ]", Vector2(150, 150), Color(0.5, 0.25, 0.28)))

	var einfo := VBoxContainer.new()
	einfo.custom_minimum_size = Vector2(360, 0)
	einfo.add_theme_constant_override("separation", 6)
	einfo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_row.add_child(einfo)

	_enemy_name = Label.new()
	_enemy_name.add_theme_font_size_override("font_size", 24)
	einfo.add_child(_enemy_name)

	_enemy_bar = _make_bar(Color(0.85, 0.3, 0.3))
	einfo.add_child(_enemy_bar)

	_enemy_hp_lbl = Label.new()
	_enemy_hp_lbl.add_theme_font_size_override("font_size", 13)
	_enemy_hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	einfo.add_child(_enemy_hp_lbl)

	_enemy_weak = Label.new()
	_enemy_weak.add_theme_font_size_override("font_size", 14)
	einfo.add_child(_enemy_weak)

	# ── 中区:左消息窗 + 右命令窗 ──
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	# 消息窗(左)
	var msg_win := _make_window()
	msg_win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(msg_win)
	var msg_body: VBoxContainer = msg_win.get_child(0)
	var msg_title := Label.new()
	msg_title.text = "战斗记录"
	msg_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))
	msg_title.add_theme_font_size_override("font_size", 12)
	msg_body.add_child(msg_title)
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg_body.add_child(_log_scroll)
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)

	# 命令窗(右)
	var cmd_win := _make_window()
	cmd_win.custom_minimum_size = Vector2(300, 0)
	mid.add_child(cmd_win)
	var cmd_body: VBoxContainer = cmd_win.get_child(0)
	_cmd_title = Label.new()
	_cmd_title.text = "▶ 用哪颗核?"
	_cmd_title.add_theme_font_size_override("font_size", 15)
	_cmd_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	cmd_body.add_child(_cmd_title)
	cmd_body.add_child(HSeparator.new())
	_cmd_box = VBoxContainer.new()
	_cmd_box.add_theme_constant_override("separation", 6)
	cmd_body.add_child(_cmd_box)

	# ── 底区:主角立绘占位 + 状态条 + 结算按钮 ──
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	root.add_child(bottom)

	bottom.add_child(_make_portrait("[ 主角 ]", Vector2(56, 56), Color(0.28, 0.4, 0.5)))

	var pinfo := VBoxContainer.new()
	pinfo.custom_minimum_size = Vector2(260, 0)
	pinfo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(pinfo)
	_player_hp_lbl = Label.new()
	_player_hp_lbl.add_theme_font_size_override("font_size", 14)
	pinfo.add_child(_player_hp_lbl)
	_player_bar = _make_bar(Color(0.4, 0.75, 0.4))
	pinfo.add_child(_player_bar)

	_footer = HBoxContainer.new()
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(_footer)

## 立绘占位方块(待美术替换)
func _make_portrait(caption: String, size: Vector2, tint: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.4, tint.g * 0.4, tint.b * 0.4, 1.0)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = tint
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.7))
	l.add_theme_font_size_override("font_size", 12)
	p.add_child(l)
	return p

## 带边框的"窗口"面板;返回其内层 VBox 作为 child(0)
func _make_window() -> PanelContainer:
	var win := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.18, 1.0)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.42, 0.6, 1.0)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	win.add_theme_stylebox_override("panel", sb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	win.add_child(body)
	return win

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 20)
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 3; sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3; sb.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", sb)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.16, 0.22, 1.0)
	bg.corner_radius_top_left = 3; bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3; bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	return bar

# ── 刷新 ──────────────────────────────────────────────────────────────────────
func _refresh() -> void:
	_enemy_name.text = str(_mgr.enemy["name"])
	_enemy_bar.max_value = int(_mgr.enemy["max_hp"])
	_enemy_bar.value = int(_mgr.enemy["hp"])
	_enemy_hp_lbl.text = "HP  %d / %d" % [int(_mgr.enemy["hp"]), int(_mgr.enemy["max_hp"])]
	var weak: String = str(_mgr.enemy.get("weakness", ""))
	_enemy_weak.text = "弱点:%s" % weak if weak != "" else "无明显弱点"
	_enemy_weak.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35))

	_player_hp_lbl.text = "主角     HP  %d / %d" % [_mgr.player_hp, _mgr.player_max_hp]
	_player_bar.max_value = _mgr.player_max_hp
	_player_bar.value = _mgr.player_hp

	_rebuild_log()
	_rebuild_cmd()

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
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

## 命令菜单:每颗可用核一行(核名 + 元素 + 剩余次数 + 招牌)
func _rebuild_cmd() -> void:
	for ch in _cmd_box.get_children():
		ch.queue_free()
	if _mgr.finished:
		_cmd_title.text = "战斗结束"
		return
	# 普攻(总可用,弱保底)
	var atk := _cmd_btn("⚔ 普攻(弱)", "主角挥杖,伤害低但不耗核")
	atk.pressed.connect(_on_basic_attack)
	_cmd_box.add_child(atk)
	# 核
	var cores := _mgr.available_cores()
	for i in cores.size():
		var core: Core = cores[i]
		var els := " ".join(core.elements) if not core.elements.is_empty() else "无元素"
		var sig := "   ★%s" % core.signature_name if core.signature_unlocked else ""
		var b := _cmd_btn(core.display_name, "%s ｜ 剩 %d 次%s" % [els, core.current_uses, sig])
		b.pressed.connect(_on_use_core.bind(i))
		_cmd_box.add_child(b)
	# 药
	var pots := _mgr.available_potions()
	for i in pots.size():
		var pot: Core = pots[i]
		var pb := _cmd_btn("♥ 喝 %s" % pot.display_name, "回血 ｜ 剩 %d 次" % pot.current_uses)
		pb.pressed.connect(_on_use_potion.bind(i))
		_cmd_box.add_child(pb)
	# 撤退
	var flee := _cmd_btn("🏳 撤退", "放弃这场,退回地图")
	flee.pressed.connect(_on_retreat)
	_cmd_box.add_child(flee)

func _cmd_btn(title: String, sub: String) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, sub]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = _busy
	return b

# ── 交互 ──────────────────────────────────────────────────────────────────────
func _on_use_core(idx: int) -> void:
	await _player_action(func(): _mgr.player_attack(idx))

func _on_basic_attack() -> void:
	await _player_action(func(): _mgr.player_basic_attack())

func _on_use_potion(idx: int) -> void:
	await _player_action(func(): _mgr.player_use_potion(idx))

## 玩家行动统一流程:执行 → 刷新 → 敌人回合 → 刷新 → 结算
func _player_action(act: Callable) -> void:
	if _busy or _mgr.finished:
		return
	_busy = true
	act.call()
	_refresh()
	if not _mgr.finished:
		await get_tree().create_timer(0.55).timeout
		_mgr.enemy_turn()
	_busy = false
	_refresh()
	if _mgr.finished:
		_show_result()

func _on_retreat() -> void:
	if _busy or _mgr.finished:
		return
	_mgr.retreat()
	_refresh()
	_show_result()

func _show_result() -> void:
	for ch in _footer.get_children():
		ch.queue_free()

	var result_lbl := Label.new()
	result_lbl.add_theme_font_size_override("font_size", 18)
	if _mgr.victory:
		result_lbl.text = "🎉 胜利!"
		result_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		_grant_drop()
	elif _mgr.retreated:
		result_lbl.text = "🏳 撤退了(未获战利品,但无损失)"
		result_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	else:
		result_lbl.text = "💀 战败,被传回工作室(损失部分采集)"
		result_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		_retreat_loss()
	_log_box.add_child(result_lbl)
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

	var back := Button.new()
	var is_defeat := not _mgr.victory and not _mgr.retreated
	back.text = "继续探索" if (GameState.expedition_active and not is_defeat) else "返回工作室"
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(_leave_battle)
	_footer.add_child(back)

func _leave_battle() -> void:
	# 战败(HP 归零)→ 结束远征、传回工作室;胜利/主动撤退 → 回地图继续探索
	if not _mgr.victory and not _mgr.retreated:
		GameState.end_expedition()
		get_tree().change_scene_to_file(WORKSHOP)
	elif GameState.expedition_active:
		get_tree().change_scene_to_file("res://scenes/world/map.tscn")
	else:
		get_tree().change_scene_to_file(WORKSHOP)

func _grant_drop() -> void:
	var mat := MaterialDB.get_material("史莱姆凝胶")
	if mat != null:
		GameState.add_backpack_item(MaterialInstance.roll_from(mat, 0.6))
		var lbl := Label.new()
		lbl.text = "· 掉落:史莱姆凝胶 ×1"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		_log_box.add_child(lbl)

func _retreat_loss() -> void:
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
