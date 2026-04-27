class_name CraftingManager
extends RefCounted

var state: CraftingState


func set_recipe_by_id(p_id: String) -> bool:
	var r: Recipe = RecipeDB.make_recipe(p_id)
	if r == null:
		return false
	if state == null:
		state = CraftingState.new(r)
	else:
		state.set_recipe(r)
	return true


static func pool_value_to_tier(v: int) -> String:
	if v <= 20:
		return "small"
	if v <= 50:
		return "medium"
	return "large"


func get_pool_contribution(_slot_type: String) -> int:
	if state == null or state.recipe == null:
		return 0
	var t: int = 0
	for i in state.fills.size():
		if str(state.recipe.slots[i]) != _slot_type:
			continue
		var mid: String = str(state.fills[i])
		if mid == "":
			continue
		t += MaterialDB.get_contribution(mid)
	return t


func preview_tiers() -> Dictionary:
	# For UI: show tier string per pool type for main; supports show "-"
	if state == null or state.recipe == null:
		return {}
	if state.recipe.core_type == "support":
		return {
			"main_line": "Support (fixed effect)"
		}
	var d_sum := 0
	var r_sum := 0
	var s_sum := 0
	for i in state.fills.size():
		var st: String = str(state.recipe.slots[i])
		var mid: String = str(state.fills[i])
		if mid == "":
			continue
		var c: int = MaterialDB.get_contribution(mid)
		match st:
			"damage":
				d_sum += c
			"range":
				r_sum += c
			"special":
				s_sum += c
			"element":
				pass
	return {
		"damage": [d_sum, pool_value_to_tier(d_sum)],
		"range": [r_sum, pool_value_to_tier(r_sum)],
		"special": [s_sum, pool_value_to_tier(s_sum)]
	}


func can_place_slot(slot_index: int, mat_id: String) -> String:
	if state == null or state.recipe == null:
		return "no recipe"
	if slot_index < 0 or slot_index >= state.fills.size():
		return "bad slot"
	if not MaterialDB.has(mat_id):
		return "unknown mat"
	var need_type: String = str(state.recipe.slots[slot_index])
	var mat := MaterialDB.get_data(mat_id)
	if str(mat.get("slot_type", "")) != need_type:
		return "wrong slot for material"
	# If we set this slot to mat_id, is workshop stash enough for the full multiset?
	var temp: Array = state.fills.duplicate()
	temp[slot_index] = mat_id
	var need: Dictionary = {}
	for s in temp:
		var id0: String = str(s)
		if id0 == "":
			continue
		need[id0] = need.get(id0, 0) + 1
	for k in need.keys():
		if GameState.get_workshop_count(str(k)) < int(need[k]):
			return "not enough in workshop stash"
	return ""


func set_slot(slot_index: int, mat_id: String) -> String:
	var err: String = can_place_slot(slot_index, mat_id)
	if err != "":
		return err
	state.fills[slot_index] = mat_id
	return ""


func clear_slot(slot_index: int) -> void:
	if state == null:
		return
	if slot_index >= 0 and slot_index < state.fills.size():
		state.fills[slot_index] = ""


func all_slots_filled() -> bool:
	if state == null:
		return false
	for v in state.fills:
		if str(v) == "":
			return false
	return true


func _count_materials_in_fills() -> Dictionary:
	var m: Dictionary = {}
	for s in state.fills:
		var id: String = str(s)
		if id == "":
			continue
		m[id] = m.get(id, 0) + 1
	return m


func can_settle() -> bool:
	if not all_slots_filled():
		return false
	var need: Dictionary = _count_materials_in_fills()
	for k in need.keys():
		if GameState.get_workshop_count(str(k)) < int(need[k]):
			return false
	return true


func settle() -> Core:
	if state == null or state.recipe == null:
		return null
	if not can_settle():
		return null
	var need2: Dictionary = _count_materials_in_fills()
	for k2 in need2.keys():
		GameState.remove_workshop_material(str(k2), int(need2[k2]))
	var r: Recipe = state.recipe
	var uid: int = int(Time.get_ticks_msec() + randi() % 10000)
	if r.core_type == "main":
		var d_total := 0
		var r_total := 0
		var s_total := 0
		var el := ""
		for i in r.slots.size():
			var st2: String = str(r.slots[i])
			var mid2: String = str(state.fills[i])
			var c2: int = MaterialDB.get_contribution(mid2)
			match st2:
				"damage":
					d_total += c2
				"range":
					r_total += c2
				"special":
					s_total += c2
				"element":
					var d3: Dictionary = MaterialDB.get_data(mid2)
					el = str(d3.get("element", ""))
		var dt: String = pool_value_to_tier(d_total)
		var rt3: String = pool_value_to_tier(r_total)
		var st3: String = pool_value_to_tier(s_total)
		var id_str: String = "%s_%d" % [r.id, uid]
		var c_main: Core = Core.make_main_from_tiers(
			id_str,
			r.display_name,
			r.attack_pattern,
			dt, rt3, st3,
			r.max_ammo,
			el,
			r.base_charge
		)
		GameState.owned_cores.append(c_main)
		return c_main
	var id_s: String = "%s_%d" % [r.id, uid]
	var c_sup: Core = Core.make_support(id_s, r.display_name, r.support_effect, r.support_value)
	GameState.owned_cores.append(c_sup)
	return c_sup
