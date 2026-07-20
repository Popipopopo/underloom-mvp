## CraftingScreen — 多步合成向导
## Step 0: 选配方
## Step 1: 逐槽选材料
## Step 2+3: 自动计算（无UI，内部处理）
## Step 4: 元素干涉
## Step 5: Tag共鸣
## Step 7: 结果展示
extends Control

signal closed

# ── 颜色常量 ──────────────────────────────────────────────────────────────────
const EL_COLOR: Dictionary = {
	"风": Color(0.45, 0.85, 0.45),
	"水": Color(0.35, 0.65, 1.0),
	"火": Color(1.0, 0.4, 0.25),
	"土": Color(0.9, 0.75, 0.25),
}
const EL_COLOR_DEFAULT := Color(0.7, 0.7, 0.7)

# ── 状态 ─────────────────────────────────────────────────────────────────────
var _manager: CraftingManager = CraftingManager.new()
var _current_step: int = 0   # 0=配方 1=材料 4=干涉工作台 7=结果
var _current_slot: int = 0   # 用于Step1逐槽推进
var _first_tag_resonance_triggered: bool = false

# 干涉工作台的动态区域引用（_show_step_4 创建，_refresh_interfere 刷新）
var _i_pts_lbl: Label = null
var _i_dots: HFlowContainer = null
var _i_el_res: VBoxContainer = null
var _i_tags: VBoxContainer = null

# ── UI 根节点 ─────────────────────────────────────────────────────────────────
var _panel: Panel
var _content: VBoxContainer     # 每次切步骤时清空重填
var _title_label: Label
var _slot_bar: HBoxContainer    # 槽位总览行（Step1期间显示，其余步骤隐藏）
var _footer: HBoxContainer      # 固定底栏（后退按钮放这里）
var _back_btn: Button           # 后退按钮引用

# ── 初始化 ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_show_step_0()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()

# ── 固定外壳（Panel + title + content VBox）────────────────────────────────────
func _build_shell() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.93)   # 实心遮罩
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(700, 520)
	_panel.anchor_left  = 0.5;  _panel.anchor_right  = 0.5
	_panel.anchor_top   = 0.5;  _panel.anchor_bottom = 0.5
	_panel.offset_left  = -350; _panel.offset_right  = 350
	_panel.offset_top   = -270; _panel.offset_bottom = 270
	# 深色实心面板背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.15, 1.0)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.30, 0.50, 1.0)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 16; root_vbox.offset_right  = -16
	root_vbox.offset_top  = 12; root_vbox.offset_bottom = -12
	root_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(root_vbox)

	# 标题行（左：配方名，右：步骤）
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(_title_label)

	# 槽位总览行（Step1 时显示）
	_slot_bar = HBoxContainer.new()
	_slot_bar.add_theme_constant_override("separation", 8)
	_slot_bar.visible = false
	root_vbox.add_child(_slot_bar)

	root_vbox.add_child(HSeparator.new())

	# 主内容区（可滚动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	root_vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	root_vbox.add_child(HSeparator.new())

	# 固定底栏：后退 + 关闭
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_footer)

	_back_btn = Button.new()
	_back_btn.text = "← 返回"
	_back_btn.visible = false
	_footer.add_child(_back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "关闭 (Esc)"
	close_btn.pressed.connect(_on_close)
	_footer.add_child(close_btn)

func _clear_content() -> void:
	for ch in _content.get_children():
		ch.queue_free()

# ── Step 0: 选配方 ─────────────────────────────────────────────────────────────
func _show_step_0() -> void:
	_current_step = 0
	_clear_content()
	_title_label.text = "炼成 — 要做什么呢"
	_slot_bar.visible = false
	_back_btn.visible = false
	# 断开之前绑的信号
	if _back_btn.pressed.get_connections().size() > 0:
		_clear_back_btn_connections()

	var recipes: Array = RecipeDB.get_all()
	if recipes.is_empty():
		_add_label("没有可用配方")
		return

	for r in recipes:
		var recipe: Recipe = r as Recipe
		var btn := Button.new()
		btn.text = recipe.display_name
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sub := Label.new()
		sub.text = "[%s] 槽位: %s" % [_product_type_cn(recipe.product_type), " / ".join(recipe.slot_tags)]
		sub.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		sub.add_theme_font_size_override("font_size", 12)
		_content.add_child(btn)
		_content.add_child(sub)
		# 招牌目标常驻显示(明确目标,凑够才解锁)
		if not recipe.signature.is_empty():
			var sig := Label.new()
			sig.text = "　★招牌「%s」：%s" % [recipe.signature.get("name", ""), recipe.signature.get("effect", "")]
			sig.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
			sig.add_theme_font_size_override("font_size", 11)
			sig.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(sig)
		btn.pressed.connect(_on_recipe_chosen.bind(recipe.id))

func _on_recipe_chosen(recipe_id: String) -> void:
	var ok: bool = _manager.set_recipe_by_id(recipe_id)
	if not ok:
		return
	_current_slot = 0
	_first_tag_resonance_triggered = false
	_show_step_1(_current_slot)

# ── Step 1: 逐槽选材料 ────────────────────────────────────────────────────────
func _show_step_1(slot_index: int) -> void:
	_current_step = 1
	_clear_content()
	var recipe: Recipe = _manager.state.recipe
	var slot_tag: String = recipe.slot_tags[slot_index]
	_title_label.text = "魔力核 — 1. 挑选材料"

	# 更新槽位总览行
	_slot_bar.visible = true
	_update_slot_bar(slot_index)

	# 更新底栏后退按钮
	_back_btn.visible = true
	if _back_btn.pressed.get_connections().size() > 0:
		_clear_back_btn_connections()
	if slot_index == 0:
		_back_btn.text = "← 返回配方"
		_back_btn.pressed.connect(_show_step_0)
	else:
		_back_btn.text = "← 上一槽"
		_back_btn.pressed.connect(_go_back_slot.bind(slot_index))

	# 材料候选：仓库里带该 tag 的每一份实例一张卡（炼金工房式卡片背包），
	# 元素在采集时已定型——卡上显示的就是实际元素，同名材料各卡可以不同
	var candidates: Array = GameState.workshop_items_by_tag(slot_tag)
	# 排除已被其他槽占用的实例
	var used: Array = _manager.state.fills
	candidates = candidates.filter(func(inst): return not used.has(inst))
	if candidates.is_empty():
		_add_label("仓库里没有符合条件的材料 [%s]" % slot_tag)
		return

	candidates.sort_custom(func(a, b) -> bool:
		var ma: CraftingMaterial = (a as MaterialInstance).base()
		var mb: CraftingMaterial = (b as MaterialInstance).base()
		if ma.lv != mb.lv:
			return ma.lv < mb.lv
		if ma.id != mb.id:
			return ma.id < mb.id
		return (a as MaterialInstance).elements.size() > (b as MaterialInstance).elements.size())

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_content.add_child(flow)

	for inst_obj in candidates:
		var inst: MaterialInstance = inst_obj as MaterialInstance
		var card := _make_item_card(inst)
		flow.add_child(card)
		var btn: Button = card.find_child("SelectBtn", true, false) as Button
		if btn != null:
			btn.pressed.connect(_on_material_selected.bind(slot_index, inst))

## 重建槽位总览行
func _update_slot_bar(active_slot: int) -> void:
	for ch in _slot_bar.get_children():
		ch.queue_free()
	var recipe: Recipe = _manager.state.recipe
	for i in recipe.slot_count():
		var slot_box := _make_slot_chip(i, active_slot)
		_slot_bar.add_child(slot_box)
		# 分隔箭头
		if i < recipe.slot_count() - 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
			_slot_bar.add_child(arrow)

func _make_slot_chip(slot_i: int, active_slot: int) -> PanelContainer:
	var recipe: Recipe = _manager.state.recipe
	var filled_inst: MaterialInstance = _manager.state.fills[slot_i] if _manager.state.fills.size() > slot_i else null
	var is_active: bool = slot_i == active_slot
	var is_filled: bool = filled_inst != null

	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sty := StyleBoxFlat.new()
	if is_active:
		sty.bg_color = Color(0.22, 0.18, 0.35, 1.0)
		sty.border_color = Color(0.65, 0.5, 1.0, 1.0)
	elif is_filled:
		sty.bg_color = Color(0.14, 0.20, 0.18, 1.0)
		sty.border_color = Color(0.35, 0.7, 0.5, 1.0)
	else:
		sty.bg_color = Color(0.12, 0.12, 0.18, 1.0)
		sty.border_color = Color(0.30, 0.30, 0.40, 1.0)
	sty.border_width_left = 1; sty.border_width_right  = 1
	sty.border_width_top  = 1; sty.border_width_bottom = 1
	sty.corner_radius_top_left     = 4; sty.corner_radius_top_right    = 4
	sty.corner_radius_bottom_left  = 4; sty.corner_radius_bottom_right = 4
	sty.content_margin_left = 8; sty.content_margin_right  = 8
	sty.content_margin_top  = 6; sty.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	chip.add_child(vbox)

	# 槽位 tag 标签
	var tag_lbl := Label.new()
	tag_lbl.text = recipe.slot_tags[slot_i]
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color",
		Color(0.85, 0.75, 1.0) if is_active else Color(0.55, 0.55, 0.65))
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tag_lbl)

	if is_filled:
		# 已选实例：材料名 + 定型元素
		var mat: CraftingMaterial = filled_inst.base()
		if mat != null:
			var name_lbl := Label.new()
			name_lbl.text = mat.display_name
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(name_lbl)

			var el_row := HBoxContainer.new()
			el_row.add_theme_constant_override("separation", 2)
			el_row.alignment = BoxContainer.ALIGNMENT_CENTER
			for el in _manager.get_slot_elements(slot_i):
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(8, 8)
				dot.color = EL_COLOR.get(el, EL_COLOR_DEFAULT)
				el_row.add_child(dot)
			vbox.add_child(el_row)

			# tag 常驻显示（实测反馈：后面选共鸣时需要看到词条出处）
			var tags_lbl := Label.new()
			tags_lbl.text = " ".join(mat.tags)
			tags_lbl.add_theme_font_size_override("font_size", 9)
			tags_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
			tags_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(tags_lbl)
	elif is_active:
		var hint := Label.new()
		hint.text = "← 正在选择"
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(0.65, 0.55, 0.9))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)

	return chip

func _go_back_slot(slot_index: int) -> void:
	# 清掉前一槽的选择，回到前一槽
	_manager.clear_slot(slot_index - 1)
	_current_slot = slot_index - 1
	_show_step_1(_current_slot)

## 单份材料实例的卡片（炼金工房式：每张卡的元素在采集时已定型，
## 卡上显示的就是实际元素，同名材料各卡可以不同）
func _make_item_card(inst: MaterialInstance) -> PanelContainer:
	var mat: CraftingMaterial = inst.base()

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 0)

	# 背景样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.22, 1.0)
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.38, 0.65, 1.0)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	# 名字 + Lv
	var name_lbl := Label.new()
	name_lbl.text = mat.display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv%d" % mat.lv
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	vbox.add_child(lv_lbl)

	# 元素点（小彩色方块）——这份实例的实际元素，全实色
	var el_row := HBoxContainer.new()
	el_row.add_theme_constant_override("separation", 3)
	vbox.add_child(el_row)
	for el in inst.elements:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.color = EL_COLOR.get(el, EL_COLOR_DEFAULT)
		el_row.add_child(dot)

	# tags（小字）
	var tag_lbl := Label.new()
	tag_lbl.text = " ".join(mat.tags)
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tag_lbl)

	# 选择按钮
	var btn := Button.new()
	btn.name = "SelectBtn"
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(0, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn)

	return card

func _on_material_selected(slot_index: int, inst: MaterialInstance) -> void:
	var err: String = _manager.set_slot(slot_index, inst)
	if err != "":
		_add_label("错误: " + err)
		return
	_current_slot = slot_index + 1
	if _current_slot < _manager.state.recipe.slot_count():
		_show_step_1(_current_slot)
	else:
		# All slots filled — 汇入元素池 + 算品质，直接进干涉工作台
		_manager.build_element_pool()
		_manager.compute_lv()
		_show_step_4()

# ── Step 4: 干涉工作台（v1.1 实测修订）─────────────────────────────────────────
# 元素锁定 + Tag 共鸣同屏，共用一个点数池（实测：预分配是"信息之前的决策"，删）。
# 左：元素点阵 + 重炼 + 效果小抄；右：元素共鸣实时反馈 + Tag 共鸣触发（含来源）。
func _show_step_4() -> void:
	_current_step = 4
	_clear_content()
	_title_label.text = "干涉工作台 — 品质 %s" % _manager.get_quality_name()
	_slot_bar.visible = true
	_update_slot_bar(-1)
	_configure_back_btn_to_slot_selection()

	# 左右分栏
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	_content.add_child(split)

	# 左栏：点数 + 元素格子 + 重炼 + 小抄
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	_i_pts_lbl = Label.new()
	_i_pts_lbl.add_theme_font_size_override("font_size", 15)
	left.add_child(_i_pts_lbl)

	var hint := Label.new()
	hint.text = "点亮想保留的元素——只有点亮的会进成品"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	left.add_child(hint)

	_i_dots = HFlowContainer.new()
	_i_dots.add_theme_constant_override("h_separation", 6)
	_i_dots.add_theme_constant_override("v_separation", 6)
	left.add_child(_i_dots)

	left.add_child(_make_cheat_sheet())

	# 右栏：元素共鸣（实时）+ Tag 共鸣（触发）
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(280, 0)
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)

	var el_title := Label.new()
	el_title.text = "元素共鸣（点亮元素自动触发）"
	el_title.add_theme_font_size_override("font_size", 13)
	right.add_child(el_title)

	_i_el_res = VBoxContainer.new()
	right.add_child(_i_el_res)

	right.add_child(HSeparator.new())

	var tag_title := Label.new()
	tag_title.text = "Tag 共鸣（第 1 个免费，之后每个 1 点）"
	tag_title.add_theme_font_size_override("font_size", 13)
	right.add_child(tag_title)

	_i_tags = VBoxContainer.new()
	right.add_child(_i_tags)

	# 完成按钮
	var confirm_btn := Button.new()
	confirm_btn.text = "完成合成 →"
	confirm_btn.pressed.connect(_on_interfere_confirm)
	_content.add_child(confirm_btn)

	_refresh_interfere()

## 干涉工作台整体刷新：干涉点、元素点阵、元素共鸣、Tag 共鸣
func _refresh_interfere() -> void:
	var sig_line := ""
	if not _manager.state.recipe.signature.is_empty():
		var unlocked: bool = bool(_manager.check_signature()["unlocked"])
		var mark := "✅ 已解锁" if unlocked else "⬜ 未达成"
		sig_line = "\n★招牌 %s  %s" % [_manager.signature_hint(), mark]
	_i_pts_lbl.text = "剩余干涉点：%d / %d%s" % [_manager.pts, _manager.total_pts, sig_line]

	# 元素点阵
	for ch in _i_dots.get_children():
		ch.queue_free()
	for i in _manager.rolled_elements.size():
		var entry: Dictionary = _manager.rolled_elements[i]
		var el: String = entry["element"]
		var is_locked: bool = entry["state"] == "locked"

		var dot := Button.new()
		dot.custom_minimum_size = Vector2(52, 38)
		if is_locked:
			dot.text = "✓ " + el
			dot.modulate = EL_COLOR.get(el, EL_COLOR_DEFAULT)
		else:
			dot.text = el
			dot.modulate = Color(0.45, 0.45, 0.5, 0.7)
			dot.disabled = _manager.pts <= 0
		dot.pressed.connect(_on_element_dot_pressed.bind(i))
		_i_dots.add_child(dot)

	# 元素共鸣实时反馈
	for ch in _i_el_res.get_children():
		ch.queue_free()
	var resonances: Array[String] = _manager.active_resonances()
	if resonances.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "（暂无，点亮元素试试）"
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		none_lbl.add_theme_font_size_override("font_size", 12)
		_i_el_res.add_child(none_lbl)
	else:
		for res_name in resonances:
			var lbl := Label.new()
			lbl.text = "✦ " + res_name
			lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
			_i_el_res.add_child(lbl)

	# Tag 共鸣列表（含来源材料）
	for ch in _i_tags.get_children():
		ch.queue_free()
	var available: Array[Dictionary] = _manager.available_tag_resonances()
	if available.is_empty() and _manager.triggered_tag_resonances.is_empty():
		var no_tag := Label.new()
		no_tag.text = "（这批材料没有可组合的 Tag）"
		no_tag.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		no_tag.add_theme_font_size_override("font_size", 12)
		_i_tags.add_child(no_tag)
	for res in available:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_i_tags.add_child(row)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)

		var name_lbl := Label.new()
		name_lbl.text = "✦ " + str(res["name"])
		col.add_child(name_lbl)

		# 来源：哪个 tag 来自哪个材料（实测反馈：选共鸣时看不到词条出处）
		var src_parts: Array[String] = []
		for t in res["tags"]:
			var providers: Array[String] = _manager.get_tag_providers(str(t))
			var src: String = "/".join(providers) if not providers.is_empty() else "?"
			src_parts.append("%s←%s" % [t, src])
		var src_lbl := Label.new()
		src_lbl.text = "　" + "　".join(src_parts)
		src_lbl.add_theme_font_size_override("font_size", 10)
		src_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
		col.add_child(src_lbl)

		var btn := Button.new()
		var is_free: bool = not _first_tag_resonance_triggered
		btn.text = "免费触发" if is_free else "触发 -1点"
		btn.disabled = not (is_free or _manager.pts > 0)
		btn.pressed.connect(_on_trigger_tag_resonance.bind(str(res["name"])))
		row.add_child(btn)

	if not _manager.triggered_tag_resonances.is_empty():
		var done_lbl := Label.new()
		done_lbl.text = "已触发: " + ", ".join(_manager.triggered_tag_resonances)
		done_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_i_tags.add_child(done_lbl)

func _on_element_dot_pressed(idx: int) -> void:
	_manager.toggle_lock(idx)
	_refresh_interfere()

func _on_trigger_tag_resonance(resonance_name: String) -> void:
	var is_free: bool = not _first_tag_resonance_triggered
	if _manager.trigger_tag_resonance(resonance_name, is_free) != "":
		return
	_first_tag_resonance_triggered = true
	_refresh_interfere()

func _on_interfere_confirm() -> void:
	_show_step_7()

## 元素效果小抄：不用背表，看着点
func _make_cheat_sheet() -> PanelContainer:
	var panel := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	sty.border_width_left = 1; sty.border_width_right = 1
	sty.border_width_top = 1; sty.border_width_bottom = 1
	sty.border_color = Color(0.25, 0.25, 0.35, 1.0)
	sty.content_margin_left = 8; sty.content_margin_right = 8
	sty.content_margin_top = 6; sty.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "效果对照（同色元素数量）"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(title)

	var lines: Array = [
		["风", "1微提速  2轻追踪  3强追踪  4暴风"],
		["水", "1微减速  2减速  3扩散  4冻结"],
		["火", "1微火伤  2小爆炸  3燃烧  4连锁爆炸"],
		["土", "1微破防  2击退  3穿透  4震地"],
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = "%s  %s" % [line[0], line[1]]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", EL_COLOR.get(line[0], EL_COLOR_DEFAULT))
		vbox.add_child(lbl)

	var duo := Label.new()
	duo.text = "双元素：风水=冰弹 风火=火箭 火水=蒸汽 火土=熔岩 水土=泥沼 风土=沙暴"
	duo.add_theme_font_size_override("font_size", 10)
	duo.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55))
	duo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(duo)
	return panel

# ── Step 7: 结果展示 ──────────────────────────────────────────────────────────
func _show_step_7() -> void:
	_current_step = 7
	_clear_content()
	_title_label.text = "合成结果"

	var core: Core = _manager.build_product()
	if core == null:
		_add_label("合成失败（材料不足？）")
		return

	# Quality banner
	var banner := Label.new()
	banner.text = "=== %s ===" % core.display_name
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 24)
	match _manager.get_quality_name():
		"石": banner.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		"铜": banner.add_theme_color_override("font_color", Color(0.85, 0.55, 0.25))
		"银": banner.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		"金": banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_content.add_child(banner)

	_add_result_row("类型", _product_type_cn(core.product_type))
	_add_result_row("品质", "%s  Lv%d" % [_manager.get_quality_name(), core.result_lv])
	if core.is_consumable():
		_add_result_row("使用次数", str(core.max_uses))

	# 解读镜头:这些元素在本产物里是什么效果
	if not core.element_effects.is_empty():
		_add_result_row("效果(%s)" % _product_type_cn(core.product_type), "；".join(core.element_effects))

	# 元素共鸣 + Tag 共鸣(通用词条)
	if not core.element_tags.is_empty():
		_add_result_row("元素共鸣", ", ".join(core.element_tags))
	if not core.tag_words.is_empty():
		_add_result_row("Tag词条", ", ".join(core.tag_words))

	# 招牌效果
	if core.signature_name != "":
		var sig_val: String = "★ 已解锁！%s" % _manager.state.recipe.signature.get("effect", "") if core.signature_unlocked else "☆ 未解锁（%s）" % core.signature_name
		_add_result_row("招牌", sig_val)

	_content.add_child(HSeparator.new())

	var again_btn := Button.new()
	again_btn.text = "再合成一个"
	again_btn.pressed.connect(_show_step_0)
	_content.add_child(again_btn)

func _product_type_cn(pt: String) -> String:
	match pt:
		"core": return "核"
		"potion": return "药剂"
		"charm": return "护符"
		"trade": return "交易品"
	return pt

func _add_result_row(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var k := Label.new()
	k.text = label + ":"
	k.custom_minimum_size = Vector2(120, 0)
	k.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	row.add_child(k)
	var v := Label.new()
	v.text = value
	row.add_child(v)

# ── 工具 ──────────────────────────────────────────────────────────────────────

## 断开 _back_btn.pressed 的所有连接（GDScript4 没有 disconnect_all）
func _clear_back_btn_connections() -> void:
	for conn in _back_btn.pressed.get_connections():
		_back_btn.pressed.disconnect(conn["callable"])

func _configure_back_btn_to_slot_selection() -> void:
	_back_btn.visible = true
	if _back_btn.pressed.get_connections().size() > 0:
		_clear_back_btn_connections()
	_back_btn.text = "← 返回选材"
	_back_btn.pressed.connect(_back_to_last_slot_selection)

func _back_to_last_slot_selection() -> void:
	if _manager.state == null:
		_show_step_0()
		return
	_current_slot = max(_manager.state.recipe.slot_count() - 1, 0)
	_show_step_1(_current_slot)

func _add_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(lbl)
	return lbl

func _on_close() -> void:
	queue_free()
	closed.emit()
