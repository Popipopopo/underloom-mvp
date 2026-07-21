extends Control

## 地点探索界面(简单版):踩到探索点后不再自动触发,而是进入地点、主动选行动。
## MVP 只做采集点:「搜刮」耗 1 天换材料(最多 2 次),「离开」返回地图。
## 之后遗迹/事件/交易等类型共用此框架(CE1 式 地点+选项)。

signal closed

const MAX_SEARCHES := 2
const GATHER_POOL := ["白蘑菇", "苔藓", "史莱姆凝胶", "风化石英", "草药"]

var site_type: String = "gather"
var _searches_left: int = MAX_SEARCHES

var _result_box: VBoxContainer
var _status_lbl: Label
var _search_btn: Button

func setup(p_type: String) -> void:
	site_type = p_type

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_leave()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -430; panel.offset_top = -310
	panel.offset_right = 430; panel.offset_bottom = 310
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.16, 1.0)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.42, 0.6)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 22; sb.content_margin_right = 22
	sb.content_margin_top = 16; sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "✿ 采集点"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	# 地点插画占位(之后换 2D 美术,像 CE1 的地点场景图)
	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(0, 150)
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.12, 0.18, 0.14, 1.0)
	asb.border_width_left = 2; asb.border_width_right = 2
	asb.border_width_top = 2; asb.border_width_bottom = 2
	asb.border_color = Color(0.3, 0.5, 0.35)
	asb.corner_radius_top_left = 6; asb.corner_radius_top_right = 6
	asb.corner_radius_bottom_left = 6; asb.corner_radius_bottom_right = 6
	art.add_theme_stylebox_override("panel", asb)
	var art_lbl := Label.new()
	art_lbl.text = "[ 地点插画 ]"
	art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.72, 0.6))
	art.add_child(art_lbl)
	root.add_child(art)

	var desc := Label.new()
	desc.text = "洞壁间生着成片的菌菇与苔藓,石缝里透出微光。\n看起来能搜出些有用的东西。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	root.add_child(desc)

	root.add_child(HSeparator.new())

	# 搜刮结果区
	_result_box = VBoxContainer.new()
	_result_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_box.add_theme_constant_override("separation", 4)
	root.add_child(_result_box)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	root.add_child(_status_lbl)

	root.add_child(HSeparator.new())

	# 选项
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	root.add_child(btns)

	_search_btn = Button.new()
	_search_btn.custom_minimum_size = Vector2(240, 46)
	_search_btn.pressed.connect(_on_search)
	btns.add_child(_search_btn)

	var leave_btn := Button.new()
	leave_btn.text = "离开 (Esc)"
	leave_btn.custom_minimum_size = Vector2(160, 46)
	leave_btn.pressed.connect(_on_leave)
	btns.add_child(leave_btn)

func _on_search() -> void:
	if _searches_left <= 0:
		return
	if GameState.is_backpack_full():
		_add_result("背包满了,装不下更多东西。", Color(0.9, 0.7, 0.4))
		_refresh()
		return
	GameState.day += 1
	_searches_left -= 1
	var mat: CraftingMaterial = MaterialDB.get_material(GATHER_POOL[randi() % GATHER_POOL.size()])
	if mat != null:
		var inst := MaterialInstance.roll_from(mat, 0.5)
		GameState.add_backpack_item(inst)
		_add_result("搜出了 %s(元素 %s)" % [mat.display_name, " ".join(inst.elements)], Color(0.6, 0.9, 0.6))
	_refresh()

func _add_result(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = "· " + text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	_result_box.add_child(lbl)

func _refresh() -> void:
	_status_lbl.text = "第 %d 天    背包 %d/%d" % [
		GameState.day, GameState.backpack_items.size(), GameState.BACKPACK_CAP]
	_search_btn.text = "🔍 搜刮(耗 1 天,剩 %d 次)" % _searches_left
	_search_btn.disabled = _searches_left <= 0 or GameState.is_backpack_full()

func _on_leave() -> void:
	closed.emit()
