extends Control

## 工作室库存查看:左栏材料仓库(按种类分组计数),右栏合成产物。
## placeholder UI(纯代码),之后换 2D 美术。

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -550; panel.offset_top = -350
	panel.offset_right = 550; panel.offset_bottom = 350
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.16, 1.0)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.42, 0.6)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20; sb.content_margin_right = 20
	sb.content_margin_top = 16; sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title := Label.new()
	title.text = "📦 库存"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)
	root.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	cols.add_child(_make_column("材料仓库", _fill_materials))
	cols.add_child(_make_column("合成产物", _fill_products))

	var close_btn := Button.new()
	close_btn.text = "关闭 (Esc)"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.pressed.connect(_close)
	root.add_child(close_btn)

func _make_column(header: String, fill_fn: Callable) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	var h := Label.new()
	h.text = header
	h.add_theme_font_size_override("font_size", 17)
	h.add_theme_color_override("font_color", Color(0.85, 0.8, 0.55))
	col.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	scroll.add_child(body)
	fill_fn.call(body)
	return col

func _fill_materials(body: VBoxContainer) -> void:
	var groups: Dictionary = {}
	for inst in GameState.workshop_items:
		var bid: String = (inst as MaterialInstance).base_id
		groups[bid] = int(groups.get(bid, 0)) + 1
	if groups.is_empty():
		body.add_child(_dim_label("(空)"))
		return
	var ids: Array = groups.keys()
	ids.sort()
	for bid in ids:
		var mat: CraftingMaterial = MaterialDB.get_material(bid)
		if mat == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_lbl := Label.new()
		name_lbl.text = "%s ×%d" % [mat.display_name, int(groups[bid])]
		name_lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(name_lbl)
		var tag_lbl := Label.new()
		tag_lbl.text = " ".join(mat.tags)
		tag_lbl.add_theme_font_size_override("font_size", 12)
		tag_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
		row.add_child(tag_lbl)
		body.add_child(row)

func _fill_products(body: VBoxContainer) -> void:
	if GameState.owned_items.is_empty():
		body.add_child(_dim_label("(还没合成任何东西)"))
		return
	for it in GameState.owned_items:
		var item: Core = it
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		var head := Label.new()
		var extra := ""
		if item.is_consumable():
			extra = "  剩 %d/%d 次" % [item.current_uses, item.max_uses]
		head.text = "%s  [%s]%s" % [item.display_name, _type_cn(item.product_type), extra]
		head.add_theme_font_size_override("font_size", 14)
		line.add_child(head)
		var parts: Array[String] = []
		if not item.elements.is_empty():
			parts.append("元素 " + " ".join(item.elements))
		if item.signature_unlocked and item.signature_name != "":
			parts.append("★" + item.signature_name)
		if not item.tag_words.is_empty():
			parts.append("词条 " + " ".join(item.tag_words))
		if not parts.is_empty():
			var d := Label.new()
			d.text = "   " + "  ｜  ".join(parts)
			d.add_theme_font_size_override("font_size", 11)
			d.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
			line.add_child(d)
		body.add_child(line)

func _type_cn(pt: String) -> String:
	match pt:
		"core": return "核"
		"potion": return "药剂"
		"charm": return "护符"
		"trade": return "交易品"
	return pt

func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	return l

func _close() -> void:
	closed.emit()
	queue_free()
