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
var _current_step: int = 0   # 0=配方 1=材料 3=点数分配 4=元素干涉 5=tag共鸣 7=结果
var _current_slot: int = 0   # 用于Step1逐槽推进
var _alloc_elem: int = 0     # 点数分配步骤：当前分给元素保留点的数量
var _first_tag_resonance_triggered: bool = false

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
	_title_label.text = "魔力核 — 要做什么呢"
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
		sub.text = "槽位: " + " / ".join(recipe.slot_tags)
		sub.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		sub.add_theme_font_size_override("font_size", 12)
		_content.add_child(btn)
		_content.add_child(sub)
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

	# 材料候选网格
	var candidates: Array = MaterialDB.get_by_tag(slot_tag)
	if candidates.is_empty():
		_add_label("没有符合条件的材料 [%s]" % slot_tag)
		return

	candidates.sort_custom(func(a, b): return (a as CraftingMaterial).lv < (b as CraftingMaterial).lv)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_content.add_child(flow)

	# v1.1 方案B：每种材料一张卡，显示元素"潜力"（上限），真实 roll 在入槽后
	# 显示在上方槽位条里——入槽即所得，不满意可返回换材料重掷
	for mat_obj in candidates:
		var mat: CraftingMaterial = mat_obj as CraftingMaterial
		var stock: int = GameState.get_workshop_count(mat.id)
		var card := _make_item_card(mat, stock > 0)
		flow.add_child(card)
		var btn: Button = card.find_child("SelectBtn", true, false) as Button
		if btn != null and stock > 0:
			btn.pressed.connect(_on_material_selected.bind(slot_index, mat.id))

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
	var filled_id: String = str(_manager.state.fills[slot_i]) if _manager.state.fills.size() > slot_i else ""
	var is_active: bool = slot_i == active_slot
	var is_filled: bool = filled_id != ""

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
		# 已选材料名 + 真实 roll 结果（v1.1 方案B：入槽即所得）
		var mat: CraftingMaterial = MaterialDB.get_material(filled_id)
		if mat != null:
			var name_lbl := Label.new()
			name_lbl.text = mat.display_name
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(name_lbl)

			var el_row := HBoxContainer.new()
			el_row.add_theme_constant_override("separation", 2)
			el_row.alignment = BoxContainer.ALIGNMENT_CENTER
			for el in _manager.get_slot_roll(slot_i):
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(8, 8)
				dot.color = EL_COLOR.get(el, EL_COLOR_DEFAULT)
				el_row.add_child(dot)
			vbox.add_child(el_row)
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

## 单个材料格子（紧凑卡片，适合 flow 网格）
## 元素点显示"潜力"：保底元素实色，其余可能出的元素半透明
func _make_item_card(mat: CraftingMaterial, available: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 0)

	# 背景样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.22, 1.0) if available else Color(0.10, 0.10, 0.13, 1.0)
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.38, 0.65, 1.0) if available else Color(0.28, 0.28, 0.35, 1.0)
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
	if not available:
		name_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	vbox.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv%d　库存 %d" % [mat.lv, GameState.get_workshop_count(mat.id)]
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	vbox.add_child(lv_lbl)

	# 元素点（小彩色方块）——显示潜力上限：保底 1 个实色，其余半透明表示"可能出"
	var el_row := HBoxContainer.new()
	el_row.add_theme_constant_override("separation", 3)
	vbox.add_child(el_row)
	var default_shown: bool = false
	for el in mat.elements_max.keys():
		for _j in range(int(mat.elements_max[el])):
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(10, 10)
			var col: Color = EL_COLOR.get(el, EL_COLOR_DEFAULT) if available else Color(0.3, 0.3, 0.3)
			if el == mat.default_element and not default_shown:
				default_shown = true   # 保底那 1 个实色
			else:
				col.a = 0.4            # 其余是可能性
			dot.color = col
			el_row.add_child(dot)

	# tags（小字）
	var tag_lbl := Label.new()
	tag_lbl.text = " ".join(mat.tags)
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.75, 0.5) if available else Color(0.35, 0.35, 0.35))
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tag_lbl)

	# 选择按钮
	var btn := Button.new()
	btn.name = "SelectBtn"
	btn.text = "选择" if available else "缺货"
	btn.disabled = not available
	btn.custom_minimum_size = Vector2(0, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn)

	return card

func _on_material_selected(slot_index: int, mat_id: String) -> void:
	var err: String = _manager.set_slot(slot_index, mat_id)
	if err != "":
		_add_label("错误: " + err)
		return
	_current_slot = slot_index + 1
	if _current_slot < _manager.state.recipe.slot_count():
		_show_step_1(_current_slot)
	else:
		# All slots filled — 汇入元素池 + 算品质，然后先分配点数（v1.1）
		_manager.roll_elements()
		_manager.compute_lv()
		_show_step_allocate()

# ── Step 3: 点数分配（v1.1 §2.4）───────────────────────────────────────────────
# 总点数由品质决定，玩家自主分给「元素保留点」和「共鸣保留点」：
# 想稳就多拿元素点，想赌 tag 组合就多拿共鸣点。
func _show_step_allocate() -> void:
	_current_step = 3
	_clear_content()
	_title_label.text = "分配保留点 — 品质 %s（共 %d 点）" % [
		_manager.get_quality_name(), _manager.total_pts]
	_slot_bar.visible = true
	_update_slot_bar(-1)
	_configure_back_btn_to_slot_selection()

	# 默认分配：约 2/3 给元素（与 v1 固定值一致），玩家可调
	_alloc_elem = int((_manager.total_pts + 1) / 2.0)

	var hint := Label.new()
	hint.text = "元素保留点用来锁定想要的元素；共鸣保留点用来触发额外的 Tag 组合。\n第一个 Tag 共鸣永远免费。"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)

	_content.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)

	var alloc_lbl := Label.new()
	alloc_lbl.name = "AllocLabel"
	alloc_lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(alloc_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(btn_row)

	var minus_btn := Button.new()
	minus_btn.text = "◀ 元素-1"
	minus_btn.custom_minimum_size = Vector2(110, 36)
	minus_btn.pressed.connect(_on_alloc_changed.bind(-1, alloc_lbl))
	btn_row.add_child(minus_btn)

	var plus_btn := Button.new()
	plus_btn.text = "元素+1 ▶"
	plus_btn.custom_minimum_size = Vector2(110, 36)
	plus_btn.pressed.connect(_on_alloc_changed.bind(1, alloc_lbl))
	btn_row.add_child(plus_btn)

	_refresh_alloc_label(alloc_lbl)

	_content.add_child(HSeparator.new())

	var confirm_btn := Button.new()
	confirm_btn.text = "就这样，开始干涉 →"
	confirm_btn.pressed.connect(_on_alloc_confirm)
	_content.add_child(confirm_btn)

func _refresh_alloc_label(alloc_lbl: Label) -> void:
	alloc_lbl.text = "元素保留点 %d　|　共鸣保留点 %d" % [
		_alloc_elem, _manager.total_pts - _alloc_elem]

func _on_alloc_changed(delta: int, alloc_lbl: Label) -> void:
	_alloc_elem = clampi(_alloc_elem + delta, 0, _manager.total_pts)
	_refresh_alloc_label(alloc_lbl)

func _on_alloc_confirm() -> void:
	var err: String = _manager.allocate_points(_alloc_elem, _manager.total_pts - _alloc_elem)
	if err != "":
		_add_label("错误: " + err)
		return
	_show_step_4()

# ── Step 4: 元素干涉 ──────────────────────────────────────────────────────────
# 元素默认灰色（inactive），花元素保留点勾选保留，只有勾选的才计入共鸣
func _show_step_4() -> void:
	_current_step = 4
	_clear_content()
	_title_label.text = "元素干涉 — 选择要保留的元素"
	_slot_bar.visible = true
	_update_slot_bar(-1)
	_back_btn.visible = true
	if _back_btn.pressed.get_connections().size() > 0:
		_clear_back_btn_connections()
	_back_btn.text = "← 重新分配点数"
	_back_btn.pressed.connect(_show_step_allocate)

	# 左右分栏
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(split)

	# 左栏：点数 + 元素格子
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	# 点数显示（动态，名字引用它方便刷新）
	var pts_lbl := Label.new()
	pts_lbl.name = "PtsLabel"
	pts_lbl.add_theme_font_size_override("font_size", 13)
	left.add_child(pts_lbl)

	var hint := Label.new()
	hint.text = "点击灰色元素点勾选保留，再点取消"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	left.add_child(hint)


	var dots_flow := HFlowContainer.new()
	dots_flow.name = "DotsFlow"
	dots_flow.add_theme_constant_override("h_separation", 6)
	dots_flow.add_theme_constant_override("v_separation", 6)
	left.add_child(dots_flow)

	# 重炼：锁定的保留，未锁定的重掷（v1.1 §2.4，每次合成 1 次）
	var reroll_btn := Button.new()
	reroll_btn.name = "RerollBtn"
	reroll_btn.text = "🎲 重炼（剩 %d 次）" % _manager.reroll_charges
	reroll_btn.disabled = _manager.reroll_charges <= 0
	reroll_btn.tooltip_text = "保留已勾选的元素，重新 roll 其余部分"
	left.add_child(reroll_btn)

	# 右栏：共鸣列表
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(200, 0)
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)

	var res_title := Label.new()
	res_title.text = "可触发元素共鸣："
	res_title.add_theme_font_size_override("font_size", 13)
	right.add_child(res_title)

	var res_list := VBoxContainer.new()
	res_list.name = "ResonanceList"
	right.add_child(res_list)

	# 确认按钮
	var confirm_btn := Button.new()
	confirm_btn.text = "确认 →"
	confirm_btn.pressed.connect(_on_step4_confirm)
	_content.add_child(confirm_btn)

	reroll_btn.pressed.connect(_on_reroll_pressed.bind(reroll_btn, dots_flow, res_list, pts_lbl))

	_rebuild_element_dots(dots_flow, res_list, pts_lbl)

func _on_reroll_pressed(reroll_btn: Button, dots_flow: HFlowContainer, res_list: VBoxContainer, pts_lbl: Label) -> void:
	if not _manager.reroll_unlocked():
		return
	reroll_btn.text = "🎲 重炼（剩 %d 次）" % _manager.reroll_charges
	reroll_btn.disabled = _manager.reroll_charges <= 0
	_rebuild_element_dots(dots_flow, res_list, pts_lbl)

func _rebuild_element_dots(dots_flow: HFlowContainer, res_list: VBoxContainer, pts_lbl: Label) -> void:
	for ch in dots_flow.get_children():
		ch.queue_free()

	var remaining_pts: int = _manager.element_retain_pts

	# 更新点数标签
	pts_lbl.text = "元素保留点剩余: %d  （已选: %d）" % [
		remaining_pts, _manager.locked_count()]

	for i in _manager.rolled_elements.size():
		var entry: Dictionary = _manager.rolled_elements[i]
		var el: String = entry["element"]
		var is_locked: bool = entry["state"] == "locked"

		var dot := Button.new()
		dot.custom_minimum_size = Vector2(52, 38)
		dot.text = el

		if is_locked:
			# 已保留：亮色 + 勾
			dot.text = "✓ " + el
			dot.modulate = EL_COLOR.get(el, EL_COLOR_DEFAULT)
		else:
			# 未保留：灰色
			dot.text = el
			dot.modulate = Color(0.45, 0.45, 0.5, 0.7)
			# 没点数了就禁止点击
			dot.disabled = (remaining_pts <= 0)

		dot.pressed.connect(_on_element_dot_pressed.bind(i, dots_flow, res_list, pts_lbl))
		dots_flow.add_child(dot)

	_rebuild_resonance_list(res_list)

func _rebuild_resonance_list(res_list: VBoxContainer) -> void:
	for ch in res_list.get_children():
		ch.queue_free()
	var resonances: Array[String] = _manager.active_resonances()
	if resonances.is_empty():
		var lbl := Label.new()
		lbl.text = "（暂无，继续勾选元素点）"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.add_theme_font_size_override("font_size", 12)
		res_list.add_child(lbl)
	else:
		for res_name in resonances:
			var lbl := Label.new()
			lbl.text = "✦ " + res_name
			lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
			res_list.add_child(lbl)

func _on_element_dot_pressed(idx: int, dots_flow: HFlowContainer, res_list: VBoxContainer, pts_lbl: Label) -> void:
	_manager.toggle_lock(idx)
	_rebuild_element_dots(dots_flow, res_list, pts_lbl)

func _on_step4_confirm() -> void:
	_show_step_5()

# ── Step 5: Tag共鸣 ───────────────────────────────────────────────────────────
func _show_step_5() -> void:
	_current_step = 5
	_clear_content()
	_title_label.text = "Tag共鸣  (共鸣保留点: %d)" % _manager.resonance_retain_pts
	_slot_bar.visible = true
	_update_slot_bar(-1)
	_back_btn.visible = true
	if _back_btn.pressed.get_connections().size() > 0:
		_clear_back_btn_connections()
	_back_btn.text = "← 返回元素干涉"
	_back_btn.pressed.connect(_show_step_4)

	var info := Label.new()
	info.text = "第一个共鸣免费触发，之后每个消耗1共鸣保留点。可以选择不触发。"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(info)

	_content.add_child(HSeparator.new())
	_refresh_step5_list()

func _refresh_step5_list() -> void:
	# Remove everything after the first HSeparator
	var children := _content.get_children()
	var past_sep: bool = false
	for ch in children:
		if not past_sep:
			if ch is HSeparator:
				past_sep = true
			continue
		ch.queue_free()

	await get_tree().process_frame   # let queue_free complete

	var available: Array[Dictionary] = _manager.available_tag_resonances()
	if available.is_empty():
		_add_label("没有可触发的Tag共鸣")
	else:
		for res in available:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			_content.add_child(row)

			var name_lbl := Label.new()
			name_lbl.text = "✦ %s  (需要: %s)" % [res["name"], ", ".join(res["tags"])]
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)

			var btn := Button.new()
			btn.text = "触发"
			var is_free: bool = not _first_tag_resonance_triggered
			var can_afford: bool = is_free or _manager.resonance_retain_pts > 0
			btn.disabled = not can_afford
			btn.pressed.connect(_on_trigger_tag_resonance.bind(res["name"]))
			row.add_child(btn)

	# Triggered list
	if not _manager.triggered_tag_resonances.is_empty():
		_content.add_child(HSeparator.new())
		var done_lbl := Label.new()
		done_lbl.text = "已触发: " + ", ".join(_manager.triggered_tag_resonances)
		done_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_content.add_child(done_lbl)

	_content.add_child(HSeparator.new())

	var next_btn := Button.new()
	next_btn.text = "完成，进入结果 →"
	next_btn.pressed.connect(_on_step5_confirm)
	_content.add_child(next_btn)

func _on_trigger_tag_resonance(resonance_name: String) -> void:
	var is_free: bool = not _first_tag_resonance_triggered
	var err: String = _manager.trigger_tag_resonance(resonance_name, is_free)
	if err != "":
		return
	_first_tag_resonance_triggered = true
	_refresh_step5_list()

func _on_step5_confirm() -> void:
	# Step 6: roll remaining elements
	_manager.roll_remaining_elements()
	_show_step_7()

# ── Step 7: 结果展示 ──────────────────────────────────────────────────────────
func _show_step_7() -> void:
	_current_step = 7
	_clear_content()
	_title_label.text = "合成结果"

	var core: Core = _manager.build_core()
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

	_add_result_row("品质", "%s  Lv%d" % [_manager.get_quality_name(), core.result_lv])
	_add_result_row("威力 / 直径", _manager.get_power_label())

	# Element resonances
	var el_res: Array[String] = _manager.triggered_element_resonances()
	if el_res.is_empty():
		_add_result_row("元素词条", "（无）")
	else:
		_add_result_row("元素词条", ", ".join(el_res))

	# Tag words
	if core.tag_words.is_empty():
		_add_result_row("Tag词条", "（无）")
	else:
		_add_result_row("Tag词条", ", ".join(core.tag_words))

	# Final elements breakdown
	var final_el: Array[String] = _manager.final_elements()
	if not final_el.is_empty():
		_add_result_row("最终元素", ", ".join(final_el))

	_content.add_child(HSeparator.new())

	var again_btn := Button.new()
	again_btn.text = "再合成一个"
	again_btn.pressed.connect(_show_step_0)
	_content.add_child(again_btn)

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
