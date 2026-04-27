class_name CraftingMaterial
extends RefCounted

var id: String
var display_name: String
var description: String
var tier: int = 1
var slot_type: String = ""      # "damage" / "range" / "special" / "element"
var contribution: int = 0
var element: String = ""         # "fire" / "ice" / "lightning" / ""

static func make(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_tier: int,
	p_slot_type: String,
	p_contribution: int,
	p_element: String = ""
) -> CraftingMaterial:
	var m := CraftingMaterial.new()
	m.id = p_id
	m.display_name = p_name
	m.description = p_desc
	m.tier = p_tier
	m.slot_type = p_slot_type
	m.contribution = p_contribution
	m.element = p_element
	return m