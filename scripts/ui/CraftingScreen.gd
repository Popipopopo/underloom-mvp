extends Control

signal closed

var _manager: CraftingManager = CraftingManager.new()
var _recipe_ids: Array = []

var _recipe_option: OptionButton
var _slot_vbox: VBoxContainer
var _summary_label: Label
var _message_label: Label
var _craft_button: Button
var _slot_option_buttons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, 0, false)
	_build_ui()
	_recipe_ids.clear()
	for d in RecipeDB.get_all():
		_recipe_ids.append(str(d.get("id", "")))
	_recipe_option.clear()
	if _recipe_ids.is_empty():
		_message_label.text = "No recipes in DB"
		_craft_button.disabled = true
		return
	for id in _recipe_ids:
		_recipe_option.add_item(id)
	_on_recipe_selected(0)
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(600, 460)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -230.0
	panel.offset_right = 300.0
	panel.offset_bottom = 230.0
	add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16.0
	v.offset_top = 12.0
	v.offset_right = -16.0
	v.offset_bottom = -12.0
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Crafting (stable / pool -> tiers)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)

	_recipe_option = OptionButton.new()
	_recipe_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_option.item_selected.connect(_on_recipe_selected)
	v.add_child(_recipe_option)

	_slot_vbox = VBoxContainer.new()
	_slot_vbox.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.add_child(_slot_vbox)
	v.add_child(scroll)

	_summary_label = Label.new()
	_summary_label.text = "Pools: -"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary_label)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_message_label)

	_craft_button = Button.new()
	_craft_button.text = "Craft (consume materials)"
	_craft_button.pressed.connect(_on_craft)
	v.add_child(_craft_button)

	var close_row := HBoxContainer.new()
	var b := Button.new()
	b.text = "Close (or Esc)"
	b.pressed.connect(_on_close)
	close_row.add_child(b)
	v.add_child(close_row)


func _on_close() -> void:
	queue_free()
	closed.emit()


func _on_recipe_selected(index: int) -> void:
	for n in _slot_vbox.get_children():
		n.queue_free()
	_slot_option_buttons.clear()
	if index < 0 or index >= _recipe_ids.size():
		return
	_manager.set_recipe_by_id(str(_recipe_ids[index]))
	if _manager.state == null or _manager.state.recipe == null:
		return
	for i in _manager.state.recipe.slots.size():
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = "Slot %d: [%s]" % [i, str(_manager.state.recipe.slots[i])]
		lab.custom_minimum_size = Vector2(200, 0)
		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.set_meta("slot_i", i)
		# Signal passes (selected_index) first, then bound args: (selected_index, slot_i).
		opt.item_selected.connect(_on_slot_material_selected.bind(i))
		row.add_child(lab)
		row.add_child(opt)
		_slot_vbox.add_child(row)
		_slot_option_buttons.append(opt)
		_refill_option_for_slot(i)
	_sync_all_options()
	_refresh_all()


func _refill_option_for_slot(slot_i: int) -> void:
	if slot_i < 0 or slot_i >= _slot_option_buttons.size():
		return
	var opt: OptionButton = _slot_option_buttons[slot_i]
	opt.clear()
	opt.add_item("-- empty --")
	opt.set_item_metadata(0, "")
	if _manager.state == null or _manager.state.recipe == null:
		return
	var st_need: String = str(_manager.state.recipe.slots[slot_i])
	for mid in MaterialDB.get_all_ids():
		if str(MaterialDB.get_data(mid).get("slot_type", "")) != st_need:
			continue
		# List every type-matching mat (with workshop stock count). Do not use can_place here:
		# that also checks full workshop stash; at 0 stock it hid the whole list.
		var cnt: int = GameState.get_workshop_count(str(mid))
		opt.add_item("%s  (x%d)" % [str(mid), cnt])
		var new_i: int = opt.get_item_count() - 1
		opt.set_item_metadata(new_i, str(mid))


func _sync_all_options() -> void:
	if _manager.state == null:
		return
	for i in _slot_option_buttons.size():
		var opt: OptionButton = _slot_option_buttons[i]
		opt.set_block_signals(true)
		var cur: String = str(_manager.state.fills[i])
		if cur == "":
			opt.select(0)
			opt.set_block_signals(false)
			continue
		var found: bool = false
		for it in range(opt.item_count):
			if opt.get_item_text(it) == "":
				continue
			if str(opt.get_item_metadata(it)) == cur:
				opt.select(it)
				found = true
				break
		if not found:
			opt.select(0)
		opt.set_block_signals(false)


func _on_slot_material_selected(selected_index: int, slot_i: int) -> void:
	_message_label.text = ""
	if slot_i < 0 or slot_i >= _slot_option_buttons.size():
		return
	var opt: OptionButton = _slot_option_buttons[slot_i]
	var it: int = selected_index
	if it < 0:
		return
	var meta: Variant = opt.get_item_metadata(it)
	if it == 0 or str(meta) == "":
		_manager.clear_slot(slot_i)
	else:
		var err3: String = _manager.set_slot(slot_i, str(meta))
		if err3 != "":
			_message_label.text = err3
			_sync_all_options()
			return
	for j2 in _slot_option_buttons.size():
		_refill_option_for_slot(j2)
	_sync_all_options()
	_refresh_all()


func _refresh_all() -> void:
	if _manager.state == null or _manager.state.recipe == null:
		_craft_button.disabled = true
		_summary_label.text = "—"
		return
	var t: Dictionary = _manager.preview_tiers()
	if t.has("main_line"):
		_summary_label.text = t["main_line"]
	else:
		_summary_label.text = "Dmg %s  |  Rng %s  |  Spe %s" % [
			str(t.get("damage", ["?","?"])),
			str(t.get("range", ["?","?"])),
			str(t.get("special", ["?","?"])),
		]
	_craft_button.disabled = not _manager.can_settle()


func _on_craft() -> void:
	_message_label.text = ""
	if not _manager.can_settle():
		_message_label.text = "Fill all slots; check workshop stash (same mat needs x2 if two slots use it)"
		return
	var result: Core = _manager.settle()
	if result == null:
		_message_label.text = "Craft failed"
		return
	print("[Crafting] core: %s" % result.id)
	_message_label.text = "Created: %s" % str(result.id)
	if _manager.state:
		_manager.state.reset_fills()
	for s in _slot_option_buttons.size():
		_refill_option_for_slot(s)
	_sync_all_options()
	_refresh_all()
